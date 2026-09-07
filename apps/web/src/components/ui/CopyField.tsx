"use client";

import { useState } from "react";

/** Ein Wert, der zum Kopieren dasteht — mit Knopf, weil Markieren auf dem Tablet mühsam ist.
 *
 *  Fällt die Zwischenablage aus (ältere Browser, unsicherer Kontext), wird der Text stattdessen
 *  markiert: dann tut der Knopf wenigstens den halben Weg, statt still zu versagen. */
export function CopyField({ value, label }: { value: string; label: string }) {
  const [state, setState] = useState<"idle" | "done" | "failed">("idle");

  const copy = async (e: React.MouseEvent<HTMLButtonElement>) => {
    try {
      await navigator.clipboard.writeText(value);
      setState("done");
    } catch {
      const code = e.currentTarget.parentElement?.querySelector("code");
      if (code) {
        const range = document.createRange();
        range.selectNodeContents(code);
        const sel = window.getSelection();
        sel?.removeAllRanges();
        sel?.addRange(range);
      }
      setState("failed");
    }
    setTimeout(() => setState("idle"), 2500);
  };

  return (
    <div className="flex items-start gap-3">
      <code className="mono min-w-0 flex-1 break-all text-[14px] text-text-1">{value}</code>
      <button
        onClick={copy}
        aria-label={`${label} kopieren`}
        className="mono shrink-0 rounded-[3px] border px-2.5 py-1 text-[11px] uppercase tracking-[.08em]"
        style={{
          borderColor: state === "done" ? "var(--amber)" : "var(--line-2)",
          color: state === "done" ? "var(--amber)" : "var(--text-3)",
        }}
      >
        {state === "done" ? "kopiert" : state === "failed" ? "markiert" : "kopieren"}
      </button>
    </div>
  );
}
