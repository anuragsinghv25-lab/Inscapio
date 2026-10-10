# InScapio: instructions for AI agents

InScapio is an AI-native publishing platform for interactive knowledge experiences. The repository is in **Phase 1**: documentation, a frozen prototype, and a small Next.js app (content schema + renderer + design tokens) that renders both v0 experiences from validated data. No backend, auth, studio or AI yet. Commands: see `README.md` (Setup).

## Before you do anything

1. Read `README.md`, `docs/README.md` and `docs/DECISIONS.md`.
2. Read the document relevant to your task (list in `docs/engineering/ai-development-guidelines.md`).
3. Inspect the repository's actual state. Don't assume.

## Workflow

Understand → Inspect → Read docs → Plan → Implement → Test → Review → Report.
For anything non-trivial, state your plan first. For changes to architecture, the schema or the block vocabulary: **propose, don't implement.**

## Never

- Edit anything under `prototype/v0/` (frozen baseline).
- Generate arbitrary HTML/CSS/JS for AI-created experiences. They are **schema-validated structured content**.
- Hard-code experience content or data in components.
- Rewrite unrelated code, change architecture unexplained, delete features without approval, or add dependencies casually.
- Make broad visual changes when asked for a specific one.
- Push to `main`, force-push, or merge unless asked. Work on a branch; open a PR.
- Commit secrets. Claim something works without running it.

## Always

- Preserve existing behaviour unless asked to change it.
- Keep files small and single-purpose.
- Update docs and `docs/DECISIONS.md` in the same PR as the change.
- Report: what changed, how it was verified, what was **not** verified, decisions and questions raised.

Full rules: `docs/engineering/ai-development-guidelines.md`.
