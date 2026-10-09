# Development workflow

> **Status:** Phase 0 · Proposed. This describes how we work. Tooling named here (CI, hosting) does not exist yet; each item says when it arrives.

## Principles

1. **`main` is always in a releasable state.**
2. **Small, reviewable changes**, merged often.
3. **Few branches, few commits that matter.** No dozens of long-lived branches; no commit-per-keystroke.
4. **Documentation moves with the code** (same pull request).
5. **Decisions are written down once** ([`../DECISIONS.md`](../DECISIONS.md)) so they are not relitigated.

## Branching

```
main
  ▲   (squash-merge via pull request)
  │
feature branches   feat/…  fix/…  docs/…  chore/…  refactor/…  exp/…
```

| Prefix | Use | Lifetime |
|---|---|---|
| `feat/<topic>` | New capability | Days, not weeks |
| `fix/<topic>` | Bug fix (with a regression test) | Hours to days |
| `docs/<topic>` | Documentation only | Short |
| `chore/<topic>` | Tooling, dependencies, config | Short |
| `refactor/<topic>` | Behaviour-preserving restructure | Short |
| `exp/<topic>` | **Experiments.** Disposable; *never merged directly*. If an idea wins, re-implement it cleanly on a `feat/` branch and record what was learned | ≤ 30 days; delete when done |
| `phase-N/<topic>` | A phase's foundational work (e.g. `phase-0/foundation`) | Until the phase PR merges |

Rules:

- **No direct commits to `main`** once the repository is past its bootstrap commit. (The first commit adding the frozen prototype baseline was the unavoidable exception on an empty repository.)
- Branch from the latest `main`; rebase or merge `main` in before opening a PR.
- **Delete branches after merge.**
- Prefer **one branch per logical change.** Don't stack unrelated work.

## Commits

- **Conventional Commits:** `feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`, `perf:`, `build:`, `ci:`. Imperative, ≤ 72 characters in the subject.
- The **body explains why**, not what the diff already shows. Reference the decision (`D-0xx`) when relevant.
- Squash-merge makes each PR **one commit on `main`**, so the PR title is the commit message. Write it well.
- AI-assisted commits carry the `Co-Authored-By` trailer for the assisting model.
- Never commit secrets, `.env` files, large binaries or generated build output.

## Pull requests

- **Small:** aim for under ~400 changed lines excluding generated files and fixtures. Larger changes need a note saying why they can't be split.
- **Template:** `.github/pull_request_template.md` asks for *what and why*, *how it was verified*, *what was not verified*, *docs/decisions updated*, and *screenshots for UI*.
- **Review:** the author self-reviews first. Every PR gets at least one review (the owner, or a second pair of eyes) before merge.
- **Draft PRs** are welcome for early feedback.
- A PR that changes architecture, the schema or the vocabulary of blocks **must** update the relevant document and `DECISIONS.md`.

## Feature development

1. Check the relevant docs and `DECISIONS.md` (see [`ai-development-guidelines.md`](./ai-development-guidelines.md)).
2. For anything non-trivial, write a **short plan** in the PR description or an issue *before* coding.
3. Implement on a `feat/` branch with tests.
4. Open a PR; CI must pass; a preview deployment is generated.
5. Review, address comments, **squash-merge**.
6. Incomplete work that must merge early goes behind a **feature flag**, off by default.

## Bug fixes

1. Reproduce and **write a failing test** first.
2. Fix on a `fix/` branch.
3. PR includes the test; explain the root cause.
4. **Hotfix path** (production broken): branch from `main`, minimal fix, expedited review, deploy. If the cause is not immediately clear, **revert first, diagnose second.**

## Experiments

For spikes and design explorations. They are valuable and cheap, but they are not the product.

- Use `exp/` branches. Time-box them.
- The output is **learning**, written into a PR description, `DECISIONS.md` or `OPEN-QUESTIONS.md`.
- Do not merge experimental code into `main`. Re-implement properly.

## Releases

- **Continuous delivery:** merging to `main` deploys to production once hosting exists (Phase 2), after CI passes.
- Every PR gets a **preview deployment** (arrives with the app scaffold).
- **Tags** mark milestones (`v0.1.0` …) and phase completions (`phase-1-complete`). A short `CHANGELOG.md` summarises user-visible changes (introduced with the first release).
- **Schema or database changes** are released **expand → migrate → contract** so a rollback never strands data.

## Rollback

| Situation | Action |
|---|---|
| Bad deploy | Roll back to the previous deployment in the host (instant), then revert on `main` |
| Bad commit on `main` | `git revert` via a PR (never rewrite `main`) |
| Bad database migration | Forward-fix with a new migration; restore from point-in-time backup only for data loss |
| Bad prompt/model change | Prompt versions and model IDs are configuration: revert the config; evaluation set identifies regressions |
| Bad published experience | Unpublish (soft); history retained; publish a corrected revision |
| Prototype reference | `prototype/v0/` is permanent and untouched |

## Definition of done

A change is done when:

1. **Behaviour** works as described and nothing existing regressed.
2. **Tests** exist for the new behaviour; the suite passes locally and in CI.
3. **Types and lint** pass; no new warnings.
4. **Accessibility** checked: keyboard, focus, contrast, reduced motion, screen-reader labels; automated axe passes.
5. **Responsive** at 375px and 1280px; themes verified.
6. **Performance** is within budgets (see [`../design/design-principles.md`](../design/design-principles.md)).
7. **Security** reviewed for the change: no raw HTML from content, validated inputs, no secrets in code, correct authorisation.
8. **Docs updated:** relevant document, `DECISIONS.md` if a decision was made, `OPEN-QUESTIONS.md` if one was raised, block documentation if a block changed.
9. **No dead code, debug logging or commented-out blocks.**
10. **PR description** states what was verified and what was **not**.
11. **Reviewed and merged** by squash.

For UI work additionally: screenshots (light/dark, mobile/desktop) in the PR. For schema work: fixtures and migration tests. For AI work: evaluation results compared to baseline.

## Testing expectations

| Layer | Expectation |
|---|---|
| **Schema and content** | Every fixture validates; invalid examples are rejected; every migration has tests |
| **Unit** | Pure logic and utilities; fast |
| **Component / block** | Baseline output and interaction; accessibility attributes |
| **Accessibility** | axe on every block × theme; keyboard paths for interactive blocks |
| **End to end** | Critical journeys: read an experience (JS on *and off*), enter via the transition, submit feedback; Studio: interview → draft → preview → approve → publish (from Phase 3) |
| **Visual** | Gallery snapshots at 375 / 1280 per theme |
| **Authorisation** | Row-level security tests: a publisher cannot read or write another's data; AI credentials cannot approve or publish |
| **AI evaluation** | Evaluation set runs on prompt or schema changes; thresholds documented |
| **Parity** | During migration, scripted comparison against `prototype/v0` ([`../architecture/migration-strategy.md`](../architecture/migration-strategy.md)) |

Coverage is a signal, not a target. **Critical paths and boundaries must be tested** regardless of the percentage.

## Continuous integration (arrives with the scaffold)

On every PR: install (locked), lint, type-check, unit tests, build, schema-fixture validation, accessibility tests, a small E2E smoke suite, dependency audit, secret scan. Slower suites (full visual, parity, AI evaluation live runs) run on labels or nightly. **Target:** a PR's feedback in about ten minutes.

## Environments and secrets

- Local, Preview, Production ([`../architecture/architecture-overview.md`](../architecture/architecture-overview.md)).
- `.env.example` lists every variable with a description and *no real values*.
- Secrets live in the host's secret manager, scoped per environment. **Server-only variables are never exposed to the browser.**
- Rotate on suspicion of exposure; the secret scan blocks commits containing recognised patterns.

## Dependency policy

Add a dependency only if it clearly beats writing a small amount of code or using a platform feature. State in the PR *why*, its size, its maintenance state and its licence. Prefer well-maintained, widely used packages. Review upgrade PRs; don't let them pile up.

## Documentation upkeep

- Documents under `/docs` describe **intent**; code describes **reality**. When they diverge, one of them is wrong. Fix it in the same PR.
- Documents carry a **Status** line (Phase 0 draft, Accepted, Superseded).
- Superseded decisions are marked, not deleted.
