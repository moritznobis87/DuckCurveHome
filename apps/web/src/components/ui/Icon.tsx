/* Stroke-Icons auf 24-px-Raster, einheitlicher Stil: 1,75 px Strich, runde Enden, kein Emoji.
 *
 * Ein Icon ist eine Zeichnung, keine Beschriftung. Wo eines allein steht (Bereichsleiste, Dock),
 * steht der Name im `title` und `aria-label` des Elements, das es traegt. */
const PATHS: Record<string, string> = {
  // ---- Bereiche. Vier Zeichen, die man im Vorbeigehen auseinanderhaelt: Entenkurve, Blitz,
  // Flamme, Euro. Ein Zahnrad fuer System, das nur der Hausherr sieht.
  // Die Marke selbst: die Kurve aus dem Logo, in das Raster gerechnet. Der Strich skaliert
  // nicht mit, damit er in 18 px genauso dick ist wie die anderen.
  duck: '<path vector-effect="non-scaling-stroke" d="M 2 15.46 C 4.48 13.11 6.35 15.9 9.01 15.99 C 13.18 16.12 13.88 12.84 16.24 9.52 C 17.39 7.88 19.25 8.19 19.69 9.74 C 19.96 10.67 20.71 10.85 22 11.07 C 21.07 11.56 20.27 11.6 19.43 12.04"/>',
  bolt: '<path d="M13.2 2.5 5.6 13.4h5.2L10.6 21.5l7.8-11.2h-5.3z"/>',
  // Flamme mit innerem Kern. Der Kern ist das, was eine Flamme von einem Tropfen unterscheidet.
  flame: '<path d="M12 2.5c.9 3.3 4.6 5 5.6 8.6 1.1 4-1.6 8.4-5.6 8.4s-6.7-4.4-5.6-8.4c.4-1.6 1.4-2.9 2.4-4.1.4 1.4 1.1 2.4 2.2 2.9C10.5 7.6 10.8 5 12 2.5z"/><path d="M12 19.5c-1.8 0-3-1.4-2.7-3 .2-1 .9-1.8 1.6-2.6.3.8.8 1.3 1.5 1.5.3-1 .5-1.8 1-2.6 1.1 1.1 1.9 2.4 1.6 3.8-.3 1.7-1.4 2.9-3 2.9z"/>',
  euro: '<path d="M18.2 6.6A7.4 7.4 0 1 0 18.2 17.4"/><path d="M4 10.4h10M4 13.6h10"/>',
  // Echte Zahnkontur, in Python aus Kopf- und Fusskreis gerechnet.
  gear: '<path d="M21.86 10.36 L21.86 13.64 L19.18 13.78 L18.34 15.82 L20.14 17.81 L17.81 20.14 L15.82 18.34 L13.78 19.18 L13.64 21.86 L10.36 21.86 L10.22 19.18 L8.18 18.34 L6.19 20.14 L3.86 17.81 L5.66 15.82 L4.82 13.78 L2.14 13.64 L2.14 10.36 L4.82 10.22 L5.66 8.18 L3.86 6.19 L6.19 3.86 L8.18 5.66 L10.22 4.82 L10.36 2.14 L13.64 2.14 L13.78 4.82 L15.82 5.66 L17.81 3.86 L20.14 6.19 L18.34 8.18 L19.18 10.22 Z"/><circle cx="12" cy="12" r="3.6"/>',

  // ---- Knoten des Energieflusses
  sun: '<circle cx="12" cy="12" r="3.9"/><path d="M12 2.5v2.3M12 19.2v2.3M2.5 12h2.3M19.2 12h2.3M5.3 5.3l1.6 1.6M17.1 17.1l1.6 1.6M5.3 18.7l1.6-1.6M17.1 6.9l1.6-1.6"/>',
  home: '<path d="M3.5 11.2 12 4l8.5 7.2"/><path d="M5.8 9.8V20h12.4V9.8"/><path d="M10 20v-5.5h4V20"/><path d="M16.3 4.9h2v2.9"/>',
  house: '<path d="M3.5 11.2 12 4l8.5 7.2"/><path d="M5.8 9.8V20h12.4V9.8"/><path d="M10 20v-5.5h4V20"/><path d="M16.3 4.9h2v2.9"/>',
  // Freileitungsmast: Traverse ueber auseinanderlaufenden Beinen.
  grid: '<path d="M9.4 3h5.2"/><path d="M10.2 3 5.5 21M13.8 3l4.7 18"/><path d="M3.8 8.6h16.4"/><path d="M6.4 14.4h11.2"/>',
  // Speicher mit Fuellstand: die Flaeche innen ist gefuellt, nicht gestrichelt, damit sie
  // auch bei 18 px als Ladung zu lesen ist.
  battery: '<rect x="2.5" y="7" width="16.5" height="10" rx="2.2"/><path d="M21.5 10.4v3.2"/><rect x="5.1" y="9.6" width="6.4" height="4.8" rx="1" fill="currentColor" stroke="none"/>',
  // Ausseneinheit mit Luefterrad.
  pump: '<rect x="2.5" y="5" width="19" height="14" rx="2.5"/><circle cx="12" cy="12" r="4.2"/><path d="M12 12 9.3 9.4M12 12l3.5-1.3M12 12l-.7 3.8"/><path d="M6 19v1.8M18 19v1.8"/>',
  // Auto von der Seite, mit Raedern. Das vorige Symbol zeigte die Wallbox selbst und war
  // als Geraet eindeutig, aber niemand erkennt eine Wallbox auf 18 px; ein Auto erkennt jeder.
  car: '<path d="M3.5 14.3 5.1 9.9a2 2 0 0 1 1.9-1.4h8.6a2 2 0 0 1 1.7 1l2.5 4.8"/><path d="M3.5 14.3h17v3.4a1 1 0 0 1-1 1h-1.4M3.5 14.3v3.4a1 1 0 0 0 1 1h1.4"/><circle cx="8.1" cy="18.4" r="1.9"/><circle cx="15.9" cy="18.4" r="1.9"/><path d="M10 18.7h4"/>',
  // Pelletofen: Korpus mit Sichtscheibe und Flamme darin.
  stove: '<rect x="4" y="2.6" width="16" height="17.8" rx="2"/><path d="M4 7.5h16"/><path d="M12 10.6c1.7 1.7 2.7 2.9 2.7 4.3a2.7 2.7 0 0 1-5.4 0c0-1.4 1-2.6 2.7-4.3z"/><path d="M7.5 20.4v1.4M16.5 20.4v1.4"/>',

  // ---- Schalter im Dock
  coffee: '<path d="M4.5 9h11.5v5.4a4.6 4.6 0 0 1-4.6 4.6H9.1a4.6 4.6 0 0 1-4.6-4.6z"/><path d="M16 10.6h1.8a2.2 2.2 0 0 1 0 4.4H16"/><path d="M8.3 3.6c-.9 1-.9 1.9 0 2.9M11.7 3.6c-.9 1-.9 1.9 0 2.9"/>',
  bulb: '<path d="M9.3 17.6h5.4"/><path d="M10.2 20.5h3.6"/><path d="M8.6 14.3a5.7 5.7 0 1 1 6.8 0c-.7.6-1.1 1.5-1.1 2.4H9.7c0-.9-.4-1.8-1.1-2.4z"/>',

  // ---- Reiter und Hinweise
  thermo: '<path d="M10 4.5a2 2 0 0 1 4 0v8.7a4 4 0 1 1-4 0z"/><path d="M12 9.5v5.3"/><circle cx="12" cy="16.6" r="1.5" fill="currentColor" stroke="none"/>',
  chart: '<path d="M3 20h18"/><path d="M5.5 17v-6"/><path d="M10.2 17V6.5"/><path d="M14.8 17v-4.5"/><path d="M19.5 17V8.5"/>',
  calendar: '<rect x="3" y="4" width="18" height="17" rx="2"/><path d="M3 9h18"/><path d="M9 9v12M15 9v12"/><path d="M3 15h18"/>',
  table: '<rect x="3" y="4" width="18" height="16" rx="2"/><path d="M3 9h18"/><path d="M9 9v11"/><path d="M6 16.5l2.2-3 2.6 2 3-4.2 2.4 2.6 2-2.4"/>',
  door: '<path d="M5.5 21V4.5A1.5 1.5 0 0 1 7 3h10a1.5 1.5 0 0 1 1.5 1.5V21"/><path d="M3.5 21h17"/><circle cx="14.6" cy="12.6" r="1.1" fill="currentColor" stroke="none"/>',
  shield: '<path d="M12 3 5 5.8v5.3c0 4.3 3 7.7 7 8.9 4-1.2 7-4.6 7-8.9V5.8z"/><path d="M9.2 12.2l2 2 3.8-4"/>',
  dashboard: '<rect x="3" y="3" width="7.5" height="7.5" rx="1.5"/><rect x="13.5" y="3" width="7.5" height="7.5" rx="1.5"/><rect x="3" y="13.5" width="7.5" height="7.5" rx="1.5"/><rect x="13.5" y="13.5" width="7.5" height="7.5" rx="1.5"/>',
  alert: '<path d="M12 3l10 18H2z"/><path d="M12 10v5"/><path d="M12 18v.5"/>',
  clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
};

export type IconName = keyof typeof PATHS;

export function Icon({ name, size = 22, color = "currentColor", strokeWidth = 1.75 }: { name: IconName | string; size?: number; color?: string; strokeWidth?: number }) {
  const d = PATHS[name] ?? "";
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth={strokeWidth} strokeLinecap="round" strokeLinejoin="round" aria-hidden dangerouslySetInnerHTML={{ __html: d }} />
  );
}
