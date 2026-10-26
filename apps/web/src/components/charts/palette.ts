/**
 * Die Farben aller Diagramme, an einer Stelle.
 *
 * **Warum eine Stelle.** Es gab zwei Kopien dieser Liste, eine in `charts.ts` und eine in
 * `DayChart.tsx`, und sie waren bereits auseinandergelaufen: derselbe Schlüssel `grid` meinte hier
 * die Netzfarbe und dort die Gitterlinie. Eine Farbe gehört zur Sache, die sie bezeichnet, nicht
 * zur Datei, in der das Diagramm zufällig steht.
 *
 * **Warum diese Werte.** Geprüft mit dem Palettenprüfer der dataviz-Anleitung gegen die
 * Kartenfläche `--surface-2` (#123544), Modus dunkel, alle Paare. Maßgeblich ist der Abstand
 * zwischen Farben, die im **selben** Diagramm vorkommen:
 *
 * | Diagramm | Serien | schlechtestes Paar |
 * |---|---|---|
 * | Tagesverlauf Dashboard | PV, Wärmepumpe, Wallbox | ΔE 23,0 normal · 22,0 CVD |
 * | Wer hat verbraucht? | Wärmepumpe, Wallbox, Haushalt | ΔE 21,8 normal · 18,7 CVD |
 * | Woher kam der Strom? | PV, Batterie, Netz | ΔE 20,8 normal · 15,1 CVD |
 *
 * Zwei Werte wurden dabei ersetzt, weil sie den Test nicht bestanden:
 *
 * * **Wallbox** war #5c8fa3 und lag nur ΔE 7,5 vom Strompreis und ΔE 11,4 vom Haushalt entfernt.
 *   Unter 15 sind zwei Flächen auch mit normalem Farbsehen kaum zu trennen, und genau das war auf
 *   der Hausseite zu sehen: die gestapelten Balken hatten drei Segmente, von denen zwei wie eines
 *   aussahen.
 * * **Haushalt** war #4d6b78 und hatte zusätzlich nur 2,28:1 Kontrast gegen die Karte - der
 *   unterste Balkenabschnitt verschwand fast im Hintergrund. Der Rest des Hausverbrauchs ist jetzt
 *   sandfarben: eine eigene Familie, die mit keiner der kühlen Flüsse verwechselt werden kann.
 *
 * Der Strompreis behält seine Farbe, obwohl er der Batterie gleicht. Beide kommen nie im selben
 * Diagramm vor, und der Preis steht im Dashboard in einer eigenen Fläche mit eigener Achse und
 * eigener Legende. Was zusammen zu lesen ist, muss sich unterscheiden; was getrennt steht, nicht.
 */
export const C = {
  // Energieflüsse
  pv: "#f2a900",
  battery: "#7fa3b3",
  grid: "#e0533d", // Netzbezug
  hp: "#e4ecef", // Wärmepumpe
  ev: "#2f89b5", // Wallbox
  base: "#c2a86b", // Haushalt ohne Wärmepumpe und Wallbox
  // Hausverbrauch als Summe, nicht als Quelle. Eigene Farbe, weil er in der Prüfansicht neben
  // PV, Netz und Speicher steht; dort scheitert das Sandfarbene des Haushalts an der PV
  // (ΔE 9,3). Geprüft: schlechtestes Paar dieser vier ΔE 18,5 normal / 15,1 CVD.
  house: "#cfd8dc",
  export: "rgba(228,236,239,.5)",
  stove: "#b5651d",
  // Die Waermepumpe als Linie, in der Farbe ihres Knotens im Energiefluss. `hp` ist ein helles
  // Grau fuer Flaechen und steht der weissen Hauslinie zu nah (CIEDE2000 4,5); dieses Orange
  // haelt Abstand zu allen Linien der Tageskurve (zur Sonne 18,4, zum Strompreis 34,0).
  heatPump: "#e0966b",
  // Die Sonne eines anderen Tages: hinter heute liegt gestern, hinter morgen heute. Dieselbe
  // Familie wie `pv`, nur dunkler - CIEDE2000 9,9 zur Sonne, also nach dem Maßstab dieser Liste
  // zu nah. **Hier ist das der Sinn:** Es ist dieselbe Größe an einem anderen Tag, und wer die
  // beiden für verwandt hält, hat richtig gelesen. Unterschieden werden sie an der Form - keine
  // Fläche, dünner, hinter allem - und in der Legende, die den Tag nennt. Gegen die Kartenfläche
  // #123544 hat sie 4,63:1, reicht also auch aus drei Metern.
  pvSchatten: "#c8902f",
  mist: "#7fa3b3",
  // Nicht-Energie
  price: "#7fa3b3",
  alert: "#e0533d",
  // Gerüst
  gridline: "rgba(255,255,255,.09)",
  axis: "rgba(255,255,255,.2)",
  text: "rgba(255,255,255,.48)",
  deep: "#082431",
} as const;

export const MONO = "'IBM Plex Mono', ui-monospace, monospace";
