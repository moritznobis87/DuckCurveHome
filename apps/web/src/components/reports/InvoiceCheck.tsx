"use client";

import Link from "next/link";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { api, ApiError } from "@/lib/api/client";
import type { InvoiceFinding, InvoiceReport, InvoiceSummary } from "@/lib/api/models";
import { Card, CardHead } from "@/components/ui/Card";
import { Stat } from "@/components/ui/Stat";
import { EChart } from "@/components/charts/EChart";
import { invoiceCostStack, invoicePositions, invoicePriceLine, invoiceVsMeasured } from "./charts";
import { de1, ErrorBanner, eur, Note } from "./ReportShell";

const TONE: Record<string, { color: string; label: string }> = {
  ok: { color: "var(--amber)", label: "geprüft, alles stimmig" },
  info: { color: "var(--mist)", label: "geprüft, mit Hinweisen" },
  warning: { color: "var(--alert)", label: "auffällig" },
  error: { color: "var(--alert)", label: "Rechenfehler" },
};
const RANK: Record<string, number> = { error: 0, warning: 1, info: 2, ok: 3 };
const short = (label: string) => label.replace(/(\w{3})\w* (\d{4})/, "$1 $2");

function Dot({ severity }: { severity: string }) {
  const filled = severity === "error" || severity === "warning";
  return (
    <span
      aria-hidden
      className="mt-[5px] inline-block h-2 w-2 shrink-0 rounded-full"
      style={{ background: filled ? "var(--alert)" : severity === "info" ? "var(--mist)" : "var(--amber)" }}
    />
  );
}

function FindingRow({ f }: { f: InvoiceFinding }) {
  const hasNumbers = f.expected != null && f.actual != null;
  return (
    <li className="flex gap-2.5 border-t border-line-1 py-2 first:border-t-0">
      <Dot severity={f.severity} />
      <div className="min-w-0 flex-1">
        <div className="flex flex-wrap items-baseline justify-between gap-x-3">
          <span className="text-[13px] text-text-1">{f.title_de}</span>
          {hasNumbers ? (
            <span className="mono whitespace-nowrap text-[12px]" style={{ color: f.severity === "ok" ? "var(--text-3)" : "var(--alert)" }}>
              {de1(f.expected, 2)} erwartet · {de1(f.actual, 2)} {f.unit}
              {f.delta != null && Math.abs(f.delta) >= 0.005 ? ` · ${f.delta > 0 ? "+" : ""}${de1(f.delta, 2)}` : ""}
            </span>
          ) : null}
        </div>
        {f.detail_de ? <p className="m-0 mt-0.5 text-[12px] leading-[1.5] text-text-3">{f.detail_de}</p> : null}
      </div>
    </li>
  );
}

function DropZone({ onFiles, busy, compact }: { onFiles: (files: File[]) => void; busy: boolean; compact: boolean }) {
  const [over, setOver] = useState(false);
  const input = useRef<HTMLInputElement>(null);
  const take = (list: FileList | null) => {
    const files = Array.from(list ?? []).filter((f) => f.type === "application/pdf" || f.name.toLowerCase().endsWith(".pdf"));
    if (files.length) onFiles(files);
  };
  return (
    <div
      onDragOver={(e) => {
        e.preventDefault();
        setOver(true);
      }}
      onDragLeave={() => setOver(false)}
      onDrop={(e) => {
        e.preventDefault();
        setOver(false);
        take(e.dataTransfer.files);
      }}
      onClick={() => input.current?.click()}
      role="button"
      tabIndex={0}
      onKeyDown={(e) => {
        if (e.key === "Enter" || e.key === " ") input.current?.click();
      }}
      className="flex cursor-pointer flex-col items-center justify-center gap-1.5 rounded-[3px] text-center transition-colors"
      style={{
        border: `1.5px dashed ${over ? "var(--amber)" : "var(--line-2)"}`,
        background: over ? "rgba(242,169,0,.07)" : "transparent",
        padding: compact ? "16px" : "34px 20px",
      }}
    >
      <input ref={input} type="file" accept="application/pdf,.pdf" multiple hidden onChange={(e) => take(e.target.files)} />
      <span className="text-[14px] text-text-1">{busy ? "Rechnung wird geprüft …" : "Tibber-Rechnung hierher ziehen"}</span>
      <span className="text-[12px] text-text-3">
        {busy ? "Positionen werden nachgerechnet" : "oder klicken, um PDFs auszuwählen – mehrere auf einmal möglich"}
      </span>
    </div>
  );
}

export function InvoiceCheck() {
  const [items, setItems] = useState<InvoiceSummary[]>([]);
  const [report, setReport] = useState<InvoiceReport | null>(null);
  const [selected, setSelected] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [loaded, setLoaded] = useState(false);

  const reload = useCallback(async () => {
    try {
      setItems(await api.tibberInvoices());
      setError(null);
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "Rechnungen konnten nicht geladen werden.");
    } finally {
      setLoaded(true);
    }
  }, []);
  useEffect(() => {
    void reload();
  }, [reload]);

  const open = useCallback(async (number: string) => {
    setSelected(number);
    try {
      setReport(await api.tibberInvoice(number));
      setError(null);
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "Rechnung konnte nicht geladen werden.");
    }
  }, []);

  // Beim Öffnen die neueste Rechnung zeigen, damit Befunde und Preisbestandteile nicht leer bleiben
  useEffect(() => {
    if (selected === null && items.length > 0) void open(items[0]!.number);
  }, [items, selected, open]);

  const upload = useCallback(
    async (files: File[]) => {
      setBusy(true);
      setError(null);
      const failed: string[] = [];
      let last: InvoiceReport | null = null;
      for (const file of files) {
        try {
          last = await api.checkTibberInvoice(file);
        } catch (e) {
          failed.push(`${file.name}: ${e instanceof ApiError ? e.message : "Fehler beim Prüfen"}`);
        }
      }
      if (last) {
        setReport(last);
        setSelected(last.invoice.number);
      }
      if (failed.length) setError(failed.join(" · "));
      await reload();
      setBusy(false);
    },
    [reload],
  );

  const chronological = useMemo(() => [...items].sort((a, b) => a.period_start.localeCompare(b.period_start)), [items]);
  const kwhOpt = useMemo(
    () => invoiceVsMeasured(chronological.map((i) => ({ label: short(i.period_label), invoice: i.kwh, measured: i.measured_kwh ?? null }))),
    [chronological],
  );
  const costOpt = useMemo(
    () =>
      invoiceCostStack(
        chronological.map((i) => ({
          label: short(i.period_label),
          energy: i.energy_net_eur,
          fees: i.fees_net_eur,
          vat: Math.round((i.total_gross_eur - i.total_net_eur) * 100) / 100,
        })),
      ),
    [chronological],
  );
  const priceOpt = useMemo(
    () =>
      invoicePriceLine(
        chronological.map((i) => ({
          label: short(i.period_label),
          invoice: i.avg_ct_kwh_gross,
          measured: i.measured_avg_ct_kwh ?? null,
        })),
      ),
    [chronological],
  );
  const positionsOpt = useMemo(
    () => invoicePositions((report?.invoice.positions ?? []).map((p) => ({ label: p.label, group: p.group, ct: p.ct_per_kwh }))),
    [report],
  );

  const problems = items.filter((i) => i.verdict === "error" || i.verdict === "warning").length;
  const totalGross = items.reduce((a, i) => a + i.total_gross_eur, 0);
  const totalKwh = items.reduce((a, i) => a + i.kwh, 0);
  const findings = useMemo(
    () => [...(report?.findings ?? [])].sort((a, b) => (RANK[a.severity] ?? 9) - (RANK[b.severity] ?? 9)),
    [report],
  );
  const computed = findings.filter((f) => !["measured_kwh", "measured_price", "coverage", "no_measurement"].includes(f.code));
  const compared = findings.filter((f) => ["measured_kwh", "measured_price", "coverage", "no_measurement"].includes(f.code));

  return (
    <main className="dashboard-bg report-main flex min-h-[100dvh] flex-col gap-4 p-5 text-text-1">
      <header className="report-header flex h-14 shrink-0 items-center justify-between rounded-[3px] border border-line-2 px-5" style={{ background: "var(--surface-glass)", backdropFilter: "blur(18px)" }}>
        <div className="flex min-w-0 items-center gap-5">
          <Link href="/haus" className="kicker whitespace-nowrap" style={{ fontSize: 12 }}>← Haus</Link>
          <div className="flex min-w-0 items-baseline gap-2.5">
            <span className="whitespace-nowrap text-[17px] font-semibold tracking-[-.02em]">Rechnungsprüfung</span>
            <span className="kicker truncate" style={{ fontSize: 12 }}>Tibber · nachgerechnet und gegen die eigene Messung gehalten</span>
          </div>
        </div>
      </header>

      {error ? <ErrorBanner message={error} /> : null}

      <div className="report-row" style={{ "--cols": "5fr 7fr" } as React.CSSProperties}>
        <Card style={{ padding: 16, gap: 12 }}>
          <CardHead title="Rechnung prüfen" right={busy ? "läuft" : `${items.length} gespeichert`} />
          <DropZone onFiles={(f) => void upload(f)} busy={busy} compact={items.length > 0} />
          <Note>
            Geprüft werden alle Positionen der Rechnung gegen Menge und Preis, die Summen, die Mehrwertsteuer,
            die Grundgebühr nach Tagen sowie der Anschluss an die Vorrechnung. Zusätzlich vergleichen wir die
            abgerechnete Menge mit unserem gemessenen Netzbezug. Das PDF selbst wird nicht gespeichert.
          </Note>
        </Card>
        <div className="kpi-grid" style={{ "--cols": 2 } as React.CSSProperties}>
          <Stat label="Geprüfte Rechnungen" value={String(items.length)} hint={items.length ? `${chronological[0]?.period_label} bis ${chronological[chronological.length - 1]?.period_label}` : "noch keine"} />
          <Stat label="Beanstandet" value={String(problems)} tone={problems ? "ember" : "amber"} hint={problems ? "Befunde unten ansehen" : "keine Auffälligkeit"} />
          <Stat label="Summe brutto" value={eur(totalGross)} hint={`über ${de1(totalKwh, 0)} kWh`} />
          <Stat label="Ø Preis brutto" value={totalKwh > 0 ? de1(items.reduce((a, i) => a + i.avg_ct_kwh_gross * i.kwh, 0) / totalKwh, 2) : "–"} unit="ct/kWh" tone="amber" hint="mengengewichtet über alle Rechnungen" />
        </div>
      </div>

      {items.length > 0 ? (
        <>
          <div className="report-row" style={{ "--cols": "1fr 1fr" } as React.CSSProperties}>
            <Card style={{ padding: 16, height: 280 }}>
              <CardHead title="Menge: Rechnung gegen eigene Messung" right="je Abrechnungszeitraum" />
              <div className="min-h-0 flex-1"><EChart option={kwhOpt} /></div>
            </Card>
            <Card style={{ padding: 16, height: 280 }}>
              <CardHead title="Rechnungsbetrag" right="Arbeitspreis · Grundgebühr · Steuer" />
              <div className="min-h-0 flex-1"><EChart option={costOpt} /></div>
            </Card>
          </div>
          <div className="report-row" style={{ "--cols": "5fr 7fr" } as React.CSSProperties}>
            <Card style={{ padding: 16, height: 280 }}>
              <CardHead title="Durchschnittspreis" right="brutto" />
              <div className="min-h-0 flex-1"><EChart option={priceOpt} /></div>
            </Card>
            <Card style={{ padding: 16, height: 280 }}>
              <CardHead title="Preisbestandteile" right={report ? report.invoice.period_label : "Rechnung auswählen"} />
              {report && (report.invoice.positions?.length ?? 0) > 0 ? (
                <div className="min-h-0 flex-1"><EChart option={positionsOpt} /></div>
              ) : (
                <div className="flex flex-1 items-center justify-center"><Note>Eine Rechnung in der Liste auswählen.</Note></div>
              )}
            </Card>
          </div>

          <Card style={{ padding: 16 }}>
            <CardHead title="Geprüfte Rechnungen" right="Zeile anklicken für die Befunde" />
            <div className="mt-2 overflow-auto">
              <table className="w-full border-collapse text-[12px]">
                <thead>
                  <tr className="kicker text-left" style={{ fontSize: 10 }}>
                    <th className="py-1.5 pr-3 font-medium">Zeitraum</th>
                    <th className="py-1.5 pr-3 font-medium">Nummer</th>
                    <th className="py-1.5 pr-3 text-right font-medium">Menge</th>
                    <th className="py-1.5 pr-3 text-right font-medium">Eigene Messung</th>
                    <th className="py-1.5 pr-3 text-right font-medium">Ø brutto</th>
                    <th className="py-1.5 pr-3 text-right font-medium">Netto</th>
                    <th className="py-1.5 pr-3 text-right font-medium">Brutto</th>
                    <th className="py-1.5 font-medium">Ergebnis</th>
                  </tr>
                </thead>
                <tbody className="mono">
                  {items.map((i) => {
                    const tone = TONE[i.verdict] ?? TONE.info!;
                    const active = i.number === selected;
                    return (
                      <tr
                        key={i.number}
                        onClick={() => void open(i.number)}
                        className="cursor-pointer border-t border-line-1"
                        style={{ background: active ? "var(--surface-1)" : undefined }}
                      >
                        <td className="py-1.5 pr-3 whitespace-nowrap">{i.period_label}</td>
                        <td className="py-1.5 pr-3 text-text-3">{i.number}</td>
                        <td className="py-1.5 pr-3 text-right">{de1(i.kwh, 2)} kWh</td>
                        <td className="py-1.5 pr-3 text-right text-text-3">
                          {i.measured_kwh != null && i.measured_kwh > 0
                            ? `${de1(i.measured_kwh, 1)} kWh${i.coverage != null && i.coverage < 0.98 ? ` (${Math.round(i.coverage * 100)} %)` : ""}`
                            : "–"}
                        </td>
                        <td className="py-1.5 pr-3 text-right">{de1(i.avg_ct_kwh_gross, 2)} ct</td>
                        <td className="py-1.5 pr-3 text-right text-text-3">{eur(i.total_net_eur)}</td>
                        <td className="py-1.5 pr-3 text-right">{eur(i.total_gross_eur)}</td>
                        <td className="py-1.5 whitespace-nowrap" style={{ color: tone.color }}>
                          {tone.label}
                          {i.problems > 0 ? ` (${i.problems})` : ""}
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          </Card>

          {report ? (
            <div className="report-row" style={{ "--cols": "7fr 5fr" } as React.CSSProperties}>
              <Card style={{ padding: 16 }}>
                <CardHead
                  title={`Rechnerische Prüfung · ${report.invoice.period_label}`}
                  right={`${computed.filter((f) => f.severity === "ok").length} von ${computed.length} stimmig`}
                />
                <ul className="m-0 mt-1 list-none p-0">
                  {computed.map((f) => (
                    <FindingRow key={f.code} f={f} />
                  ))}
                </ul>
              </Card>
              <Card style={{ padding: 16 }}>
                <CardHead title="Abgleich mit eigenen Daten" right={report.invoice.number} />
                <ul className="m-0 mt-1 list-none p-0">
                  {compared.length ? compared.map((f) => <FindingRow key={f.code} f={f} />) : <Note>Kein Abgleich möglich.</Note>}
                </ul>
                <div className="mt-3 border-t border-line-1 pt-2 text-[12px] text-text-3">
                  Zeitraum {report.invoice.period_start} bis {report.invoice.period_end} ·{" "}
                  Zählerstand {de1(report.invoice.meter_start, 2)} → {de1(report.invoice.meter_end, 2)} kWh
                  {report.invoice.meter_estimated ? " (errechnet)" : " (abgelesen)"}
                </div>
              </Card>
            </div>
          ) : null}
        </>
      ) : loaded && !busy ? (
        <Card style={{ padding: 24 }}>
          <Note>
            Noch keine Rechnung geprüft. Lade eine Tibber-Rechnung als PDF hoch – die Auswertung entsteht dann
            hier und wächst mit jeder weiteren Rechnung.
          </Note>
        </Card>
      ) : null}
    </main>
  );
}
