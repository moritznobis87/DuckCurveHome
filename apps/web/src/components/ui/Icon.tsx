/* Stroke-Icons auf 24-px-Raster, einheitlicher Stil (kein Emoji). */
const PATHS: Record<string, string> = {
  sun: '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/>',
  home: '<path d="M3 11l9-7 9 7"/><path d="M5 10v10h14V10"/><path d="M10 20v-6h4v6"/>',
  // Freileitungsmast: Traverse über den auseinanderlaufenden Beinen, wie am Original. Die
  // A-Silhouette davor las sich als Buchstabe A - nachgesehen, nicht vermutet.
  grid: '<path d="M9.2 3.5h5.6"/><path d="M10 3.5L5 20.5M14 3.5l5 17"/><path d="M3.5 8.5h17"/><path d="M6.6 14.5h10.8"/>',
  battery: '<rect x="3" y="7" width="16" height="10" rx="1.5"/><path d="M21 10v4"/><path d="M7 11v2M10 11v2M13 11v2"/>',
  // Außeneinheit mit Lüfterrad: liest sich als Wärmepumpe, nicht als Fadenkreuz.
  pump: '<rect x="3" y="5.5" width="18" height="13" rx="2"/><circle cx="12" cy="12" r="3.6"/><path d="M12 12l2.9-1.9M12 12l-2.9-1.9M12 12v3.4"/><path d="M6.5 18.5v1.6M17.5 18.5v1.6"/>',
  // Die Wallbox selbst: Gehäuse, Blitz, hängendes Ladekabel. Vier Auto-Varianten haben es davor
  // nicht getan - von vorn wurde ein Tisch daraus, von der Seite ein Kleinbus, mit Stecker am Heck
  // ein Anhänger. Das Gerät zu zeichnen statt seinen Zweck ist hier eindeutiger.
  car: '<rect x="6" y="2.8" width="9" height="12.5" rx="2"/><path d="M11.3 6.1l-1.8 3.2h2.5l-1.8 3.2"/><path d="M10.5 15.3v2.4a3.3 3.3 0 0 0 3.3 3.3h1.9a3.3 3.3 0 0 0 3.3-3.3v-4.6"/>',
  coffee: '<path d="M5 9h11v5a5 5 0 0 1-10 0V9z"/><path d="M16 10h2a2 2 0 0 1 0 4h-2"/><path d="M4 20h13"/><path d="M8 5c0 1 1 1 1 2M11 5c0 1 1 1 1 2"/>',
  bulb: '<path d="M9 18h6"/><path d="M10 21h4"/><path d="M8.5 14.5A6 6 0 1 1 15.5 14.5c-.7.7-1 1.6-1 2.5h-5c0-.9-.3-1.8-1-2.5z"/>',
  // Dashboard: Kachelraster - das Bild der Startseite, abgesetzt vom Haus-Symbol.
  dashboard: '<rect x="3" y="3" width="7.5" height="7.5" rx="1.5"/><rect x="13.5" y="3" width="7.5" height="7.5" rx="1.5"/><rect x="3" y="13.5" width="7.5" height="7.5" rx="1.5"/><rect x="13.5" y="13.5" width="7.5" height="7.5" rx="1.5"/>',
  // Haus als Navigationsziel (Verbrauch), gleiche Kontur wie im Energiefluss.
  house: '<path d="M3 11l9-7 9 7"/><path d="M5 10v10h14V10"/><path d="M10 20v-6h4v6"/>',
  chart: '<path d="M3 20h18"/><path d="M5 17V11"/><path d="M10 17V6"/><path d="M15 17v-4"/><path d="M20 17V8"/>',
  // Jahreskarte: ein Raster aus Zellen - das Bild, das die Seite zeigt.
  calendar: '<rect x="3" y="4" width="18" height="17" rx="2"/><path d="M3 9h18"/><path d="M9 9v12M15 9v12"/><path d="M3 15h18"/>',
  // Echte Zahnkontur, in Python aus Kopf- und Fußkreis gerechnet. Das vorherige „Zahnrad" war
  // ein Kreis mit acht Strahlen - also eine Sonne.
  gear: '<path d="M21.86 10.36 L21.86 13.64 L19.18 13.78 L18.34 15.82 L20.14 17.81 L17.81 20.14 L15.82 18.34 L13.78 19.18 L13.64 21.86 L10.36 21.86 L10.22 19.18 L8.18 18.34 L6.19 20.14 L3.86 17.81 L5.66 15.82 L4.82 13.78 L2.14 13.64 L2.14 10.36 L4.82 10.22 L5.66 8.18 L3.86 6.19 L6.19 3.86 L8.18 5.66 L10.22 4.82 L10.36 2.14 L13.64 2.14 L13.78 4.82 L15.82 5.66 L17.81 3.86 L20.14 6.19 L18.34 8.18 L19.18 10.22 Z"/><circle cx="12" cy="12" r="3.6"/>',
  alert: '<path d="M12 3l10 18H2z"/><path d="M12 10v5"/><path d="M12 18v.5"/>',
  clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
  // Pelletofen: Korpus mit Sichtscheibe und Flamme darin. Eine Flamme allein hieße „Wärme"
  // irgendwoher - hier geht es um ein bestimmtes Gerät, das neben der Wärmepumpe steht.
  stove: '<rect x="4" y="2.6" width="16" height="17.8" rx="2"/><path d="M4 7.5h16"/><path d="M12 10.6c1.7 1.7 2.7 2.9 2.7 4.3a2.7 2.7 0 0 1-5.4 0c0-1.4 1-2.6 2.7-4.3z"/><path d="M7.5 20.4v1.4M16.5 20.4v1.4"/>',
  thermo: '<path d="M10 4a2 2 0 0 1 4 0v9.5a4 4 0 1 1-4 0z"/><path d="M12 9v6"/>',
};

export function Icon({ name, size = 22, color = "currentColor", strokeWidth = 1.75 }: { name: keyof typeof PATHS | string; size?: number; color?: string; strokeWidth?: number }) {
  const d = PATHS[name] ?? "";
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth={strokeWidth} strokeLinecap="round" strokeLinejoin="round" aria-hidden dangerouslySetInnerHTML={{ __html: d }} />
  );
}
