# Duck Curve Home - Web (Next.js standalone). Build-Kontext: apps/web.
#
# **Gebaut wird auf dem Bau-Rechner, nicht auf dem Ziel.** Das Abbild entsteht fuer amd64 (Railway)
# und fuer arm64 (das Hausgeraet, deploy/haus). Bis zum 24.11.2026 lief der ganze Bau je Ziel,
# der arm64-Teil also unter QEMU. Dort stuerzte der Emulator mitten im Next.js-Bau ab
# (`qemu: uncaught target signal 4 (Illegal instruction)`, Lauf 45176921906 auf main am
# 23.11.2026 und Lauf 45352484208 am 24.11.2026), und fuer den betroffenen Stand von main gab
# es dann kein Abbild. Wo er durchlief, brauchte er zehn bis zwanzig Minuten.
#
# Was Next.js baut, ist JavaScript und fuer beide Ziele dasselbe. Deshalb laufen `deps` und
# `build` auf $BUILDPLATFORM und nur einmal. Plattformabhaengig ist allein `sharp`, das Next.js
# fuer seine Bildroute in die Ausgabe legt: `pnpm install` holt es fuer beide Architekturen
# (gemessen: die Ausgabe enthaelt dann `sharp-linuxmusl-x64` und `sharp-linuxmusl-arm64`), und
# die Stufe `ausgabe` wirft je Ziel weg, was nicht passt. Unter dem Emulator laeuft so nur noch
# das Anlegen des Benutzers in der letzten Stufe.
#
# Der Vorgabewert hinter `:-` gilt fuer einen Bau ohne BuildKit, der $BUILDPLATFORM nicht kennt.
FROM --platform=${BUILDPLATFORM:-linux/amd64} node:22-alpine AS deps
RUN corepack enable && corepack prepare pnpm@10 --activate
WORKDIR /app
COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile --os=linux --libc=musl --cpu=x64 --cpu=arm64

FROM --platform=${BUILDPLATFORM:-linux/amd64} node:22-alpine AS build
RUN corepack enable && corepack prepare pnpm@10 --activate
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
ENV NEXT_TELEMETRY_DISABLED=1
RUN pnpm build

# Die Ausgabe fuer ein Ziel: alles aus `build`, von `sharp` nur die Fassung des Ziels. Docker
# nennt die Architektur amd64, npm nennt sie x64; arm64 heisst in beiden gleich.
#
# `ARG TARGETARCH` steht ohne Vorgabewert da, und das ist Absicht: mit `ARG TARGETARCH=amd64`
# gewinnt die Vorgabe gegen den Wert, den BuildKit je Ziel setzt, und das arm64-Abbild bekaeme
# die x64-Fassung (am 24.11.2026 so gemessen). Die Vorgabe fuer einen Bau ohne BuildKit steht
# deshalb in der Shell.
FROM --platform=${BUILDPLATFORM:-linux/amd64} node:22-alpine AS ausgabe
ARG TARGETARCH
WORKDIR /out
COPY --from=build /app/.next/standalone ./
COPY --from=build /app/.next/static ./.next/static
COPY --from=build /app/public ./public
RUN cpu="${TARGETARCH:-amd64}"; [ "$cpu" = "amd64" ] && cpu=x64; \
    find node_modules/.pnpm -maxdepth 1 -name '@img+sharp-*' \
      ! -name "@img+sharp-linuxmusl-${cpu}@*" ! -name "@img+sharp-libvips-linuxmusl-${cpu}@*" \
      -exec rm -rf {} + \
    && find node_modules -type l ! -exec test -e {} \; -delete

FROM node:22-alpine AS runtime
ENV NODE_ENV=production NEXT_TELEMETRY_DISABLED=1 PORT=3000 HOSTNAME=0.0.0.0
RUN addgroup -S dch && adduser -S dch -G dch
WORKDIR /app
COPY --from=ausgabe /out ./
USER dch
EXPOSE 3000
CMD ["node", "server.js"]
