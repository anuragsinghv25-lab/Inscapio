import { z } from "zod";
import { HttpsUrl, Id, IsoDate, MediumText } from "./primitives";

/**
 * A citation. Provenance is structural: blocks and inline nodes reference sources by id,
 * and validation fails if a reference does not resolve (docs/product/principles.md, Principle 7).
 * Only fields that exist in the source material are modelled: v0 cites by name, without URLs.
 */
export const Source = z.strictObject({
  id: Id,
  citation: MediumText,
  url: HttpsUrl.optional(),
  accessedAt: IsoDate.optional(),
});
export type Source = z.infer<typeof Source>;
