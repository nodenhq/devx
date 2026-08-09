# CHANGELOG — <module_name>

Migration from Odoo **<SOURCE>.0** → **<TARGET>.0**. Rules applied from the `odoo-module-migration` skill, hops v<S>→v<S+1> … v<T-1>→v<T>, plus general rules.

## General

<!-- Always-apply rules that fired. One bullet per concrete change, with the file path. -->
- `__manifest__.py`: `version` bumped `<OLD>` → `<NEW>`.
- `__manifest__.py`: removed `# -*- coding: utf-8 -*-` header (unnecessary since v11+).
- Python `super(ClassName, self).method()` → `super().method()` throughout <where>.

## v<S> → v<S+1>

<!--
One section per hop in range — even hops where nothing matched.

Record NEGATIVE findings explicitly. "No `read_group(` calls" tells a reviewer the rule
was checked and did not apply; silence tells them nothing, and they have to re-verify by hand.
-->

No specific rules matched this module's code:
- No `read_group(` calls (nothing to convert to `_read_group`).
- No `attrs="{...}"` dictionaries in views.
- No usage of removed fields/models.

Only general `super()` modernization applied.

## v<T-1> → v<T>

- `views/<file>.xml`:
  - `<tree>...</tree>` → `<list>...</list>`.
  - `view_mode`: `tree,form` → `list,form`.
- `data/<file>.xml`: removed `<field name="numbercall">-1</field>` (field removed from `ir.cron` in v18).
- No `oe_chatter` div (no chatter conversion needed).

## Decisions

<!--
Judgement calls a reviewer would otherwise have to reverse-engineer: why a value was
dropped rather than translated, which of two valid targets was chosen, what was
deliberately left alone because the rules do not require changing it.
-->

- <Rule X removed field Y; the target version's default behaviour covers it, so the field is simply dropped rather than translated.>
- <`views/<file>.xml` still contains `<form string="...">`. The rules only require removing `string=` from `<tree>`/`<list>`, so the form `string` is preserved.>

## TODO_AI (Human Review Required)

<!--
One H3 per flagged item, matching a `# TODO_AI:` comment in the code.
State: what the code does, why the rules do not cover it, what the expected
refactor is, and that it was NOT auto-generated.

Delete this whole section if there are no TODO_AI comments.
-->

### `<path/to/file.py>` — `<symbol>`

<What the original code does and why it matters.>

The migration rules do **not** cover this area, but Odoo changed <subsystem> in v<N>:

- **v<N>**: <what changed>.

**Expected refactor** (flagged for human implementation, NOT auto-generated):

- <Concrete steps.>

A `# TODO_AI:` comment has been added above <symbol> describing the expected refactor. The v<SOURCE> implementation is preserved verbatim so human reviewers can migrate it deliberately — it will **not work on v<TARGET> as-is**.

## Verification

```bash
docker compose up -d
docker compose exec odoo odoo -d migration_test -i <module_name> --stop-after-init --no-http
docker compose logs -f odoo
```

**Install result (<YYYY-MM-DD>):** <installed cleanly / failed with X>. <N dependency modules loaded, errors, warnings.> <Pre-existing non-blocking notes.>

<!--
State the limits of what the install actually proved. `--stop-after-init` verifies
load and schema only — it does not exercise runtime flows. Say so, and point at the
TODO_AI items that remain unproven.
-->
