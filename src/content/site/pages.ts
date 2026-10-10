/**
 * Copy for the platform's own pages (home, about). Source: prototype/v0/index.html home and about views.
 * Kept out of components so wording can change without touching code. Experience content lives in
 * src/content/experiences/ and is schema-validated; this is ordinary site copy.
 */
export const HOME = {
  title: { light: "Don’t just read it.", strong: "Explore it." },
  sub: "Where knowledge becomes an experience.",
  strip: {
    label: "The same idea, first as text and then as something you can explore",
    readHeading: "What will your city feel like in 2070?",
    readParagraphs: [
      "Cities are warming. In the demo model used on this site, Madrid’s year in 2070 starts to resemble a different city’s: summers are hotter, winters are milder, and the gap between the seasons grows.",
      "Climatologists describe this with classifications built from temperature and rainfall. A place keeps its label until the pattern of its year moves far enough to earn another.",
    ],
    chartLabel: "Madrid's monthly temperature today compared with 2070 in the demo model",
    sliderLabel: "Drag to move from reading to exploring",
    readEnd: "Read",
    exploreEnd: "Explore",
    valueText: { reading: "Reading", exploring: "Exploring", mixed: "Part read, part explored" },
    legend: { today: "today", future: "in 2070" },
  },
  analogue: { mid: " in 2070 feels like ", end: " does today." },
  rooms: {
    body: {
      heading: "Whose Body Is It?",
      description: "Safety, honour, gender, respect and the boundaries we place around other people’s lives.",
      enter: "Enter experience →",
      prompt: "Six layers sit behind one harm. Tap a layer to open it.",
    },
    climate: {
      heading: "What will your city feel like in 2070?",
      description: "Explore how a changing climate could transform the places we know.",
      enter: "Enter experience →",
      prompt: "Pick a city.",
      idle: "Where will it be in 2070?",
      note: "Illustrative data, not a forecast.",
    },
  },
  what: { heading: "InScapio is an interactive knowledge platform where ideas become experiences you can explore.", link: "What is InScapio?" },
  closing: { heading: "Some ideas are worth more than a scroll.", cta: "Explore InScapio →" },
  wallCities: ["london", "madrid", "cairo", "delhi", "mumbai", "chicago", "tokyo", "moscow", "sydney", "lagos", "new-york", "singapore"],
} as const;

export const ABOUT = {
  title: "What is InScapio?",
  prose: [
    { text: "The web is full of things worth knowing." },
    { text: "Most of them arrive the same way: a headline, a paragraph, another paragraph, a scroll." },
    { text: "What if an idea could be explored?", emphasis: true },
    { text: "What if understanding meant moving, choosing, comparing and going deeper only when you want to?" },
    { text: "That is what InScapio is trying out: a small set of experiences, built to find out whether ideas land better when you can step inside them." },
  ],
  deeper: {
    lead: "Every experience has a deeper layer. It stays closed until you ask for it.",
    open: "Go deeper",
    close: "Back to simple",
    body: "This is what a deeper layer looks like: the context, the sources and the harder questions that would crowd a first pass. Open it where you are curious. Skip it where you are not.",
  },
  finale: { light: "Don’t just read it.", strong: "Explore it." },
  link: "See the experiences",
} as const;

export const FOOTER = {
  name: "InScapio",
  note: "An early-stage prototype. The experiences are works in progress, and some of the data in them is illustrative.",
  domain: "inscapio.in",
} as const;

export const NAV = { explore: "Explore", about: "About" } as const;

export const NOT_FOUND = {
  title: "Page not found",
  body: "That page doesn’t exist, or it has moved.",
  link: "Back to InScapio",
} as const;
