/* Beispieldaten für die Entwürfe der Startseite (Werkstatt, 25.11.2026).
   Drei Szenen desselben Novembertags, gewählt über die Adresse: entwurf.html?szene=mittag,
   ?szene=abend (Vorgabe) oder ?szene=stoerung. Die Zahlen sind erfunden, aber stimmig: Quellen
   und Verbraucher gehen in jeder Szene auf, und die Reihen sind festgelegt, nicht zufällig.

   Ein Entwurf liest window.SZENE. Alle Texte stehen so da, wie die Seite sie zeigen würde. */
(function () {
  var de = function (n, stellen) {
    if (n == null || !isFinite(n)) return "–";
    return n.toFixed(stellen == null ? 1 : stellen).replace(".", ",");
  };
  window.de = de;

  // Ein fester Zufall, damit jede Aufnahme dieselbe Kurve zeigt.
  var saat = 20261125;
  var zufall = function () {
    saat = (saat + 0x6d2b79f5) | 0;
    var t = Math.imul(saat ^ (saat >>> 15), 1 | saat);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };

  // ---------------------------------------------------------------- der Kalendertag, 96 Viertelstunden
  var AUF = 7.87, UNTER = 16.35; // Sonnenaufgang 07:52, Untergang 16:21
  var glocke = function (h, hoch) {
    if (h <= AUF || h >= UNTER) return 0;
    var x = (h - AUF) / (UNTER - AUF);
    return hoch * Math.pow(Math.sin(Math.PI * x), 1.6);
  };
  var PREIS_STUNDE = [27, 26, 24, 24, 25, 28, 34, 41, 45, 43, 38, 31, 26, 22, 22, 25, 33, 46, 53, 51, 47, 39, 34, 30];
  var PREIS_MORGEN = [28, 26, 25, 24, 26, 29, 36, 43, 44, 40, 35, 29, 25, 23, 24, 27, 35, 44, 49, 48, 42, 37, 32, 29];
  var PREIS_GESTERN = [30, 29, 28, 27, 28, 31, 37, 42, 43, 41, 37, 33, 30, 28, 29, 32, 38, 45, 48, 46, 41, 36, 33, 31];
  var prognose = [], gemessen = [], gestern = [], haus = [], preis = [];
  for (var i = 0; i < 96; i++) {
    var h = i / 4;
    var p = glocke(h, 4.9);
    prognose.push(+p.toFixed(2));
    gemessen.push(+Math.max(0, p * (0.9 + 0.2 * zufall())).toFixed(2));
    gestern.push(+Math.max(0, glocke(h, 1.9) * (0.7 + 0.5 * zufall())).toFixed(2));
    var last = 0.32 + 0.1 * zufall();
    if (h >= 1 && h < 2) last += 4.1;               // Wärmepumpe im Preistief der Nacht
    if (h >= 5.25 && h < 6) last += 4.4;             // und vor dem Aufstehen
    if (h >= 6.5 && h < 8) last += 0.5;              // Morgen im Haus
    if (h >= 11.5 && h < 13.5) last += 2.4;          // Wärmepumpe mit Sonnenstrom
    if (h >= 12 && h < 12.75) last += 0.6;           // Mittagessen
    if (h >= 17.5 && h < 19.5) last += 1.2;          // Abend im Haus
    if (h >= 19.5 && h < 22.5) last += 0.4;
    haus.push(+last.toFixed(2));
    preis.push(PREIS_STUNDE[Math.floor(h)]);
  }

  // Gestern lief die Wärmepumpe zu anderen Stunden. Die Reihe entsteht nach den übrigen, damit
  // der feste Zufall für die Reihen von heute derselbe bleibt.
  var hausGestern = [];
  for (var g = 0; g < 96; g++) {
    var hg = g / 4, lastG = 0.3 + 0.1 * zufall();
    if (hg >= 2 && hg < 3.25) lastG += 4.2;
    if (hg >= 13 && hg < 14.5) lastG += 3.9;
    if (hg >= 6.5 && hg < 8) lastG += 0.5;
    if (hg >= 17.5 && hg < 22) lastG += 0.9;
    hausGestern.push(+lastG.toFixed(2));
  }
  var viertel = function (stundenwerte) { var r = []; for (var k = 0; k < 96; k++) r.push(stundenwerte[Math.floor(k / 4)]); return r; };

  var hhmm = function (stunden) {
    var s = Math.floor(stunden) % 24, m = Math.round((stunden - Math.floor(stunden)) * 60);
    return (s < 10 ? "0" : "") + s + ":" + (m < 10 ? "0" : "") + m;
  };

  // Der Tag bis zu einer Uhrzeit: was gemessen ist, hört bei „jetzt“ auf.
  var tag = function (jetztStunden, preiseMorgenBekannt) {
    var j = Math.round(jetztStunden * 4);
    return {
      jetztIndex: j,
      // je 96 Werte; null heißt: noch nicht gemessen
      sonneKw: gemessen.map(function (v, k) { return k <= j ? v : null; }),
      prognoseKw: prognose,
      gesternKw: gestern,
      hausKw: haus.map(function (v, k) { return k <= j ? v : null; }),
      preisCt: preis,
      // Gestern ist ganz gemessen. Die Preise für morgen gibt es erst am frühen Nachmittag: bis
      // dahin ist die Reihe null, und die Kurve zeigt für morgen keinen Preis.
      hausGesternKw: hausGestern,
      preisGesternCt: viertel(PREIS_GESTERN),
      preisMorgenCt: preiseMorgenBekannt ? viertel(PREIS_MORGEN) : null,
      // Bänder des Preistiefs als Viertelstunden-Indizes, Ende ausschließlich
      preistief: [{ von: 8, bis: 16 }, { von: 52, bis: 60 }],
      achseKw: 6,
      achseCt: [10, 60],
    };
  };

  // Die nächsten 24 Stunden ab einer Uhrzeit, stündlich. Preise für morgen gibt es ab 13 Uhr.
  var naechste = function (jetztStunden, preiseMorgenBekannt) {
    var start = Math.floor(jetztStunden), stunden = [];
    for (var k = 0; k < 24; k++) {
      var s = start + k, morgen = s >= 24, std = s % 24;
      var wp = (std >= 1 && std < 2) || (std === 5) || (!morgen && std >= 12 && std < 13) || (morgen && std === 12);
      stunden.push({
        uhr: hhmm(std),
        morgen: morgen,
        preisCt: morgen ? (preiseMorgenBekannt ? PREIS_MORGEN[std] : null) : PREIS_STUNDE[std],
        sonneKw: +glocke(std + 0.5, morgen ? 3.1 : 4.9).toFixed(2),
        waermepumpe: wp,
      });
    }
    return stunden;
  };

  var BEREICHE = [
    { name: "Jetzt", zeichen: "duck", aktiv: true },
    { name: "Haus", zeichen: "house" },
    { name: "Energie", zeichen: "bolt" },
    { name: "Geld", zeichen: "euro" },
    { name: "Anlage", zeichen: "pump" },
  ];

  var dock = function (abend, wpLaeuft) {
    return [
      { kurz: "Kaffee", name: "Kaffeemaschine", zeichen: "coffee", an: false, farbe: "var(--amber)" },
      { kurz: "Terrasse", name: "Licht Terrasse", zeichen: "bulb", an: abend, farbe: "var(--amber)" },
      { kurz: "Hof", name: "Licht Innenhof", zeichen: "bulb", an: false, farbe: "var(--amber)" },
      { kurz: "Zaun", name: "Licht Gartenzaun", zeichen: "bulb", an: abend, farbe: "var(--amber)" },
      // Ab hier öffnet ein Tippen eine Auswahl (Automatik, an, aus, mit Dauer) statt zu schalten.
      { kurz: "Wärmepumpe", name: "Wärmepumpe", zeichen: "pump", an: wpLaeuft, wort: wpLaeuft ? "läuft" : "aus", farbe: "var(--heat-pump)", auswahl: true },
      { kurz: "Ofen", name: "Pelletofen", zeichen: "stove", an: false, wort: "aus", farbe: "var(--stove)", auswahl: true },
      { kurz: "Alarm", name: "Alarmanlage", zeichen: "shield", an: abend, wort: abend ? "zu Hause scharf" : "unscharf", farbe: "var(--mist)", auswahl: true },
    ];
  };

  var mittag = {
    name: "mittag",
    datum: "Mittwoch, 25. November", zeit: "12:40", jetztStunden: 12.67,
    aussenC: 8.4, aussenWort: "draußen",
    verbindung: { wort: "live", gestoert: false },
    nacht: false, sonneAuf: "07:52", sonneUnter: "16:21",
    // Der Satz der Regelung und die Zeile darunter: wer entscheidet, und was als Nächstes kommt.
    satz: "Die Wärmepumpe läuft mit Sonnenstrom und lädt den Puffer.",
    dazu: "Automatik · Stand 12:38",
    zustand: "waermepumpe-laeuft",
    wache: [],
    fluss: {
      sonne: { kw: 4.6 },
      netz: { kw: 0.3, richtung: "einspeisung", wort: "Einspeisung" },
      // Haus ist die Summe aller Verbraucher im Haus, Wärmepumpe und Wallbox eingeschlossen.
      haus: { kw: 3.5, grundlastKw: 1.1 },
      speicher: { prozent: 64, kw: 0.8, wort: "lädt" },
      waermepumpe: { kw: 2.4, wort: "läuft" },
      wallbox: { kw: 0.0, wort: "steht" },
    },
    puffer: { prozent: 71, wort: "lädt", fuehlerC: [58, 52, 44, 33] },
    strom: { preisCt: 26.0, wort: "Strom ist gerade günstig", minCt: 22, maxCt: 53 },
    naechste24: {
      stunden: naechste(12.67, false),
      preistief: { von: "13:00", bis: "15:00", mittelCt: 22 },
      sonnenhoch: { von: "11:45", bis: "13:45" },
      waermepumpe: { von: "12:00", bis: "13:30", laeuft: true },
      hinweis: "Preise sind bis morgen 00:00 bekannt; die für morgen kommen am frühen Nachmittag.",
    },
    tag: tag(12.67, false),
    zahlen: {
      gestern: [
        { wert: "3,9", einheit: "kWh", wort: "Sonne geerntet", gelb: true },
        { wert: "18", einheit: "%", wort: "ohne Netz" },
        { wert: "6,42", einheit: "€", wort: "bezahlt" },
        { wert: "31,4", einheit: "ct", wort: "Strom im Mittel" },
      ],
      heute: [
        { wert: "11,8", einheit: "kWh", wort: "Sonne geerntet", gelb: true },
        { wert: "46", einheit: "%", wort: "ohne Netz" },
        { wert: "2,71", einheit: "€", wort: "bezahlt bis jetzt" },
        { wert: "26,0", einheit: "ct", wort: "Strom gerade" },
      ],
      morgen: [
        { wert: "9,6", einheit: "kWh", wort: "Sonne erwartet", gelb: true },
        { wert: "44", einheit: "kWh", wort: "Wärme erwartet" },
        { wert: "–", einheit: "ct", wort: "Preise kommen gegen 13 Uhr" },
        { wert: "–", einheit: "ct", wort: "günstigste Stunde" },
      ],
    },
    dock: dock(false, true),
    bereiche: BEREICHE,
  };

  var abend = {
    name: "abend",
    datum: "Mittwoch, 25. November", zeit: "18:40", jetztStunden: 18.67,
    aussenC: 3.1, aussenWort: "draußen",
    verbindung: { wort: "live", gestoert: false },
    nacht: true, sonneAuf: "07:52", sonneUnter: "16:21",
    satz: "Die Wärmepumpe ist aus: gerade gibt es weder genug Sonne noch günstigen Strom.",
    dazu: "Automatik · nächster geplanter Lauf um 01:00",
    zustand: "waermepumpe-aus",
    wache: [],
    fluss: {
      sonne: { kw: 0.0 },
      netz: { kw: 1.3, richtung: "bezug", wort: "Bezug" },
      haus: { kw: 1.9, grundlastKw: 1.9 },
      speicher: { prozent: 22, kw: 0.6, wort: "entlädt" },
      waermepumpe: { kw: 0.0, wort: "steht" },
      wallbox: { kw: 0.0, wort: "steht" },
    },
    puffer: { prozent: 39, wort: "hält", fuehlerC: [59, 51, 37, 30] },
    strom: { preisCt: 53.0, wort: "Strom ist gerade teuer", minCt: 22, maxCt: 53 },
    naechste24: {
      stunden: naechste(18.67, true),
      preistief: { von: "13:00", bis: "15:00", mittelCt: 23 },
      sonnenhoch: { von: "11:45", bis: "13:45" },
      waermepumpe: { von: "01:00", bis: "02:00", laeuft: false },
      hinweis: "",
    },
    tag: tag(18.67, true),
    zahlen: {
      gestern: mittag.zahlen.gestern,
      heute: [
        { wert: "19,4", einheit: "kWh", wort: "Sonne geerntet", gelb: true },
        { wert: "52", einheit: "%", wort: "ohne Netz" },
        { wert: "3,17", einheit: "€", wort: "bezahlt bis jetzt" },
        { wert: "53,0", einheit: "ct", wort: "Strom gerade" },
      ],
      morgen: [
        { wert: "9,6", einheit: "kWh", wort: "Sonne erwartet", gelb: true },
        { wert: "44", einheit: "kWh", wort: "Wärme erwartet" },
        { wert: "33,1", einheit: "ct", wort: "Strom im Mittel" },
        { wert: "23", einheit: "ct", wort: "günstigste Stunde ab 13:00" },
      ],
    },
    dock: dock(true, false),
    bereiche: BEREICHE,
  };

  // Der Abend mit einem Befund der Wache und unterbrochener Verbindung: das Bild ist dann von
  // eben, und die Seite muss das zeigen, ohne zu erschrecken.
  var stoerung = JSON.parse(JSON.stringify(abend));
  stoerung.name = "stoerung";
  stoerung.verbindung = { wort: "unterbrochen · 18:26", gestoert: true };
  stoerung.wache = [
    { schwere: "warnung", text: "Der Zähler am Netzanschluss liefert seit 14 Minuten keinen Wert." },
  ];

  window.SZENEN = { mittag: mittag, abend: abend, stoerung: stoerung };
  var gewaehlt = new URLSearchParams(location.search).get("szene") || "abend";
  window.SZENE = window.SZENEN[gewaehlt] || abend;
  document.documentElement.setAttribute("data-szene", window.SZENE.name);
})();
