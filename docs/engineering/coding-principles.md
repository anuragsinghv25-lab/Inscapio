# Coding principles

> **Status:** Phase 0 · Proposed. Conventions for the production application. The prototype at `prototype/v0/` is exempt and must not be edited.

Each rule exists for a reason. Where a reason is the prototype's own experience, it is stated.

## 1. Content, presentation and behaviour are separate

This is the repository's central rule (Principle 6).

- **Content** is data, validated by the schema. **Never** put experience text, data or sources in component code.
- **Presentation** comes from design tokens. **Never** put raw colours, sizes or durations in components.
- **Behaviour** is a block's declared parameters interpreted by the block's component.

*Why:* In v0, the same six-layer content is written once and rendered by two separate UIs, and "Whose Body Is It?" keeps its arguments in JavaScript arrays. That is fine for a prototype and is what stops an AI from being able to produce experiences safely.

## 2. Small, single-purpose modules

- A file does one thing. As a guide: components under ~200 lines, modules under ~300. Exceeding it is a prompt to split, not a hard rule.
- **No giant monolithic files.** If a file needs a table of contents, it needs splitting.
- Prefer composition over configuration. Prefer many small functions over deep conditionals.
- Co-locate what changes together: a block's schema, component, styles, tests and fixture live in one folder.

## 3. TypeScript, strictly

- `strict` on. **No `any`**; use `unknown` and narrow. No non-null assertions without a comment explaining the invariant.
- **Parse, don't trust.** Validate external data (requests, database JSON, AI output, environment) with the schema at the boundary and use typed values inside.
- Derive types from schemas rather than writing them twice.
- Exhaustive `switch` over discriminated unions (`type`), enforced by the compiler.

## 4. Components

- **Server components by default.** Add `"use client"` only to the smallest interactive leaf.
- Props are typed and minimal. No components that accept `className` overrides to escape the design system; accept **named variants** instead.
- Presentational components do not fetch data. Features do.
- Every interactive component implements its **accessibility contract**: roles, keyboard, focus, announcements, reduced motion.
- Every block has a **baseline** rendering that works without JavaScript.
- No inline `style` except to pass a CSS custom property (such as a section accent token).

## 5. Styling

- CSS Modules with tokens (`var(--…)`). **Raw values are bugs.**
- Mobile-first; fluid sizing with `clamp()` and `minmax()`.
- Animate only composited properties (`transform`, `opacity`, `clip-path`). Every animation has a reduced-motion behaviour.
- No global styles beyond reset, tokens and base typography.

## 6. Data access and server code

- Database access only through the **repository layer**; no queries in components or route handlers.
- **Server-only modules** are marked as such and linted so they cannot be imported by client code.
- **Parameterised queries only.**
- Authorisation is enforced in the database (RLS) *and* checked in code.

## 7. Security rules (non-negotiable)

- **No `dangerouslySetInnerHTML` or `innerHTML`** for anything derived from content, users or AI. A lint rule bans them; exceptions need a security review.
- No secrets in the repository or the client bundle.
- Validate and limit every input. Allowlist URLs and media origins.
- AI output is untrusted until validated.
- Never log personal data or full AI prompts containing publisher material without the retention policy permitting it.

*Why:* v0 builds interface strings with `innerHTML`. Safe for constants, dangerous for publisher content.

## 8. Errors

- Handle errors deliberately; never swallow them. Return typed results at boundaries where failure is expected (validation, AI calls).
- A failing block **degrades to its baseline** and reports; it does not take the page down.
- User-facing messages are plain and actionable. Internal details go to logs.
- Saving the publisher's work comes **before** any operation that might fail, especially AI calls.

## 9. Dependencies

Follow the policy in [`development-workflow.md`](./development-workflow.md): justify, minimise, review. Prefer the platform (CSS, `<details>`, native form controls) to a library. Avoid heavy chart, animation or UI-kit dependencies by default.

## 10. Naming and structure

| Thing | Convention |
|---|---|
| Directories, files | `kebab-case` (components may be `PascalCase.tsx`) |
| Components, types | `PascalCase` |
| Functions, variables | `camelCase` |
| Constants | `SCREAMING_SNAKE_CASE` only for true constants |
| Block `type` strings | `kebab-case`, singular nouns (`stepper`, `scrubber-chart`) |
| CSS custom properties | `--role-name` (`--color-ink`, `--space-gutter`), by role not value |
| Tests | `*.test.ts(x)`; E2E `*.spec.ts` |
| Branches / commits | See the workflow document |

## 11. Comments and documentation

- Code should say *what*; comments say **why**, especially for non-obvious constraints (accessibility decisions, workarounds, security reasons).
- No commented-out code. No TODOs without an issue reference.
- Public modules (`content/`, `renderer/`, block folders) carry a short README or header describing purpose, inputs and invariants.

## 12. Testing conventions

- Tests describe behaviour: *"rejects a dataset without provenance"*, not *"test validator"*.
- Arrange–act–assert; one concept per test; **no logic in tests**.
- Fixtures are real, canonical experiences, not toy data. The prototype's content is the first fixture set.
- Tests must be deterministic. AI calls are recorded or mocked in CI.
- A bug fix lands with the test that failed.

## 13. Performance

- Treat budgets as requirements ([`../design/design-principles.md`](../design/design-principles.md)).
- Lazy-load interactive islands; keep reading-only pages free of client JavaScript.
- Avoid layout thrash and unbounded listeners; one passive, throttled scroll handler (as v0 does) rather than many.
- Measure before optimising; record the measurement in the PR.

## 14. Accessibility

- Semantic HTML first; ARIA only when HTML cannot express it.
- Every interactive element is keyboard operable with a visible focus state.
- Don't convey meaning by colour alone. Provide text alternatives, including a data table for each chart.
- Respect `prefers-reduced-motion` and `prefers-color-scheme`.

## 15. Things we do not do

- Hard-code content or data in components.
- Add a block, style or dependency "just in case".
- Generate arbitrary HTML for AI-created experiences.
- Fix a bug by disabling a test or a lint rule.
- Mix unrelated changes in one PR.
- Edit `prototype/v0/`.
