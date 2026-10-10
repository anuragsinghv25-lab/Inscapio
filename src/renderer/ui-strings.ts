/**
 * Platform UI strings: wording that belongs to the application chrome, not to any experience.
 * Experience wording lives in content. Keeping these in one module is the seam for localisation later.
 */
export const UI = {
  siteName: "InScapio",
  skipToContent: "Skip to content",
  backToHome: "Back to InScapio home",
  experienceControls: "Experience controls",
  deeper: "Deeper",
  simple: "Simple",
  deeperTitle: "Show deeper notes",
  goingDeeper: "Going deeper",
  biggerText: "Bigger text",
  smallerText: "Smaller text",
  switchTheme: "Switch between light and dark",
  blockFailed: "This part could not be shown.",
  correct: "Correct.",
  notQuite: "Not quite.",
  questionOf: (n: number, total: number) => `Question ${n} of ${total}`,
  scoreLine: (score: number, total: number) => `You scored ${score} of ${total}.`,
  noJsMatches: (group: string, step: string | number, match: string) => `${group} in ${step} feels like ${match} does today.`,
  chartLabel: (group: string, title: string, hiLabel: string, hi0: string, step: string | number, hi: string) =>
    `${group}: ${title}. ${hiLabel} today ${hi0} degrees, in ${step} ${hi} degrees.`,
  feedback: {
    title: "Help shape what this becomes",
    lede: "One minute. No account.",
    send: "Send feedback",
    share: "Enjoyed the rabbit hole? Share it",
    addAnswer: "Add an answer first.",
    copied: "Thanks. Your answers are copied to your clipboard. Paste them to whoever sent you this link.",
    saved: "Thanks. Your answers were saved on this device.",
    linkCopied: "Link copied.",
    shareText: "Don't just read it. Explore it.",
    questions: [
      { id: "interest", q: "How interesting was this?", options: ["1", "2", "3", "4", "5"], ends: ["Not much", "Very"] },
      { id: "different", q: "How different did this feel from a normal article?", options: ["1", "2", "3", "4", "5"], ends: ["The same", "Very different"] },
      { id: "share", q: "Would you share it with someone?", options: ["Yes", "Maybe", "No"] },
      { id: "return", q: "Would you come back for another experience?", options: ["Yes", "Maybe", "No"] },
    ],
    texts: [
      { id: "liked", q: "What did you like?" },
      { id: "change", q: "What would you change?" },
      { id: "other", q: "Anything else?" },
    ],
  },
} as const;
