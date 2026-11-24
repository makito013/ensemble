'use strict';
// Run with: node core/watcher-session.test.js (works on Windows, unlike the .sh stubs)
const assert = require('assert');
const cp = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');

const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'watcher-'));
process.env.CLAUDE_CONTINUIDADE_QUEUE_DIR = path.join(dir, 'queue');
const calls = [];
let reply = { status: 0, stdout: '{"is_error":false}' };
cp.spawnSync = (bin, args, opts) => {
  calls.push({ args, opts });
  return reply;
};

const { run, classifyResult } = require('./watcher');
const store = require('./lib/queue-store');
const { parseResetTime } = require('./lib/session');

const sub = path.join(dir, 'sub');
fs.mkdirSync(sub);
const T = Date.now();
const transcript = path.join(dir, 't.jsonl');
const entry = (at, extra) =>
  JSON.stringify(Object.assign({ type: 'assistant', cwd: dir, timestamp: new Date(at).toISOString() }, extra));
const setup = (lines, extra) => {
  fs.rmSync(store.queueDir(), { recursive: true, force: true });
  calls.length = 0;
  fs.writeFileSync(transcript, lines.join('\n'));
  store.writeItem(
    Object.assign(
      {
        cwd: sub,
        session_id: 's',
        config_dir: path.join(os.homedir(), '.claude'),
        transcript_path: transcript,
        queued_at: T,
        error: 'rate_limit',
      },
      extra
    )
  );
};

for (const msg of [
  "You've hit your weekly limit",
  "You've hit your session limit",
  "You've hit your 5-hour limit",
  "You're out of usage credits",
]) {
  assert.strictEqual(classifyResult({ status: 1, stdout: msg }).reason, 'rate-limit', msg);
}

setup([entry(T - 1000), entry(T + 60000, { isApiErrorMessage: true })]);
assert.strictEqual(run(T + 1000)[0].action, 'resumed');
assert.strictEqual(calls[0].opts.cwd, dir, 'uses the original session cwd');
assert.ok(!('CLAUDE_CONFIG_DIR' in calls[0].opts.env), 'default config dir is not exported');

setup([entry(T - 1000), entry(T + 60000)]);
assert.strictEqual(run(T + 70000)[0].action, 'stale-already-continued');
assert.strictEqual(calls.length, 0);

const ref = new Date(2026, 10, 20, 16, 43).getTime();
assert.strictEqual(parseResetTime('resets Nov 23, 3am (x)', ref), new Date(2026, 10, 23, 3).getTime());
assert.strictEqual(parseResetTime('resets 8:10pm (x)', ref), new Date(2026, 10, 20, 20, 10).getTime());
assert.strictEqual(parseResetTime('resets 1:10am (x)', ref), new Date(2026, 10, 21, 1, 10).getTime());
assert.strictEqual(parseResetTime('nothing', ref), null);

setup([entry(ref - 1000)], { queued_at: ref, last_assistant_message: 'resets 8:10pm' });
assert.strictEqual(run(ref + 60000)[0].action, 'waiting-reset');
assert.strictEqual(calls.length, 0);
assert.strictEqual(run(new Date(2026, 10, 20, 20, 11).getTime())[0].action, 'resumed');

// a weekly reset announced 4 days ahead must survive the 48h age limit
setup([entry(ref - 1000)], { queued_at: ref, last_assistant_message: 'resets Nov 24, 3am' });
assert.strictEqual(run(new Date(2026, 10, 23, 12).getTime())[0].action, 'waiting-reset');
assert.strictEqual(run(new Date(2026, 10, 24, 3, 5).getTime())[0].action, 'resumed');

reply = { status: 1, stdout: "You've hit your weekly limit" };
setup([entry(T - 1000)]);
assert.strictEqual(run(T + 1000)[0].reason, 'rate-limit');
const saved = store.readItem(store.listItems()[0]);
assert.strictEqual(saved.first_queued_at, T);
assert.ok(saved.last_attempt_at >= T);
// the failed attempt's own prompt must not look like manual activity
fs.appendFileSync(transcript, '\n' + entry(saved.last_attempt_at - 10, { type: 'user' }));
assert.strictEqual(run(T + 2000)[0].action, 'still-blocked');

fs.rmSync(dir, { recursive: true, force: true });
console.log('PASS');
