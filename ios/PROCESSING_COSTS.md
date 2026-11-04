# Batch recipes and costing

The Processing tab now records the actual raw-material weight and price, finished weight,
and an editable ingredient list for every batch. Each ingredient has its use quantity/unit
and purchase quantity/unit/total price. Compatible mass and volume units convert automatically;
Taiwan jin is 600 g. Packaging units must match; no density or pack-size assumptions are made.

Changing raw weight proportionally scales the current ingredient quantities and estimated yield.
The user must verify actual finished weight before saving. Empty prices stay pending; explicit 0
is permitted for free materials. Costs round each ingredient to cents, then sum raw and marinade
costs. Finished unit cost divides by actual finished kg. Templates are per vendor (up to 100),
with up to 100 ingredients. They can be saved, updated, or copied as a new template.

Every saved batch includes a `costing` snapshot plus the batch's own quantities and prices.
Changing a recipe or later prices never rewrites older batch snapshots. Legacy text-only rows
retain their source text and totals; editing notes does not infer a missing historical formula.
Users can explicitly create ingredient details for a legacy batch and replace its costing.

Recipes are stored as `vb_recipes_v32_<vendorId>` and included in web and native recovery
JSON backups. Old backups without recipes remain supported and leave existing templates alone.
Restores validate structured batch calculations and templates before writing, using the existing
rollback/recovery mechanism. Switching vendors remounts the processing editor.

Manufacturing records do not directly deduct inventory or profit. The current app has no reliable
mapping between manually entered recipe ingredient names/units and stock rows. Automatic stock
posting would risk duplicate deductions when editing imported batches. Daily consumed costs and
inventory remain explicit entries, consistent with the existing profit engine.

Validation: `node ios/tests/processing.test.cjs` and
`node ios/tests/processing-browser.cjs` (Playwright WebKit, iPhone 13 touch).
The screenshots' example is a regression fixture only: raw 340 kg × 55 = 18,700;
marinade 2,024; batch total 20,724; finished 360 kg => 57.5667 per kg.
