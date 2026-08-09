---
name: odoo-module-migration
description: Migrate Odoo module source code across versions (v12 → v19) — manifests, Python ORM/API changes, XML views, JS, security CSVs. Applies only the rules for the given source → target range, hop by hop. Use when asked to migrate, upgrade, or port an Odoo module, addon, or custom module between versions ("migra el módulo a v19", "upgrade this addon from 16 to 18", "port this module to Odoo 17"), or when fixing deprecated Odoo patterns in module code.
---

# Odoo Module Migration (v12 → v19)

Migrate an Odoo module's **source code** from one version to another by applying each version hop in sequence. For migrating a **database**, use the [odoo-db-migration](../odoo-db-migration/SKILL.md) skill instead — the two are usually done together: migrate the custom module code first, then the database.

## Inputs to collect

Before starting, you need:

- **Source version** and **target version** of the module (e.g. 16 → 19).
- **Path** of each module to migrate.
- **Output path** — never write over the source. If not given, default to `out/<module_name>` inside the workspace, or ask.
- **Migration order**, if several modules depend on each other. Migrate dependencies first.

If the source version is not stated, infer it from `__manifest__.py`'s `version` field and confirm with the user before proceeding.

## Which references to load

Load `references/general-rules.md` first, then **only the hops in your range, in ascending order**. Never skip a hop: rules chain, and a v13 transformation can produce a pattern that a v17 rule must then convert.

| Load | When |
|---|---|
| `references/general-rules.md` | always, first |
| `references/v12-v13.md` | source ≤ 12 and target ≥ 13 |
| `references/v13-v14.md` | source ≤ 13 and target ≥ 14 |
| `references/v14-v15.md` | source ≤ 14 and target ≥ 15 |
| `references/v15-v16.md` | source ≤ 15 and target ≥ 16 |
| `references/v16-v17.md` | source ≤ 16 and target ≥ 17 |
| `references/v17-v18.md` | source ≤ 17 and target ≥ 18 |
| `references/v18-v19.md` | source ≤ 18 and target = 19 |
| `references/deprecated-modules.md` | a `depends` entry or import is missing in the target version |
| `references/final-scan.md` | after all hops, before writing the CHANGELOG |

Example — migrating 16 → 19 loads exactly five files: `general-rules.md`, `v16-v17.md`, `v17-v18.md`, `v18-v19.md`, `final-scan.md`. Do not read the v12–v15 references.

File types to process: `.py`, `.xml`, `.js`, `.csv`.

## Workflow

1. **Analyze** — Read the full module structure (models, views, security, data, controllers, reports) before touching any file. Do not start editing from a partial picture.
2. **Copy** — Copy the source module to the output path. **Never mutate the source in place.**
3. **Migrate hop by hop** — Apply the loaded references in version order (v12→v13, then v13→v14, …). Preserve the module's directory structure (`models/`, `views/`, `security/`, `data/`, …).
4. **Final scan** — Run the sweep in `references/final-scan.md`. Every hit is either a missed rule or a decision that belongs in the CHANGELOG.
5. **Document** — Write a `CHANGELOG.md` inside the migrated module, following `assets/CHANGELOG.template.md`: changes per hop, decisions made, and every `# TODO_AI:` item. Record **negative findings** too ("no `read_group(` calls found") — that is how a reviewer knows a rule was checked rather than skipped.
6. **Verify** — Install the module in the test environment and confirm a clean load.

## Anti-hallucination rule

> **CRITICAL**: If you encounter code, XML tags, or logic that you **cannot migrate with certainty**, do NOT invent code. Leave the original code (commented if appropriate) and add a marker for human review:

```python
# TODO_AI: [Explanation of what could not be migrated and why]
```

Use exactly `TODO_AI` — one spelling, so `grep -rn TODO_AI` finds every flag. Then describe the item in the CHANGELOG's `## TODO_AI (Human Review Required)` section, including what the expected refactor looks like and that it was not auto-generated.

Guessing at an API you are unsure about produces a module that installs and then fails at runtime, which is worse than a flagged gap.

## Test environment

The `module-migration/` workspace runs the target Odoo version in Docker with `out/` mounted at `/mnt/extra-addons`:

```bash
cd module-migration

# Bring up the environment (ODOO_VERSION / POSTGRES_VERSION come from .env)
docker compose up -d

# Install / upgrade the migrated module
docker compose exec odoo odoo \
  -d migration_test \
  -i MODULE_NAME \
  --stop-after-init \
  --no-http

# Tail logs
docker compose logs -f odoo
```

Use `-u MODULE_NAME` instead of `-i` to upgrade an already-installed module.

Configuration: `docker-compose.yaml`, `.env` (`ODOO_VERSION`, `POSTGRES_VERSION`), and the `./out` → `/mnt/extra-addons` mount.

`--stop-after-init` proves the module **loads** — schema, views, and data files parse and install. It does **not** exercise runtime flows. Say so when reporting results, and name what remains unproven.

## Agent behavior

- Read and understand the full module before making changes.
- Apply rules in version order; never skip a hop.
- Never mutate the source module.
- After all transformations, scan for leftover deprecated patterns (`references/final-scan.md`).
- Validate xpath anchors against the **target version's** base views. Field positions and template structure shift between versions — this is the most common cause of a module that passes every grep and still fails to install.
- Report install failures with the actual traceback, not a summary.
