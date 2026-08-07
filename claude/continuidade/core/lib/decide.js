'use strict';

const fs = require('fs');

const MAX_AGE_MS = 48 * 60 * 60 * 1000;

function decideAction(item, now) {
  if (!item.cwd || !item.session_id) return 'invalid';
  if (!fs.existsSync(item.cwd)) return 'stale-missing-cwd';
  if (now - item.queued_at > MAX_AGE_MS) return 'stale-expired';
  return 'retry';
}

module.exports = { decideAction, MAX_AGE_MS };
