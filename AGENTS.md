# noden · Odoo DevX — Agent Guide

Developer Experience and infrastructure tooling for the Odoo ecosystem: module packaging, database streaming, and version migrations.

This file is the entrypoint for **any** AI coding agent working in this repository.

## Skills

Migration knowledge lives in two skills under `.claude/skills/`. Each is a directory with a `SKILL.md` (the instructions) and a `references/` folder loaded on demand.

| Skill | Use it for |
|---|---|
| [`odoo-module-migration`](.claude/skills/odoo-module-migration/SKILL.md) | Migrating Odoo **module source code** between versions (v12 → v19) — manifests, Python, XML views, JS, security. One reference per version hop. |
| [`odoo-db-migration`](.claude/skills/odoo-db-migration/SKILL.md) | Migrating an Odoo **PostgreSQL database** between versions via OCA OpenUpgrade — import, sequential hops, resume after failure, validation. |

Migrating a whole instance uses both, in this order: **code first, then database.** A hop fails if a custom module does not load in the target version.

### Using them without skill support

`.claude/skills/` is a plain directory — nothing about it is Claude-specific.

- **Skill-aware tools** (Claude Code, claude.ai) discover and load these automatically from the YAML frontmatter. Nothing to do.
- **Any other agent** (Codex, Cursor, Copilot, Gemini CLI, Aider, …): read `.claude/skills/<skill-name>/SKILL.md` and follow it as your instructions for the task. It tells you which files under its `references/` to load and when — load only those, not the whole directory. That progressive loading is the point: a v16 → v19 module migration reads 5 reference files, not 11.

Do not copy skill content into another file to "vendor" it. An earlier copy-based setup in this repo drifted until its documented source file no longer existed.

## Repository layout

```text
odoo-devx/
├── AGENTS.md               # this file — agent entrypoint
├── CLAUDE.md               # imports AGENTS.md
├── .claude/skills/         # Agent Skills (see above)
│   ├── odoo-module-migration/
│   └── odoo-db-migration/
├── scripts/                # operational and addon tooling (see scripts/README.md)
│   ├── db-manager.sh       # database backup/restore via Odoo's web API
│   ├── stream.sh           # local database + filestore backup/restore (pg_dump)
│   ├── stream.example.json # config template for stream.sh
│   ├── pack.py             # addon packaging (module + local depends → versioned zip)
│   └── publish.sh          # publish/mirror to read-only repos
├── module-migration/       # workspace for module code migrations (src/ → out/)
└── migrations/             # workspace for OpenUpgrade database migrations
```

`migrations/` and `module-migration/{src,out}` are gitignored working directories.

## Conventions

**Anti-hallucination marker.** When code cannot be migrated with certainty, never invent an implementation. Keep the original (commented if appropriate) and add:

```python
# TODO_AI: [what could not be migrated and why]
```

Exactly `TODO_AI` — one spelling, so `grep -rn TODO_AI` finds every flag. Then explain it in the migrated module's `CHANGELOG.md`.

**Never mutate sources.** Module migrations read from `src/` and write to `out/`. Database migrations run against a staging copy, never production.

**Report failures with the real output.** Paste the actual traceback or log excerpt, not a paraphrase. For database work, read the full log file — OpenUpgrade's root cause is usually well before the final error line.

## About

**noden** — Odoo Engineering

Odoo engineering for complex operations. A Sentilis company.

- Website — <https://sentilis.me/noden>
- GitHub — <https://github.com/nodenlabs>
- DevX — <https://github.com/nodenlabs/devx>
- Email — <noden@sentilis.me>

Copyright © 2026 Noden Labs. See [LICENSE](LICENSE).
