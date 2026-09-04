import type { ReactNode } from "react";

export function Card({ children, accent = false, className = "", style }: { children: ReactNode; accent?: boolean; className?: string; style?: React.CSSProperties }) {
  return (
    <section className={`card ${accent ? "card-accent" : ""} ${className}`} style={style}>
      {children}
    </section>
  );
}

export function CardHead({ title, right }: { title: string; right?: ReactNode }) {
  return (
    <div className="flex items-baseline justify-between gap-4">
      <h2 className="kicker m-0">{title}</h2>
      {right ? <div className="text-[12px] text-text-3">{right}</div> : null}
    </div>
  );
}
