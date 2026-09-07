/* Stroke-Icons auf 24-px-Raster, einheitlicher Stil (kein Emoji). */
const PATHS: Record<string, string> = {
  sun: '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/>',
  home: '<path d="M3 11l9-7 9 7"/><path d="M5 10v10h14V10"/><path d="M10 20v-6h4v6"/>',
  // Freileitungsmast: zwei sich öffnende Beine, zwei Traversen, ein Andreaskreuz als Verstrebung.
  grid: '<path d="M9.2 21L11 4M14.8 21L13 4"/><path d="M10.6 5.5h2.8"/><path d="M7.4 9.5h9.2"/><path d="M8.4 14.5h7.2"/><path d="M10.2 9.5l3.6 5M13.8 9.5l-3.6 5"/>',
  battery: '<rect x="3" y="7" width="16" height="10" rx="1.5"/><path d="M21 10v4"/><path d="M7 11v2M10 11v2M13 11v2"/>',
  // Außeneinheit mit Lüfterrad: liest sich als Wärmepumpe, nicht als Fadenkreuz.
  pump: '<rect x="3" y="5.5" width="18" height="13" rx="2"/><circle cx="12" cy="12" r="3.6"/><path d="M12 12l2.9-1.9M12 12l-2.9-1.9M12 12v3.4"/><path d="M6.5 18.5v1.6M17.5 18.5v1.6"/>',
  // Wallbox statt Auto: Gehäuse mit Blitz und abgehängtem Ladekabel.
  car: '<rect x="4" y="3" width="10" height="14" rx="2"/><path d="M10.4 6.6L8.2 10.4h3L9 14.2"/><path d="M14 8h2.4A1.6 1.6 0 0 1 18 9.6V17a2.5 2.5 0 0 1-2.5 2.5H14"/>',
  coffee: '<path d="M5 9h11v5a5 5 0 0 1-10 0V9z"/><path d="M16 10h2a2 2 0 0 1 0 4h-2"/><path d="M4 20h13"/><path d="M8 5c0 1 1 1 1 2M11 5c0 1 1 1 1 2"/>',
  bulb: '<path d="M9 18h6"/><path d="M10 21h4"/><path d="M8.5 14.5A6 6 0 1 1 15.5 14.5c-.7.7-1 1.6-1 2.5h-5c0-.9-.3-1.8-1-2.5z"/>',
  chart: '<path d="M3 20h18"/><path d="M5 17V11"/><path d="M10 17V6"/><path d="M15 17v-4"/><path d="M20 17V8"/>',
  gear: '<circle cx="12" cy="12" r="3"/><path d="M12 2v3M12 19v3M2 12h3M19 12h3M4.9 4.9l2.1 2.1M17 17l2.1 2.1M4.9 19.1L7 17M17 7l2.1-2.1"/>',
  alert: '<path d="M12 3l10 18H2z"/><path d="M12 10v5"/><path d="M12 18v.5"/>',
  clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
  thermo: '<path d="M10 4a2 2 0 0 1 4 0v9.5a4 4 0 1 1-4 0z"/><path d="M12 9v6"/>',
};

export function Icon({ name, size = 22, color = "currentColor", strokeWidth = 1.75 }: { name: keyof typeof PATHS | string; size?: number; color?: string; strokeWidth?: number }) {
  const d = PATHS[name] ?? "";
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth={strokeWidth} strokeLinecap="round" strokeLinejoin="round" aria-hidden dangerouslySetInnerHTML={{ __html: d }} />
  );
}
