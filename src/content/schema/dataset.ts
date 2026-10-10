import { z } from "zod";
import { Id, MediumText, ShortText } from "./primitives";

/**
 * A dataset for the scrubber chart: a value for every (group × step × period), plus a small
 * set of precomputed per-(group × step) outputs. The renderer performs NO modelling: anything
 * that was computed in v0 is computed once, offline, and stored here with its provenance.
 *
 * Climate example: groups = cities, steps = years, periods = months,
 * values = monthly mean temperature, derived = analogue city / climate type / warming fraction.
 */
const GroupDef = z.strictObject({ id: Id, label: ShortText });

const DerivedStep = z.strictObject({
  /** The group this group most resembles at this step. */
  match: Id,
  /** A short label for the group's category at this step. */
  category: ShortText,
  /** 0..1: drives the data-bound theme (cool → warm). */
  warm: z.number().min(0).max(1),
  /** Highest and lowest period value at this step (exact; not re-derived from rounded values). */
  high: z.number().finite(),
  low: z.number().finite(),
});

export const DATASET_PROVENANCE_KINDS = ["illustrative-model", "publisher-supplied", "cited-source"] as const;

export const Dataset = z
  .strictObject({
    id: Id,
    title: ShortText,
    unit: z.string().min(1).max(8),
    /** Honesty flag. When true, the experience must carry a visible data note (see references). */
    illustrative: z.boolean(),
    provenance: z.strictObject({
      kind: z.enum(DATASET_PROVENANCE_KINDS),
      description: MediumText,
      sourceIds: z.array(Id).max(10).optional(),
    }),
    groups: z.array(GroupDef).min(1).max(100),
    steps: z.array(z.number().int()).min(2).max(200),
    periods: z.array(ShortText).min(2).max(24),
    /** values[groupId][stepIndex][periodIndex] */
    values: z.record(Id, z.array(z.array(z.number().finite()).min(2)).min(2)),
    /** derived[groupId][stepIndex] */
    derived: z.record(Id, z.array(DerivedStep).min(2)),
  })
  .superRefine((d, ctx) => {
    const add = (message: string, path: (string | number)[]) => ctx.addIssue({ code: "custom", message, path });
    const ids = d.groups.map((g) => g.id);
    if (new Set(ids).size !== ids.length) add("group ids must be unique", ["groups"]);
    for (let i = 1; i < d.steps.length; i++) {
      if ((d.steps[i] as number) <= (d.steps[i - 1] as number)) add("steps must be strictly increasing", ["steps"]);
    }
    if (d.illustrative && d.provenance.kind !== "illustrative-model")
      add("an illustrative dataset must declare provenance.kind 'illustrative-model'", ["provenance", "kind"]);
    if (!d.illustrative && d.provenance.kind === "illustrative-model")
      add("provenance.kind 'illustrative-model' requires illustrative: true", ["illustrative"]);
    for (const id of ids) {
      const rows = d.values[id];
      const der = d.derived[id];
      if (!rows) add(`values missing for group '${id}'`, ["values", id]);
      else {
        if (rows.length !== d.steps.length) add(`values['${id}'] needs ${d.steps.length} steps`, ["values", id]);
        rows.forEach((row, i) => {
          if (row.length !== d.periods.length)
            add(`values['${id}'][${i}] needs ${d.periods.length} periods`, ["values", id, i]);
        });
      }
      if (!der) add(`derived missing for group '${id}'`, ["derived", id]);
      else {
        if (der.length !== d.steps.length) add(`derived['${id}'] needs ${d.steps.length} steps`, ["derived", id]);
        der.forEach((s, i) => {
          if (!ids.includes(s.match)) add(`derived['${id}'][${i}].match '${s.match}' is not a group`, ["derived", id, i]);
        });
      }
    }
    for (const key of [...Object.keys(d.values), ...Object.keys(d.derived)]) {
      if (!ids.includes(key)) add(`'${key}' is not a declared group`, ["groups"]);
    }
  });
export type Dataset = z.infer<typeof Dataset>;
