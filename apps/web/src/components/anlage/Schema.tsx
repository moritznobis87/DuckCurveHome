"use client";

import { useRouter } from "next/navigation";
import type { MouseEvent, ReactNode } from "react";
import type { Anlage } from "@/lib/api/models";
import { PufferGlas } from "@/components/puffer/Glas";
import {
  batterieWort,
  dauerText,
  de,
  FARBE,
  farbe,
  grad,
  heizungStatus,
  istAn,
  mischung,
  nettoFarbe,
  nettoText,
  netzWort,
  ofenStatus,
  partikelZahl,
  rohrDauer,
  rohrStaerke,
  warmwasserStatus,
  ZIELE,
  type Ziel,
} from "./schema";

/**
 * Das Anlagenschema als eine Bühne.
 *
 * Links sammeln sich drei Stromquellen zu einem Strang in die Wärmepumpe. Rechts davon der
 * Speicher als Glas, und an ihm treffen sich vier getrennte Systeme, die sich nur dort berühren:
 * der Ofenkreis (ganz oben hinein, unten heraus), der Wärmepumpenkreis (Mitte hinein, unten
 * heraus), der Heizkreis (Mitte heraus, unten hinein) und das Trinkwasser, das unten kalt
 * nachläuft und ganz oben warm entnommen wird. Jeder Kreis ist eine Schleife aus Licht: Vorlauf
 * warm, Rücklauf kühl, gegenläufig.
 *
 * **Reihenfolge ist Tiefe.** Was später im Baum steht, liegt oben. Deshalb stehen die Rohre vor
 * den Kacheln, und der Wärmepumpenvorlauf bekommt einen dunklen Hof, damit er sichtbar über dem
 * Ofensteiger liegt, statt mit ihm zu verschmelzen.
 */

type RohrProps = {
  id: string;
  d: string;
  kw: number | null | undefined;
  col: string;
  umkehren?: boolean;
  leise?: boolean;
  farben?: string[] | null;
  ruhig: boolean;
};

/** Ein Rohr: Grundschicht breit und leise, Kern dünn und hell, Licht wandert darauf.
 *
 *  `leise` sind Rückläufe: schmaler, blasser, weniger Licht, damit die Schleife als Paar lesbar
 *  bleibt und der Vorlauf das Wort führt. `farben` sind für Stränge mit gemischtem Strom: dann hat
 *  jeder Lichtpunkt die Farbe einer Quelle, im Verhältnis der Anteile, und `col` ist nur noch die
 *  Grundfarbe des Rohrs.
 *
 *  Die Lichtpunkte sind SMIL-Animationen entlang des Pfads. Ihr Schlüssel enthält Dauer und
 *  Anzahl, damit React sie nur dann neu anlegt, wenn sich das Tempo wirklich ändert; sonst
 *  spränge bei jedem Abruf jeder Punkt an den Anfang. */
function Rohr({ id, d, kw, col, umkehren = false, leise = false, farben = null, ruhig }: RohrProps) {
  const an = istAn(kw);
  const dur = an ? rohrDauer(kw, leise) : 0;
  const n = an ? (farben ? farben.length : partikelZahl(kw, leise)) : 0;
  const pfad = `anlage-r-${id}`;
  return (
    <g>
      <path id={pfad} className="anlage-rohr" d={d} stroke={col} strokeOpacity={an ? (leise ? 0.12 : 0.16) : 0.06} strokeWidth={rohrStaerke(kw, leise)} />
      <path className="anlage-faden" d={d} stroke={col} strokeOpacity={an ? (leise ? 0.35 : 0.5) : 0.12} strokeWidth={an ? (leise ? 1.2 : 1.6) : 1} />
      {!ruhig && an
        ? Array.from({ length: n }, (_, i) => (
            <circle
              key={`${id}-${i}-${n}-${dur}-${umkehren ? "r" : "v"}`}
              r={(farben ? 3 : i % 2 ? 2.2 : 3.2) * (leise ? 0.8 : 1)}
              fill={farben ? farben[i % farben.length] : col}
              opacity={(farben ? 0.92 : i % 2 ? 0.55 : 0.95) * (leise ? 0.7 : 1)}
              filter="url(#anlage-weich)"
            >
              <animateMotion dur={`${dur}s`} repeatCount="indefinite" begin={`${-(i / n) * dur}s`} {...(umkehren ? { keyPoints: "1;0", keyTimes: "0;1", calcMode: "linear" } : {})}>
                <mpath href={`#${pfad}`} xlinkHref={`#${pfad}`} />
              </animateMotion>
            </circle>
          ))
        : null}
    </g>
  );
}

/** Eine Pumpe: ein ruhender Punkt auf dem Rohr, der leuchtet, wenn sie läuft. */
function Pumpe({ x, y, laeuft, text }: { x: number; y: number; laeuft: boolean; text: string }) {
  return (
    <g transform={`translate(${x} ${y})`} opacity={laeuft ? 1 : 0.55}>
      <circle r={13} fill="#fff" opacity={laeuft ? 0.16 : 0} filter="url(#anlage-weich)" />
      <circle r={8} fill="#0a2735" stroke="#fff" strokeOpacity={laeuft ? 0.7 : 0.25} strokeWidth={1.2} />
      <circle r={3} fill={laeuft ? FARBE.pvSoft : "rgba(255,255,255,.35)"} />
      {text ? (
        <text className="anlage-hint" y={-16} textAnchor="middle">
          {text}
        </text>
      ) : null}
    </g>
  );
}

/** Ein anklickbares Symbol: ein SVG-Link auf die Seite des Geräts, dieselben Ziele wie die Knoten
 *  der Startseite. Ein echter Link, damit Mittelklick, Vorlesehilfe und „Link kopieren" gehen;
 *  der normale Klick geht über den Router, damit die Seite nicht neu lädt. */
function Symbol({ ziel, children }: { ziel: Ziel; children: ReactNode }) {
  const router = useRouter();
  const { href, label } = ZIELE[ziel];
  const klick = (ev: MouseEvent<HTMLAnchorElement>) => {
    if (ev.metaKey || ev.ctrlKey || ev.shiftKey || ev.altKey || ev.button !== 0) return;
    ev.preventDefault();
    router.push(href);
  };
  return (
    <a href={href} className="anlage-ziel" aria-label={`${label}. Details öffnen`} onClick={klick}>
      {children}
    </a>
  );
}

/** Eine Glaskachel mit Haarlinie oben. */
function Kachel({ x, y, w, h, rx, children, gedimmt }: { x: number; y: number; w: number; h: number; rx: number; children: ReactNode; gedimmt?: boolean }) {
  return (
    <g filter="url(#anlage-schatten)" opacity={gedimmt ? 0.7 : 1} className="anlage-fade">
      <rect x={x} y={y} width={w} height={h} rx={rx} className="anlage-glas" />
      <rect x={x + 0.5} y={y + 0.5} width={w - 1} height={h - 1} rx={rx - 0.5} className="anlage-glas-hi" />
      {children}
    </g>
  );
}

/** Eine große Zahl mit Einheit; ohne Zahl nur ein Strich, ohne Einheit. */
function Zahl({ x, y, size, wert, einheit, anchor = "start", unitSize = 12 }: { x: number; y: number; size: number; wert: string; einheit: string; anchor?: "start" | "end" | "middle"; unitSize?: number }) {
  return (
    <text className="anlage-num" x={x} y={y} textAnchor={anchor} fontSize={size}>
      <tspan>{wert}</tspan>
      {wert !== "-" && einheit ? (
        <tspan className="anlage-unit" fontSize={unitSize}>
          {einheit}
        </tspan>
      ) : null}
    </text>
  );
}

export function Schema({ a, nowMs, ruhig }: { a: Anlage; nowMs: number; ruhig: boolean }) {
  const e = a.strom;
  const w = a.waermepumpe;
  const o = a.ofen;
  const p = a.speicher;
  const t = p.temps_c;
  const hz = a.heizkreis;
  const ww = a.warmwasser;
  const mix = mischung(e);

  // Die Leistungen, die das Tempo der Rohre bestimmen. Wo niemand misst, läuft ein Rohr mit
  // einem festen, mittleren Tempo: das Licht sagt dann „es fließt", nicht „so viel".
  const wpKw = w.running ? (w.thermal_kw ?? 5) : 0;
  const ofKw = o.running ? (o.water_kw ?? 5) : 0;
  const hzKw = hz.running ? 4 : 0;
  const wwKw = ww.tapping ? 1.5 : 0;
  // Der Rücklauf kommt aus der untersten Spitze; seine Temperatur ist die des untersten Fühlers.
  const rl = p.return_c;
  const soc = p.soc != null ? Math.round(p.soc * 100) : null;
  const batSoc = e.battery_soc != null ? `${Math.round(e.battery_soc * 100)} %` : "";
  const cop = w.cop;

  return (
    <svg className="anlage-flaeche" viewBox="0 0 1200 640" role="img" aria-label="Anlage: Strom links, Speicher als Glas rechts, vier getrennte Wasserkreise">
      <defs>
        <linearGradient id="anlage-hairline" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#fff" stopOpacity=".28" />
          <stop offset=".25" stopColor="#fff" stopOpacity=".06" />
          <stop offset="1" stopColor="#fff" stopOpacity=".02" />
        </linearGradient>
        <radialGradient id="anlage-sonne">
          <stop offset="0" stopColor="#ffd778" stopOpacity=".9" />
          <stop offset=".35" stopColor="#f2a900" stopOpacity=".35" />
          <stop offset="1" stopColor="#f2a900" stopOpacity="0" />
        </radialGradient>
        <radialGradient id="anlage-glut">
          <stop offset="0" stopColor="#ffb070" stopOpacity=".55" />
          <stop offset=".5" stopColor="#c9742c" stopOpacity=".18" />
          <stop offset="1" stopColor="#c9742c" stopOpacity="0" />
        </radialGradient>
        <radialGradient id="anlage-hp-licht">
          <stop offset="0" stopColor="#e0966b" stopOpacity=".5" />
          <stop offset="1" stopColor="#e0966b" stopOpacity="0" />
        </radialGradient>
        <filter id="anlage-weich" x="-50%" y="-50%" width="200%" height="200%">
          <feGaussianBlur stdDeviation="2.2" />
        </filter>
        <filter id="anlage-weich-gross" x="-80%" y="-80%" width="260%" height="260%">
          <feGaussianBlur stdDeviation="14" />
        </filter>
        <filter id="anlage-schatten" x="-20%" y="-20%" width="140%" height="160%">
          <feDropShadow dx="0" dy="14" stdDeviation="14" floodColor="#000" floodOpacity=".38" />
        </filter>
      </defs>

      <text className="anlage-cap" x="60" y="54">
        Strom
      </text>
      <text className="anlage-cap" x="420" y="54">
        Wärme
      </text>

      {/* Lichtquellen hinter allem */}
      <circle cx="120" cy="150" r="90" fill="url(#anlage-sonne)" opacity={0.08 + Math.min(0.9, (e.pv_kw ?? 0) * 0.14)} className="anlage-fade" />
      <ellipse cx="550" cy="145" rx="200" ry="80" fill="url(#anlage-glut)" opacity={o.running ? 1 : 0} className="anlage-fade" />
      <ellipse cx="550" cy="332" rx="210" ry="95" fill="url(#anlage-hp-licht)" opacity={w.running ? 0.4 : 0} className="anlage-fade" />

      {/* ============ Rohre ============ */}
      {/* Strom: drei Quellen laufen in einen Knoten; von dort zwei Abgänge: zur Wärmepumpe und
          hinunter zum Haushalt. Der Haushalt ist Abnehmer, keine Quelle, darum hängt er unter dem
          Knoten und nicht in der Spalte der Quellen. */}
      <Rohr id="pv" d="M160 150 C 220 150, 230 300, 300 300" kw={e.pv_kw} col={FARBE.pv} ruhig={ruhig} />
      <Rohr id="netz" d="M160 300 L 300 300" kw={e.grid_kw} col={istAn(e.grid_kw) && e.grid_kw < 0 ? FARBE.pvSoft : FARBE.netz} umkehren={istAn(e.grid_kw) && e.grid_kw < 0} ruhig={ruhig} />
      <Rohr id="bat" d="M160 450 C 220 450, 230 300, 300 300" kw={e.battery_kw} col={FARBE.speicher} umkehren={istAn(e.battery_kw) && e.battery_kw < 0} ruhig={ruhig} />
      <Rohr id="wp" d="M300 300 C 360 300, 370 332, 420 332" kw={e.heat_pump_kw} col={mix.haupt} farben={mix.farben} ruhig={ruhig} />
      <Rohr id="ev" d="M300 300 C 300 380, 330 400, 330 432" kw={e.rest_kw} col={mix.haupt} farben={mix.farben} ruhig={ruhig} />
      {/* Ofenkreis: der Vorlauf steigt über das Glas und fällt von oben senkrecht in die Spitze. */}
      <Rohr id="ofvl" d="M680 135 C 740 135, 860 40, 860 92" kw={ofKw} col={farbe(o.flow_c ?? t[0])} ruhig={ruhig} />
      {/* Der gemeinsame Rücklauf: ein Rohr aus der untersten Spitze bis zum Abzweig, dort teilt es
          sich zum Ofen (Steiger nach oben) und zur Wärmepumpe (Bogen nach links). So ist es gebaut,
          und so führt es auch dieselbe Wassertemperatur: die des untersten Fühlers. */}
      <Rohr id="rl" d="M860 562 C 860 584, 816 590, 784 560" kw={wpKw + ofKw} col={farbe(rl)} leise ruhig={ruhig} />
      <Rohr id="orl" d="M784 560 L 784 204 C 784 184, 764 172, 680 172" kw={ofKw} col={farbe(rl)} leise ruhig={ruhig} />
      <Rohr id="wprl" d="M784 560 C 770 500, 740 420, 680 364" kw={wpKw} col={farbe(rl)} leise ruhig={ruhig} />
      {/* Wärmepumpenvorlauf mit Hof, damit er sichtbar über dem Ofensteiger liegt */}
      <path className="anlage-halo" d="M680 300 C 740 300, 760 262, 824 262" />
      <Rohr id="wpvl" d="M680 300 C 740 300, 760 262, 824 262" kw={wpKw} col={farbe(w.flow_c ?? t[1])} ruhig={ruhig} />
      {/* Trinkwasser: unten kalt nach, ganz oben warm heraus */}
      <Rohr id="kw" d="M980 562 C 950 562, 930 548, 896 548" kw={wwKw} col={farbe(ww.inlet_c ?? 12)} leise ruhig={ruhig} />
      <Rohr id="ww" d="M896 106 C 940 106, 940 180, 980 180" kw={wwKw} col={farbe(t[0] != null ? t[0] + 2 : null)} ruhig={ruhig} />
      {/* Heizkreis: Mitte heraus, unten hinein */}
      <Rohr id="hz" d="M896 330 C 940 330, 940 330, 980 330" kw={hzKw} col={farbe(t[2])} ruhig={ruhig} />
      <Rohr id="hzrl" d="M1070 380 C 1070 470, 960 470, 896 470" kw={hzKw} col={farbe(rl)} leise ruhig={ruhig} />

      {/* ============ Strom ============ */}
      <Symbol ziel="pv">
      <g>
        <circle className="anlage-kreis" cx="120" cy="150" r="40" fill="#0a2735" stroke={FARBE.pv} strokeOpacity=".75" strokeWidth="1.2" />
        <text className="anlage-name" x="120" y="146" textAnchor="middle" fontSize="14">
          PV
        </text>
        <Zahl x={120} y={164} size={14} wert={de(e.pv_kw)} einheit=" kW" anchor="middle" />
      </g>
      </Symbol>
      <Symbol ziel="netz">
      <g>
        <circle className="anlage-kreis" cx="120" cy="300" r="40" fill="#0a2735" stroke={FARBE.netz} strokeOpacity=".75" strokeWidth="1.2" />
        <text className="anlage-name" x="120" y="296" textAnchor="middle" fontSize="14">
          Netz
        </text>
        <Zahl x={120} y={314} size={14} wert={de(e.grid_kw)} einheit=" kW" anchor="middle" />
        <text className="anlage-hint" x="120" y="356" textAnchor="middle">
          {netzWort(e.grid_kw)}
        </text>
      </g>
      </Symbol>
      <Symbol ziel="bat">
      <g>
        <circle className="anlage-kreis" cx="120" cy="450" r="40" fill="#0a2735" stroke={FARBE.speicher} strokeOpacity=".75" strokeWidth="1.2" />
        <text className="anlage-name" x="120" y="446" textAnchor="middle" fontSize="14">
          Speicher
        </text>
        <Zahl x={120} y={464} size={14} wert={de(e.battery_kw)} einheit=" kW" anchor="middle" />
        <text className="anlage-hint" x="120" y="506" textAnchor="middle">
          {batSoc ? `${batterieWort(e.battery_kw)} · ${batSoc}` : batterieWort(e.battery_kw)}
        </text>
      </g>
      </Symbol>
      {/* Der Knoten: ein Lichtpunkt ohne Namen. Hier treffen sich die Quellen, hier teilen sie sich. */}
      <g>
        <circle cx="300" cy="300" r="14" fill="#fff" opacity=".12" filter="url(#anlage-weich)" />
        <circle cx="300" cy="300" r="5" fill="#fff" opacity=".9" />
        <text className="anlage-hint" x="286" y="292" textAnchor="end">
          zusammen {de(e.house_kw)} kW
        </text>
      </g>
      {/* Haushalt: Abnehmer unter dem Knoten, alles außer der Wärmepumpe */}
      <Symbol ziel="haus">
      <g>
        <circle className="anlage-kreis" cx="330" cy="470" r="38" fill="#0a2735" stroke={FARBE.ev} strokeOpacity=".6" strokeWidth="1.2" />
        <text className="anlage-name" x="330" y="469" textAnchor="middle" fontSize="12.5">
          Haushalt
        </text>
        <Zahl x={330} y={486} size={13} wert={de(e.rest_kw)} einheit=" kW" anchor="middle" />
        <text className="anlage-hint" x="330" y="522" textAnchor="middle">
          inkl. Wallbox
        </text>
      </g>
      </Symbol>

      {/* ============ Pelletofen, oben ============ */}
      <Symbol ziel="ofen">
      <Kachel x={420} y={100} w={260} h={90} rx={24} gedimmt={!o.running}>
        <text className="anlage-name" x="446" y="130">
          Pelletofen
        </text>
        <text className="anlage-sub" x="446" y="148">
          {ofenStatus(o)}
        </text>
        <Zahl x={656} y={166} size={32} wert={o.running && o.water_kw != null ? `≈${de(o.water_kw)}` : "-"} einheit=" kW" anchor="end" unitSize={13} />
        <text className="anlage-hint" x="656" y="182" textAnchor="end">
          {o.running && o.water_kw != null ? "geschätzt aus der Stufe" : ""}
        </text>
      </Kachel>
      </Symbol>

      {/* ============ Wärmepumpe, die Bühne ============ */}
      <Symbol ziel="wp">
      <Kachel x={420} y={268} w={260} h={128} rx={26} gedimmt={!w.running}>
        <text className="anlage-name" x="446" y="298">
          Wärmepumpe
        </text>
        <text className="anlage-sub" x="446" y="316">
          {w.running ? (dauerText(w.running_since, nowMs) ? `läuft seit ${dauerText(w.running_since, nowMs)}` : "läuft") : "steht"}
        </text>
        <Zahl x={446} y={364} size={30} wert={de(w.power_kw)} einheit=" kW" />
        <text className="anlage-hint" x="446" y="388">
          Strom hinein
        </text>
        <Zahl x={656} y={364} size={44} wert={w.running ? (w.thermal_kw != null ? de(w.thermal_kw) : "-") : "0,0"} einheit=" kW" anchor="end" unitSize={13} />
        <text className="anlage-hint" x="656" y="388" textAnchor="end">
          {w.running && w.thermal_kw == null ? "Wärme nicht gemessen" : "Wärme heraus"}
        </text>
        <g transform="translate(648 298)">
          <circle r="17" fill="none" stroke="rgba(255,255,255,.12)" strokeWidth="3" />
          <circle r="17" fill="none" stroke={FARBE.hp} strokeWidth="3" strokeLinecap="round" strokeDasharray="106.8" strokeDashoffset={106.8 * (1 - Math.min(1, (cop ?? 0) / 5))} strokeOpacity={cop ? 1 : 0.15} transform="rotate(-90)" />
          <text className="anlage-num" y="5" textAnchor="middle" fontSize="13" fontWeight="400">
            {cop ? de(cop) : "-"}
          </text>
          <text className="anlage-hint" x="-26" y="4" textAnchor="end" fontSize="10">
            COP
          </text>
        </g>
      </Kachel>
      </Symbol>

      {/* ============ Speicher: das Glas ============ */}
      <Symbol ziel="puffer">
      <g>
        <ellipse cx="860" cy="582" rx="46" ry="9" fill="#000" opacity=".35" filter="url(#anlage-weich-gross)" />
        {/* Ladestand und Nettoleistung unter dem Glas. Die Nettoleistung ist aus den vier Fühlern
            gerechnet: Änderung der gespeicherten Energie je Zeit. Sie braucht keinen Bus. */}
        <text className="anlage-num" x="860" y="614" textAnchor="middle" fontSize="24">
          <tspan>{soc != null ? soc : "-"}</tspan>
          {soc != null ? <tspan className="anlage-unit"> %</tspan> : null}
          {nettoText(p) ? (
            <tspan className="anlage-unit" dx="10" fill={nettoFarbe(p)}>
              {nettoText(p)}
            </tspan>
          ) : null}
        </text>
        <text className="anlage-hint" x="860" y="632" textAnchor="middle">
          {p.usable_kwh != null ? `${Math.round(p.usable_kwh)} kWh nutzbar · ` : ""}
          {Math.round(p.volume_liters)} l
        </text>
        {/* Das Glas selbst ist die eine Zeichnung des Speichers, die es gibt (`puffer/Glas`). */}
        <PufferGlas temps={t} x={824} y={92} breite={72} hoehe={470} ruhig={ruhig} randKlasse="anlage-glasrand" />
      </g>
      </Symbol>

      {/* ============ Abnehmer ============ */}
      <Symbol ziel="warmwasser">
      <Kachel x={980} y={140} w={200} h={80} rx={22} gedimmt={!ww.present}>
        <text className="anlage-name" x="1004" y="172">
          Warmwasser
        </text>
        <Zahl x={1156} y={176} size={22} wert={ww.outlet_c != null ? String(Math.round(ww.outlet_c)) : "-"} einheit=" °" anchor="end" />
        <text className="anlage-sub" x="1004" y="200">
          {warmwasserStatus(ww, nowMs)}
        </text>
      </Kachel>
      </Symbol>
      <Symbol ziel="heizung">
      <Kachel x={980} y={300} w={200} h={80} rx={22} gedimmt={!hz.running}>
        <text className="anlage-name" x="1004" y="332">
          Heizung
        </text>
        <Zahl x={1156} y={336} size={22} wert={hz.rooms_total ? String(hz.rooms_open) : "-"} einheit={` von ${hz.rooms_total}`} anchor="end" />
        <text className="anlage-sub" x="1004" y="360">
          {heizungStatus(hz)}
        </text>
      </Kachel>
      </Symbol>
      {/* Kaltwasser: kein Kasten, nur ein Wort am Rohr */}
      <text className="anlage-hint" x="992" y="567">
        {`Kaltwasser${ww.inlet_c != null ? ` ${grad(ww.inlet_c)}` : ""}${ww.tapping ? " läuft nach" : ""}`}
      </text>

      {/* Pumpen */}
      <Pumpe x={748} y={282} laeuft={!!w.running} text={w.running ? "Pumpe" : ""} />
      <Pumpe x={745} y={116} laeuft={!!o.running} text={o.running && o.pump_pct != null ? `${Math.round(o.pump_pct)} %` : ""} />
      <Pumpe x={938} y={330} laeuft={hz.running} text={hz.running ? "läuft" : ""} />

      {/* Temperaturen an den Stutzen */}
      <text className="anlage-hint" x="800" y="52" textAnchor="end">
        {o.running && o.flow_c != null ? grad(o.flow_c) : ""}
      </text>
      <text className="anlage-hint" x="770" y="252" textAnchor="end">
        {w.running ? (w.flow_c != null ? grad(w.flow_c) : "Vorlauf ?") : ""}
      </text>
      <text className="anlage-hint" x="774" y="582" textAnchor="end">
        {(w.running || o.running) && rl != null ? `zurück ${grad(rl)}` : ""}
      </text>
      <text className="anlage-hint" x="1000" y="488">
        {hz.running && rl != null ? `zurück ${grad(rl)}` : ""}
      </text>
    </svg>
  );
}
