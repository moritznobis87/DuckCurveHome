import Link from "next/link";
import type { ReactNode } from "react";

export function Card({ children, accent = false, className = "", style, href, ariaLabel }: { children: ReactNode; accent?: boolean; className?: string; style?: React.CSSProperties; href?: string; ariaLabel?: string }) {
  const cls = `card ${accent ? "card-accent" : ""} ${className}`;
  if (href) {
    return (
      <Link href={href} aria-label={ariaLabel} className={`${cls} card-link`} style={{ ...style, color: "inherit", textDecoration: "none" }}>
        {children}
      </Link>
    );
  }
  return (
    <section className={cls} style={style}>
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
