# Open questions

> **Purpose:** questions that **materially affect the product** and that Phase 0 deliberately does *not* answer. Each says why it matters, a leaning where we have one, and when an answer is needed. Answered questions move to [`DECISIONS.md`](./DECISIONS.md).
> **Not here:** implementation details (those are Phase 1 spikes, listed in the architecture docs).

## Product

### Q-01 · What exactly qualifies as an InScapio experience?
- **Why it matters:** defines the schema, curation standard, QA rules and the line between InScapio and a blog. "Whose Body Is It?" is mostly text with light interaction; the climate experience is mostly interaction.
- **Leaning:** a coherent surface/deeper structure, sources, *and* at least one interaction that passes the interaction test. Pure text isn't an experience.
- **Needed by:** Phase 1 (schema), Phase 3 (AI design stage).

### Q-02 · Who is the initial target publisher segment?
- **Why it matters:** determines onboarding, content policy, legal exposure and what "good" looks like. See candidates in [`product/users.md`](./product/users.md).
- **Leaning:** independent domain experts and mission-driven organisations, via direct conversations. **Needs evidence from real publisher conversations.**
- **Needed by:** before Phase 3.

### Q-03 · Do publishers actually want an AI *interview*, or a better starting point from material they already have?
- **Why it matters:** the AI interview is the central workflow thesis. Some publishers may prefer to upload a draft, report or notes and have it restructured.
- **Leaning:** support both entry paths (start from conversation; start from material) feeding the same knowledge-capture step. Test early with real publishers.
- **Needed by:** Phase 3 design.

### Q-04 · Individuals, organisations, or both?
- **Why it matters:** identity, permissions, billing, brand and moderation.
- **Leaning:** individuals first; the data model must not preclude organisations and members.
- **Needed by:** before opening beyond the closed alpha.

### Q-05 · Which experience kinds are MVP?
- **Why it matters:** each kind (explainer, opinion, investigation, data story, deep dive) has different structure, AI prompts, verification burden and legal risk.
- **Leaning:** explainers and opinion pieces first; data stories once datasets are handled; investigations last (highest legal risk).
- **Needed by:** Phase 3.

### Q-06 · Should publishing require approval beyond the publisher?
- **Why it matters:** quality, brand and liability versus publisher autonomy and speed. Principle 5 requires *human* approval; it doesn't say whose.
- **Leaning:** in the closed alpha, an InScapio editorial and policy check before the first publication of each publisher (and always for flagged categories); relax with trust. Needs legal advice.
- **Needed by:** before the first outside publisher.

### Q-07 · What is the content policy for real, identifiable people, minors and open legal matters?
- **Why it matters:** the prototype's "Whose Body Is It?" discusses a specific, recent, open criminal case involving minors. At platform scale this is the highest-severity risk category.
- **Leaning:** an explicit policy, mandatory flags in QA, human review, takedown process, publisher agreement. **Requires legal counsel; not decided here.**
- **Needed by:** before any outside publisher, and before the v0 content is published anywhere new.

## AI

### Q-08 · How much AI-generated content is acceptable, and must it be disclosed?
- **Why it matters:** trust (Principle 7), regulation, and the product's identity.
- **Leaning:** disclose AI assistance by default; measure and display the proportion of AI-originated text per revision; never AI-originated facts.
- **Needed by:** Phase 3.

### Q-09 · Where is the boundary between the publisher's voice and AI editing?
- **Why it matters:** the core promise of Principle 4. Too conservative and the AI isn't useful; too liberal and publishers lose ownership.
- **Leaning:** generous with structure, conservative with wording, edits as diffs. Tune from real publisher feedback.
- **Needed by:** Phase 3.

## Market and growth

### Q-10 · Do readers come to InScapio, or through publishers' own audiences?
- **Why it matters:** decides how much to invest in discovery, topics, search and the home page versus share previews and embeds.
- **Leaning:** assume publisher-driven and share-driven; keep discovery curated and light.
- **Needed by:** before Phase 5.

### Q-11 · Hosted only on InScapio, or also embeddable/portable on publishers' own sites?
- **Why it matters:** publishers often want their audience on their domain; affects SEO ownership, architecture (embeds, domains) and the value proposition.
- **Leaning:** hosted-only for the MVP; revisit with publisher feedback.
- **Needed by:** Phase 4.

### Q-12 · Which languages?
- **Why it matters:** an India-first audience implies Hindi and regional languages. It affects fonts, AI interview quality, typography and schema (`language`, variants).
- **Leaning:** English for the MVP; the schema carries `language` from day one; evaluate Hindi after.
- **Needed by:** before Phase 5.

### Q-13 · What monetisation model should eventually be tested, and when?
- **Why it matters:** shapes what to build into publishers' and readers' accounts, and who InScapio's customer is (publishers paying for tools, readers paying publishers, platform subscription, sponsorship).
- **Leaning:** none in the MVP. Test publisher willingness to pay for the *creation* tool first; reader subscriptions only after the content loop works.
- **Needed by:** after Phase 4.

## Ownership and capacity

### Q-14 · Can publishers export and own their content?
- **Why it matters:** trust and adoption. Experiences are structured JSON, so exporting is cheap; the harder question is the *experience* outside InScapio.
- **Leaning:** yes, export of content and sources; licence terms to be set.
- **Needed by:** before the first outside publisher.

### Q-15 · What are the team size, timeline and AI budget?
- **Why it matters:** the phasing in [`product/mvp-scope.md`](./product/mvp-scope.md) assumes a small team; AI cost per experience could be material.
- **Needed by:** before committing to Phase 2 dates.
