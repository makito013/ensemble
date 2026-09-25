'use strict';

const fs = require('fs');
const path = require('path');
const os = require('os');

function queueDir() {
  return process.env.CLAUDE_CONTINUIDADE_QUEUE_DIR || path.join(os.homedir(), '.claude-resume-queue');
}

function staleDir() {
  return path.join(queueDir(), 'stale');
}

function ensureDirs() {
  fs.mkdirSync(queueDir(), { recursive: true });
  fs.mkdirSync(staleDir(), { recursive: true });
}

function writeItem(item) {
  ensureDirs();
  const file = path.join(queueDir(), `${item.queued_at}-${process.pid}.json`);
  fs.writeFileSync(file, JSON.stringify(item, null, 2));
  return file;
}

// Rewrites an existing queue item (e.g. to bump its attempt counter). Writes
// to a temp name that does not end in .json and renames it over the original,
// so a crash mid-write never leaves a half-written item in the queue.
function updateItem(file, item) {
  const tmp = `${file}.${process.pid}.tmp`;
  fs.writeFileSync(tmp, JSON.stringify(item, null, 2));
  fs.renameSync(tmp, file);
}

function listItems() {
  ensureDirs();
  return fs
    .readdirSync(queueDir())
    .filter((name) => name.endsWith('.json'))
    .sort()
    .map((name) => path.join(queueDir(), name));
}

function readItem(file) {
  return JSON.parse(fs.readFileSync(file, 'utf8'));
}

// Like readItem, but never throws: a corrupt or unreadable item must not
// block the rest of the queue. Returns { item } or { error }.
function tryReadItem(file) {
  try {
    const item = readItem(file);
    if (item === null || typeof item !== 'object' || Array.isArray(item)) {
      return { error: new Error('queue item is not a JSON object') };
    }
    return { item };
  } catch (err) {
    return { error: err };
  }
}

function moveToStale(file) {
  ensureDirs();
  let dest = path.join(staleDir(), path.basename(file));
  if (fs.existsSync(dest)) {
    dest = path.join(staleDir(), `${Date.now()}-${path.basename(file)}`);
  }
  fs.renameSync(file, dest);
  return dest;
}

function removeItem(file) {
  fs.unlinkSync(file);
}

module.exports = {
  queueDir,
  staleDir,
  ensureDirs,
  writeItem,
  updateItem,
  listItems,
  readItem,
  tryReadItem,
  moveToStale,
  removeItem,
};
