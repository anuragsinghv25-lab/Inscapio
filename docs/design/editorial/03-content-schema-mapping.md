# 03 · Content-schema and interactive-block mapping

**Status:** Proposal only. Per `CLAUDE.md`, changes to the schema or block vocabulary are *proposed, not implemented*. No file under `src/content/schema/` or `supabase/` was touched.

## 1. What exists (read from the repository)

- `src/content/schema/experience.ts`: strict Zod document. `kind` is `"explainer" | "data-story"`. A document has `hero`, `sections[]` (each with `blocks[]`, 1–40), `sources[]`, `datasets[]`, `endnotes[]`, `theme`, `reading` controls. Unknown keys are rejected (`strictObject`).
- Closed block vocabulary (15): `paragraph, callout, card, fact-row, compare-table, resource-box, source-list, data-note, deeper, accordion, stepper, claims, classify, selector-content, scrubber-chart`. Unknown `type` is rejected. Text is plain text only; URLs must be https.
- `Source` = `{ id, citation, url?, accessedAt? }`. Blocks refer to sources by id; unresolved references fail validation (`references.ts`).
- Database (local only): `experiences.kind` and `published_experiences.kind` have `CHECK (kind in ('explainer','data-story'))`; a SQL **shape gate** checks structure only, full validation is a future validator service (D-056); revisions are append-only; the public projection is `published_experiences` (with `published_at`, `topic_slugs`); `topics` and `experience_topics` exist; revision notes are private (≤280 characters); `admin_takedown` and `set_experience_hold` exist.

## 2. Mapping: story needs → existing blocks → change required

| Story need (prototype) | Reuse an existing block? | Proposal |
|---|---|---|
| Paragraph text | `paragraph` | Reuse. **Add optional `epistemic` label** (see §3). |
| Key facts strip | `fact-row` | Reuse. |
| Comparison table ("Who bears the cost?") | `compare-table` | Reuse as is (columns/rows). First column acts as row header; add `rowHeaders: true` flag for correct `<th scope="row">` (small change). |
| Aside / "why it matters" | `callout`, `card` | Reuse. |
| Sources list | `source-list` + `sources[]` | Reuse; **extend `Source`** (see §4). |
| "Illustrative data" note | `data-note` | Reuse for text; add a document-level `illustrative: true` flag that the renderer shows next to charts. |
| Expandable detail | `deeper`, `accordion` | Reuse where a timeline is unnecessary. |
| Step-through explanation | `stepper` | Could render the cause chain, but a static numbered chain reads better and prints; **new `cause-chain`** recommended. |
| Reader "what people say" | `claims` | Reuse unchanged (different purpose from epistemic labels). |
| Quiz / classification | `classify` | Not used in news. |
| Choose-an-option content | `selector-content` | Not used in the prototype; usable later for "pick a country". |
| Chart with scrubbing | `scrubber-chart` | **Cannot be reused**: it is climate-specific (groups, years, analogue sentence, theme response). |
| Briefing (3 labelled claims) | none | **New `briefing`** |
| Timeline (dated, filterable, expandable) | none (accordion is close) | **New `timeline`** |
| Stakeholders and stated positions | none (`card` is close) | **New `stakeholders`** |
| Cause-and-effect chain | none | **New `cause-chain`** |
| Generic line/bar chart + table alternative | none | **New `chart`** |
| Scenario set (hypothetical) | none | **New `scenarios`** |
| Open questions | none (no list block) | **New `open-questions`** (small) |
| Update / correction log | none | **Not authored in content.** Derived from the revision history (see §5). |
| Related stories | none | Document field `related: Id[]` of slugs (resolved at read time; unpublished ones dropped). |
| India implications | `callout` / `card` | No new block; a section whose `region: "IN"` tag styles it. |

**Net new blocks: 6** (`briefing`, `timeline`, `stakeholders`, `cause-chain`, `chart`, `scenarios`) **plus 1 small** (`open-questions`). Everything stays a closed, declarative, text-only vocabulary; nothing executable.

## 3. Epistemic labels (new, applies to paragraphs, briefing claims, timeline events, stakeholder positions, cause-chain steps)

```
epistemic: "established" | "attributed" | "contested" | "analysis" | "scenario" | "unresolved"
```

Rules (enforced by the validator, not by the model's goodwill):

- Required on every `briefing` claim, `timeline` event, `stakeholders` position and `cause-chain` step; optional on ordinary paragraphs (default `analysis` is *not* assumed: unlabeled prose is rendered without a label).
- `established` and `attributed` and `contested` require ≥1 `sourceId`.
- `attributed` requires `attributedTo` (who said it).
- `scenario` content must sit inside a `scenarios` block or carry `scenario` explicitly.
- Display: text + glyph + border style; colour is secondary (WCAG 1.4.1).

## 4. Proposed `Source` extension

```
{ id, citation, url?, accessedAt?,            // existing
  sourceKind: "official" | "industry" | "media" | "research" | "statement" | "own-analysis",
  publisher?: ShortText,
  publishedAt?: IsoDate,
  archiveUrl?: HttpsUrl,
  offlineReason?: ShortText }                 // required when no url
```

Validation: each source needs `url` or `offlineReason`; a warning (not an error) if no `archiveUrl`.

## 5. Story metadata and public change log

**Document fields (proposed):** `kind: "story"`, `topic` (one of the topic slugs), `regions?: string[]`, `illustrative?: boolean`, `dek` (reuses `summary`), `related?: Id[]`. The existing `hero` is kept (title, intro, optional actions).

**Not in the document (stored by the database, shown by the page):** first-published time, last-updated time, lead flag/position, public change log, tombstone reason. The document is the *content*; these are *publication facts* and should not be authored by an AI.

**Needed in the database (proposed forward-only migration; none written):**

| Need | Today | Proposal |
|---|---|---|
| New `kind` | CHECK allows only `explainer`, `data-story`; shape gate hard-codes it | Add `'story'` to both CHECKs and the shape function; keep older rows valid |
| First-published and updated times | single `published_at` on the projection (to confirm exact semantics) | Add `first_published_at`, `last_updated_at` |
| Lead / featured | none | Add `featured_rank smallint null` (admin-only setter) |
| Public change log | revision notes private, ≤280 | New append-only `public_changes (experience_id, at, type: updated|corrected|unpublished, public_note, revision_id)`; readable by anon; insert only through the publish/update functions |
| Tombstone | takedown has internal reason fields | Public-safe `unpublish_public_reason` (category + text) on the projection or view; **no private reason exposed** |
| AI disclosure | revisions have `author_kind` (`human`/`ai`) | Display a method note site-wide; per-story disclosure flag to be decided (Q-53) |

## 6. Example (illustrative only, not valid against today's schema)

```json
{
  "schemaVersion": 2,
  "kind": "story",
  "slug": "karesh-strait-talks",
  "topic": "conflict-security",
  "illustrative": true,
  "title": "Ceasefire talks over the Karesh Strait stall on a 12-nautical-mile question",
  "summary": "Both delegations say they want a deal. A single definition decides whether it is signed.",
  "sources": [{ "id": "s1", "citation": "Joint statement of the regional council", "sourceKind": "official",
                "url": "https://example.org/statement", "publishedAt": "2026-10-19", "accessedAt": "2026-10-22" }],
  "sections": [
    { "id": "briefing", "title": "The briefing", "blocks": [
      { "id": "b1", "type": "briefing", "claims": [
        { "epistemic": "established", "text": "Talks ended Wednesday without a signed text.", "sourceIds": ["s1"] },
        { "epistemic": "contested", "text": "The sides define territorial waters differently.", "sourceIds": ["s1"] },
        { "epistemic": "unresolved", "text": "Whether a monitoring mission will be accepted." } ] } ] },
    { "id": "timeline", "title": "Timeline", "blocks": [
      { "id": "t1", "type": "timeline", "events": [
        { "date": "2026-10-19", "title": "Talks open", "detail": "…", "epistemic": "established", "sourceIds": ["s1"] } ] } ] }
  ]
}
```

(All names and values are invented. Field names are proposals.)

## 7. Limits to impose (suggested)

`briefing` 3–5 claims; `timeline` ≤24 events; `stakeholders` ≤8; `chart` ≤3 series and ≤24 points with `unit`, `illustrative`, and a mandatory data table; `scenarios` 2–4 with a visible hypothetical flag and no probabilities unless sourced; each text field keeps the existing safe-string rules.

## 8. Conflicts and decisions this raises

- Adding a `kind` and six blocks is a **schema version bump** (`schemaVersion` 2) and a **new forward-only migration**; both require owner approval (CLAUDE.md "propose, don't implement").
- The validator service (D-056) must know the new vocabulary; without it the SQL shape gate only checks structure.
- Whether `draft → ready` is a status or a UI label: today statuses are defined in the 3.2 migration; "Ready for review" in the prototype is proposed as a UI label unless the owner wants a status.
- Q-28 / Q-16: whether *Whose Body Is It?* may appear on a news front page remains open.
