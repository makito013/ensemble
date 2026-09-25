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

function pausedAtOf(content) {
  const match = /^paused_at: (.*)$/m.exec(content || '');
  return match ? match[1].trim() : 'desconhecido';
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

// Removes the checkpoint of `cwd`. Returns true when one existed.
function clear({ cwd }) {
  const file = stateFile(cwd);
  if (!fs.existsSync(file)) return false;
  fs.unlinkSync(file);
  return true;
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
    // Only one checkpoint per directory: warn (stderr, so stdout stays the
    // file path) when a previous pause is being replaced.
    const previous = load({ cwd: args.cwd });
    const file = save({
      cwd: args.cwd,
      sessionId: args['session-id'],
      summary,
    });
    if (previous !== null) {
      console.error(`AVISO_CHECKPOINT_SOBRESCRITO paused_at=${pausedAtOf(previous)}`);
    }
    console.log(file);
  } else if (cmd === 'clear') {
    if (!args.cwd) {
      console.error('uso: state.js clear --cwd <path>');
      process.exitCode = 2;
      return;
    }
    // Idempotent: clearing a directory without a checkpoint is not an error.
    console.log(clear({ cwd: args.cwd }) ? 'ESTADO_LIMPO' : 'SEM_ESTADO_PAUSADO');
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
    console.error('     state.js clear --cwd <path>');
    process.exitCode = 2;
  }
}

if (require.main === module) main();

module.exports = { save, load, clear, pausedAtOf, stateFile, stateDir, parseArgs, readStdin };
