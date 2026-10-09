# Documentation index

**Source-of-truth rule:** the prototype ([`../prototype/v0/index.html`](../prototype/v0/index.html)) is the source of truth for **what currently exists**; these documents are the source of truth for **where InScapio is going**. When they disagree, the difference is intentional or a bug, and should be recorded.

Every document carries a **Status** line. Phase 0 documents are *drafts pending owner review* unless a decision in [`DECISIONS.md`](./DECISIONS.md) says `Accepted`.

| Area | Document | Answers |
|---|---|---|
| **Start here** | [`DECISIONS.md`](./DECISIONS.md) | What has been decided, and why? |
| | [`OPEN-QUESTIONS.md`](./OPEN-QUESTIONS.md) | What hasn't? |
| **Product** | [`product/vision.md`](./product/vision.md) | What are we building and why? |
| | [`product/users.md`](./product/users.md) | For whom? |
| | [`product/positioning.md`](./product/positioning.md) | How are we different, and what could go wrong? |
| | [`product/principles.md`](./product/principles.md) | What rules settle arguments? |
| | [`product/mvp-scope.md`](./product/mvp-scope.md) | What do we build first, and not build? |
| **UX** | [`ux/information-architecture.md`](./ux/information-architecture.md) | Pages, URLs, navigation |
| | [`ux/reader-journey.md`](./ux/reader-journey.md) | The reader's path |
| | [`ux/publisher-journey.md`](./ux/publisher-journey.md) | The publisher's path and the AI's role |
| | [`ux/content-model.md`](./ux/content-model.md) | Entities, and the content/presentation/behaviour split |
| **Design** | [`design/current-design-audit.md`](./design/current-design-audit.md) | What the prototype contains |
| | [`design/design-principles.md`](./design/design-principles.md) | How we design: type, motion, interaction, accessibility |
| | [`design/design-system-direction.md`](./design/design-system-direction.md) | Where the design system goes |
| **Architecture** | [`architecture/architecture-overview.md`](./architecture/architecture-overview.md) | The big picture and stack choices |
| | [`architecture/frontend-architecture.md`](./architecture/frontend-architecture.md) | Rendering, structure, state |
| | [`architecture/backend-architecture.md`](./architecture/backend-architecture.md) | Data, auth, jobs, security, privacy |
| | [`architecture/ai-architecture.md`](./architecture/ai-architecture.md) | AI capabilities, guardrails, evaluation |
| | [`architecture/content-architecture.md`](./architecture/content-architecture.md) | Schema, blocks, renderer contract |
| | [`architecture/migration-strategy.md`](./architecture/migration-strategy.md) | Prototype → production |
| **Engineering** | [`engineering/development-workflow.md`](./engineering/development-workflow.md) | Git, PRs, releases, definition of done |
| | [`engineering/coding-principles.md`](./engineering/coding-principles.md) | Conventions |
| | [`engineering/ai-development-guidelines.md`](./engineering/ai-development-guidelines.md) | How AI agents work here |

`migration-strategy.md` is the one document beyond the requested set; the migration plan was an explicit requirement and needed a home.
