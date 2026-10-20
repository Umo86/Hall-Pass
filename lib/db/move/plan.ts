/**
 * Insert order for the copy (parents before children) and the foreign-key
 * columns that have to be filled in afterwards because they close a cycle.
 * Pure: computed from the catalog at run time, never hard-coded. Cycles are
 * found with Tarjan's strongly connected components; inside a component every
 * nullable foreign key is deferred (inserted as NULL, filled in after every
 * table is in), and what remains must sort topologically (Kahn, ties by
 * name). A cycle with no nullable key, or a NOT NULL self-reference, throws.
 */
import { tableMap, type Catalog, type TableInfo } from "./catalog";

export type DeferredKey = {
  /** "schema.table" holding the key. */
  table: string;
  /** The constraint name. */
  fk: string;
  cols: string[];
  /** "schema.table" it references. */
  ref: string;
};

export type CopyPlan = {
  order: string[];
  deferred: DeferredKey[];
  /** Components with more than one table, or a table referencing itself. */
  cycles: string[][];
};

function stronglyConnected(nodes: string[], edges: Map<string, Set<string>>): string[][] {
  let index = 0;
  const idx = new Map<string, number>();
  const low = new Map<string, number>();
  const onStack = new Set<string>();
  const stack: string[] = [];
  const out: string[][] = [];
  const visit = (v: string) => {
    idx.set(v, index);
    low.set(v, index);
    index++;
    stack.push(v);
    onStack.add(v);
    for (const w of edges.get(v) ?? []) {
      if (!idx.has(w)) {
        visit(w);
        low.set(v, Math.min(low.get(v)!, low.get(w)!));
      } else if (onStack.has(w)) {
        low.set(v, Math.min(low.get(v)!, idx.get(w)!));
      }
    }
    if (low.get(v) === idx.get(v)) {
      const component: string[] = [];
      let w: string;
      do {
        w = stack.pop()!;
        onStack.delete(w);
        component.push(w);
      } while (w !== v);
      out.push(component.sort());
    }
  };
  for (const v of nodes) if (!idx.has(v)) visit(v);
  return out;
}

export function planCopy(catalog: Pick<Catalog, "tables">): CopyPlan {
  const tables = tableMap(catalog);
  const nodes = [...tables.keys()].sort();
  const inSet = (key: string) => tables.has(key);

  // NOT NULL self-references can never be inserted.
  for (const t of tables.values()) {
    for (const f of t.fks) {
      if (f.ref === t.key && !f.nullable) {
        throw new Error(`Self-reference ${f.name} on ${t.key} is NOT NULL, so it can't be copied`);
      }
    }
  }

  const edges = new Map<string, Set<string>>(nodes.map((n) => [n, new Set<string>()]));
  for (const t of tables.values()) {
    for (const f of t.fks) if (inSet(f.ref)) edges.get(t.key)!.add(f.ref);
  }
  const components = stronglyConnected(nodes, edges);
  const componentOf = new Map<string, number>();
  components.forEach((c, i) => c.forEach((n) => componentOf.set(n, i)));

  const deferred: DeferredKey[] = [];
  for (const key of nodes) {
    const t = tables.get(key) as TableInfo;
    for (const f of t.fks) {
      if (!inSet(f.ref) || componentOf.get(key) !== componentOf.get(f.ref)) continue;
      if (f.nullable) deferred.push({ table: key, fk: f.name, cols: [...f.cols], ref: f.ref });
    }
  }
  const deferredNames = new Set(deferred.map((d) => `${d.table}|${d.fk}`));

  // What's left (minus deferred keys and self-references) must sort topologically.
  const remaining = new Map<string, Set<string>>(nodes.map((n) => [n, new Set<string>()]));
  for (const t of tables.values()) {
    for (const f of t.fks) {
      if (inSet(f.ref) && f.ref !== t.key && !deferredNames.has(`${t.key}|${f.name}`)) {
        remaining.get(t.key)!.add(f.ref);
      }
    }
  }
  const order: string[] = [];
  const placed = new Set<string>();
  const ready = nodes.filter((n) => remaining.get(n)!.size === 0);
  while (ready.length) {
    ready.sort();
    const n = ready.shift()!;
    order.push(n);
    placed.add(n);
    for (const [k, deps] of remaining) {
      if (deps.delete(n) && deps.size === 0 && !placed.has(k) && !ready.includes(k)) ready.push(k);
    }
  }
  if (order.length !== nodes.length) {
    const stuck = nodes.filter((n) => !placed.has(n));
    throw new Error(`Foreign-key cycle with no nullable column to break it: ${stuck.join(", ")}`);
  }

  const cycles = components.filter((c) => c.length > 1 || edges.get(c[0])!.has(c[0]));
  return { order, deferred, cycles };
}

/** "schema.table.col1,col2" for reports. */
export function describeDeferred(d: DeferredKey): string {
  return `${d.table}.${d.cols.join(",")}`;
}
