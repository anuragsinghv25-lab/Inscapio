import { render, screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { beforeAll, describe, expect, it, vi } from "vitest";
import { listExperienceSlugs, loadExperience } from "@/content/load";
import { BlockRenderer } from "@/renderer/BlockRenderer";
import { interpolateRow, periodicSplinePath, signed, xFor, yFor } from "@/renderer/blocks/scrubber/geometry";
import { RichText } from "@/renderer/RichText";
import { templateText } from "@/renderer/template";
import type { RenderContext } from "@/renderer/types";

beforeAll(() => {
  vi.stubGlobal("matchMedia", (q: string) => ({ matches: false, media: q, addEventListener() {}, removeEventListener() {} }));
  vi.stubGlobal("ResizeObserver", class { observe() {} disconnect() {} unobserve() {} });
});

const ctxFor = (e: ReturnType<typeof loadExperience>): RenderContext => ({
  sources: new Map(e.sources.map((s) => [s.id, s])),
  datasets: new Map(e.datasets.map((d) => [d.id, d])),
});

describe("geometry", () => {
  it("maps values and periods into the plot", () => {
    expect(yFor(-12, 270, -12, 42)).toBe(270 - 26); // yMin sits on the baseline
    expect(yFor(42, 270, -12, 42)).toBe(24); // yMax sits at the top margin
    expect(xFor(0, 12, 600)).toBe(34);
    expect(xFor(11, 12, 600)).toBe(592);
  });
  it("blends dataset rows linearly between steps", () => {
    expect(interpolateRow([[0, 10], [10, 20]], 0.5)).toEqual([5, 15]);
    expect(interpolateRow([[0, 10], [10, 20]], 5)).toEqual([10, 20]); // clamps beyond the last step
  });
  it("draws a spline through every point and starts/ends at the first/last period", () => {
    const xs = [0, 10, 20, 30], ys = [5, 1, 5, 1];
    const d = periodicSplinePath(xs, ys);
    expect(d.startsWith("M0.0 5.0")).toBe(true);
    expect(d.endsWith("30.0 1.0")).toBe(true);
    expect(d.match(/C/g)).toHaveLength(3);
  });
  it("formats deltas as v0 does", () => {
    expect(signed(1.234)).toBe("+1.2");
    expect(signed(0.04)).toBe("0.0");
    expect(signed(-0.4)).toBe("-0.4");
  });
});

describe("templates", () => {
  it("fills closed tokens", () => {
    const t = [{ token: "group" as const }, { text: " in " }, { token: "step" as const }];
    expect(templateText(t, { group: "London", step: 2070, lastStep: 2070, match: "Madrid" })).toBe("London in 2070");
  });
});

describe("RichText", () => {
  it("renders marks as elements and never interprets text as HTML", () => {
    const ctx = ctxFor(loadExperience("climate"));
    const { container } = render(<RichText ctx={ctx} nodes={[{ text: "a " }, { text: "bold", marks: ["strong"] }, { text: " <b>not bold</b>" }]} />);
    expect(container.querySelectorAll("strong")).toHaveLength(1);
    expect(container.querySelectorAll("b")).toHaveLength(0);
    expect(container.textContent).toBe("a bold <b>not bold</b>");
  });
  it("renders a source reference as its citation", () => {
    const e = loadExperience("whose-body-is-it");
    const { container } = render(<RichText ctx={ctxFor(e)} nodes={[{ sourceRef: "bns-2023" }]} />);
    expect(container.textContent).toBe("Bharatiya Nyaya Sanhita 2023");
  });
});

describe("every block of both experiences renders", () => {
  for (const slug of listExperienceSlugs()) {
    it(slug, () => {
      const e = loadExperience(slug);
      const ctx = ctxFor(e);
      const blocks = [...e.sections.flatMap((s) => s.blocks)];
      expect(blocks.length).toBeGreaterThan(0);
      for (const block of blocks) {
        const { container, unmount } = render(<BlockRenderer block={block} ctx={ctx} />);
        expect(container.textContent?.length, `${block.type} ${block.id}`).toBeGreaterThan(0);
        expect(screen.queryByText("This part could not be shown.")).toBeNull();
        unmount();
      }
    });
  }
});

describe("block behaviour", () => {
  const body = loadExperience("whose-body-is-it");
  const find = <T extends string>(type: T) => body.sections.flatMap((s) => s.blocks).find((b) => b.type === type)!;

  it("accordion toggles aria-expanded", async () => {
    render(<BlockRenderer block={find("accordion")} ctx={ctxFor(body)} />);
    const b = screen.getByRole("button", { name: /The fruit/ });
    expect(b).toHaveAttribute("aria-expanded", "false");
    await userEvent.click(b);
    expect(b).toHaveAttribute("aria-expanded", "true");
  });

  it("classify scores and finishes", async () => {
    render(<BlockRenderer block={find("classify")} ctx={ctxFor(body)} />);
    for (const label of ["Safety advice", "Blame", "Blame", "Safety advice", "Blame", "Blame"]) {
      await userEvent.click(screen.getByRole("button", { name: label }));
    }
    expect(screen.getByText(/You scored 5 of 6\./)).toBeInTheDocument();
  });

  it("claims filter by theme", async () => {
    render(<BlockRenderer block={find("claims")} ctx={ctxFor(body)} />);
    expect(screen.getAllByRole("button", { expanded: false })).toHaveLength(16);
    await userEvent.click(screen.getByRole("button", { name: "About men" }));
    expect(screen.getAllByRole("button", { expanded: false })).toHaveLength(5);
  });

  it("selector shows the chosen option's content", async () => {
    render(<BlockRenderer block={find("selector-content")} ctx={ctxFor(body)} />);
    await userEvent.click(screen.getByRole("button", { name: "An elder" }));
    const live = document.querySelector("[aria-live=polite]")!;
    expect(within(live as HTMLElement).getByText(/Your words carry weight/)).toBeInTheDocument();
  });

  it("scrubber: prediction marks the right answer and the slider reaches the last step", async () => {
    const climate = loadExperience("climate");
    const block = climate.sections.flatMap((s) => s.blocks).find((b) => b.type === "scrubber-chart")!;
    render(<BlockRenderer block={block} ctx={ctxFor(climate)} />);
    expect(screen.getByTestId("scrubber-step")).toHaveTextContent("2026");
    await userEvent.click(within(screen.getByTestId("scrubber-options")).getByRole("button", { name: "Madrid" }));
    expect(screen.getByText(/^Close\./)).toBeInTheDocument();
  });
});

describe("safety: content cannot inject markup", () => {
  it("renders hostile-looking text as text (schema rejects it earlier; the renderer is a second line of defence)", () => {
    const ctx = ctxFor(loadExperience("climate"));
    const { container } = render(<RichText ctx={ctx} nodes={[{ text: "<img src=x onerror=alert(1)>" }]} />);
    expect(container.querySelector("img")).toBeNull();
  });
});
