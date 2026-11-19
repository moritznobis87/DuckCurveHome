#!/bin/sh
# Startet Chromium im Kiosk (deploy/haus/einrichten.sh setzt @CHROMIUM@ ein). Die Sperren selbst
# stehen in den Richtlinien (/etc/chromium/policies/managed/duckcurve.json); die Schalter hier
# nehmen nur Meldungen und Gesten weg, die in einem Kiosk nichts zu suchen haben.
exec @CHROMIUM@ \
	--kiosk \
	--ozone-platform=wayland \
	--noerrdialogs \
	--disable-infobars \
	--no-first-run \
	--disable-session-crashed-bubble \
	--disable-features=TranslateUI,OverscrollHistoryNavigation \
	--overscroll-history-navigation=0 \
	--disable-pinch \
	--check-for-update-interval=31536000 \
	--password-store=basic \
	--user-data-dir="$HOME/.config/duckcurve-kiosk" \
	file:///opt/duckcurve/kiosk/laden.html
