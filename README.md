noden · Odoo DevX
=================

**Odoo engineering for complex operations.**

Developer Experience (DevX) and infrastructure tooling for the Odoo ecosystem.

Overview
--------
This repository provides standard tools for Odoo infrastructure, module packaging, and version migrations.

Directory Structure
-------------------
```text
|-- AGENTS.md                     # Entrypoint for AI coding agents
|-- .claude/skills/               # AI Agent Skills
|   |-- odoo-module-migration/    # Migrate module source code (v12 -> v19)
|   |-- odoo-db-migration/        # Migrate databases via OCA OpenUpgrade
|-- scripts/                      # Operational and addon tooling
|   |-- db-manager.sh             # DB backup/restore via Odoo's web API
|   |-- stream.sh                 # Local DB + filestore backup/restore (pg_dump)
|   |-- pack.py                   # Clean addon packaging utility
|   |-- publish.sh                # Addon publishing automation
|-- module-migration/             # Workspace for module code migrations
|-- migrations/                   # Workspace for OpenUpgrade DB migrations
```

Quick Start
-----------
Clone the repository and grant execution permissions to the scripts:

```bash
git clone https://github.com/nodenlabs/devx.git
cd devx
chmod +x scripts/*.sh scripts/*.py
```

Note: Refer to the header of each individual script for specific parameters and usage
instructions, or run it with `help` / no arguments. See [scripts/README.md](scripts/README.md)
for an index.

AI Agents
---------
Migration knowledge is packaged as two Agent Skills under `.claude/skills/`. Skill-aware
tools load them automatically; any other agent can read `SKILL.md` directly.
See [AGENTS.md](AGENTS.md) for details.

About
-----
**noden** — Odoo Engineering

Odoo engineering for complex operations. A Sentilis company.

- Website — <https://sentilis.me/noden>
- GitHub — <https://github.com/nodenlabs>
- Email — <noden@sentilis.me>

Copyright © 2026 Noden Labs. See [LICENSE](LICENSE).
