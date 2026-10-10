/** Smallest valid experience, plus a tiny illustrative dataset, for schema tests. Not shipped content. */
export function minimalExperience() {
  const steps = [2026, 2027];
  const row = [1, 2];
  const d = (match: string) => [
    { match, category: "Cool", warm: 0, high: 2, low: 1 },
    { match, category: "Cool", warm: 0.5, high: 2, low: 1 },
  ];
  return {
    schemaVersion: 1,
    id: "test-experience",
    slug: "test-experience",
    kind: "data-story",
    title: "Test",
    shortTitle: "Test",
    language: "en",
    summary: "A test experience.",
    theme: "tarn",
    reading: ["deeper"],
    hero: {
      title: "Test",
      intro: ["Intro."],
      actions: [{ label: "Begin", targetSectionId: "one", emphasis: "primary" }],
    },
    sections: [
      {
        id: "one",
        title: "One",
        blocks: [
          { id: "p1", type: "paragraph", content: [{ text: "Hello " }, { text: "world", marks: ["strong"] }, { sourceRef: "src-a" }] },
          {
            id: "chart",
            type: "scrubber-chart",
            datasetId: "ds",
            groupSelector: { label: "Pick" },
            stepControl: { label: "Year" },
            chart: { title: "T", yMin: 0, yMax: 10, yTicks: [0, 5, 10], valueSuffix: "°" },
            legend: { first: [{ text: "First" }], now: [{ text: "Now" }], match: [{ token: "match" }] },
            headline: { atFirstStep: [{ token: "group" }], later: [{ token: "step" }] },
            stats: [{ kind: "high", label: "Hottest" }],
            prediction: {
              question: [{ text: "Which?" }],
              optionsByGroup: { a: ["a", "b"], b: ["a", "b"] },
              correctPrefix: "Yes.",
              wrongPrefix: "No.",
              reveal: [{ token: "match" }],
            },
            themeBinding: "warmth",
          },
        ],
      },
    ],
    sources: [{ id: "src-a", citation: "A source." }],
    datasets: [
      {
        id: "ds",
        title: "Demo",
        unit: "°C",
        illustrative: true,
        provenance: { kind: "illustrative-model", description: "Made up." },
        groups: [{ id: "a", label: "A" }, { id: "b", label: "B" }],
        steps,
        periods: ["Jan", "Feb"],
        values: { a: [row, row], b: [row, row] },
        derived: { a: d("b"), b: d("a") },
      },
    ],
    endnotes: [{ id: "note", type: "data-note", content: [{ text: "Demo data, not a forecast." }] }],
  };
}
