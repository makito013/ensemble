'use strict';

const fs = require('fs');

const RATE_LIMIT_PATTERN =
  /rate.?limit|usage limit|limit reached|limit atingido|hit your [^\n]{0,40}limit|out of usage credits/i;

const MONTHS = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];

// Reset time (epoch ms, machine timezone) announced by a limit message such as
// "resets 8:10pm (...)" or "resets Nov 23, 3am (...)". Null when absent.
function parseResetTime(text, reference) {
  const m = /resets\s+(?:([a-z]{3})[a-z]*\s+(\d{1,2}),?\s+(?:at\s+)?)?(\d{1,2})(?::(\d{2}))?\s*(am|pm)/i.exec(
    String(text || '')
  );
  if (!m) return null;
  const date = new Date(reference);
  const hour = (Number(m[3]) % 12) + (m[5].toLowerCase() === 'pm' ? 12 : 0);
  if (m[1]) {
    const month = MONTHS.indexOf(m[1].toLowerCase());
    if (month < 0) return null;
    date.setMonth(month, Number(m[2]));
  }
  date.setHours(hour, Number(m[4] || 0), 0, 0);
  if (date.getTime() <= reference) {
    if (!m[1]) {
      date.setDate(date.getDate() + 1);
    } else if (reference - date.getTime() > 180 * 86400000) {
      date.setFullYear(date.getFullYear() + 1);
    }
  }
  return date.getTime();
}

// Reads the session transcript. Returns the directory the session started in
// (`claude -r` looks sessions up by it, while the hook reports the current
// shell directory) and the time of the last real message.
function inspectTranscript(file) {
  const info = { cwd: null, lastActivity: 0 };
  let content;
  try {
    content = fs.readFileSync(file, 'utf8');
  } catch (err) {
    return info;
  }
  for (const line of content.split('\n')) {
    let entry;
    try {
      entry = JSON.parse(line);
    } catch (err) {
      continue;
    }
    if (!entry || typeof entry !== 'object') continue;
    if (!info.cwd && entry.cwd) info.cwd = entry.cwd;
    if (entry.type !== 'user' && entry.type !== 'assistant') continue;
    if (entry.isApiErrorMessage || entry.isSidechain) continue;
    const at = Date.parse(entry.timestamp);
    if (at > info.lastActivity) info.lastActivity = at;
  }
  return info;
}

module.exports = { RATE_LIMIT_PATTERN, parseResetTime, inspectTranscript };
