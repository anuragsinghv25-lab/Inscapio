# AI development guidelines

> **Status:** Phase 0 · Proposed. For **any AI agent** (Claude or otherwise) working in this repository, and for the humans directing them. A short pointer to this file lives in the root [`CLAUDE.md`](../../CLAUDE.md) so it loads automatically in Claude Code.

This repository is developed collaboratively between a human owner and AI. The risk of that arrangement is **fast, plausible, unrequested change**. These rules exist to keep the work correct, reviewable and consistent with decisions already made.

## The loop

```
Understand → Inspect repository → Read relevant docs → Plan → Implement → Test → Review → Report
```

Not optional, and not only for large tasks.

| Step | What it means |
|---|---|
| **Understand** | Restate the request in your own words. Identify what is *in* and *out* of scope. If something material is ambiguous and a wrong guess is costly, ask; otherwise choose the most reasonable reading, say which, and continue. |
| **Inspect repository** | Look at what actually exists: the files, the branch, recent history, tests. Don't assume. |
| **Read relevant documentation** | At minimum: this file, the **relevant** architecture/design doc, and [`../DECISIONS.md`](../DECISIONS.md). See the reading list below. |
| **Plan** | For anything beyond a trivial change, state the plan *before* editing: files to touch, approach, risks, what you will not change. For changes to architecture, schema or the block vocabulary: **propose and wait**, don't implement. |
| **Implement** | The smallest change that satisfies the request. |
| **Test** | Run the checks. Add tests for new behaviour. |
| **Review** | Read your own diff as a reviewer. Remove anything unrelated. |
| **Report** | Say what changed, how it was verified, **what was not verified**, and any decisions or open questions raised. |

## Reading list (by task)

| If the task touches… | Read first |
|---|---|
| Anything | [`../../README.md`](../../README.md), [`../DECISIONS.md`](../DECISIONS.md), [`../product/principles.md`](../product/principles.md) |
| A block, the schema, the renderer | [`../architecture/content-architecture.md`](../architecture/content-architecture.md), [`../ux/content-model.md`](../ux/content-model.md) |
| UI, styling, motion | [`../design/design-principles.md`](../design/design-principles.md), [`../design/design-system-direction.md`](../design/design-system-direction.md), [`../design/current-design-audit.md`](../design/current-design-audit.md) |
| AI features or prompts | [`../architecture/ai-architecture.md`](../architecture/ai-architecture.md) |
| Data, auth, security | [`../architecture/backend-architecture.md`](../architecture/backend-architecture.md) |
| Migrating v0 | [`../architecture/migration-strategy.md`](../architecture/migration-strategy.md) |
| Scope questions | [`../product/mvp-scope.md`](../product/mvp-scope.md), [`../OPEN-QUESTIONS.md`](../OPEN-QUESTIONS.md) |

## Hard rules

An AI agent must **not**:

1. **Rewrite unrelated code**, or reformat files it was not asked to touch.
2. **Change architecture without explanation.** Anything that contradicts a recorded decision requires proposing a *new* decision first.
3. **Delete existing features** or behaviour without explicit approval.
4. **Introduce dependencies unnecessarily.** Justify every one (what, why, size, maintenance, licence).
5. **Generate giant monolithic files.** Split by responsibility.
6. **Hard-code data that belongs in the content layer** (experience text, datasets, sources).
7. **Generate arbitrary HTML, CSS or JavaScript for AI-created experiences.** AI-created experiences are *structured content* conforming to the schema. This applies to the product's AI features and to any tooling you write for them.
8. **Make broad visual changes when asked for a specific one.** A request to adjust a button is not a request to retheme the page.
9. **Edit anything under `prototype/v0/`.** It is the frozen baseline.
10. **Commit secrets**, credentials or `.env` files, or print them in output.
11. **Push to `main`, force-push, rewrite published history, or merge** without being asked to.
12. **Silently skip, weaken or delete a failing test or lint rule** to get green.
13. **Claim something works without having run it.** If a check could not be run, say so.
14. **Expand scope.** Notice other problems, *report* them, don't fix them uninvited.

Every meaningful change must **preserve existing functionality** unless the task is explicitly to change it.

## Decisions and questions

- Before proposing an approach, **check `DECISIONS.md`.** If a decision covers it, follow it. If you think it is wrong, say so with reasons and propose a superseding decision; don't quietly deviate.
- When a task forces a new significant decision (technology, boundary, data shape), **record it** in `DECISIONS.md` in the same PR using the template there.
- When a product question blocks you and is materially consequential, add it to `OPEN-QUESTIONS.md` rather than answering it by implication.

## Working with the schema and blocks

- The Zod schema in `content/schema/` is the contract. Change it only through the process in [`../architecture/content-architecture.md`](../architecture/content-architecture.md): additive change, or a versioned breaking change with a migration and tests.
- **Adding a block** follows the checklist in that document (interaction test, schema, baseline, accessibility contract, fixture, tests, gallery, AI catalogue).
- When building the product's AI features: output is **schema-validated data**; prompts live in the repository, versioned; model IDs come from configuration; evaluation sets are updated with the prompts.

## Prompts for in-product AI

Treat these as code:

- Single responsibility per prompt; named by capability.
- Untrusted material (publisher documents, pasted text, web pages) is **delimited and declared as data**.
- Instruct the model to ask or flag rather than invent. **Never ask it to generate statistics, quotations or URLs.**
- Include the schema and a small number of canonical examples drawn from fixtures.
- Add an evaluation case for every defect found in practice.

## Communication

### When starting a task
One or two sentences: what you understood and what you will do. If you made an assumption, state it.

### When finishing a task, report
1. **What changed** (files, in plain words).
2. **How it was verified** (commands run and results).
3. **What was not verified**, and why.
4. **Decisions made** (and whether logged) and **questions raised**.
5. **Anything noticed but left alone.**

Be plain about uncertainty. A short honest report is better than a long confident one.

### Pull request description
Use the template in `.github/pull_request_template.md`. Link the relevant docs and decision IDs.

## Quality bar for AI-written code

Same as human-written code ([`coding-principles.md`](./coding-principles.md), [`development-workflow.md`](./development-workflow.md)). Specifically watch for failure modes common to generated code:

| Failure mode | Guard |
|---|---|
| Plausible but unverified APIs | Check the installed version's docs; run it |
| Over-engineering | Smallest change that works; no speculative abstractions |
| Duplicated logic instead of reuse | Search the repository first |
| Tests that assert implementation, not behaviour | Test observable outcomes |
| Silent catch-and-continue | Handle or propagate deliberately |
| Inventing content, numbers or sources | Never; ask the owner |
| Style drift | Use tokens and existing components |
| Dropping accessibility | Check the block's accessibility contract |

## Stop and ask when

- The change would contradict a decision or a principle.
- It would delete or substantially alter existing behaviour.
- It requires a new dependency, a new service, or a schema change.
- It touches authentication, authorisation, payments, personal data or the publish path.
- Requirements are contradictory, or the request disagrees with the material provided.
- You discover the repository's state is not what the task assumed.

## Session handoff

Sessions don't share memory. **The repository is the memory.** At the end of a session, leave it so the next one can start cold:

- Decisions in `DECISIONS.md`; open questions in `OPEN-QUESTIONS.md`.
- Docs updated to match the code.
- The final report states the current phase and the recommended next step.

## For the human directing the work

Short, specific instructions work best: *what outcome, which files or area, what must not change.* Name the phase. If you want a visual or structural change, say how broad it should be. If you want AI to go beyond the stated scope, say so explicitly. If a result is wrong, point to the principle or decision it breaks; that is exactly what the documents are for.
