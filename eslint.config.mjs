import nextCoreWebVitals from "eslint-config-next/core-web-vitals";
import nextTypescript from "eslint-config-next/typescript";

const config = [
  { ignores: [".next/**", "node_modules/**", "prototype/**", "next-env.d.ts", "playwright-report/**", "test-results/**", "coverage/**"] },
  ...nextCoreWebVitals,
  ...nextTypescript,
  {
    rules: {
      // Principle 6 / docs/engineering/coding-principles.md §7: content never becomes markup.
      "react/no-danger": "error",
      "no-eval": "error",
      "no-implied-eval": "error",
      "no-new-func": "error",
      "@typescript-eslint/no-explicit-any": "error",
    },
  },
  {
    // Build-time tooling that reads the frozen prototype and generates data. Never shipped.
    files: ["scripts/**/*.mjs"],
    rules: { "no-new-func": "off", "no-implied-eval": "off" },
  },
];

export default config;
