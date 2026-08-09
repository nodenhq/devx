# noden · DevX Scripts

Operational and addon tooling for Odoo. Every script is self-documenting — run it with `help` or no arguments for full usage.

| Script | Purpose |
|---|---|
| [`db-manager.sh`](db-manager.sh) | Back up / restore an Odoo database through the `/web/database` HTTP API. Works against any reachable Odoo instance; needs the master password. |
| [`stream.sh`](stream.sh) | Back up / restore databases **locally** with `pg_dump` + filestore copy. Config-driven, handles many instances and databases in one run. |
| [`pack.py`](pack.py) | Package an Odoo addon and its local dependencies into a versioned ZIP. |
| [`publish.sh`](publish.sh) | Publish selected paths to a read-only repo (`sync`), or mirror a whole branch between repos (`mirror`). |
| [`copy-addons.sh`](copy-addons.sh) | Copy modules from another repo into the current one, matching the branch you are on. |

Setup:

```bash
chmod +x scripts/*.sh scripts/*.py
```

---

## `db-manager.sh` — remote backup/restore via web API

```bash
./db-manager.sh backup  URL MASTER_PWD DB_NAME [FORMAT] [LOCATION]
./db-manager.sh restore URL MASTER_PWD DB_NAME FILE    [COPY]
```

`FORMAT` is `zip` (default) or `dump`; `LOCATION` defaults to the current directory. Use this when you only have HTTP access to the instance.

## `stream.sh` — local backup/restore via pg_dump

```bash
./stream.sh backup  [CONFIG_FILE]
./stream.sh restore INSTANCE DB ZIP_FILE [CONFIG_FILE]
./stream.sh help
```

Requires `jq` and direct PostgreSQL access.

Config resolution order: the `CONFIG_FILE` argument → `$ODOO_BACKUP_CONFIG` → `stream.json` **next to the script**. Copy the template to get started:

```bash
cp scripts/stream.example.json scripts/stream.json
```

`stream.json` is gitignored — it holds instance credentials. Keep it beside `stream.sh`, or point `$ODOO_BACKUP_CONFIG` somewhere else (e.g. `/etc/odoo/stream.json`).

## `pack.py` — package an addon

```bash
cd /path/to/custom-addons
python3 /path/to/scripts/pack.py MODULE_NAME [EXTRA_FILE ...]
```

Run it **from the custom addons directory** containing the module. It reads `version` from `__manifest__.py`, walks the module plus every `depends` entry that exists locally, and writes `MODULE_NAME-VERSION+YYYYMMDD.zip`.

## `publish.sh` — publish or mirror a repo

```bash
./publish.sh sync   git@github.com:org/public-repo.git -b main
./publish.sh mirror git@github.com:org/source.git git@github.com:org/dest.git
./publish.sh help
```

For `sync`, create a `publish.txt` in the repo you are publishing **from**, listing paths one per line (`#` comments and globs supported). Options: `-b/--branch`, `-f/--file`, `-m/--message`, `--force`, `--dry-run`.

Always `--dry-run` first — `sync` and `mirror` both push to remotes, and `--force` overwrites the target branch.

## `copy-addons.sh` — copy modules from another repo at the same branch

```bash
./copy-addons.sh --path DIR [options] [MODULE ...]
./copy-addons.sh --repo URL [options] [MODULE ...]
./copy-addons.sh help
```

Run it **from the destination repo**. It reads the branch you are on, puts the source repo on that same branch, and copies each module across. Options: `--sources` (default `addons`), `--destiny` (default `addons`), `-b/--branch`, `--no-checkout`, `--skip-existing`, `--dry-run`.

A module is a direct subdirectory of `--sources` containing `__manifest__.py`. Each one is replaced wholesale — the destination copy is removed first, so files deleted upstream do not linger. `__pycache__`, `*.pyc` and `.git` are never copied.

```bash
# On branch 18.0, pull every module from a sibling checkout
./copy-addons.sh --path ../odoo-skydropx

# Clone the source instead, and copy a single module
./copy-addons.sh --repo git@github.com:nodenlabs/odoo-skydropx.git innovt_srenvio
```

With `--path` the source repo is switched to the target branch and **left there**; the script refuses if its working tree is dirty. Use `--no-checkout` to read the branch via `git archive` and leave the source untouched — the safer choice when the source is a checkout you are working in.

---

## Related

- Version migrations live in the Agent Skills under [`../.claude/skills/`](../.claude/skills/) — module code and OpenUpgrade database migrations.
- [`../AGENTS.md`](../AGENTS.md) — repository guide for AI agents.
