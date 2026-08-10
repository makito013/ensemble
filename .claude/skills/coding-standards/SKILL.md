---
name: coding-standards
description: Use before writing, naming, or reviewing any code — variables, functions, classes, files, folders, comments, database tables/columns/schemas, config keys, routes/endpoints, commit messages, branch names, test names. Enforces English-only identifiers and comments, even when the conversation itself is in Portuguese. Applies regardless of whether a pipeline agent (Dev, QA, TL, Arquiteto, Revisor) is active — this is a general coding-standards rule for the project, not specific to the agentes-pipeline.
---

# Coding standards: English-only code

All code artifacts are always written in English, regardless of the
conversation language:

- Variable, function, class, method, file, and folder names
- Code comments
- Database tables, columns, indexes, and schema names
- Config keys, API routes/endpoints, event names
- Commit messages and branch names
- Test names (`describe`/`it`/`test`, fixtures, mocks)

**Stays in the user's language:** communication with the user (chat replies,
PR/report summaries) and end-user-facing strings (UI copy, displayed error
messages) when the product targets a non-English-speaking audience — that's a
product/i18n decision, not a coding convention.

**Legacy code already in Portuguese:** keep local consistency and flag the
inconsistency to the user instead of mass-migrating it on your own
initiative — that's a refactor outside the scope of most tasks unless asked
for explicitly.
