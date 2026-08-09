# Odoo Deprecated Modules Reference (Cumulative v12→v19)

**Applies when:** a manifest `depends` entry, an import, or an `ir_module_module` row references a module that is missing in the target version.

Shared reference — used by both the [odoo-module-migration](../SKILL.md) skill (to fix `depends` lists) and the [odoo-db-migration](../../odoo-db-migration/SKILL.md) skill (to uninstall modules before a hop).

When migrating, verify the module's `depends` list. Below is a summary of key module changes. If a dependency references a deprecated/renamed/merged module, update accordingly.

---

## Modules Removed (No Replacement)

`web_settings_dashboard`, `account_budget`, `anonymization`, `mrp_repair`, `pos_data_drinks`, `product_extended`, `rating_project`, `report_intrastat`, `website_forum_doc`, `website_rating_project`, `website_sale_options`, `website_sale_stock_options`, `l10n_be_intrastat`, `l10n_be_intrastat_2019`, `document`, `l10n_eu_service`, `hw_blackbox_be`, `website_form_project`, `crm_reveal`, `snailmail_account`, `account_cancel`, `website_sale_coupon`, `account_analytic_default`, `pad`, `pad_project`, `google_spreadsheet`, `base_setup`, `web_tour`, `website_event_track_quiz`, `survey_question_type`

## Modules Merged Into Another

| Old Module | Merged Into |
|---|---|
| `account_cash_basis_base_account` | `account` |
| `account_invoicing` | `account` |
| `auth_crypt` | `base` |
| `sale_order_dates` | `sale` |
| `sale_payment` | `sale` |
| `sale_service_rating` | `sale_timesheet` |
| `web_planner` | `web` |
| `website_livechat` | `livechat` |
| `base_address_city` | `base` (but `res.city` **views/actions** stay in `base_address_extended` — see [v17-v18.md](v17-v18.md)) |

## Modules Renamed

| Old Module | New Module |
|---|---|
| `base_vat_autocomplete` | `partner_autocomplete` |
| `stock_picking_wave` | `stock_picking_batch` |
| `base_action_rule` | `base_automation` |

## Modules Moved to OCA

| Old Module | New Module | OCA Repository |
|---|---|---|
| `account_asset` | `account_asset_management` | OCA/account-financial-tools |
| `hr_timesheet_sheet` | `hr_timesheet_sheet` | OCA/hr-timesheet |
| `account_budget` | — | OCA (see note below) |

---

## Per-Hop Index

Which modules to expect trouble from at each hop. Primarily for the database-migration workflow, where deprecated modules must be uninstalled **before** running the hop.

| Hop | Modules |
|---|---|
| v12 → v13 | `document`, `report_intrastat`, `l10n_eu_service`, `hw_blackbox_be` |
| v13 → v14 | `website_form_project`, `crm_reveal`, `snailmail_account` |
| v14 → v15 | `web_settings_dashboard`, `account_cancel`, `website_sale_coupon` |
| v15 → v16 | `account_analytic_default`, `pad`, `pad_project`, `google_spreadsheet` |
| v16 → v17 | `base_setup`, `web_tour`, `website_event_track_quiz`, `survey_question_type` |
| v17 → v18 | `account_budget` (→ OCA), `website_livechat` (merged into `livechat`) |
| v18 → v19 | **Unverified** — not yet catalogued here |

---

## Unverified / Needs Confirmation

Do not act on these as facts; confirm against the target version's addon list or [OpenUpgrade coverage](https://oca.github.io/OpenUpgrade/) first.

- **v18 → v19 removals** are not catalogued. The source rulesets recorded only "various consolidations" and "check OCA OpenUpgrade docs for latest removals". Verify against the v19 addons directory before assuming a module survived.
- **`web_settings_dashboard`** — the module ruleset dated its removal to v12→v13; the database ruleset dated it to v14→v15. The two disagree; confirm against the actual version you are hopping from.
- **`account_budget`** — the module ruleset lists it as removed with no replacement (v12→v13); the database ruleset lists it as moved to OCA at v17→v18. Both may be true at different points in its history. Confirm before rewriting a `depends` entry.

Always cross-check the target version's addons directory rather than trusting this table alone:

```bash
# Is the module present in the target version's core addons?
docker compose exec odoo ls /usr/lib/python3/dist-packages/odoo/addons | grep '^module_name$'
```
