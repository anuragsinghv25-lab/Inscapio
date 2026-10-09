# Content model (conceptual)

> **Status:** Phase 0 · Conceptual. This defines *what things exist and how they relate*, deliberately **not** a database schema. The technical treatment (block taxonomy, schema versioning, storage, renderer) is in [`../architecture/content-architecture.md`](../architecture/content-architecture.md).

## Why this is the most important Phase 0 decision

If InScapio content is represented independently of the front end, the AI can generate *data* instead of *code*, the renderer can improve every experience at once, and experiences can be re-rendered, previewed, versioned and checked for quality. If it is not, we end up with the architecture the brief warns against: *Publisher → AI → arbitrary HTML*.

The prototype is the evidence. Today, "Whose Body Is It?" holds its text partly in HTML and partly in JavaScript arrays (`A`, `Q`, `M`, `W`, `LAYERS`), the climate experience holds its data and *model* in script, and the **same six-layer content (`LAYERS`) is rendered twice with two different UIs**: as coloured bands on the home page and as buttons in chapter 3. That is a content model waiting to be extracted: one piece of content, two presentations.

## The three separations

Every piece of an experience is described in three independent layers.

| Layer | Answers | Owned by | Example (from v0) |
|---|---|---|---|
| **Content** | *What is being said?* | Publisher (with AI assistance, human-approved) | The text of the six root-cause layers; the 16 claims and their responses; the city temperature data; the sources |
| **Presentation** | *How does it look?* | InScapio design system; chosen from a **closed set** | Section accent colour; light/dark "mood"; layout variant; whether a callout is a pull statement or a note |
| **Interaction behaviour** | *What can the reader do, and how does it respond?* | InScapio renderer; configured by **declarative parameters** | "Expand one layer at a time", "classify each statement as safety advice or blame and give feedback per item", "scrub time 2026→2070" |

### Rules

1. **Content is meaningful on its own.** Strip all styling and all JavaScript, and the content layer still reads as a coherent document (the *no-JS reading path*). It is also what search engines, screen readers and AI QA consume.
2. **Presentation is never freeform.** No raw CSS, colours or HTML in content. The AI and the publisher choose among named options (a theme, an accent from a limited palette, a layout variant).
3. **Behaviour is declared, not coded.** An interaction is a type plus parameters. The renderer owns the code. No scripts, ever, in content.
4. **Any layer can change without the others.** A new design system version restyles every experience. A new interaction implementation upgrades every use of that interaction. A publisher's edit never touches code.

## Entities

```
Publisher ──< Experience >── Topic        (many-to-many)
                │
                ├──< Revision ──< Section ──< Block ──┬─ Interaction (declarative)
                │                                      ├─ Source (0..n)
                │                                      └─ Media / Dataset (0..n)
                │
                ├──  Draft           (the working, unapproved head)
                └──< Publication     (a Revision made public)

InterviewSession ──< KnowledgeItem ─ referenced by Blocks (provenance)
Reader ──< Follow / Subscription / Saved   (Later)
Feedback, AnalyticsEvent                   (attached to Publications)
```

### Definitions

| Entity | What it is | Notes |
|---|---|---|
| **Publisher** | The person (later also organisation) who authors and is accountable for experiences | MVP: individual. Model must not preclude organisations and members. |
| **Reader** | Someone who consumes experiences | MVP: anonymous, no record. Later: account with follows, saves, subscriptions. |
| **Topic** | A curated subject grouping | Curated by InScapio at first; publishers *propose* topics later. |
| **Experience** | The unit of publication, and **the name for what the brief calls a "Story"** (see decision below) | Has a *kind* (explainer, opinion, investigation, data story, deep dive …), a publisher, topics, and a lifecycle. |
| **Section** | A coherent chunk (a "chapter") | Carries presentation hints such as accent and mood. Ordered. |
| **Block** | The atomic, typed unit of content | Text, callout, accordion, stepper, claim-and-response, classify quiz, comparison table, chart, source note, … Each has *content*, optional *interaction* parameters and a *depth* of `surface` or `deeper`. |
| **Interaction** | Declarative parameters for a block's behaviour | Not a free-standing entity; it belongs to a block. Examples: `classify`, `stepper`, `scrubber`, `predict-then-reveal`. |
| **Source** | A citation: what, who, where, when, how reliable | Attaches to blocks (and, Later, to specific claims). Includes access date and a type (primary, report, news, dataset, expert). |
| **Media** | An image or other asset | Alt text, credit and licence are **required**, not optional. |
| **Dataset** | Tabular data used by a chart | With units, provenance and a flag for *illustrative* data. The climate experience's "Demo data, not a forecast" becomes a required label. |
| **KnowledgeItem** | A discrete statement captured from the publisher in the interview | Claim, example, definition, data point, source. Links blocks back to *what the publisher actually said*. |
| **InterviewSession** | The AI conversation | Durable, resumable, retained as provenance. |
| **Draft** | The mutable working state of an experience | Never public. |
| **Revision** | An **immutable** snapshot of an experience's content | Created on save points, before AI edits, and on approval. Supports diff and restore. |
| **Publication** | A Revision made public at a URL | Records who approved it and when. Can be unpublished or superseded, but the history remains. |
| **Feedback / AnalyticsEvent** | Reader signal | Tied to a Publication. Privacy-light. |

## Decision: "Story" and "Experience"

The brief lists both. Keeping both invites ambiguity: two names for one thing. **Proposal: one entity, `Experience`.** "Story" is a *kind* of experience (a narrative one), not a separate record.

- *Cost:* if we ever want one body of knowledge expressed as several formats (a 3-minute explorable and a deep dive), a single entity does not say so.
- *Mitigation:* that relationship can be added later as a link between experiences without a data migration.
- Recorded in [`../DECISIONS.md`](../DECISIONS.md) (D-007) and raised in [`../OPEN-QUESTIONS.md`](../OPEN-QUESTIONS.md).

## Lifecycle

```
         ┌──────────── restore ────────────┐
         ▼                                  │
 Draft ──► Revision (immutable) ──► Approved ──► Published ──► Unpublished
   ▲            │                      ▲  (publisher only)        (history retained)
   └── edit ────┘                      │
                              QA findings resolved
```

- **AI can write to Draft and create Revisions marked `ai`.** It can never set `Approved` or `Published`.
- **A Publication points at one Revision.** Editing afterward creates a new Revision; publishing it creates a new Publication or supersedes the old.
- **Unpublishing is soft.** The URL stays reserved; the record stays.

## Illustration

Using the prototype's "safety advice or blame?" interaction, expressed as the three layers. *Illustrative shape only; the real schema is in [`../architecture/content-architecture.md`](../architecture/content-architecture.md).*

```jsonc
{
  "type": "classify",
  "depth": "surface",

  // CONTENT: what is said
  "prompt": "Is this fair safety advice, or victim-blaming?",
  "categories": [
    { "id": "safety", "label": "Safety advice" },
    { "id": "blame",  "label": "Blame" }
  ],
  "items": [
    { "text": "Share your live location with a friend when you travel late.",
      "answer": "safety",
      "feedback": "An offer of practical help, and it puts no blame on anyone." },
    { "text": "What did she expect, dressed like that?",
      "answer": "blame",
      "feedback": "Clothes are never consent, and this moves guilt to the victim." }
  ],
  "closing": "The same words can be care or blame depending on who they punish.",

  // PRESENTATION: from a closed set
  "presentation": { "variant": "card", "accent": "teal" },

  // INTERACTION BEHAVIOUR: declarative parameters
  "behaviour": { "reveal": "after-each", "showScore": true }
}
```

In v0 the same content is a JavaScript array `Q` plus a hand-written `showQ()` function. Extracting it changes nothing a reader sees, and it is exactly what lets an AI *produce* this block safely.

## What this model deliberately leaves out (for now)

Comments, ratings, collections, reader-created content, multi-language variants, A/B variants, scheduled publication, and organisation hierarchies. Each should be addable without redesigning the above.
