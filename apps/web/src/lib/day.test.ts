import { describe, expect, it } from "vitest";
import { istTagIso } from "./day";

describe("istTagIso", () => {
  it.each(["2026-10-17", "2024-02-29"])("nimmt %s an", (s) => expect(istTagIso(s)).toBe(true));
  it.each(["", "today", "2026-13-45", "2026-02-30", "2026-1-7", "Invalid Date", null, undefined])("weist %s zurueck", (s) =>
    expect(istTagIso(s)).toBe(false),
  );
});
