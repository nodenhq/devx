# Odoo Module Migration — General Rules (Apply Always)

**Applies when:** always. Load this reference first, before any version-hop reference, regardless of the source → target range.

---

## Manifest File
- Rename `__openerp__.py` → `__manifest__.py` (if still named `__openerp__.py`).
- Set `"installable": True` in the manifest.
- Remove the `migrations/` folder from the module if it exists.
- Update the `version` field to match the target Odoo version (e.g., `"19.0.1.0.0"`).
- Remove `<data noupdate="0">` → replace with `<data>` in XML data files.
- Remove the `string="..."` attribute from `<tree>` / `<list>` tags in XML.

## Python Encoding Headers
- Remove `# -*- encoding: utf-8 -*-` and `# -*- coding: utf-8 -*-` headers (unnecessary since v11+).

## Python 3 Modernization
- **Replace** `super(ClassName, self).method()` → `super().method()` (Python 3 style, cleaner and less error-prone).
- **Replace** `from openerp import ...` → `from odoo import ...` and `from openerp.exceptions` → `from odoo.exceptions` (if migrating from v8-v10 era code).
- **Remove** `print()` debug statements — replace with `_logger.debug()` or `_logger.info()` if logging is needed.

## Model Inheritance Pattern
When extending an **existing** model (e.g., `res.partner`, `res.company`), do NOT set `_name`:
```python
# WRONG (creates a new model or causes conflicts)
class ResPartner(models.Model):
    _name = 'res.partner'
    _inherit = ['res.partner', 'mail.thread']

# CORRECT (extends the existing model)
class ResPartner(models.Model):
    _inherit = 'res.partner'
```
> **Note**: If the base model already inherits `mail.thread` (as `res.partner` does in v13+), do not re-add it to the `_inherit` list.

## Obsolete Artifacts
- Delete the `migrations/` folder if it exists.
- Remove Python 2 encoding headers (see above).
