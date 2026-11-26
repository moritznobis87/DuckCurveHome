#!/usr/bin/env bash
# Richtet Duck Curve Home auf einem frischen Raspberry Pi OS Lite (64 Bit) ein
# (deploy/haus/README.md, docs/HAUSGERAET.md).
#
#   sudo ./einrichten.sh [--kiosk] [--ohne-marke] [--name NAME] [--bauen] [--pcie-gen3]
#
#   --kiosk       Am Geraet haengt ein Display: Oberflaeche im Vollbild, kein Betriebssystem sichtbar.
#   --ohne-marke  Startbild und Boot-Einstellungen des Raspberry Pi unveraendert lassen.
#   --name NAME   Name im Netz (Vorgabe duckcurve-home; Oberflaeche dann unter https://NAME.local).
#   --bauen       Images auf dem Geraet bauen statt fertige von GHCR zu ziehen (langsam).
#   --pcie-gen3   NVMe-SSD mit PCIe Gen 3 statt Gen 2 betreiben (offiziell nicht freigegeben).
#
# Beliebig oft ausfuehrbar. Eine vorhandene /opt/duckcurve/.env wird nie ueberschrieben; die
# gewaehlten Schalter merkt sich das Skript fuer `dch selbst-aktualisieren`.

set -euo pipefail

HIER=$(cd "$(dirname "$(readlink -f "$0")")" && pwd)
QUELLE=$(cd "$HIER/../.." && pwd)
# Umlenkbar nur fuer Tests (DCH_NUR_DATEIEN=1); auf dem Geraet gelten die Vorgaben.
BASIS=${DCH_BASIS:-/opt/duckcurve}
SICHERUNG=${DCH_SICHERUNG:-/var/lib/duckcurve/sicherung}
GERAET=${DCH_GERAET:-/var/lib/duckcurve/geraet}

KIOSK=0
MARKE=1
NAME=""
BAUEN=0
PCIE3=0
# Nur fuer Tests ausserhalb eines Pi: keine Pakete, kein systemd, kein Bootloader.
NUR_DATEIEN=${DCH_NUR_DATEIEN:-0}

while [ $# -gt 0 ]; do
	case "$1" in
	--kiosk) KIOSK=1 ;;
	--ohne-marke) MARKE=0 ;;
	--name)
		NAME=${2:-}
		shift
		;;
	--bauen) BAUEN=1 ;;
	--pcie-gen3) PCIE3=1 ;;
	-h | --help)
		sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
		exit 0
		;;
	*)
		echo "Unbekannte Angabe: $1 (--help zeigt die moeglichen)" >&2
		exit 1
		;;
	esac
	shift
done

schritt() { echo; echo "==> $*"; }
[ "$NUR_DATEIEN" = "1" ] || [ "$(id -u)" -eq 0 ] || { echo "Bitte mit sudo ausfuehren." >&2; exit 1; }

if [ -n "$NAME" ] && ! [[ "$NAME" =~ ^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$ ]]; then
	echo "Ungueltiger Name: $NAME (Kleinbuchstaben, Ziffern, Bindestrich)" >&2
	exit 1
fi

BOOT=/boot/firmware
[ -d "$BOOT" ] || BOOT=/boot
IST_PI=0
grep -qi "raspberry pi" /proc/device-tree/model 2>/dev/null && IST_PI=1

# --------------------------------------------------------------------------------------- Pakete

pakete() {
	schritt "Pakete"
	export DEBIAN_FRONTEND=noninteractive
	apt-get update -q
	apt-get install -y -q ca-certificates curl git jq openssl avahi-daemon unattended-upgrades rclone smartmontools

	if ! command -v docker >/dev/null || ! docker compose version >/dev/null 2>&1; then
		schritt "Docker (aus der Paketquelle von Docker)"
		install -m 0755 -d /etc/apt/keyrings
		curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
		chmod a+r /etc/apt/keyrings/docker.asc
		# shellcheck disable=SC1091
		codename=$(. /etc/os-release && echo "$VERSION_CODENAME")
		echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $codename stable" \
			>/etc/apt/sources.list.d/docker.list
		apt-get update -q
		apt-get install -y -q docker-ce docker-ce-cli containerd.io docker-compose-plugin
	fi

	# Protokolle der Container begrenzt und kompakt, damit sie die SSD nicht fuellen.
	if [ ! -f /etc/docker/daemon.json ]; then
		mkdir -p /etc/docker
		echo '{ "log-driver": "local" }' >/etc/docker/daemon.json
		systemctl restart docker
	fi
	systemctl enable --now docker

	# Sicherheitsupdates des Systems automatisch; die Anwendung selbst nur ueber `dch aktualisieren`.
	cat >/etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF
}

# ---------------------------------------------------------------------------------- Name im Netz

name_setzen() {
	local name=$1
	[ "$(hostname)" = "$name" ] && return 0
	schritt "Name im Netz: $name"
	hostnamectl set-hostname "$name"
	if grep -q '^127\.0\.1\.1' /etc/hosts; then
		sed -i "s/^127\.0\.1\.1.*/127.0.1.1\t$name/" /etc/hosts
	else
		printf '127.0.1.1\t%s\n' "$name" >>/etc/hosts
	fi
	systemctl restart avahi-daemon 2>/dev/null || true
}

# ---------------------------------------------------------------------------------------- Zeit

zeitdienst_laeuft() {
	# Haelt schon irgendwer die Uhr? Die Namen sind die ueblichen Pakete in Debian; es genuegt
	# einer, denn mehr als ein Dienst an derselben Uhr zieht sie gegeneinander.
	local dienst
	for dienst in systemd-timesyncd chrony chronyd ntpsec ntp openntpd; do
		systemctl is-active --quiet "$dienst.service" 2>/dev/null && return 0
	done
	return 1
}

zeit() {
	# Die Uhr des Geraets traegt alles: jeder Messwert, jeder Tagesabschluss und die grosse Uhr auf
	# der Wandanzeige haengen an ihr. Der CM5 hat keine gepufferte Echtzeituhr, also startet er mit
	# einer geratenen Zeit und driftet ohne Zeitdienst weiter (am 22.11.2026 ging die Uhr drei
	# Minuten nach). Die Zeitzone stellt der Nutzer beim Bespielen der SSD ein (README Abschnitt 1),
	# die Synchronisation richtet dieses Skript ein - sie darf nicht an einer Rueckfrage haengen und
	# nicht abbrechen, wenn das System kein systemd-timesyncd kennt.
	schritt "Zeit synchron halten"
	if ! command -v timedatectl >/dev/null || [ ! -d /run/systemd/system ]; then
		echo "Hinweis: ohne systemd keine Zeitsynchronisation eingerichtet - Uhr selbst stellen." >&2
		return 0
	fi
	# Ein bereits laufender Zeitdienst bleibt unangetastet: chrony, ntpsec und systemd-timesyncd
	# belegen in Debian dasselbe virtuelle Paket (time-daemon), apt wuerde den vorhandenen Dienst
	# also beim Nachinstallieren entfernen. Zwei Dienste an einer Uhr stoeren sich ausserdem.
	if ! zeitdienst_laeuft; then
		if ! systemctl cat systemd-timesyncd.service >/dev/null 2>&1; then
			DEBIAN_FRONTEND=noninteractive apt-get install -y -q systemd-timesyncd ||
				echo "Hinweis: systemd-timesyncd liess sich nicht installieren." >&2
		fi
		# set-ntp schaltet den Zeitdienst ein, den timedated kennt, und startet ihn; ohne einen
		# solchen schlaegt es fehl, und das darf die Einrichtung nicht beenden.
		timedatectl set-ntp true 2>/dev/null ||
			echo "Hinweis: Zeitsynchronisation liess sich nicht einschalten." >&2
	fi
	# Dieselben Felder liest `dch zustand` fuer die App; hier stehen sie fuer den, der einrichtet.
	timedatectl show -p Timezone -p NTP -p NTPSynchronized 2>/dev/null | sed 's/^/    /' || true
}

# ------------------------------------------------------------------------------------- Dateien

zufall() { openssl rand -hex 24; }

dateien() {
	schritt "Dateien unter $BASIS"
	install -d -m 0755 "$BASIS" "$BASIS/kiosk"
	install -d -m 0700 "$SICHERUNG"
	# Austausch mit der App: Berichte, Status und Protokolle schreibt nur dieses Geraet, in anfrage/
	# darf die API (Benutzer 10001 im Image) eine Anfrage ablegen - mehr kann sie hier nicht.
	install -d -m 0755 "$GERAET" "$GERAET/protokoll"
	install -d -m 0770 "$GERAET/anfrage"
	[ "$NUR_DATEIEN" = "1" ] || chown 10001:10001 "$GERAET/anfrage"
	install -m 0644 "$HIER/compose.yaml" "$BASIS/compose.yaml"
	install -m 0644 "$HIER/Caddyfile" "$BASIS/Caddyfile"
	install -m 0755 "$HIER/dch" "$BASIS/dch"
	[ "$NUR_DATEIEN" = "1" ] || ln -sfn "$BASIS/dch" /usr/local/bin/dch
	ln -sfn "$QUELLE" "$BASIS/quelle"

	if [ ! -f "$BASIS/.env" ]; then
		schritt "Neue Einstellungen mit eigenen Geheimnissen ($BASIS/.env)"
		local zeile
		umask 077
		while IFS= read -r zeile || [ -n "$zeile" ]; do
			# Jedes @ZUFALL@ bekommt einen eigenen Wert, nicht alle denselben.
			while [[ "$zeile" == *@ZUFALL@* ]]; do
				zeile=${zeile/@ZUFALL@/$(zufall)}
			done
			printf '%s\n' "$zeile"
		done <"$HIER/env.vorlage" >"$BASIS/.env"
		umask 022
	fi
	chmod 600 "$BASIS/.env"
	if [ -n "$NAME" ]; then
		sed -i "s/^DCH_HOSTNAME=.*/DCH_HOSTNAME=$NAME/" "$BASIS/.env"
	fi
	NAME=$(sed -n 's/^DCH_HOSTNAME=//p' "$BASIS/.env" | tail -n1)
	NAME=${NAME:-duckcurve-home}

	if [ "$BAUEN" = "1" ]; then
		# Die Images aus dem Quelltext bauen; dieselben Dockerfiles wie in der CI.
		cat >"$BASIS/compose.bauen.yaml" <<EOF
# Von einrichten.sh --bauen angelegt: Images auf dem Geraet bauen statt sie zu ziehen.
services:
  api:
    image: duckcurve-api:lokal
    build:
      context: $BASIS/quelle
      dockerfile: apps/api/Dockerfile
  web:
    image: duckcurve-web:lokal
    build:
      context: $BASIS/quelle/apps/web
EOF
	else
		rm -f "$BASIS/compose.bauen.yaml"
	fi

	# Die Schalter fuer `dch selbst-aktualisieren`.
	{
		[ "$KIOSK" = "1" ] && echo "--kiosk"
		[ "$MARKE" = "0" ] && echo "--ohne-marke"
		[ "$BAUEN" = "1" ] && echo "--bauen"
		[ "$PCIE3" = "1" ] && echo "--pcie-gen3"
		true
	} | tr '\n' ' ' >"$BASIS/einrichtung.conf"
}

# ------------------------------------------------------------------------------------- Dienste

dienste() {
	schritt "Systemdienste"
	install -m 0644 "$HIER/systemd/duckcurve.service" /etc/systemd/system/duckcurve.service
	install -m 0644 "$HIER/systemd/duckcurve-sicherung.service" /etc/systemd/system/duckcurve-sicherung.service
	install -m 0644 "$HIER/systemd/duckcurve-sicherung.timer" /etc/systemd/system/duckcurve-sicherung.timer
	install -m 0644 "$HIER/systemd/duckcurve-anfrage.path" /etc/systemd/system/duckcurve-anfrage.path
	install -m 0644 "$HIER/systemd/duckcurve-anfrage.service" /etc/systemd/system/duckcurve-anfrage.service
	install -m 0644 "$HIER/systemd/duckcurve-pruefen.service" /etc/systemd/system/duckcurve-pruefen.service
	install -m 0644 "$HIER/systemd/duckcurve-pruefen.timer" /etc/systemd/system/duckcurve-pruefen.timer
	install -m 0644 "$HIER/systemd/duckcurve-zustand.service" /etc/systemd/system/duckcurve-zustand.service
	install -m 0644 "$HIER/systemd/duckcurve-zustand.timer" /etc/systemd/system/duckcurve-zustand.timer
	systemctl daemon-reload
	systemctl enable duckcurve.service duckcurve-sicherung.timer duckcurve-anfrage.path duckcurve-pruefen.timer \
		duckcurve-zustand.timer
	systemctl start duckcurve-sicherung.timer duckcurve-anfrage.path duckcurve-pruefen.timer duckcurve-zustand.timer

	if [ "$BAUEN" = "1" ]; then
		schritt "Images bauen (das dauert einige Minuten)"
		dch_compose build
	fi
	schritt "Dienste starten (beim ersten Mal werden die Images geladen)"
	systemctl restart duckcurve.service
}

dch_compose() {
	local dateien=(-f "$BASIS/compose.yaml")
	[ -f "$BASIS/compose.bauen.yaml" ] && dateien+=(-f "$BASIS/compose.bauen.yaml")
	docker compose --project-directory "$BASIS" "${dateien[@]}" "$@"
}

# --------------------------------------------------------------------------- Boot-Einstellungen

# Ein verwalteter Block am Ende von config.txt, unter [all], damit er nicht in einen bedingten
# Abschnitt ([cm5], [pi5], ...) faellt. Beim naechsten Lauf wird er ersetzt, nicht verdoppelt.
config_block() {
	local datei="$BOOT/config.txt" block=$1 vorher
	[ -f "$datei" ] || return 0
	vorher=$(cat "$datei")
	sed -i '/^# duckcurve-anfang$/,/^# duckcurve-ende$/d' "$datei"
	# Die Leerzeile vor dem Block wuerde sonst bei jedem Lauf eine mehr.
	sed -i -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$datei"
	if [ -n "$block" ]; then
		printf '\n# duckcurve-anfang\n[all]\n%s\n# duckcurve-ende\n' "$block" >>"$datei"
	fi
	[ "$(cat "$datei")" = "$vorher" ] || NEUSTART=1
}

cmdline_ergaenzen() {
	# Die Kernelzeile um Parameter ergaenzen, die noch fehlen. cmdline.txt ist eine einzige Zeile;
	# eine zweite wuerde der Pi stillschweigend ueberlesen. Mit --marke zusaetzlich die Konsole
	# vom Bildschirm weg (tty3).
	local datei="$BOOT/cmdline.txt" zeile vorher p
	[ -f "$datei" ] || return 0
	zeile=$(head -n1 "$datei")
	vorher=$zeile
	if [ "${1:-}" = "--marke" ]; then
		zeile=$(echo "$zeile" | sed 's/console=tty1/console=tty3/')
		shift
	fi
	for p in "$@"; do
		[[ " $zeile " == *" $p "* ]] || zeile="$zeile $p"
	done
	if [ "$zeile" != "$vorher" ]; then
		# Die Fassung von vor der ersten Aenderung bleibt erhalten, nicht die von gestern.
		[ -f "$datei.vor-duckcurve" ] || cp "$datei" "$datei.vor-duckcurve" 2>/dev/null || true
		echo "$zeile" >"$datei"
		NEUSTART=1
	fi
}

bootloader() {
	# Startreihenfolge: SD-Karte vor NVMe. Beim Kunden steckt keine Karte, also startet die SSD;
	# fuer eine Wartung startet eine eingelegte Karte. Mit Marke kein Diagnosebildschirm.
	command -v rpi-eeprom-config >/dev/null || return 0
	local jetzt neu
	jetzt=$(rpi-eeprom-config 2>/dev/null || true)
	[ -n "$jetzt" ] || return 0
	neu=$(echo "$jetzt" | grep -v -E '^(BOOT_ORDER|DISABLE_HDMI)=')
	neu="$neu"$'\n'"BOOT_ORDER=0xf461"
	[ "$MARKE" = "1" ] && neu="$neu"$'\n'"DISABLE_HDMI=1"
	if [ "$(echo "$jetzt" | sort)" != "$(echo "$neu" | sed '/^$/d' | sort)" ]; then
		if [ "$MARKE" = "1" ]; then
			schritt "Bootloader: Startreihenfolge und Diagnosebildschirm"
		else
			schritt "Bootloader: Startreihenfolge"
		fi
		local datei
		datei=$(mktemp)
		echo "$neu" | sed '/^$/d' >"$datei"
		rpi-eeprom-config --apply "$datei" ||
			echo "Hinweis: Bootloader nicht geaendert (Schreibschutz-Jumper auf der IO-Platine?)." >&2
		rm -f "$datei"
		NEUSTART=1
	fi
}

boot_einstellungen() {
	[ "$IST_PI" = "1" ] || return 0
	schritt "Boot-Einstellungen"
	local block=""
	[ "$PCIE3" = "1" ] && block="dtparam=pciex1_gen=3"
	if [ "$MARKE" = "1" ]; then
		# Kein Regenbogen beim Einschalten.
		block="${block:+$block$'\n'}disable_splash=1"
	fi
	config_block "$block"
	# Speicherabrechnung fuer Container: Der Kernel von Raspberry Pi OS schaltet sie ab Werk ab
	# (`docker info` warnt dann "No memory limit support"), und `docker stats` meldet fuer jeden
	# Dienst 0 MB. Die Seite Hausgeraet zeigte genau das, am ersten Geraet am 26.11.2026.
	cmdline_ergaenzen cgroup_enable=memory cgroup_memory=1
	# Keine Himbeeren, keine Meldungen, Startbild an.
	[ "$MARKE" = "1" ] && cmdline_ergaenzen --marke quiet splash logo.nologo vt.global_cursor_default=0 \
		loglevel=0 plymouth.ignore-serial-consoles
	bootloader
}

# --------------------------------------------------------------------------------------- Marke

marke() {
	[ "$MARKE" = "1" ] || return 0
	schritt "Startbild (Duck Curve statt Raspberry Pi)"
	apt-get install -y -q plymouth
	install -d /usr/share/plymouth/themes/duckcurve
	install -m 0644 "$HIER/marke/plymouth/"* /usr/share/plymouth/themes/duckcurve/
	# -R baut die Initramdisk neu, damit das Startbild schon frueh erscheint.
	plymouth-set-default-theme -R duckcurve
}

# --------------------------------------------------------------------------------------- Kiosk

kiosk() {
	[ "$KIOSK" = "1" ] || return 0
	schritt "Kiosk: nur die Anwendung auf dem Display"
	local chromium="chromium"
	if ! apt-cache show chromium >/dev/null 2>&1; then
		chromium="chromium-browser"
	fi
	apt-get install -y -q cage "$chromium" fonts-dejavu-core

	# Ein eigener Benutzer ohne Passwort und ohne Rechte.
	id kiosk >/dev/null 2>&1 || useradd --system --create-home --shell /usr/sbin/nologin kiosk
	usermod -a -G video,render,input,audio kiosk

	# Seit dem 23.11.2026 gibt es keinen Pairing-Link mehr, mit dem sich das Display selbst
	# anmelden koennte - er vergab Vollzugriff ueber einen stehenden Token. Die Ladeseite zeigt
	# deshalb auf die Anwendung; wie sich das Display dort ausweist, ist OFFEN (siehe README).
	sed -e "s|@KOPPELN@|http://localhost:3000/|" \
		"$HIER/kiosk/laden.html" >"$BASIS/kiosk/laden.html"
	install -m 0644 "$HIER/kiosk/ente.svg" "$BASIS/kiosk/ente.svg"
	sed -e "s|@CHROMIUM@|$(command -v "$chromium")|" "$HIER/kiosk/start.sh" >"$BASIS/kiosk/start.sh"
	chown root:kiosk "$BASIS/kiosk/laden.html"
	chmod 0640 "$BASIS/kiosk/laden.html"
	chmod 0755 "$BASIS/kiosk/start.sh"

	# Chromium-Richtlinien: nur die Anwendung, keine Entwicklerwerkzeuge, keine Downloads, ...
	install -d /etc/chromium/policies/managed
	install -m 0644 "$HIER/kiosk/richtlinien.json" /etc/chromium/policies/managed/duckcurve.json

	# Kein Weg auf die Konsole.
	echo 'kernel.sysrq = 0' >/etc/sysctl.d/90-duckcurve.conf
	sysctl -q -p /etc/sysctl.d/90-duckcurve.conf || true
	systemctl mask ctrl-alt-del.target >/dev/null 2>&1 || true
	systemctl disable getty@tty1.service >/dev/null 2>&1 || true

	install -m 0644 "$HIER/systemd/duckcurve-kiosk.service" /etc/systemd/system/duckcurve-kiosk.service
	systemctl daemon-reload
	systemctl set-default graphical.target
	systemctl enable duckcurve-kiosk.service
	NEUSTART=1
}

# ------------------------------------------------------------------------------------------ Lauf

NEUSTART=0
if [ "$NUR_DATEIEN" = "1" ]; then
	dateien
	exit 0
fi

pakete
zeit
dateien
name_setzen "$NAME"
dienste
boot_einstellungen
marke
kiosk

schritt "Fertig"
/usr/local/bin/dch koppeln || true
if [ "$NEUSTART" = "1" ]; then
	echo
	echo "Boot-Einstellungen wurden geaendert. Bitte einmal neu starten: sudo reboot"
fi
