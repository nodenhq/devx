#!/usr/bin/env python3

import ast
import os
import sys
import zipfile
from datetime import datetime, timezone

HELP = """pack-addon.py — Package an Odoo module and its local dependencies into a ZIP.

USAGE
  pack-addon.py MODULE_NAME [EXTRA_FILE ...]

ARGUMENTS
  MODULE_NAME   Name of the Odoo module directory (must contain __manifest__.py).
  EXTRA_FILE    Optional extra files to include in the ZIP (e.g. README, license).

SETUP
  Run this script from the custom addons directory that contains the module folder.
  Local dependencies listed in __manifest__.py 'depends' are automatically included
  if their directories exist in the same path.

OUTPUT
  Creates: MODULE_NAME-VERSION+TIMESTAMP.zip

EXAMPLE
  cd /odoo/custom-addons
  pack-addon.py my_module README.md
"""


def packaging(name, *extra):
    if not os.path.exists(name):
        raise FileNotFoundError(f"Module not found: {name}")

    with open(f"{name}/__manifest__.py", "r", encoding="utf-8") as f:
        data = ast.literal_eval(f.read())

    version = data.get("version")
    if not version:
        raise ValueError(f"No version found in {name}/__manifest__.py")

    depends = [name] + [p for p in data.get("depends", []) if os.path.exists(p)]

    build = int(datetime.now(timezone.utc).timestamp())
    zip_name = f"{name}-{version}+{build}.zip"

    with zipfile.ZipFile(zip_name, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        for dep in depends:
            for root, _, files in os.walk(dep):
                for file in files:
                    zf.write(os.path.join(root, file))
        for fpath in extra:
            if os.path.exists(fpath):
                zf.write(fpath)

    print(zip_name)


if __name__ == "__main__":
    if len(sys.argv) > 1:
        packaging(*sys.argv[1:])
    else:
        print(HELP)
