/* Bausteine der Entwürfe für die Startseite (Werkstatt, 25.11.2026).
   Jede Funktion liefert das HTML eines Teils aus window.SZENE; das Aussehen steht in
   bausteine.css. Ein Entwurf setzt die Teile zusammen und zeichnet sein eigenes Hauptbild. */
(function () {
  var S = window.SZENE, z = window.zeichen, de = window.de;
  var B = (window.BAU = {});

  B.kopf = function () {
    var bereiche = S.bereiche.map(function (b) {
      return '<a class="bereich' + (b.aktiv ? " bereich-an" : "") + '" href="#">' + z(b.zeichen, 18) + "<span>" + b.name + "</span></a>";
    }).join("");
    return '<header class="kopf">' +
      '<a class="kopf-marke" href="#">' + z("duck", 24) + "<span>Duck Curve</span></a>" +
      '<nav class="bereiche">' + bereiche + "</nav>" +
      '<div class="kopfknoepfe"><a class="kopfknopf" href="#" aria-label="Einstellen">' + z("gear", 21) + '</a><a class="kopfknopf" href="#" aria-label="Mein Zugang">' + z("person", 21) + "</a></div>" +
      '<div class="kopf-rechts"><div class="kopf-daten"><span class="kopf-datum">' + S.datum + "</span>" +
      '<span class="kopf-zeile"><span class="kopf-verbindung" data-gestoert="' + S.verbindung.gestoert + '"><i></i><span>' + S.verbindung.wort + "</span></span>" +
      '<span class="kopf-aussen">' + de(S.aussenC) + " °C<i>" + S.aussenWort + "</i></span></span></div>" +
      '<span class="kopf-uhr">' + S.zeit + "</span>" +
      "</div></header>";
  };

  // Der Satz der Regelung. Die Zeile darunter: wer entscheidet als Marke, der Rest als Text.
  B.satz = function () {
    var teile = S.dazu.split(" · ");
    var laeuft = S.zustand === "waermepumpe-laeuft";
    return '<section class="satz"><h1>' + S.satz + "</h1>" +
      '<div class="satz-marken"><span class="marke">' + teile[0] + "</span>" +
      (laeuft ? '<span class="marke marke-laeuft">Wärmepumpe läuft</span>' : "") +
      "<span>" + (teile[1] || "") + "</span></div></section>";
  };

  B.wache = function () {
    return S.wache.map(function (w) {
      return '<p class="wache">' + z("alert", 20) + "<span>" + w.text + "</span></p>";
    }).join("");
  };

  // Die Farbe einer Fühlertemperatur zwischen kalt (28 °C) und warm (58 °C).
  var waerme = function (t) {
    var st = [[28, "--heat-0"], [38, "--heat-1"], [48, "--heat-2"], [58, "--heat-3"]];
    if (t <= 28) return "var(--heat-0)";
    if (t >= 58) return "var(--heat-3)";
    for (var i = 0; i < 3; i++) {
      if (t <= st[i + 1][0]) {
        return "color-mix(in srgb, var(" + st[i + 1][1] + ") " + Math.round((t - st[i][0]) * 10) + "%, var(" + st[i][1] + "))";
      }
    }
  };
  B.waerme = waerme;
  B.pufferVerlauf = function (richtung) {
    var f = S.puffer.fuehlerC;
    return "linear-gradient(" + (richtung || "180deg") + ", " + waerme(f[0]) + " 8%, " + waerme(f[1]) + " 36%, " + waerme(f[2]) + " 64%, " + waerme(f[3]) + " 92%)";
  };

  B.puffer = function () {
    var p = S.puffer;
    return '<section class="karte k-puffer">' +
      '<div class="puffer-links"><div class="k-kopf"><span class="zeichenfeld">' + z("thermo", 20) + "</span><h2>Puffer</h2></div>" +
      '<div class="grosszahl">' + p.prozent + "<small>%</small></div>" +
      '<span class="marke' + (p.wort === "lädt" ? " marke-hinweis" : "") + '">' + p.wort + "</span></div>" +
      '<div class="tank"><div class="tank-glas" style="background:' + B.pufferVerlauf() + '"></div>' +
      '<div class="tank-fuehler">' + p.fuehlerC.map(function (t) { return "<span>" + t + " °C</span>"; }).join("") + "</div></div>" +
      "</section>";
  };

  // Die nächsten 24 Stunden: Preis als Säulen, die erwartete Sonne dahinter, die Läufe der
  // Wärmepumpe als Striche darunter, und drei Zeitspannen statt fünf Sätzen.
  B.ausblickBild = function () {
    var n = S.naechste24, st = n.stunden, W = 384, H = 116, b = W / 24, boden = 84, hoch = 66, t = "";
    var std = function (s) { return parseInt(s.slice(0, 2), 10); };
    var tiefVon = std(n.preistief.von), tiefBis = std(n.preistief.bis);
    var fl = "M0," + boden;
    st.forEach(function (s, i) { fl += " L" + ((i + 0.5) * b).toFixed(1) + "," + (boden - Math.min(1, s.sonneKw / 5.5) * hoch).toFixed(1); });
    t += '<defs><linearGradient id="ab-sonne" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="var(--pv)" stop-opacity="0.5"/><stop offset="1" stop-color="var(--pv)" stop-opacity="0.04"/></linearGradient></defs>';
    t += '<path d="' + fl + " L" + W + "," + boden + ' Z" fill="url(#ab-sonne)"/>';
    t += '<path d="' + fl.replace("M0," + boden + " L", "M") + '" fill="none" stroke="var(--pv)" stroke-width="1.5" stroke-opacity="0.9"/>';
    st.forEach(function (s, i) {
      var x = i * b + 3.5, w = b - 7;
      if (s.preisCt == null) {
        t += '<rect x="' + x + '" y="' + (boden - 20) + '" width="' + w + '" height="20" rx="' + w / 2 + '" fill="none" stroke="var(--mist)" stroke-opacity="0.45" stroke-dasharray="2 3"/>';
        return;
      }
      var h = (s.preisCt / 60) * hoch, tief = std(s.uhr) >= tiefVon && std(s.uhr) < tiefBis;
      t += '<rect x="' + x + '" y="' + (boden - h).toFixed(1) + '" width="' + w + '" height="' + h.toFixed(1) + '" rx="' + w / 2 + '" fill="' + (i === 0 ? "var(--house)" : "var(--mist)") + '" fill-opacity="' + (i === 0 ? 0.95 : tief ? 1 : 0.42) + '"/>';
      if (s.waermepumpe) t += '<rect x="' + (i * b + 1) + '" y="' + (boden + 6) + '" width="' + (b - 2) + '" height="5" rx="2.5" fill="var(--heat-pump)"/>';
    });
    t += '<line x1="0" x2="' + W + '" y1="' + (boden + 8.5) + '" y2="' + (boden + 8.5) + '" stroke="var(--line-1)" stroke-width="1"/>';
    st.forEach(function (s, i) {
      if (i === 0) t += '<text x="1" y="' + (H - 2) + '" fill="var(--text-1)">jetzt</text>';
      else if (std(s.uhr) % 6 === 0 && i > 2) t += '<text x="' + ((i + 0.5) * b) + '" y="' + (H - 2) + '" text-anchor="middle">' + s.uhr.slice(0, 2) + " Uhr</text>";
    });
    return '<svg class="ausblick-bild" viewBox="0 0 ' + W + " " + H + '" role="img" aria-label="Strompreis, erwartete Sonne und Läufe der Wärmepumpe in den nächsten 24 Stunden">' + t + "</svg>";
  };
  B.preismarke = function () {
    var teuer = /teuer/.test(S.strom.wort);
    return '<span class="marke ' + (teuer ? "marke-teuer" : "marke-guenstig") + '">' + (teuer ? "teuer" : "günstig") + "</span>";
  };
  B.zeiten = function () {
    var n = S.naechste24;
    var zeit = function (farbe, bild, wort, von, bis) {
      return '<div class="zeit" style="--zeitfarbe:' + farbe + '"><span class="zeit-wort">' + z(bild, 14) + wort + '</span><span class="zeit-uhr">' + von + "–" + bis + "</span></div>";
    };
    return '<div class="zeiten">' +
      zeit("var(--mist)", "euro", "Preistief", n.preistief.von, n.preistief.bis) +
      zeit("var(--pv)", "sun", "Beste Sonne", n.sonnenhoch.von, n.sonnenhoch.bis) +
      zeit("var(--heat-pump)", "pump", "Wärmepumpe", n.waermepumpe.von, n.waermepumpe.bis) +
      "</div>";
  };
  B.ausblick = function () {
    return '<section class="karte k-ausblick">' +
      '<div class="k-kopf"><span class="zeichenfeld">' + z("clock", 20) + "</span><h2>Nächste 24 Stunden</h2>" +
      '<span class="rechts-im-kopf"><span class="preis">' + de(S.strom.preisCt) + "<small>ct</small></span>" + B.preismarke() + "</span></div>" +
      B.ausblickBild() + B.zeiten() + "</section>";
  };

  // Die Kurve des Tages. Das Bild wird in der Größe gezeichnet, die sein Platz hat.
  B.tag = function () {
    return '<section class="karte k-tag"><div class="tag-kopf">' +
      '<div class="tage" role="group" aria-label="Tag">' + ["Gestern", "Heute", "Morgen"].map(function (t) {
        return '<button type="button" data-tag="' + t.toLowerCase() + '" aria-pressed="' + (t === "Heute") + '">' + t + "</button>";
      }).join("") + "</div>" +
      '<div class="tag-zahlen"></div></div><div class="tag-bild"></div>' +
      '<div class="tag-legende"><span><i style="background:var(--pv)"></i>Sonne</span><span><i style="background:var(--house)"></i>Haus</span><span><i style="background:var(--price)"></i>Strompreis</span><span><i style="background:color-mix(in srgb, var(--mist) 35%, transparent);height:9px"></i>Preistief</span></div>' +
      "</section>";
  };
  var linie = function (werte, x, y) {
    var d = "", offen = false;
    werte.forEach(function (v, i) {
      if (v == null) { offen = false; return; }
      d += (offen ? " L" : " M") + x(i).toFixed(1) + "," + y(v).toFixed(1);
      offen = true;
    });
    return d;
  };
  B.tagZeichnen = function (wurzel, welcher) {
    var T = S.tag, el = wurzel.querySelector(".tag-bild"), W = el.clientWidth, H = el.clientHeight;
    var l = 4, r = 4, o = 8, u = 18, t = "";
    var x = function (i) { return l + (i / 96) * (W - l - r); };
    var yk = function (kw) { return H - u - (kw / T.achseKw) * (H - o - u); };
    var yc = function (ct) { return H - u - ((ct - T.achseCt[0]) / (T.achseCt[1] - T.achseCt[0])) * (H - o - u); };
    var heute = welcher === "heute";
    var sonne = heute ? T.sonneKw : welcher === "gestern" ? T.gesternKw : T.prognoseKw.map(function (v) { return v * 0.63; });
    var letzte = heute ? T.jetztIndex : 95;
    t += '<defs><linearGradient id="tg-sonne" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="var(--pv)" stop-opacity="0.62"/><stop offset="1" stop-color="var(--pv)" stop-opacity="0.05"/></linearGradient></defs>';
    [2, 4].forEach(function (kw) { t += '<line x1="' + l + '" x2="' + (W - r) + '" y1="' + yk(kw) + '" y2="' + yk(kw) + '" stroke="var(--line-1)" stroke-dasharray="2 5"/>'; });
    T.preistief.forEach(function (b) { t += '<rect x="' + x(b.von) + '" y="' + o + '" width="' + (x(b.bis) - x(b.von)) + '" height="' + (H - o - u) + '" rx="6" fill="var(--mist)" fill-opacity="0.13"/>'; });
    if (heute) t += '<path d="' + linie(T.gesternKw, x, yk) + " L" + x(95) + "," + yk(0) + " L" + x(0) + "," + yk(0) + ' Z" fill="var(--house)" fill-opacity="0.06"/>';
    if (welcher !== "gestern") t += '<path d="' + linie(T.prognoseKw.map(function (v) { return heute ? v : v * 0.63; }), x, yk) + '" fill="none" stroke="var(--pv)" stroke-width="1.5" stroke-dasharray="3 5" stroke-opacity="0.75"/>';
    if (welcher !== "morgen") {
      t += '<path d="' + linie(sonne, x, yk) + " L" + x(letzte) + "," + yk(0) + " L" + x(0) + "," + yk(0) + ' Z" fill="url(#tg-sonne)"/>';
      t += '<path d="' + linie(sonne, x, yk) + '" fill="none" stroke="var(--pv)" stroke-width="2.2" stroke-linejoin="round"/>';
      t += '<path d="' + linie(T.hausKw, x, yk) + '" fill="none" stroke="var(--house)" stroke-width="1.5" stroke-opacity="0.9" stroke-linejoin="round"/>';
    }
    var stufen = "";
    T.preisCt.forEach(function (ct, i) { stufen += (i ? " L" : "M") + x(i).toFixed(1) + "," + yc(ct).toFixed(1) + " L" + x(i + 1).toFixed(1) + "," + yc(ct).toFixed(1); });
    t += '<path d="' + stufen + '" fill="none" stroke="var(--price)" stroke-width="1.5" stroke-opacity="0.95"/>';
    [0, 6, 12, 18, 24].forEach(function (h) {
      t += '<text x="' + x(h * 4) + '" y="' + (H - 3) + '" text-anchor="' + (h === 0 ? "start" : h === 24 ? "end" : "middle") + '">' + (h < 10 ? "0" : "") + h + ":00</text>";
    });
    [2, 4].forEach(function (kw) { t += '<text class="hof" x="' + (l + 2) + '" y="' + (yk(kw) - 4) + '">' + kw + " kW</text>"; });
    if (heute) {
      var jx = x(T.jetztIndex);
      t += '<line x1="' + jx + '" x2="' + jx + '" y1="' + o + '" y2="' + (H - u) + '" stroke="var(--house)" stroke-opacity="0.55"/>';
      t += '<circle cx="' + jx + '" cy="' + yk(T.hausKw[T.jetztIndex] || 0) + '" r="4.5" fill="var(--house)"/>';
      t += '<text x="' + (jx + 7) + '" y="' + (o + 9) + '" fill="var(--text-1)">jetzt</text>';
    }
    el.innerHTML = '<svg viewBox="0 0 ' + W + " " + H + '" role="img" aria-label="Sonne, Hausverbrauch und Strompreis über den Tag">' + t + "</svg>";
    wurzel.querySelector(".tag-zahlen").innerHTML = S.zahlen[welcher].map(function (n) {
      return '<div class="tag-zahl"><b data-gelb="' + !!n.gelb + '">' + n.wert + "<small>" + n.einheit + "</small></b><span>" + n.wort + "</span></div>";
    }).join("");
  };
  B.tagEinrichten = function () {
    var wurzel = document.querySelector(".k-tag");
    if (!wurzel) return;
    var zeichne = function () { B.tagZeichnen(wurzel, wurzel.querySelector('.tage button[aria-pressed="true"]').dataset.tag); };
    wurzel.querySelectorAll(".tage button").forEach(function (k) {
      k.addEventListener("click", function () {
        wurzel.querySelectorAll(".tage button").forEach(function (a) { a.setAttribute("aria-pressed", a === k); });
        zeichne();
      });
    });
    zeichne();
    window.addEventListener("resize", zeichne);
  };

  // Die Schalter. Was eine Auswahl öffnet, zeigt seinen Zustand als Wort darunter.
  B.tasten = function () {
    return '<div class="tasten">' + S.dock.map(function (d) {
      return '<button type="button" class="taste" aria-pressed="' + d.an + '" style="--tastenfarbe:' + d.farbe + '" aria-label="' + d.name + '">' +
        '<span class="taste-rund">' + z(d.zeichen, 24) + '</span><span class="taste-wort">' + d.kurz + "</span>" +
        (d.auswahl ? '<span class="taste-dazu">' + d.wort + "</span>" : "") + "</button>";
    }).join("") + "</div>";
  };
  B.dock = function () {
    return '<section class="karte k-dock"><div class="k-kopf"><span class="zeichenfeld">' + z("sliders", 20) + "</span><h2>Schalter</h2></div>" + B.tasten() + "</section>";
  };

  B.leiste = function () {
    return '<nav class="leiste" aria-label="Bereiche">' + S.bereiche.map(function (b) {
      return '<a href="#"' + (b.aktiv ? ' aria-current="page"' : "") + "><span>" + z(b.zeichen, 21) + "</span>" + b.name + "</a>";
    }).join("") + "</nav>";
  };
  B.ente = function () { return '<a class="ente" href="#" aria-label="Alfred fragen">' + z("duck", 30) + "</a>"; };

  B.schalten = function () {
    document.querySelectorAll(".taste").forEach(function (k) {
      k.addEventListener("click", function () { k.setAttribute("aria-pressed", k.getAttribute("aria-pressed") !== "true"); });
    });
  };
})();
