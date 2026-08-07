#!/usr/bin/env node
'use strict';

const { spawnSync } = require('child_process');
const { listItems, readItem, moveToStale, removeItem } = require('./lib/queue-store');
const { decideAction } = require('./lib/decide');

const RESUME_PROMPT =
  'Você foi interrompido por ter atingido o limite de uso ou por um erro. ' +
  'Se o problema já foi resolvido, retome exatamente de onde parou e ' +
  'continue a tarefa em andamento até concluir ou até realmente precisar ' +
  'de uma decisão do usuário que só ele pode tomar.';

const RATE_LIMIT_PATTERN = /rate.?limit|usage limit|limit reached|limit atingido/i;

function attemptResume(item, claudeBin) {
  const bin = claudeBin || process.env.CLAUDE_CONTINUIDADE_BIN || 'claude';
  const env = Object.assign({}, process.env, { CLAUDE_CONFIG_DIR: item.config_dir });
  const result = spawnSync(
    bin,
    ['-r', item.session_id, '-p', RESUME_PROMPT, '--permission-mode', 'acceptEdits'],
    { cwd: item.cwd, env, encoding: 'utf8' }
  );

  // Combine stdout and stderr for rate-limit detection
  const output = String(result.stdout || '') + String(result.stderr || '');

  if (result.status !== 0) {
    return { ok: false, output };
  }

  return { ok: !RATE_LIMIT_PATTERN.test(output), output };
}

function run(now, claudeBin) {
  const results = [];
  for (const file of listItems()) {
    const item = readItem(file);
    const action = decideAction(item, now);
    if (action === 'invalid' || action === 'stale-missing-cwd' || action === 'stale-expired') {
      moveToStale(file);
      results.push({ file, action });
      continue;
    }
    const { ok, output } = attemptResume(item, claudeBin);
    if (ok) {
      removeItem(file);
      results.push({ file, action: 'resumed', output });
    } else {
      results.push({ file, action: 'still-blocked', output });
    }
  }
  return results;
}

if (require.main === module) {
  run(Date.now());
}

module.exports = { run, attemptResume };
