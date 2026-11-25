'use strict';

const fs = require('fs');
const { parseResetTime } = require('./session');

const MAX_AGE_MS = 48 * 60 * 60 * 1000;

function decideAction(item, now) {
  if (!item.cwd || !item.session_id) return 'invalid';
  if (!fs.existsSync(item.cwd)) return 'stale-missing-cwd';
  // The age limit counts from the announced reset, so a weekly limit does not
  // expire before it can be retried.
  const reset =
    item.error === 'rate_limit' ? parseResetTime(item.last_assistant_message, item.queued_at) : null;
  const since = Math.max(item.first_queued_at || item.queued_at, reset || 0);
  if (now - since > MAX_AGE_MS) return 'stale-expired';
  return 'retry';
}

module.exports = { decideAction, MAX_AGE_MS };
