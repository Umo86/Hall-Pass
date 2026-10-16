/**
 * Writes authz-v1-snapshot.json: can() over every fixture actor × action.
 * It was run once against lib/authz.ts before the abilities registry
 * (`pnpm exec tsx tests/unit/fixtures/generate-authz-snapshot.ts`); the
 * snapshot is frozen, so don't regenerate it from newer code.
 */
import { writeFileSync } from "node:fs";
import { can } from "@/lib/authz";
import { costItems, snapshotActions, snapshotActors } from "./authz-snapshot-cases";

const actions = snapshotActions();
const items = costItems();
const results: Record<string, string> = {};
const costs: Record<string, string> = {};
for (const [actorKey, actor] of snapshotActors()) {
  results[actorKey] = actions.map(([, a]) => (can(actor, a) ? "1" : "0")).join("");
  // Before Users v2 the item actions (signage.ts) decided cost editing as
  // costs.edit, or a sponsorship item the person may edit.
  costs[actorKey] = items
    .map(([, item]) =>
      can(actor, { type: "costs.edit" }) ||
      (item.kind === "sponsorship_item" && can(actor, { type: "signage.edit", item }))
        ? "1"
        : "0",
    )
    .join("");
}
const out = {
  note: "Frozen can() results from before the abilities registry. Do not regenerate.",
  actions: actions.map(([k]) => k),
  costItems: items.map(([k]) => k),
  results,
  costs,
};
writeFileSync(
  new URL("./authz-v1-snapshot.json", import.meta.url),
  `${JSON.stringify(out, null, 1)}\n`,
);
console.log(`${Object.keys(results).length} actors × ${actions.length} actions`);
