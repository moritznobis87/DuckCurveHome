ARG BUILD_FROM=ghcr.io/home-assistant/aarch64-base-python:3.12-alpine3.20
FROM ${BUILD_FROM}
ENV PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1
WORKDIR /opt/dch
# Quellen: hems-core und die Bridge (Build-Kontext ist das Repo-Root, siehe build.yaml)
COPY packages/hems-core /opt/dch/packages/hems-core
COPY apps/bridge /opt/dch/apps/bridge
RUN pip install --no-cache-dir /opt/dch/packages/hems-core /opt/dch/apps/bridge
COPY addons/duckcurve_bridge/run.sh /run.sh
RUN chmod a+x /run.sh
CMD ["/run.sh"]
