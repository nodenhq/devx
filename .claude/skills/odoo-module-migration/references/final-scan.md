# Final Scan — Leftover Deprecated Patterns

**Applies when:** all version hops are done, before writing the `CHANGELOG.md` and installing. Catches rules that were missed because a pattern appeared in an unexpected file type.

Run the sweep for **every version in your range**, not just the last hop.

---

## Quick Reference: Version-Specific Rule Summary

| Version | Key Changes |
|---|---|
| **General** | `super(Cls, self)`→`super()`; `from openerp`→`from odoo`; remove `print()` debug; model inheritance pattern (no `_name` when extending) |
| **v13** | Remove `@api.multi`/`@api.one`; `sudo(user)`→`with_user(user)`; `track_visibility`→`tracking=True`; `env.company`; `_company_default_get()`→`env.company`; `raise Warning()`→`ValidationError`; remove `size=N` from Char; remove `pycompat` |
| **v14** | `<act_window>`/`<report>` → `<record>`; `phantom_js`→`browser_js`; tour steps update; remove inline `<script>` from views |
| **v15** | `toggle_button`→`boolean_toggle`; commission model renames |
| **v16** | `_description` required on all models; `flush()`/`invalidate_cache()` deprecated; `stock.production.lot`→`stock.lot`; `account.account.type` removed; `_rec_names_search` |
| **v17** | `read_group`→`_read_group` refactor; `attrs`→inline expressions; `states` attr→`invisible`; `oe_edit_only`/`oe_read_only` removed; `message_post_with_view`→`message_post_with_source`; `web.assets_common` removed |
| **v18** | `<tree>`→`<list>`; `<chatter/>`; kanban classes; `user_has_groups`; `unaccent` removed; `ustr` removed; `_name_search`→`_search_display_name`; `Registry` import; `related store=True` cleanup; `base_address_city` merged into `base`; remove `widget="field_partner_autocomplete"` |
| **v19** | `expression`→`Domain`; `_sql_constraints`→`models.Constraint`; `type='json'`→`type='jsonrpc'`; `._cr`→`.env.cr`; `auto_join`→`bypass_search_access`; `groups_id`→`group_ids`; `category_id`→`privilege_id` on `res.groups` (new `res.groups.privilege` model); `users`→`user_ids` on `res.groups`; `target='inline'`→`target='main'`; settings `<app>/<block>/<setting>` pattern; `web_icon` root-only; stricter XML validation; `ormcache_context` deprecated; `self.env.tz`; `tools.urls.urljoin` |

---

## Grep Sweep

Run from inside the migrated module directory. **Every hit is either a missed rule or a deliberate decision that belongs in the CHANGELOG.**

```bash
# --- General ---
grep -rn 'super([A-Za-z_]\+, *self)' --include='*.py' .
grep -rn 'from openerp\|import openerp' --include='*.py' .
grep -rn '^\s*print(' --include='*.py' .
grep -rn 'coding: utf-8\|encoding: utf-8' --include='*.py' .
grep -rn 'noupdate="0"' --include='*.xml' .

# --- v13 ---
grep -rn '@api\.multi\|@api\.one\|@api\.returns\|@api\.model_cr' --include='*.py' .
grep -rn 'track_visibility\|_company_default_get\|suspend_security' --include='*.py' .
grep -rn 'raise Warning(' --include='*.py' .
grep -rn 'size=[0-9]' --include='*.py' .
grep -rn 'pycompat\|decimal_precision' --include='*.py' .
grep -rn 'view_type\|src_model' --include='*.xml' .

# --- v14 ---
grep -rn '<act_window\|<report ' --include='*.xml' .
grep -rn '<script' --include='*.xml' .
grep -rn 'phantom_js' --include='*.py' .
grep -rn 'tour\.STEPS' --include='*.js' .

# --- v15 ---
grep -rn 'toggle_button' --include='*.xml' .

# --- v16 ---
grep -rn 'get_xml_id\|fields_get_keys\|invalidate_cache\|\.recompute(\|\.refresh(' --include='*.py' .
grep -rln '_name *=' --include='*.py' . | xargs -r grep -Ln '_description'   # models missing _description

# --- v17 ---
grep -rn '\.read_group(' --include='*.py' .
grep -rn 'message_post_with_view' --include='*.py' .
grep -rn 'attrs=' --include='*.xml' .
grep -rn 'states=' --include='*.xml' .
grep -rn 'oe_edit_only\|oe_read_only' --include='*.xml' .
grep -rn 'assets_common\|get_formview_action' --include='*.xml' --include='*.py' .

# --- v18 ---
grep -rni 'tree' --include='*.xml' --include='*.py' --include='*.js' .
grep -rn 'oe_chatter' --include='*.xml' .
grep -rn 'kanban-card\|kanban-box\|kanban-menu' --include='*.xml' .
grep -rn 'numbercall\|doall' --include='*.xml' .
grep -rn 'field_partner_autocomplete' --include='*.xml' .
grep -rn 'user_has_groups\|unaccent=\|ustr(\|_name_search\|chart_template_ref' --include='*.py' .
grep -rn 'from odoo import registry\|odoo\.registry(' --include='*.py' .

# --- v19 ---
grep -rn 'osv import expression\|osv\.expression' --include='*.py' .
grep -rn '_sql_constraints' --include='*.py' .
grep -rn "type=['\"]json['\"]" --include='*.py' .
grep -rn '\._cr\|\._uid\|\._context' --include='*.py' .
grep -rn 'auto_join=' --include='*.py' .
grep -rn 'groups_id' --include='*.py' --include='*.xml' .
grep -rn 'category_id' --include='*.xml' security/ data/ 2>/dev/null   # res.groups only
grep -rn 'target=.inline.' --include='*.xml' --include='*.py' .
grep -rn 'app_settings_block' --include='*.xml' .
grep -rn 'web_icon' --include='*.xml' .
grep -rn 'ormcache_context\|pytz\.timezone' --include='*.py' .
grep -rn 'url_join\|urljoin' --include='*.py' .
```

**Known false positives** — expected hits that are correct as-is:

- `grep -rni tree` matches `<field name="complete_name">` contexts, directory names, and prose. Only view-context `tree` must change.
- `<menuitem groups="...">` is the external-ID shortcut attribute, **not** the `groups_id` field — leave it.
- `res.groups.privilege` records legitimately keep `category_id` (pointing at `ir.module.category`). Only `res.groups` records rename it to `privilege_id`.
- `size=N` on non-`Char` fields (e.g. image dimensions) is unrelated to the v13 rule.

---

## Structural Checks

Beyond pattern matching:

1. **All imports resolve** — no leftover imports of removed modules (`expression`, `ustr`, `pycompat`, `decimal_precision`, `registry`).
2. **XML is well-formed** — parse every file:
   ```bash
   find . -name '*.xml' -exec python3 -c 'import sys,xml.dom.minidom as m; m.parse(sys.argv[1])' {} \;
   ```
3. **XPath anchors validated against the target version's base views.** Field positions and template structure shift significantly between versions; an xpath that resolved in the source version can silently fail or match the wrong node. This is the single most common cause of a module that passes every grep and still fails to install. Check anchors against the actual target-version view, not against memory.
4. **Manifest** — `version` matches the target (`19.0.1.0.0` form), `installable` is `True`, `depends` has no deprecated entries (see [deprecated-modules.md](deprecated-modules.md)), no `migrations/` folder left in the module.
5. **Every `# TODO_AI:` is accounted for** in the CHANGELOG's `## TODO_AI (Human Review Required)` section:
   ```bash
   grep -rn 'TODO_AI' .
   ```
