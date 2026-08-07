#!/usr/bin/env node
'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');
const { writeItem } = require('./lib/queue-store');

function readStdin() {
  try {
    return fs.readFileSync(0, 'utf8');
  } catch (err) {
    return '';
  }
}

function defaultConfigDir() {
  return path.join(os.homedir(), '.claude');
}

function main() {
  const raw = readStdin();
  let payload = {};
  try {
    payload = raw.trim() ? JSON.parse(raw) : {};
  } catch (err) {
    console.error(`[queue.js] Erro: payload do hook contém JSON malformado. Detalhes: ${err.message}`);
    payload = {};
  }
  const item = Object.assign({}, payload, {
    config_dir: process.env.CLAUDE_CONFIG_DIR || defaultConfigDir(),
    queued_at: Date.now(),
  });
  writeItem(item);
}

main();
