# Reader journey

> **Status:** Phase 0 · Proposed. Stages are grounded in what the prototype does today; gaps are called out. Reader accounts and everything that depends on them are **Later**.

## Is the proposed flow right?

The brief proposed:

```
Discover → Understand → Explore → Go Deeper → Finish → Follow / Subscribe / Share
```

As a *mental model of progression* it is useful. As a literal *linear flow* it is slightly wrong, for three reasons:

1. **Most readers will not start at "Discover".** They arrive from a shared link, mid-journey, already holding a reason to care. The first screen of an experience has to do the job of discovery (hook) *and* orientation.
2. **"Go Deeper" is not a stage; it is a mode.** In the prototype it is a toggle available from the start and everywhere. A reader may switch it on in the first minute, or never.
3. **"Understand" and "Explore" are interleaved,** not sequential. The best moments in the prototype are where the reader predicts, then explores, then understands.

A more accurate model:

```
 Arrive ──► Orient ──► ┌──────────────────────────────┐ ──► Finish ──► Continue
 (link, home,          │  Explore ⇄ Understand         │     (feel done)  (next experience,
  topic)  (hook,       │      ⇅ Go deeper (optional)   │                   share, follow)
          promise)     └──────────────────────────────┘
```

## Stages, mapped to the prototype

| Stage | What the reader needs | What v0 does today | Gap |
|---|---|---|---|
| **Arrive** | A reason to continue within seconds, from any entry point | Home: the *Read ↔ Explore* strip shows one idea both ways. Experience pages open with a full-screen title and a promise ("Pick a city, drag time forward…"). | Experiences share one set of social metadata. |
| **Orient** | What is this, how long, how do I use it | Hero sentence; "Read it simply. Tap *Deeper* whenever you want…" | No time estimate or chapter outline. |
| **Explore** | Immediate, low-friction interaction that earns its place | City picker, time slider, predict-then-reveal; classify quiz, flip cards, steppers | Interaction state is lost on reload; no resume. |
| **Understand** | The idea lands; claims are honest | Plain-language leads, callout statements, "what can be true / what does not follow" | Sources are in a footer, not tied to claims. |
| **Go deeper** | Context, evidence and hard questions on demand | Global *Deeper* toggle; dashed "Going deeper" blocks | Deeper state not remembered; no per-block deeper. |
| **Finish** | A sense of completion | Thin progress line; final chapter and feedback form | No explicit end state or summary. |
| **Continue** | A next step that fits | Share button; feedback | No "next experience". No follow. |

## Journeys that matter

### A. The shared link (the dominant path)

1. Reader taps a link in a chat, on a phone, over mobile data.
2. The experience opens to a full-screen hook within a second or two, with text readable before any interaction code has loaded.
3. They scroll or tap *Begin*. They interact. Maybe they switch on *Deeper*.
4. They finish. The end state offers one or two next steps. They share it or leave.

**Design consequences:** the reading path works without JavaScript; the first screen is self-explanatory; nothing blocks on sign-in; the end state is designed.

### B. The browser (home → explore → experience)

Home presents a few experiences as live fragments. Entering one uses the prototype's *circular reveal from the tap point*, an effective signature moment that signals "you are stepping inside". Keyboard and reduced-motion users get an equivalent without the animation (already implemented).

### C. The returning reader *(Later)*

Follows a publisher or topic, receives an email or notification, returns to a new experience. Requires accounts and email infrastructure. Not in the MVP.

### D. The supporter *(Future)*

Hits a premium experience, understands what is free versus paid, subscribes. Requires entitlements and payments. Not in the MVP, and its design should be informed by what the first three paths teach us.

## Reader-facing surfaces

| Surface | Purpose | MVP | Later / Future |
|---|---|---|---|
| **Homepage** | Say what InScapio is; showcase a few experiences as live samples | ✔ | Personalised for signed-in readers |
| **Explore / discovery** | Browse by topic and publisher | ✔ curated | Search, related, recommendations |
| **Topic / channel pages** | A subject's framing and its experiences | ✔ simple | Follow topic; editorial intro |
| **Experience page** | The product | ✔ | Resume, notes, highlights |
| **Publisher profile** | Who made this; their other experiences | ✔ simple | Follow; subscribe |
| **Reader account** | Preferences, subscriptions | ✘ | **Later** |
| **Following** | Publishers and topics followed | ✘ | **Later** |
| **Subscriptions** | Paid access to a publisher | ✘ | **Future** |
| **Saved content** | Return to something later | ✘ | **Later** |
| **Notifications** | Updates from followed publishers | ✘ | **Later**, email first |

**Why no reader accounts in the MVP:** reading is the proof, and the cheapest reader experience to get right is the one with no sign-in. Accounts add privacy, security and compliance obligations (including under India's DPDP Act; see [`../architecture/backend-architecture.md`](../architecture/backend-architecture.md)) before we know whether anyone wants them. The prototype already follows this: *"One minute. No account."*

## Feedback and share

Both exist in v0 and are worth keeping:

- **Feedback:** four structured questions (interest, difference from a normal article, would share, would return) and three free-text prompts.
- **Share:** native share sheet or copy link.

**Important gap:** feedback today is saved to `localStorage` and copied to the clipboard for the reader to paste to "whoever sent you this link". **It never reaches the team.** Storing it properly is an MVP requirement and the first real source of reader signal.

## Reader experience quality bar

- Works on a mid-range Android phone over a slow connection.
- Reading path usable without JavaScript.
- Keyboard and screen-reader complete; respects `prefers-reduced-motion` and, where it makes sense, `prefers-color-scheme`.
- No required sign-in, no interstitials, no scroll-jacking.
- Honest about data and uncertainty, always.

See [`../design/design-principles.md`](../design/design-principles.md).
