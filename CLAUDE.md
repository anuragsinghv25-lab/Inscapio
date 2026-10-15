# InScapio: instructions for AI agents

InScapio is an AI-native publishing platform for interactive knowledge experiences. The repository holds: documentation, a frozen prototype, a Next.js app (content schema + renderer + design tokens) that renders both v0 experiences from validated **files**, and a **local-only Supabase database layer** in `supabase/` (Stage 3.1 identity core and 3.2 experience core: migrations, pgTAP, concurrency and API tests, run in CI on the real local stack). The app has **no database client, sign-in, studio or AI yet**; the public site does not read the database; no hosted Supabase project is connected and nothing here changes production. Stage 3.3 (auth integration) has not started and waits for owner decisions (`docs/architecture/stage-3-0-decision-brief.md`). Commands: see `README.md` (Setup).

## Before you do anything

1. Read `README.md`, `docs/README.md` and `docs/DECISIONS.md`.
2. Read the document relevant to your task (list in `docs/engineering/ai-development-guidelines.md`).
3. Inspect the repository's actual state. Don't assume.

## Workflow

Understand → Inspect → Read docs → Plan → Implement → Test → Review → Report.
For anything non-trivial, state your plan first. For changes to architecture, the schema or the block vocabulary: **propose, don't implement.**

## Never

- Edit anything under `prototype/v0/` (frozen baseline).
- Edit a merged migration in `supabase/migrations/` (add a new forward-only one), connect or change a hosted Supabase project, or give any AI-oriented database role a secret or `service_role` credential.
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
