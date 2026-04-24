# Noden · Module Migration Workspace

AI-assisted workspace to migrate Odoo modules (v12 → v19) with a Dockerized env to validate the result. Set `ODOO_VERSION` in `.env` to target any version (e.g. `15.0` for a v14→v15 migration, `18.0` for v17→v18).

## Layout

```
module-migration/
├── CLAUDE.md                # Agent system prompt
├── .rules/
│   └── module-migration.md  # Full migration ruleset (v12 → v19)
├── docker-compose.yaml      # Odoo 19 + PostgreSQL 16
├── Dockerfile               # Odoo 19 image
├── .env.example
├── src/                     # Source modules (you create)
└── out/                     # Migrated modules → /mnt/extra-addons (you create)
```

## 1. Setup

```bash
cp .env.example .env
mkdir -p src out
```

## 2. Migrate

Open Claude Code here. `CLAUDE.md` loads automatically and points at `.rules/module-migration.md`.

> Migrate `src/my_module` from v12 to v19. Save it in `out/my_module`.

The agent copies the module, applies rules version by version, writes a `CHANGELOG.md`, and flags uncertain code with `# TODO AI:`.

## 3. Validate

```bash
docker compose up -d --build

docker compose exec odoo odoo \
  -d migration_test -i my_module --stop-after-init --no-http

docker compose logs -f odoo
```

Odoo: <http://localhost:8069>.

## 4. Iterate

Paste tracebacks back to the agent; it fixes only the affected files in `out/`.

## Anti-hallucination

The agent never invents code. When unsure, it keeps the original and adds `# TODO AI: [reason]`. Grep `out/` for `TODO AI` after each run.

## Refresh rules

```bash
cp ../agents/skill-module-migration.md .rules/module-migration.md
```

---

## About Noden

- Website — <https://sentilis.me/nodenhq>
- GitHub — <https://github.com/nodenhq>
- DevX — <https://github.com/nodenhq/devx>

Copyright © 2026 NodenHQ. See [LICENSE](../LICENSE).
