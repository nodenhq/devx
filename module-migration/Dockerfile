ARG ODOO_VERSION=19.0
FROM odoo:${ODOO_VERSION}

LABEL org.opencontainers.image.title="Noden Odoo Module Migration Workspace" \
      org.opencontainers.image.description="Test environment for AI-assisted Odoo module migrations (v12 → v19)" \
      org.opencontainers.image.vendor="Noden" \
      org.opencontainers.image.url="https://sentilis.me/nodenhq" \
      org.opencontainers.image.source="https://github.com/nodenhq/devx"

USER root

RUN mkdir -p /mnt/extra-addons && chown -R odoo:odoo /mnt/extra-addons

USER odoo
