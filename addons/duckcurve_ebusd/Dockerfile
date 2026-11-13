# Das Grundabbild gibt es für jeden Prozessor unter demselben Namen; build.yaml nennt es dem
# Supervisor zusätzlich je Prozessor.
ARG BUILD_FROM=ghcr.io/home-assistant/base-debian:trixie
# ebusd kommt fertig gebaut aus dem Abbild seines Autors; Docker nimmt von selbst die Fassung für
# den Prozessor des Geräts. Die Fassung steht hier fest, damit ein Neubau dasselbe ergibt.
FROM john30/ebusd:v26.1 AS ebusd

FROM ${BUILD_FROM}
ARG BUILD_VERSION=dev
ENV DCH_ADDON_VERSION=${BUILD_VERSION} LANG=C.UTF-8
# Nur was ebusd zum Laufen braucht (libmosquitto) und was das Startskript benutzt (curl, jq).
RUN echo "Duck Curve eBUS Add-on ${BUILD_VERSION}" \
    && apt-get update \
    && apt-get install -y --no-install-recommends libmosquitto1 ca-certificates curl jq \
    && rm -rf /var/lib/apt/lists/*
COPY --from=ebusd /usr/bin/ebusd /usr/bin/ebusd
COPY --from=ebusd /usr/bin/ebusctl /usr/bin/ebusctl
COPY run.sh /run.sh
COPY aerotop_split.csv /etc/duckcurve/aerotop_split.csv
RUN chmod a+x /run.sh
CMD ["/run.sh"]
