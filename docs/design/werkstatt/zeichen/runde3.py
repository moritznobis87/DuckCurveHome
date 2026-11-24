"""Runde 3: Waermepumpe entscheiden, Abstimmen, Regelkreis, dazu die gefuellten Fassungen."""
import json, math, sys
sys.path.insert(0, __file__.rsplit('/', 1)[0])
import geo

V = {}
def speichen(cx, cy, r, n, start):
    aus = ''
    for k in range(n):
        w = math.radians(start + k * 360 / n)
        aus += f'M{geo.p(cx, cy)}L{geo.p(cx + r * math.cos(w), cy + r * math.sin(w))}'
    return aus
def fluegel(cx, cy, r, n, start, bogen):
    aus = ''
    for k in range(n):
        w = math.radians(start + k * 360 / n)
        aus += f'M{geo.p(cx, cy)}A{geo.z(bogen)} {geo.z(bogen)} 0 0 1 {geo.p(cx + r * math.cos(w), cy + r * math.sin(w))}'
    return aus

k13 = '<rect x="3" y="4.5" width="18" height="13" rx="2.5"/><path d="M7 17.5v2M17 17.5v2"/>'
V['wp_f'] = k13 + '<circle cx="9.25" cy="11" r="3.5"/><path d="' + speichen(9.25, 11, 3.5, 3, -135) + '"/><path d="M16 9h1.75M16 13h1.75"/>'
V['wp_g'] = k13 + '<circle cx="9.25" cy="11" r="3.5"/><path d="' + speichen(9.25, 11, 3.5, 4, 45) + '"/><path d="M16 9h1.75M16 13h1.75"/>'
V['wp_h'] = k13 + '<circle cx="9.25" cy="11" r="3.5"/><path d="' + fluegel(9.25, 11, 3.5, 3, -90, 2.3) + '"/><path d="M16 9h1.75M16 13h1.75"/>'
# groesserer Ring, kein Fuss: der Luefter als Hauptsache
V['wp_i'] = '<rect x="3" y="4" width="18" height="14.5" rx="2.5"/><path d="M7 18.5V20M17 18.5V20"/><circle cx="9.75" cy="11.25" r="4"/><path d="' + fluegel(9.75, 11.25, 4, 3, -90, 2.7) + '"/><path d="M17 8.5v5.5"/>'

V['abstimmen_schluessel'] = '<path d="' + geo.schluessel_maul(15.75, 8.25, 5.25, 1.6, 2.0, 15, 0.75) + '"/>'
V['abstimmen_schluessel2'] = '<path d="' + geo.schluessel_maul(15.9, 8.1, 5.1, 1.75, 1.9, 15.2, 0.5) + '"/>'
V['abstimmen_pult'] = '<path d="M6 3.5v8.25M6 16.25v4.25M12 3.5v2.25M12 10.25V20.5M18 3.5V11M18 15.5v5"/><circle cx="6" cy="14" r="2.25"/><circle cx="12" cy="8" r="2.25"/><circle cx="18" cy="13.25" r="2.25"/>'

V['regelkreis_c'] = '<circle cx="6" cy="9" r="2.5"/><path d="M8.5 9h12"/><path d="M17.5 6l3 3-3 3"/><path d="M15 9v6a3 3 0 0 1-3 3H9a3 3 0 0 1-3-3v-3.5"/>'
V['regelkreis_d'] = '<circle cx="5.5" cy="8.5" r="2.25"/><path d="M7.75 8.5h2.5M16.25 8.5h4.5"/><rect x="10.25" y="5.5" width="6" height="6" rx="1.25"/><path d="M18.75 8.5v6.75a3 3 0 0 1-3 3H8.5a3 3 0 0 1-3-3v-4.5"/>'
V['regelkreis_e'] = '<path d="M4 12a8 8 0 0 1 14.5-4.66"/><path d="M20 12a8 8 0 0 1-14.5 4.66"/><path d="M18.75 3.5v4h-4M5.25 20.5v-4h4"/>'

# --- gefuellte Fassungen
def doppelt(d, loecher=''):
    """Flaeche und Rand derselben Kontur: die Flaeche traegt die Loecher, der Rand die runde Aussenkante."""
    return f'<path d="{d}{loecher}" fill="currentColor" stroke="none"/><path d="{d}"/>'

haus_k = 'M3 11.25 12 3.75l3.5 2.92V4.75H18v4l3 2.5-2.5-2.08V19a1 1 0 0 1-1 1h-3.25v-5a1 1 0 0 0-1-1h-2.5a1 1 0 0 0-1 1v5H6.5a1 1 0 0 1-1-1V9.17z'
V['haus_voll'] = doppelt(haus_k)
V['blitz_voll'] = doppelt('M13 3.25 6 13.5h5l-.25 7.25L18 10.5h-5z')
rad_k = geo.zahnrad(8, 9, 6.75, 12, 10.5)
V['rad_voll'] = doppelt(rad_k, geo.kreis(12, 12, 3, loch=True))
V['euro_voll'] = '<path d="' + geo.kreis(12, 12, 9.88) + geo.euro_umriss(13.6, 12, 4.6, 0.9, 50, 1.55, 0.8, 7.1, 13.3, loch=True) + '" fill="currentColor" stroke="none"/>'
V['euro_muenze'] = '<circle cx="12" cy="12" r="9"/><path d="M15.75 8.6a4.4 4.4 0 1 0 0 6.8"/><path d="M7.75 10.75h5M7.75 13.25h5"/>'
kasten_k = 'M5.5 4.5h13A2.5 2.5 0 0 1 21 7v8a2.5 2.5 0 0 1-2.5 2.5h-13A2.5 2.5 0 0 1 3 15V7a2.5 2.5 0 0 1 2.5-2.5z'
V['wp_voll'] = ('<path d="' + kasten_k + geo.kreis(9.25, 11, 4.1, loch=True) + geo.kapsel(16, 9, 17.75, 9, 0.875, loch=True) + geo.kapsel(16, 13, 17.75, 13, 0.875, loch=True)
                + '" fill="currentColor" stroke="none"/><path d="' + kasten_k + '"/><path d="M7 17.5v2M17 17.5v2"/><path d="' + speichen(9.25, 11, 4.1, 3, -135) + '"/>')
# Ente: die Markenkurve als Ruecken, darunter der Leib bis zur Wasserlinie
ente_k = 'M2 15.46C4.48 13.11 6.35 15.9 9.01 15.99 13.18 16.12 13.88 12.84 16.24 9.52 17.39 7.88 19.25 8.19 19.69 9.74 19.96 10.67 20.71 10.85 22 11.07 21.07 11.56 20.27 11.6 19.43 12.04'
V['ente_voll'] = doppelt(ente_k + 'C19.9 14.2 19.3 19.25 14.5 19.25H8C4.6 19.25 2.6 17.6 2 15.46z')
V['ente_voll_b'] = doppelt(ente_k + 'C20.2 15.2 18.6 18.75 14 18.75H8.25C4.9 18.75 2.9 17.5 2 15.46z')

V['statusGut_voll'] = '<path d="' + geo.kreis(12, 12, 9.88) + geo.strichumriss([(8, 12.25), (10.75, 15), (16, 9.5)], 1.0, loch=True) + '" fill="currentColor" stroke="none"/>'
V['warnung_voll'] = doppelt('M12 3.75 21 20H3z', geo.kapsel(12, 10, 12, 14.5, 1.0, loch=True) + geo.kreis(12, 17.4, 1.1, loch=True))
acht_k = 'M8.27 3h7.46L21 8.27v7.46L15.73 21H8.27L3 15.73V8.27z'
V['statusStoerung'] = '<path d="' + acht_k + '"/><path d="M9 9l6 6M15 9l-6 6"/>'
V['statusStoerung_voll'] = doppelt(acht_k, geo.kreuzumriss(12, 12, 4.24, 1.0, loch=True))
V['abspielen_voll'] = doppelt('M8 5.25v13.5L19 12z')
V['anhalten_voll'] = '<rect x="6" y="4.5" width="4.5" height="15" rx="1.25" fill="currentColor" stroke="none"/><rect x="13.5" y="4.5" width="4.5" height="15" rx="1.25" fill="currentColor" stroke="none"/>'

json.dump(V, open(__file__.rsplit('/', 2)[0] + '/runde3.json', 'w'), indent=1)
print(len(V))
