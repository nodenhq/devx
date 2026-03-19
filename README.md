Noden Odoo DevX
==================

Developer Experience (DevX) and infrastructure scripts for the Odoo ecosystem. 

Overview
--------
This repository provides standard tools for Odoo infrastructure, module packaging, and database migrations.

Directory Structure
-------------------
```text
|-- core/             # Infrastructure and server scripts
|   |-- backup.sh     # Database and filestore backup automation
|   |-- stream.sh     # Database streaming and dumping
|-- modules/          # Addon management tools
|   |-- pack.py       # Clean addon packaging utility
|   |-- publish.sh    # Addon publishing automation
|-- docs/             # Engineering guides & AI Skills
|   |-- migration.md  # Agentic skill/system prompt for module migrations
```

Quick Start
-----------
Clone the repository and grant execution permissions to the scripts:

```bash
git clone https://github.com/nodenhq/devx.git
cd devx
chmod +x core/*.sh modules/*.sh
```

Note: Refer to the header of each individual script for specific parameters and usage instructions.
