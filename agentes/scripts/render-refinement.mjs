#!/usr/bin/env node
// render-refinement.mjs — fills the FIXED refinement template with refinamento.json.
// Deterministic, no LLM, no dependencies: the HTML layout never varies between
// tasks, only the data does. The script also works as the pre-dev gate: it
// reports blocking questions that still have no answer.
//
// Usage: node render-refinement.mjs <refinamento.json> <out.html> [--template <file>]
// Exit codes:
//   0  rendered, no blocking question left open (ready for development)
//   3  rendered, but blocking questions are still unanswered (gate closed)
//   1  invalid input (nothing written)
//   2  usage error
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const CHANGE_LABELS = { create: 'criar', modify: 'alterar', remove: 'remover' };

function usage(message) {
  if (message) console.error(message);
  console.error('usage: node render-refinement.mjs <refinamento.json> <out.html> [--template <file>]');
  process.exit(2);
}

function parseArgs(argv) {
  const positional = [];
  let template = join(dirname(fileURLToPath(import.meta.url)), 'refinement-template.html');
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--template') {
      template = argv[++i];
      if (!template) usage('--template requires a file');
    } else {
      positional.push(argv[i]);
    }
  }
  if (positional.length !== 2) usage();
  return { input: positional[0], output: positional[1], template };
}

const escapeHtml = (value) =>
  String(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');

// Inline `code` spans are the only markup allowed inside text fields.
const inline = (value) =>
  escapeHtml(value).replace(/`([^`]+)`/g, (_, code) => `<code>${code}</code>`);

const isNonEmptyString = (value) => typeof value === 'string' && value.trim() !== '';
const asArray = (value) => (Array.isArray(value) ? value : []);
const hasAnswer = (question) => isNonEmptyString(question.answer);

function validate(data) {
  const errors = [];
  if (data === null || typeof data !== 'object' || Array.isArray(data)) {
    return ['root must be a JSON object'];
  }
  for (const key of ['id', 'title', 'summary', 'why']) {
    if (!isNonEmptyString(data[key])) errors.push(`"${key}" must be a non-empty string`);
  }
  for (const key of ['what', 'acceptanceCriteria']) {
    if (!Array.isArray(data[key]) || data[key].length === 0) errors.push(`"${key}" must be a non-empty array`);
  }
  for (const key of ['where', 'questions']) {
    if (!Array.isArray(data[key])) errors.push(`"${key}" must be an array (use [] when empty)`);
  }
  asArray(data.where).forEach((entry, i) => {
    if (!entry || !isNonEmptyString(entry.path)) errors.push(`where[${i}].path is required`);
    if (!entry || !(entry.change in CHANGE_LABELS)) {
      errors.push(`where[${i}].change must be one of: ${Object.keys(CHANGE_LABELS).join(', ')}`);
    }
  });
  asArray(data.questions).forEach((q, i) => {
    if (!q || !isNonEmptyString(q.question)) errors.push(`questions[${i}].question is required`);
    if (!q || typeof q.blocking !== 'boolean') errors.push(`questions[${i}].blocking must be true or false`);
  });
  asArray(data.tasks).forEach((task, i) => {
    if (!task || !isNonEmptyString(task.description)) errors.push(`tasks[${i}].description is required`);
  });
  asArray(data.contingencies).forEach((c, i) => {
    if (!c || !isNonEmptyString(c.when)) errors.push(`contingencies[${i}].when is required`);
    if (!c || !isNonEmptyString(c.then)) errors.push(`contingencies[${i}].then is required`);
  });
  return errors;
}

const empty = (text = 'Nada registrado.') => `<p class="empty">${text}</p>`;

function list(items, render = (item) => inline(item), className = '') {
  const valid = asArray(items).filter((item) => item !== null && item !== undefined && item !== '');
  if (valid.length === 0) return empty();
  const cls = className ? ` class="${className}"` : '';
  return `<ul${cls}>${valid.map((item) => `<li>${render(item)}</li>`).join('')}</ul>`;
}

function renderMeta(data) {
  const meta = data.meta || {};
  const rows = [
    ['Tier', meta.tier],
    ['Perfil', meta.profile],
    ['Responsável', meta.owner],
    ['Branch', meta.branch],
    ['Criado em', meta.createdAt],
  ].filter(([, value]) => isNonEmptyString(value));
  return rows.map(([label, value]) => `<li><b>${label}:</b> ${inline(value)}</li>`).join('');
}

function renderBanner(openBlocking) {
  if (openBlocking.length === 0) {
    return '<div class="banner ready">✅ Pronto para desenvolvimento — nenhuma dúvida bloqueante em aberto.</div>';
  }
  const noun = openBlocking.length === 1 ? 'dúvida bloqueante' : 'dúvidas bloqueantes';
  return `<div class="banner pending">⚠️ Aguardando ${openBlocking.length} ${noun} antes do desenvolvimento.</div>`;
}

function renderQuestions(questions) {
  if (questions.length === 0) return empty('Nenhuma dúvida registrada.');
  // Open blocking questions first: they are what holds development back.
  const rank = (q) => (q.blocking && !hasAnswer(q) ? 0 : q.blocking ? 1 : 2);
  const sorted = questions.map((q, i) => ({ q, i })).sort((a, b) => rank(a.q) - rank(b.q) || a.i - b.i);
  return sorted
    .map(({ q, i }) => {
      const id = isNonEmptyString(q.id) ? q.id : `D${i + 1}`;
      const tag = q.blocking
        ? '<span class="tag blocking">bloqueante</span>'
        : '<span class="tag optional">não bloqueante</span>';
      const options = asArray(q.options).length ? list(q.options) : '';
      const rec = isNonEmptyString(q.recommendation)
        ? `<p class="rec">Recomendação: ${inline(q.recommendation)}</p>`
        : '';
      const answer = hasAnswer(q)
        ? `<div class="answer">Resposta: ${inline(q.answer)}${isNonEmptyString(q.answeredBy) ? ` — ${inline(q.answeredBy)}` : ''}</div>`
        : `<div class="answer missing">Sem resposta ainda.</div>`;
      const state = hasAnswer(q) ? 'answered' : 'open';
      return `<div class="q ${state}${q.blocking ? ' blocking' : ''}"><div class="head"><strong>${escapeHtml(id)}.</strong> ${tag}</div><p>${inline(q.question)}</p>${options}${rec}${answer}</div>`;
    })
    .join('');
}

function renderWhere(where) {
  if (where.length === 0) return empty('Nenhum arquivo mapeado.');
  const rows = where
    .map(
      (w) =>
        `<tr><td><code>${escapeHtml(w.path)}</code></td><td><span class="tag ${w.change}">${CHANGE_LABELS[w.change]}</span></td><td>${inline(w.reason || '')}</td></tr>`,
    )
    .join('');
  return `<div class="table-wrap"><table><thead><tr><th>Caminho</th><th>Mudança</th><th>Motivo</th></tr></thead><tbody>${rows}</tbody></table></div>`;
}

function renderTaskTable(tasks) {
  const rows = tasks
    .map((t, i) => {
      const files = asArray(t.files).map((f) => `<code>${escapeHtml(f)}</code>`).join(' ');
      const deps = asArray(t.dependsOn).map(escapeHtml).join(', ');
      return `<tr><td>${escapeHtml(isNonEmptyString(t.id) ? t.id : `T${i + 1}`)}</td><td>${inline(t.description)}</td><td>${files || '—'}</td><td>${escapeHtml(t.size || '—')}</td><td>${deps || '—'}</td></tr>`;
    })
    .join('');
  return `<div class="table-wrap"><table><thead><tr><th>#</th><th>Tarefa</th><th>Arquivos</th><th>Tam.</th><th>Depende de</th></tr></thead><tbody>${rows}</tbody></table></div>`;
}

function renderTasks(tasks) {
  if (tasks.length === 0) return empty('Sem plano de tarefas (o TL não rodou nesta demanda).');
  const phases = [...new Set(tasks.map((t) => t.phase).filter(isNonEmptyString))];
  if (phases.length === 0) return renderTaskTable(tasks);
  const unphased = tasks.filter((t) => !isNonEmptyString(t.phase));
  const blocks = phases.map((phase) => `<h3>${inline(phase)}</h3>${renderTaskTable(tasks.filter((t) => t.phase === phase))}`);
  if (unphased.length) blocks.push(`<h3>Sem fase</h3>${renderTaskTable(unphased)}`);
  return blocks.join('');
}

function renderAcceptance(criteria) {
  return list(
    criteria,
    (c) => (typeof c === 'string' ? inline(c) : `<strong>${escapeHtml(c.id || '')}</strong> ${inline(c.text || '')}`),
    'checks',
  );
}

function renderRisks(risks) {
  return list(risks, (r) =>
    typeof r === 'string'
      ? inline(r)
      : `${inline(r.risk || '')}${isNonEmptyString(r.mitigation) ? ` — <em>mitigação:</em> ${inline(r.mitigation)}` : ''}`,
  );
}

// Pre-authorized decisions: the developer applies them without asking.
function renderContingencies(contingencies) {
  if (contingencies.length === 0) return empty('Nenhuma decisão pré-autorizada.');
  const rows = contingencies
    .map(
      (c, i) =>
        `<tr><td>${escapeHtml(isNonEmptyString(c.id) ? c.id : `C${i + 1}`)}</td><td>${inline(c.when)}</td><td>${inline(c.then)}</td><td>${isNonEmptyString(c.escalateIf) ? inline(c.escalateIf) : '—'}</td></tr>`,
    )
    .join('');
  return `<p class="rec">Aprovadas junto com o documento: o desenvolvimento aplica sem perguntar.</p><div class="table-wrap"><table><thead><tr><th>#</th><th>Se acontecer</th><th>Faça</th><th>Pare e reporte se</th></tr></thead><tbody>${rows}</tbody></table></div>`;
}

function renderVerification(data) {
  const commands = asArray(data.verification);
  const strategy = asArray(data.testStrategy);
  const parts = [];
  if (strategy.length) parts.push(`<h3>Estratégia de testes</h3>${list(strategy)}`);
  if (commands.length) parts.push(`<h3>Comandos</h3>${list(commands, (c) => `<code>${escapeHtml(c)}</code>`)}`);
  return parts.length ? parts.join('') : empty();
}

function renderSources(sources) {
  return list(sources, (s) => {
    if (typeof s === 'string') return `<code>${escapeHtml(s)}</code>`;
    const label = escapeHtml(s.label || s.path || '');
    return isNonEmptyString(s.path) ? `<a href="${escapeHtml(s.path)}">${label}</a>` : label;
  });
}

function main() {
  const { input, output, template } = parseArgs(process.argv.slice(2));
  let data;
  try {
    data = JSON.parse(readFileSync(input, 'utf8'));
  } catch (error) {
    console.error(`invalid JSON in ${input}: ${error.message}`);
    process.exit(1);
  }
  const errors = validate(data);
  if (errors.length) {
    console.error(`invalid refinement data in ${input}:`);
    for (const e of errors) console.error(`  - ${e}`);
    process.exit(1);
  }

  const questions = asArray(data.questions);
  const openBlocking = questions
    .map((q, i) => ({ ...q, id: isNonEmptyString(q.id) ? q.id : `D${i + 1}` }))
    .filter((q) => q.blocking && !hasAnswer(q));
  const slots = {
    id: escapeHtml(data.id),
    title: inline(data.title),
    meta: renderMeta(data),
    banner: renderBanner(openBlocking),
    questions: renderQuestions(questions),
    summary: `<p>${inline(data.summary)}</p>`,
    what: list(data.what),
    why: `<p>${inline(data.why)}</p>`,
    where: renderWhere(asArray(data.where)),
    tasks: renderTasks(asArray(data.tasks)),
    acceptance: renderAcceptance(data.acceptanceCriteria),
    outOfScope: list(data.outOfScope),
    risks: renderRisks(data.risks),
    contingencies: renderContingencies(asArray(data.contingencies)),
    assumptions: list(data.assumptions),
    verification: renderVerification(data),
    sources: renderSources(data.sources),
    generatedAt: escapeHtml(new Date().toISOString().replace('T', ' ').slice(0, 16) + ' UTC'),
  };

  let html;
  try {
    html = readFileSync(template, 'utf8');
  } catch (error) {
    console.error(`template not found: ${template}`);
    process.exit(1);
  }
  const missing = Object.keys(slots).filter((key) => !html.includes(`{{${key}}}`));
  if (missing.length) {
    console.error(`template is missing slots: ${missing.join(', ')}`);
    process.exit(1);
  }
  // Single pass over the template: slot values are never re-scanned, so data
  // that happens to contain "{{...}}" is never treated as a slot.
  html = html.replace(/\{\{(\w+)\}\}/g, (match, key) => (key in slots ? slots[key] : match));
  writeFileSync(output, html);

  if (openBlocking.length) {
    console.log(`rendered ${output} — ${openBlocking.length} blocking question(s) without answer:`);
    openBlocking.forEach((q) => console.log(`  - ${q.id}: ${q.question}`));
    process.exit(3);
  }
  console.log(`rendered ${output} — ready for development`);
}

main();
