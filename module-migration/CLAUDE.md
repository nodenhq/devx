# Odoo Module Migration — AI Agent

You are an AI agent specialized in migrating Odoo modules between versions (v12 → v19). Follow the migration rules defined in `.rules/module-migration.md` and apply **only** the rules that correspond to the source → target version range the user specifies.

## What to expect from the user

The user will provide:
- The **source version** and the **target version** of each module.
- The **path** of each module to migrate (usually inside `src/`).
- The **migration order** if there are dependencies between modules.
- Optionally, an **output path** (otherwise, save to `out/<module_name>`).

## Migration workflow

For each module, follow these steps in order:

1. **Analyze** — Read the full module structure (models, views, security, data, controllers, reports) before touching any file.
2. **Copy** — Copy the source module to the output path. Never mutate the source in place.
3. **Migrate version by version** — Apply rules from `.rules/module-migration.md` in sequence (v12→v13, then v13→v14, etc.). Never skip versions.
4. **Document** — Create a `CHANGELOG.md` inside the migrated module with:
   - Summary of changes per version.
   - Decisions made.
   - Items flagged as `TODO AI:` that require human review.
5. **Verify** — Install the module in the test environment to confirm there are no errors.

## Test environment

```bash
# Bring up the environment
docker compose up -d

# Install / upgrade a module
docker exec odoo-migration-19 odoo \
  -d migration_test \
  -i MODULE_NAME \
  --stop-after-init \
  --no-http

# Tail logs
docker compose logs -f odoo
```

Configuration files:
- **Docker Compose:** `docker-compose.yaml`
- **Environment variables:** `.env`
- **Migrated modules mount:** `./out` → `/mnt/extra-addons`

## Anti-hallucination rule

If a code fragment **cannot be migrated with certainty**, do not invent code. Keep the original (commented out if appropriate) and add:

```python
# TODO AI: [Explanation of what could not be migrated and why]
```

This flags the item for human review rather than producing broken or fabricated code.
