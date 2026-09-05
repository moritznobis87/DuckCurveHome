ARG BUILD_FROM=ghcr.io/home-assistant/aarch64-base-python:3.12-alpine3.20
FROM ${BUILD_FROM}
ENV PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1
# Der Supervisor baut mit dem Add-on-Ordner als Kontext, nicht mit dem Repo-Root. Deshalb werden
# hems-core und die Bridge direkt aus dem öffentlichen GitHub-Repository installiert (Ref = Branch/Tag).
ARG DCH_REPO=https://github.com/moritznobis87/DuckCurveHome
ARG DCH_REF=main
RUN apk add --no-cache git \
    && pip install --no-cache-dir \
        "hems-core @ git+${DCH_REPO}@${DCH_REF}#subdirectory=packages/hems-core" \
        "dch-bridge @ git+${DCH_REPO}@${DCH_REF}#subdirectory=apps/bridge" \
    && apk del git
COPY run.sh /run.sh
RUN chmod a+x /run.sh
CMD ["/run.sh"]
