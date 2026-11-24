#!/usr/bin/env node
'use strict';

const childProcess = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');
const {
  queueDir,
  listItems,
  tryReadItem,
  updateItem,
  moveToStale,
  removeItem,
} = require('./lib/queue-store');
const { decideAction } = require('./lib/decide');
const { RATE_LIMIT_PATTERN, parseResetTime, inspectTranscript } = require('./lib/session');

const RESUME_PROMPT =
  'Você foi interrompido por ter atingido o limite de uso ou por um erro. ' +
  'Se o problema já foi resolvido, retome exatamente de onde parou e ' +
  'continue a tarefa em andamento até concluir ou até realmente precisar ' +
  'de uma decisão do usuário que só ele pode tomar.';

// Clock slack between the last transcript entry and the StopFailure hook.
const ACTIVITY_GRACE_MS = 5000;

// Only the tail of a failed run is inspected for the rate-limit message: the
// resumed session may legitimately print "rate limit" anywhere in its work.
const RATE_LIMIT_TAIL_LINES = 20;

const DEFAULT_TIMEOUT_MS = 30 * 60 * 1000;
const DEFAULT_MAX_ATTEMPTS = 5;

function positiveIntFromEnv(name, fallback) {
  const raw = process.env[name];
  const value = Number.parseInt(raw, 10);
  return Number.isFinite(value) && value > 0 ? value : fallback;
}

function timeoutMs() {
  return positiveIntFromEnv('CLAUDE_CONTINUIDADE_TIMEOUT_MS', DEFAULT_TIMEOUT_MS);
}

function maxAttempts() {
  return positiveIntFromEnv('CLAUDE_CONTINUIDADE_MAX_ATTEMPTS', DEFAULT_MAX_ATTEMPTS);
}

function tail(text, lines) {
  return String(text).split(/\r?\n/).slice(-lines).join('\n');
}

// `claude -p --output-format json` prints a single result object with an
// `is_error` flag. Returns it when the stdout (or its last line) parses,
// otherwise null (older CLI, stub binaries, crashes before any output).
function parseResultJson(stdout) {
  const text = String(stdout || '').trim();
  if (!text) return null;
  const candidates = [text, text.split(/\r?\n/).pop()];
  for (const candidate of candidates) {
    try {
      const parsed = JSON.parse(candidate);
      if (parsed && typeof parsed === 'object' && 'is_error' in parsed) return parsed;
    } catch (err) {
      // not JSON; try the next candidate
    }
  }
  return null;
}

// Classifies a finished spawnSync result:
//   { ok: true }                          resumed
//   { ok: false, reason: 'rate-limit' }   still rate limited (does not count as an attempt)
//   { ok: false, reason: 'timeout' }      killed after the timeout
//   { ok: false, reason: 'error' }        any other failure
function classifyResult(result) {
  const output = String(result.stdout || '') + String(result.stderr || '');

  if (result.error && result.error.code === 'ETIMEDOUT') {
    return { ok: false, reason: 'timeout', output };
  }
  if (result.error) {
    return { ok: false, reason: 'error', output: output || String(result.error.message) };
  }
  if (result.signal) {
    return { ok: false, reason: 'error', output };
  }

  const structured = parseResultJson(result.stdout);
  if (result.status === 0 && (!structured || structured.is_error !== true)) {
    return { ok: true, output };
  }

  const errorText = structured
    ? String(structured.result || '') + '\n' + String(structured.subtype || '')
    : tail(output, RATE_LIMIT_TAIL_LINES);
  const reason = RATE_LIMIT_PATTERN.test(errorText) ? 'rate-limit' : 'error';
  return { ok: false, reason, output };
}

function isDefaultConfigDir(dir) {
  return path.resolve(dir) === path.join(os.homedir(), '.claude');
}

function attemptResume(item, claudeBin, cwd) {
  const bin = claudeBin || process.env.CLAUDE_CONTINUIDADE_BIN || 'claude';
  const env = Object.assign({}, process.env);
  // Setting the variable to the default directory is not a no-op: it makes the
  // CLI read <dir>/.claude.json instead of ~/.claude.json.
  if (item.config_dir && !isDefaultConfigDir(item.config_dir)) {
    env.CLAUDE_CONFIG_DIR = item.config_dir;
  } else {
    delete env.CLAUDE_CONFIG_DIR;
  }
  const result = childProcess.spawnSync(
    bin,
    [
      '-r',
      item.session_id,
      '-p',
      RESUME_PROMPT,
      '--permission-mode',
      'acceptEdits',
      '--output-format',
      'json',
    ],
    { cwd: cwd || item.cwd, env, windowsHide: true, maxBuffer: 64 * 1024 * 1024, encoding: 'utf8', timeout: timeoutMs(), killSignal: 'SIGTERM' }
  );
  return classifyResult(result);
}

function run(now, claudeBin) {
  const results = [];
  // session_id -> [{ file, item }] of items that are still worth retrying.
  const bySession = new Map();

  for (const file of listItems()) {
    const { item, error } = tryReadItem(file);
    if (error) {
      moveToStale(file);
      results.push({ file, action: 'stale-corrupt', output: String(error.message) });
      continue;
    }
    const action = decideAction(item, now);
    if (action === 'invalid' || action === 'stale-missing-cwd' || action === 'stale-expired') {
      moveToStale(file);
      results.push({ file, action });
      continue;
    }
    if (!bySession.has(item.session_id)) bySession.set(item.session_id, []);
    bySession.get(item.session_id).push({ file, item });
  }

  const limit = maxAttempts();
  for (const entries of bySession.values()) {
    // Several StopFailure events for the same session collapse into a single
    // resume: keep the most recent item, carry over the highest attempt
    // count, and drop the redundant ones.
    entries.sort((a, b) => (a.item.queued_at || 0) - (b.item.queued_at || 0));
    const primary = entries[entries.length - 1];
    const priorAttempts = Math.max(...entries.map((e) => Number(e.item.attempts) || 0));
    for (const duplicate of entries.slice(0, -1)) {
      removeItem(duplicate.file);
      results.push({ file: duplicate.file, action: 'duplicate' });
    }

    const session = inspectTranscript(primary.item.transcript_path);
    const reference = Math.max(primary.item.queued_at || 0, primary.item.last_attempt_at || 0);
    if (session.lastActivity > reference + ACTIVITY_GRACE_MS) {
      // Somebody already continued this session by hand: never compete with it.
      moveToStale(primary.file);
      results.push({ file: primary.file, action: 'stale-already-continued' });
      continue;
    }

    const firstQueuedAt = Math.min(
      primary.item.queued_at,
      ...entries.map((e) => e.item.first_queued_at || Infinity)
    );
    const retryAfter =
      primary.item.error === 'rate_limit'
        ? parseResetTime(primary.item.last_assistant_message, primary.item.queued_at)
        : null;
    if (retryAfter && now < retryAfter) {
      // Persist what the removed duplicates carried.
      updateItem(
        primary.file,
        Object.assign({}, primary.item, { attempts: priorAttempts, first_queued_at: firstQueuedAt })
      );
      results.push({ file: primary.file, action: 'waiting-reset', retryAfter });
      continue;
    }

    const cwd = session.cwd && fs.existsSync(session.cwd) ? session.cwd : primary.item.cwd;
    const { ok, reason, output } = attemptResume(primary.item, claudeBin, cwd);
    if (ok) {
      removeItem(primary.file);
      results.push({ file: primary.file, action: 'resumed', output });
      continue;
    }

    // A rate-limited run is expected to fail until the limit resets (which
    // can take hours); only the 48h age limit in decide.js bounds it. Real
    // errors and timeouts count towards the attempt limit.
    const attempts = reason === 'rate-limit' ? priorAttempts : priorAttempts + 1;
    if (attempts >= limit) {
      moveToStale(primary.file);
      results.push({ file: primary.file, action: 'stale-max-attempts', reason, attempts, output });
      continue;
    }
    updateItem(primary.file, Object.assign({}, primary.item, {
      attempts,
      first_queued_at: firstQueuedAt,
      last_attempt_at: Math.max(now, Date.now()),
    }));
    results.push({ file: primary.file, action: 'still-blocked', reason, attempts, output });
  }
  return results;
}

if (require.main === module) {
  const log = (text) =>
    fs.appendFileSync(path.join(queueDir(), 'watcher.log'), `${new Date().toISOString()} ${text}\n`);
  try {
    const results = run(Date.now());
    log(`run items=${results.length}`);
    for (const r of results) {
      log(JSON.stringify(Object.assign({}, r, { output: r.output && tail(r.output, 5).slice(-500) })));
    }
  } catch (err) {
    log(`fatal ${err.stack}`);
    process.exitCode = 1;
  }
}

module.exports = {
  run,
  attemptResume,
  classifyResult,
  parseResultJson,
  DEFAULT_TIMEOUT_MS,
  DEFAULT_MAX_ATTEMPTS,
};
