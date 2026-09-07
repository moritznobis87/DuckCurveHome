import type { MetadataRoute } from "next";

/** Diese Anwendung gehört in keine Suchmaschine: sie zeigt den Zustand eines bewohnten Hauses.
 *  Drei Ebenen greifen ineinander – robots.txt, der noindex-Meta-Tag im Layout und der Header
 *  X-Robots-Tag aus next.config.ts. Der Header wirkt auch auf Antworten, die kein HTML sind. */
export default function robots(): MetadataRoute.Robots {
  return { rules: [{ userAgent: "*", disallow: "/" }] };
}
