import { index, integer, numeric, pgTable, text, uuid } from "drizzle-orm/pg-core";
import { editions } from "./events";
import { timestamps } from "./tenancy";

export const halls = pgTable(
  "halls",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    editionId: uuid("edition_id")
      .notNull()
      .references(() => editions.id),
    name: text("name").notNull(),
    floorplanPath: text("floorplan_path"),
    floorplanWidthPx: integer("floorplan_width_px"),
    floorplanHeightPx: integer("floorplan_height_px"),
    sortOrder: integer("sort_order").notNull().default(0),
    ...timestamps,
  },
  (t) => [index("halls_edition_idx").on(t.editionId)],
);

export const locations = pgTable(
  "locations",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    hallId: uuid("hall_id")
      .notNull()
      .references(() => halls.id),
    name: text("name").notNull(),
    zone: text("zone"),
    // 0–1, resolution independent.
    xPct: numeric("x_pct", { precision: 6, scale: 5 }),
    yPct: numeric("y_pct", { precision: 6, scale: 5 }),
    nearStandNumber: text("near_stand_number"),
    ...timestamps,
  },
  (t) => [index("locations_hall_idx").on(t.hallId)],
);
