#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const os = require('os');

function stateDir() {
  return path.join(os.homedir(), '.continuidade', 'state');
}

function stateFile(cwd) {
  const hash = crypto.createHash('sha256').update(cwd).digest('hex').slice(0, 16);
  return path.join(stateDir(), `${hash}.md`);
}

function save({ cwd, sessionId, summary }) {
  fs.mkdirSync(stateDir(), { recursive: true });
  const file = stateFile(cwd);
  const body = [
    '---',
    `cwd: ${cwd}`,
    `session_id: ${sessionId || 'desconhecido'}`,
    `paused_at: ${new Date().toISOString()}`,
    '---',
    '',
    summary.trim(),
    '',
  ].join('\n');
  fs.writeFileSync(file, body);
  return file;
}

function load({ cwd }) {
  const file = stateFile(cwd);
  if (!fs.existsSync(file)) return null;
  return fs.readFileSync(file, 'utf8');
}

function parseArgs(argv) {
  const args = {};
  for (let i = 0; i < argv.length; i += 2) {
    const key = argv[i].replace(/^--/, '');
    args[key] = argv[i + 1];
  }
  return args;
}

function readStdin() {
  try {
    return fs.readFileSync(0, 'utf8');
  } catch (err) {
    return '';
  }
}

function main() {
  const [cmd, ...rest] = process.argv.slice(2);
  const args = parseArgs(rest);
  if (cmd === 'save') {
    if (!args.cwd) {
      console.error('uso: state.js save --cwd <path> [--session-id <id>] < resumo.md');
      process.exitCode = 2;
      return;
    }
    const summary = readStdin();
    const file = save({
      cwd: args.cwd,
      sessionId: args['session-id'],
      summary,
    });
    console.log(file);
  } else if (cmd === 'load') {
    if (!args.cwd) {
      console.error('uso: state.js load --cwd <path>');
      process.exitCode = 2;
      return;
    }
    const content = load({ cwd: args.cwd });
    if (content === null) {
      console.log('SEM_ESTADO_PAUSADO');
      process.exitCode = 1;
    } else {
      process.stdout.write(content);
    }
  } else {
    console.error('uso: state.js save --cwd <path> [--session-id <id>] < resumo.md');
    console.error('     state.js load --cwd <path>');
    process.exitCode = 2;
  }
}

if (require.main === module) main();

module.exports = { save, load, stateFile, stateDir, parseArgs, readStdin };
