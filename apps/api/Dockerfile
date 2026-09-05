# Duck Curve Home – API und Worker (ein Image, zwei Startkommandos). Build-Kontext: Repo-Root.
FROM python:3.12-slim AS base
ENV PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1 UV_COMPILE_BYTECODE=1 UV_LINK_MODE=copy \
    UV_PYTHON_PREFERENCE=only-system UV_PYTHON=/usr/local/bin/python3
COPY --from=ghcr.io/astral-sh/uv:0.8 /uv /uvx /bin/
WORKDIR /app

FROM base AS deps
COPY pyproject.toml uv.lock ./
COPY packages/hems-core/pyproject.toml packages/hems-core/pyproject.toml
COPY apps/api/pyproject.toml apps/api/pyproject.toml
COPY apps/bridge/pyproject.toml apps/bridge/pyproject.toml
# Alle Workspace-Mitglieder als Stubs, damit uv das Lockfile auflösen kann; installiert wird nur dch-api.
RUN mkdir -p packages/hems-core/src/hems_core apps/api/src/dch_api apps/bridge/src/dch_bridge \
 && touch packages/hems-core/src/hems_core/__init__.py apps/api/src/dch_api/__init__.py apps/bridge/src/dch_bridge/__init__.py \
 && uv sync --frozen --no-dev --package dch-api

FROM base AS runtime
RUN useradd --create-home --uid 10001 dch
COPY --from=deps /app/.venv /app/.venv
COPY packages/hems-core /app/packages/hems-core
COPY apps/api /app/apps/api
COPY config /app/config
ENV PATH="/app/.venv/bin:$PATH" DCH_HOST=0.0.0.0 DCH_PORT=8000
USER dch
EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=5s --start-period=40s CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=3).status==200 else 1)"
CMD ["uvicorn", "dch_api.main:app", "--host", "0.0.0.0", "--port", "8000"]
