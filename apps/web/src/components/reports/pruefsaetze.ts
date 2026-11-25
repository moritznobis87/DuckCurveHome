/** Die Sätze der Karten; dieselben in der App (`Pruefworte`). Seit dem 25.11.2026 ohne die langen
 *  Absätze am Fuß der Seite (Hausherr: keine Erklärtexte auf den Systemseiten). */
export const PRUEFSAETZE = {
  leistungen: "Bezug und Entladen zählen positiv, Einspeisung und Laden negativ; der Ladestand steht rechts in Prozent.",
  quellen: "Was gerade liefert und was ausbleibt.",
  abdeckung: (tage: number) => `Minuten je Stunde über ${tage} Tage, von 0 bis 60.`,
  lesehilfe: "Ohne Farbe stand der Dienst still. Rot heißt, das Gerät hat in dieser Stunde nichts geliefert.",
};
