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

function listItems() {
  ensureDirs();
  return fs
    .readdirSync(queueDir())
    .filter((name) => name.endsWith('.json'))
    .map((name) => path.join(queueDir(), name));
}

function readItem(file) {
  return JSON.parse(fs.readFileSync(file, 'utf8'));
}

function moveToStale(file) {
  ensureDirs();
  fs.renameSync(file, path.join(staleDir(), path.basename(file)));
}

function removeItem(file) {
  fs.unlinkSync(file);
}

module.exports = {
  queueDir,
  staleDir,
  ensureDirs,
  writeItem,
  listItems,
  readItem,
  moveToStale,
  removeItem,
};
