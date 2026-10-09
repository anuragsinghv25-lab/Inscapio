# Current prototype audit (InScapio Prototype v0)

> **Status:** Phase 0 · Factual inventory of what exists today.
> **Subject:** [`/prototype/v0/index.html`](../../prototype/v0/index.html), 793 lines, 75,960 bytes, SHA-256 `d7c21eac…6061fa`. The file is frozen and unmodified.
> **Method:** full read of the source, plus running it in headless Chromium at 1280×800 and 375×740 to check routes, interactions, overflow, console output and reduced-motion behaviour, and computing WCAG contrast ratios from the declared colours. Line references are to the frozen file.

This document is the **source of truth for what currently exists**. [`design-principles.md`](./design-principles.md) and [`design-system-direction.md`](./design-system-direction.md) say where it should go.

## How to read this audit

The prototype set out to **test whether ideas land better when a reader can step inside them** (its own About page: *"a small set of experiences, built to find out whether ideas land better when you can step inside them"*). It is a single self-contained file by design. It is judged here on whether it does *that*, not on whether it is production architecture. Where it falls short of a production system, that is recorded as a **migration consideration**, not as a flaw.

**Verdict in brief:** it succeeds at its purpose. It has a distinctive visual identity, a coherent set of reader interactions that each earn their place, and a notably high accessibility baseline for a prototype. Its limits are the expected ones for a single file: content, data, logic and styling are interwoven, feedback never leaves the reader's device, and URLs cannot be shared with correct previews.

---

## 1. Inventory

### 1.1 Views and routes

| Route (hash) | View id | Notes |
|---|---|---|
| `#/` and anything unrecognised | `home` | Default |
| `#/explore` | `home` | Same view; scrolls to `#rooms` |
| `#/about` | `about` | |
| `#/experiences/climate` | `cl` | Alias `#/climate` |
| `#/experiences/whose-body-is-it` | `xp1` | Alias `#/body` |

Four views, one router (lines 610–639). Verified: all routes and aliases resolve; document title updates per view; no horizontal overflow on any view at 375px or 1280px.

### 1.2 Content and interaction counts (verified in browser)

| Where | Item | Count |
|---|---|---|
| Home | "Rooms" (featured experiences) | 2 |
| Home | Expandable "layer" bands | 6 |
| Home | City-wall buttons | 12 |
| Home | Read ↔ Explore strip | 1 |
| Climate | Cities | 20 |
| Climate | "Deeper" notes | 2 |
| Whose Body | Chapters | 12 |
| Whose Body | "Deeper" blocks | 7 |
| Whose Body | Root-cause layers | 6 |
| Whose Body | Honour-ladder steps / culture-ladder steps | 6 / 5 |
| Whose Body | Safety-or-blame statements | 6 |
| Whose Body | Claim-and-response cards | 16 (3 filter themes + all) |
| Whose Body | "Easy to miss" notes | 11 |
| Whose Body | "What you can do" personas | 7 |
| Both | Feedback questions | 4 choice (two 1–5 scales, two Yes/Maybe/No) + 3 free-text |

### 1.3 Reusable interaction patterns found

These matter more than the pages: they are the seeds of the block vocabulary.

| # | Pattern | Where | Notes |
|---|---|---|---|
| 1 | **Read ↔ Explore wipe** | Home hero | One idea shown as text and as a chart; a slider wipes between them. Auto-plays once, then yields to the reader. |
| 2 | **Deeper (progressive disclosure)** | Both experiences, About | A view-level toggle revealing dashed-border "Going deeper" blocks. Default closed. |
| 3 | **Expandable layers** | Home bands; Whose Body ch. 3 | One content set, two UIs (coloured bands vs buttons). |
| 4 | **Selector → computed answer** | Home city wall | Pick a city, get a derived sentence. |
| 5 | **Predict, then reveal** | Climate | Choose which city it will resemble, *then* the slider animates to 2070. |
| 6 | **Scrubber chart** | Climate | Year slider drives a monthly-temperature chart, stats and a colour shift. |
| 7 | **Stepper (cumulative reveal)** | Whose Body ch. 4, 8 | Each step highlights all prior steps and reveals its note. |
| 8 | **Claim and response cards with filters** | Whose Body ch. 7 | Tap to flip; chips filter by theme. |
| 9 | **Classify quiz** | Whose Body ch. 6 | Binary classification, per-item feedback, final score. |
| 10 | **Selector → content (persona)** | Whose Body ch. 12 | |
| 11 | **Comparison table** | Whose Body ch. 6 (deeper) | Claim / what can be true / what does not follow. |
| 12 | **Callout / pull statement** | Both | "say" blocks, large display type. |
| 13 | **Info card** | Whose Body | |
| 14 | **Resource box** | Whose Body ch. 12 | Indian helpline numbers. |
| 15 | **Sources and data note** | Footers; climate "Demo data, not a forecast" | Honesty as a component. |
| 16 | **Reading controls** | Whose Body bar | Text size (15–26px), light/dark, Deeper. |
| 17 | **Progress line** | Both experiences | One rAF-throttled passive scroll handler. |
| 18 | **Circular-reveal entrance** | Entering an experience | `clip-path` circle from the tap point; keyboard falls back to centre. |
| 19 | **Data-bound theming** | Climate | One CSS variable `--w` (0→1) interpolates background and accent with `color-mix()`. |
| 20 | **Feedback and share** | Both experiences | Structured feedback; native share or copy link. |

---

## 2. Views

### 2.1 Home (`#home`, lines 317–383)

- **Purpose:** state the idea, prove it in the first screen, offer two experiences, explain InScapio.
- **Layout:** sequence of full-width bands: *opening* (huge two-weight title, subtitle, Read↔Explore strip, slider) → *room 1* → *room 2* → *what is InScapio* → *closing* (cobalt) → footer. Rooms alternate a text column with a live interactive fragment, reversing order on desktop.
- **Interaction:** the strip auto-wipes 6%→58% after 900ms over 1.7s, then follows the slider (reduced motion: static at 50%). Bands expand. The city wall computes "*X* in 2070 feels like *Y* does today."
- **Content type:** marketing and orientation, plus *live samples* of the two experiences. Home content is hand-written in HTML and shares its data (`C`, `LAYERS`) with the experiences.
- **Navigation:** absolutely-positioned wordmark and *Explore* / *About*. Entering an experience hides site nav.
- **Strengths:** the opening *demonstrates* the promise instead of describing it. The title uses weight and width contrast (`Don't just read it.` at weight 250, width 75; `Explore it.` at 800, width 100). Each room is a working sample, not a thumbnail.
- **Weaknesses:** featured experiences are hard-coded in markup; Madrid and the 12 wall cities are fixed; no experience metadata (length, topic, publisher).
- **Migration:** home becomes a data-driven page assembled from published experiences. Keep the strip, the rooms-with-live-fragment pattern and the closing. Note that each "live fragment" requires an experience to expose a *teaser* block; this is a requirement on the content model.

### 2.2 About (`#about`, lines 386–404)

- **Purpose:** explain the philosophy and demonstrate "go deeper" in miniature.
- **Layout:** dark, single column, prose at large size, one amber question ("What if an idea could be explored?"), a deeper-layer demo, a sign-off echoing the title.
- **Interaction:** *Go deeper* button toggles a hidden paragraph (`aria-expanded`, label swaps to *Back to simple*).
- **Strengths:** concise, shows rather than tells, uses the product's own pattern.
- **Weaknesses:** none material.
- **Migration:** straightforward static page; its demo is a reusable *Deeper* block.

### 2.3 Climate experience "What will your city feel like in 2070?" (`#cl`, lines 407–440)

- **Purpose:** make a 2.5 °C abstraction concrete by letting the reader see which city theirs resembles.
- **Layout:** fixed bar (back, title, *Deeper*, progress); full-height opening; short conceptual section (three questions defining a climate); the main interactive section; a closing statement with demo-data note; feedback.
- **Interaction:** pick one of 20 cities → *guess first* (three options) → the slider animates to 2070 (1.5s ease-out) → chart, three stats and a simplified climate type update → the whole page *warms* via `--w`. The reader can then scrub manually.
- **Content type:** parametric data visualisation. Temperatures come from a sinusoidal model, with warming scaled by latitude.
- **Navigation:** linear; *Begin* jumps to the first section.
- **Strengths:** the strongest expression of the product thesis. Prediction before reveal is pedagogically sound. The colour shift is a single variable. The "Demo data, not a forecast" note names real sources and says exactly what is invented.
- **Weaknesses:** the model and the data are code, not content. The "feels like" matching is deliberately crude: with the default model, London in 2070 matches Madrid, and Madrid matches Tokyo. That is fine for an illustration and is labelled as one, but it means this experience is **not expressible as pure content** without precomputing results. The chart is exposed to assistive tech only as an `aria-label` summary; there is no data-table alternative. The three options in the guess step use a deterministic pseudo-shuffle, not randomness.
- **Migration:** the key test of the block model. See [`../architecture/migration-strategy.md`](../architecture/migration-strategy.md): MVP plan is a *Dataset* with precomputed values plus a *scrubber chart* block; a constrained *parametric model* block is Future.

### 2.4 "Whose Body Is It?" (`#xp1`, lines 443–579)

- **Purpose:** a "clear-eyed book" on safety, honour, gender and respect that holds several true things at once, structured to be read simply or deeply.
- **Layout:** fixed bar (back, title, Deeper, A+, A−, theme) with a progress line; hero; twelve chapters, each with a coloured top rule, a tag, a heading, a lead and content; sources footer; feedback.
- **Interaction:** the pattern list above: layers, ladders, flip cards with filters, classify quiz, persona picker, tables, text-size and theme controls, Deeper.
- **Content type:** argued editorial text, nearly all of it. Interaction supports the arguments rather than replacing them.
- **Navigation:** linear with in-page anchors (*Begin*, *Jump to the arguments*).
- **Strengths:** a good demonstration that **an experience can be mostly text and still benefit from interaction**. Each chapter has its own accent, giving long text a sense of place. Honest framing: it separates *risk from responsibility*, states what a case can and cannot show, warns that open cases can change, and lists sources. Reading controls (size, theme) are rare and valuable.
- **Weaknesses:** content is split between HTML (chapter prose) and JavaScript arrays (`A`, `Q`, `M`, `W`, `LAYERS`, steps). It originated as a standalone template and is *re-skinned* by an override layer (lines 276–305), so it carries its own palette separate from InScapio's tokens. Theme, text size and Deeper state are not remembered. Chapter-accent *text* on the dark theme has low contrast (see §3.8). The deeper layer cites a specific recent criminal case involving minors; at platform scale that kind of content is exactly what needs the editorial and legal review process described in [`../product/positioning.md`](../product/positioning.md).
- **Migration:** the clearest source of block types (patterns 3, 7–13). Its content should be extracted into the content model nearly one-to-one.

---

## 3. Design language

### 3.1 Fonts

| Role | Family | Use |
|---|---|---|
| Display / UI | **Bricolage Grotesque** (variable: optical size 12–96, width 75–100, weight 200–800) | Headings, labels, buttons, numbers |
| Body | **Literata** (variable serif, optical size 7–72; roman and italic) | Running text |

Both are loaded from Google Fonts with `display=swap` and `preconnect`. Fallbacks: `ui-sans-serif, Helvetica Neue…` and `Georgia…`. The page remains legible without them. **It is the only external dependency.**

### 3.2 Colour

**Core tokens (lines 25–26):**

| Token | Hex | Role |
|---|---|---|
| `--fog` | `#E3E9EA` | Page background |
| `--paper` | `#F5F8F8` | Light panels |
| `--deep` | `#102C33` | Ink; dark background |
| `--mid` | `#4A646B` | Secondary text |
| `--tarn` | `#0B2F38` | Dark teal background |
| `--cobalt` / `--cobalt-d` | `#2447D6` / `#1A36A6` | Primary accent, links, focus on light |
| `--amber` | `#F2A900` | Accent on dark, progress, focus on dark, pressed state |

**Climate theme:** `#7FD6E8` (cool accent) → `#FF8A4C` (hot accent); background `#0B2F38` → `#3A1A12`, driven by `--w`.

**"Whose Body Is It?" palette:** light `#f7f6fb` / ink `#1d1b3a` / mute `#5a5878`; dark `#13122a` / `#f1effc` / `#b4b1d3`; hero `#10242B`. **Nine chapter accents:** `#c8374f`, `#17787A`, `#6a3fb5`, `#a85f00`, `#1d6fb8`, `#8a2a6e`, `#2f7d4f`, `#d6336c`, `#3b5bdb`. The hero closes on a six-colour rule.

**Favicon:** `#102C33` square with a white bar and an amber dot, a lowercase *i*.

### 3.3 Spacing and layout

Fluid, not stepped. Gutter `--g: clamp(18px, 4.5vw, 56px)`. Vertical rhythm uses very large `clamp()` ranges (rooms: 72px→168px). Container widths vary by view (1400 home, 1100 about/climate, 760 reading column). Prose measure is capped near `34em`. Layouts use CSS grid with `minmax(0,1fr)` and `auto-fit`. Safe-area insets are applied on all fixed or edge elements.

### 3.4 Typography hierarchy

| Level | Spec |
|---|---|
| Hero title | Display, `clamp(3rem, 12.5vw, 10.5rem)`, line-height .9, tracking −.045em, two weights |
| Room / section title | Display 800, `clamp(2.7rem, 8.4vw, 7.4rem)`, line-height .92 |
| Experience H2 | Display 800, `clamp(2rem, 6vw, 3.6–3.8rem)`, line-height ≈1 |
| Lead | Display 500, `clamp(1.25rem, 2.6vw, 1.6rem)` |
| Callout | Display 600–800 at lead size, in a ruled box |
| Body | Literata 400, `1.0625rem` / 1.65 (user-adjustable 15–26px in Whose Body) |
| Labels, buttons | Display 600–700, `1rem` |
| Data numerals | Display 800, `tabular-nums` for the large year |

### 3.5 Buttons and controls

- **Primary** (`.enter`, `.cta`, `.go`, `.btn`): rectangular, 2px radius, 52–56px tall, 700 weight display type; inverts on dark backgrounds; hover → cobalt (light) or amber (dark).
- **Chips / toggles** (`aria-pressed`): 3px radius, 1px translucent border, pressed state fills **amber with near-black text**.
- **Range inputs:** custom track (4px) and a square cobalt thumb (28px) with a light border; native range on the climate page, with `accent-color: amber`.
- **Controls meet 44–48px targets** consistently.

### 3.6 Cards and surfaces

Flat. **No shadows.** Separation by borders, a coloured 3px rule, or background change. Cards: 4px radius, 1px line. Callouts: 3–6px accent rule on the left. Deeper blocks: dashed border (Whose Body) or amber left rule (climate/About) plus a *Going deeper* label.

### 3.7 Motion

| Motion | Spec | Reduced motion |
|---|---|---|
| Entering an experience | `clip-path` circle from tap point, .75s `cubic-bezier(.7,0,.2,1)` | Removed (global kill-switch) |
| Hero wipe | 900ms delay, 1.7s ease-out cubic, once | Static at 50% |
| Year tween | 1.5s ease-out cubic | Jumps to 2070 |
| Accordion | `grid-template-rows` .3s | Removed |
| Background / theme | .3–.5s colour transition | Removed |
| Smooth scroll | `scroll-behavior: smooth` | `auto` |

Motion is *meaningful* throughout: it signals transition between states or shows change over time. There is no ambient decoration.

### 3.8 Accessibility (as implemented)

**Done well:**
- A global `prefers-reduced-motion` kill-switch **plus** matching JavaScript checks.
- Visible `:focus-visible` rings, colour-switched on dark surfaces.
- `aria-pressed`, `aria-expanded`, `aria-controls`, `aria-live` regions for computed results, `aria-valuetext` on sliders, dynamic `aria-label` on charts.
- Focus moves to the new view's `<h1>` on navigation (not on first load).
- Collapsed content is `visibility: hidden`, so it cannot be tabbed into.
- 44–48px touch targets; semantic landmarks (`nav`, `main`, `article`, `section[aria-labelledby]`).
- `lang="en"`, `viewport-fit=cover`.

**Contrast (computed, WCAG ratios):**
- Core tokens are strong: ink on fog 11.96:1, amber on tarn 7.07:1, white on cobalt 7.13:1, secondary text on paper 5.91:1.
- White on each of the nine chapter accents passes 4.5:1 (lowest: `#d6336c`, 4.62).
- **Gap:** in the *dark* theme of Whose Body, chapter-accent *text* on `#13122a` falls to 2.3–3.96:1 (e.g. `#8a2a6e` 2.30, `#6a3fb5` 2.61). It affects the small "Going deeper" label and the "They say:" prefix (ratios are computed against the page background; the card background is slightly lighter, so the prefix is marginally lower). Borders and fills are unaffected.

**Gaps to close:**
- No skip-to-content link.
- Charts have only a summary label; no data-table alternative.
- Theme, text size and Deeper are not persisted; home and About do not respond to `prefers-color-scheme`.
- Some interactive text is injected with `innerHTML`; fine for hard-coded content, *unsafe for publisher content* (see §4).

### 3.9 Responsive behaviour

Fluid type and spacing via `clamp()`; breakpoints at 560, 760, 899/900 and 1200px; the city rail is a horizontal scroller on small screens and wraps on desktop; tables scroll horizontally; the chart redraws on resize (`ResizeObserver`) with a taller aspect below 560px; the top bar in Whose Body hides the title on very narrow screens. Verified: no horizontal overflow at 375px or 1280px on any view.

---

## 4. Technical implementation

| Aspect | Implementation | Production consideration |
|---|---|---|
| **Packaging** | One file: CSS (~280 lines), HTML, one `<script>` (~210 lines). No build, no package manager. The file opens with a small wrapper document containing a second full `<!doctype html>` document, and ends with a stray `</body></html>`. It appears to be an export artefact; browsers tolerate it. | Normalise on migration. The baseline file is kept byte-identical. |
| **Routing** | Hash router; `ROUTES` map; `hashchange` listener; skips in-page anchors; sets `body[data-v]`, title, focus, scroll; paths mirror future clean URLs. | Move to real paths with server rendering. Per-route metadata. |
| **JavaScript architecture** | Strict mode; global helpers `$`, `$$`, `E`; one IIFE per feature; shared globals `C` (cities) and `LAYERS`; model functions; a `FB()` factory for feedback. | Components with typed props; shared logic as tested modules. |
| **Data handling** | All content and data hard-coded in the file. Climate "model" is a handful of pure functions over a 20-city array. | Content and data in the content model; model outputs precomputed or declared. |
| **State management** | DOM is the state: `aria-pressed`, `classList`, closure variables. No persistence apart from feedback. | Explicit state per block; persisted reader preferences. |
| **Rendering** | `innerHTML` strings built from constants; SVG charts built as strings. | Safe typed rendering. **Must not `innerHTML` publisher content.** |
| **Feedback** | `FB()` builds the form; answers go to `localStorage.inscapio` and are copied to the clipboard "to paste to whoever sent you this link". Verified: in a browser without clipboard access it saves locally only. | **Nothing reaches the team.** Real collection is an MVP requirement. |
| **Share** | `navigator.share` or clipboard copy of `location.href#/…`. | Fragment URLs are ignored by crawlers and link unfurlers, so shared links preview as the generic site card. Clean URLs and per-experience metadata are needed. |
| **Dependencies** | Google Fonts only. Verified: the page makes no other external request. | Self-host fonts for performance and privacy. |
| **SEO / metadata** | Single set of title, description, OG and Twitter tags; canonical `https://inscapio.in/`; title updates per view in JS. | Server-rendered, per-experience metadata. |
| **Styles** | Global CSS, scoped by `#xp1` / `.cl` prefixes; ~70 inline `style` attributes at runtime (mostly per-chapter `--c` accents); some class-name overlap (`.sub`, `.dk`/`.cl` both a class and a view). | Token-driven, scoped styles. The per-section `--c` accent is a good pattern worth keeping as a *presentation token*. |
| **Browser support** | `color-mix()` guarded with `@supports` in climate, **unguarded** in Whose Body (`.say`). `clip-path`, `:is()`, `ResizeObserver`, `100svh`. | Define a support policy. |
| **Console** | Clean. The only error in testing was the font request I blocked on purpose. | |

### Hard-coded data worth naming

`C` (20 cities: name, latitude, mean temperature, seasonal amplitude, dryness flag; warming `dT` is derived as 1.5–3.0 °C by latitude, *an invented illustrative rule*); `LAYERS` (6); `Q` (6 statements); `A` (16 claims); `M` (11); `W` (7 personas); two stepper arrays; the wall's 12 city names; Madrid for the home headline.

---

## 5. Summary

### What to preserve

- The product line and philosophy; the two-weight display title.
- The visual identity: type pairing, colour tokens, flat/bordered surfaces, large confident scale.
- The interaction patterns above; **predict-then-reveal**, **Deeper**, and the **circular entrance** especially.
- Honesty components (data notes, sources, "what this can and cannot show").
- The accessibility baseline, including reduced motion and 44–48px targets.
- The path scheme `/experiences/<slug>`.

### What to extract

- All content and data into the content model; chapter accents into presentation tokens; each interaction into a block with declarative parameters; the feedback and share logic into platform services.

### What to rewrite

- The router (hash → paths), rendering (strings → components), state, and feedback delivery.

### What to redesign deliberately (not now)

- The two visual systems into one; the end-of-experience state; discovery beyond two hard-coded rooms.

### What to fix when the time comes

Contrast on dark-theme accent text; skip link; chart data-table alternative; persisted preferences; per-route metadata; a guard on `color-mix()`; self-hosted fonts.

Details of how this migrates are in [`../architecture/migration-strategy.md`](../architecture/migration-strategy.md).
