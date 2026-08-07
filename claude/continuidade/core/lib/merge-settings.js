#!/usr/bin/env node
'use strict';

const fs = require('fs');

function mergeHook(settings, eventName, matcher, command, timeout) {
  const hooks = settings.hooks || (settings.hooks = {});
  const list = hooks[eventName] || (hooks[eventName] = []);
  const alreadyPresent = list.some((entry) => (entry.hooks || []).some((h) => h.command === command));
  if (alreadyPresent) return settings;
  const hookDef = { type: 'command', command };
  if (timeout) hookDef.timeout = timeout;
  const entry = { hooks: [hookDef] };
  if (matcher) entry.matcher = matcher;
  list.push(entry);
  return settings;
}

function mergeSettingsFile(filePath, eventName, matcher, command, timeout) {
  let settings = {};
  if (fs.existsSync(filePath)) {
    settings = JSON.parse(fs.readFileSync(filePath, 'utf8'));
  }
  settings = mergeHook(settings, eventName, matcher, command, timeout);
  fs.writeFileSync(filePath, `${JSON.stringify(settings, null, 2)}\n`);
}

function main() {
  const [filePath, eventName, matcherRaw, command, timeoutRaw] = process.argv.slice(2);
  const matcher = matcherRaw && matcherRaw.length > 0 ? matcherRaw : null;
  const timeout = timeoutRaw ? Number(timeoutRaw) : undefined;
  mergeSettingsFile(filePath, eventName, matcher, command, timeout);
}

if (require.main === module) main();

module.exports = { mergeHook, mergeSettingsFile };
