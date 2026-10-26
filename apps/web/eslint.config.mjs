import js from "@eslint/js";
import tseslint from "typescript-eslint";
import nextPlugin from "@next/eslint-plugin-next";

export default tseslint.config(
  { ignores: [".next/**", "node_modules/**", "next-env.d.ts", "src/lib/api/types.ts"] },
  js.configs.recommended,
  ...tseslint.configs.recommended,
  // Der Service Worker laeuft nicht im Fenster, sondern in einem eigenen Gueltigkeitsbereich mit
  // `self`, `clients` und `registration`. Ohne diese Zeile haelt eslint jede davon fuer einen
  // Tippfehler.
  {
    files: ["public/sw.js"],
    languageOptions: { globals: { self: "readonly", clients: "readonly", registration: "readonly" } },
  },
  {
    files: ["**/*.{ts,tsx}"],
    plugins: { "@next/next": nextPlugin },
    rules: {
      ...nextPlugin.configs.recommended.rules,
      "@typescript-eslint/no-unused-vars": ["error", { argsIgnorePattern: "^_" }],
      "@typescript-eslint/consistent-type-imports": "error",
    },
  },
);
