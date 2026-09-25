"use client";

import { useMemo, useState, useTransition } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import {
  flexRender,
  getCoreRowModel,
  getFilteredRowModel,
  getSortedRowModel,
  useReactTable,
  type ColumnDef,
  type SortingState,
  type VisibilityState,
} from "@tanstack/react-table";
import { parseAsString, useQueryState } from "nuqs";
import { ArrowUpDown, Columns3, Kanban, Plus, Table2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
  DropdownMenu,
  DropdownMenuCheckboxItem,
  DropdownMenuContent,
  DropdownMenuLabel,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { StatusBadge } from "@/components/status-badge";
import { formatDate, formatMoney, statusLabel, roleLabel } from "@/lib/format";
import type { ScheduleRow } from "@/lib/queries/signage";
import { BulkActionsBar } from "./bulk-actions";

const STATUS_ORDER = [
  "draft",
  "awaiting_artwork",
  "in_review",
  "changes_requested",
  "approved",
  "approved_with_conditions",
  "in_production",
  "delivered",
  "installed",
  "snagged",
  "closed",
  "rejected",
  "on_hold",
];

type Props = {
  editionCode: string;
  rows: ScheduleRow[];
  suppliers: { id: string; name: string }[];
  canSeeCosts: boolean;
  canEdit: boolean;
  canEditCosts: boolean;
  canDelete: boolean;
};

// Shown by default; the rest stay one click away in the Columns menu.
const DEFAULT_HIDDEN: VisibilityState = {
  hallName: false,
  size: false,
  quantity: false,
  fixingMethod: false,
  version: false,
  costEstimate: false,
  costActual: false,
  poNumber: false,
};

export function ScheduleView({
  editionCode,
  rows,
  suppliers,
  canSeeCosts,
  canEdit,
  canEditCosts,
  canDelete,
}: Props) {
  const [view, setView] = useQueryState("view", parseAsString.withDefault("table"));
  const [status, setStatus] = useQueryState("status", parseAsString.withDefault(""));
  const [category, setCategory] = useQueryState("category", parseAsString.withDefault(""));
  const [format, setFormat] = useQueryState("format", parseAsString.withDefault(""));
  const [q, setQ] = useQueryState("q", parseAsString.withDefault(""));
  const [group, setGroup] = useQueryState("group", parseAsString.withDefault(""));
  const [sorting, setSorting] = useState<SortingState>([]);
  const [visibility, setVisibility] = useState<VisibilityState>(DEFAULT_HIDDEN);
  const [selected, setSelected] = useState<Record<string, boolean>>({});
  const router = useRouter();
  const [, startTransition] = useTransition();

  const filtered = useMemo(() => {
    const needle = q.trim().toLowerCase();
    return rows.filter((r) => {
      if (status && r.status !== status) return false;
      if (category && r.category !== category) return false;
      if (format && r.format !== format) return false;
      if (!needle) return true;
      return [
        r.ref,
        r.name,
        r.locationName ?? "",
        r.hallName ?? "",
        r.typeName ?? "",
        r.sponsorName ?? "",
        r.supplierName ?? "",
      ]
        .join(" ")
        .toLowerCase()
        .includes(needle);
    });
  }, [rows, q, status, category, format]);

  const columns = useMemo<ColumnDef<ScheduleRow>[]>(() => {
    const selectCol: ColumnDef<ScheduleRow>[] = [
      {
        id: "select",
        enableHiding: false,
        header: ({ table }) => (
          <input
            type="checkbox"
            aria-label="Select all"
            className="size-4"
            checked={table.getIsAllRowsSelected()}
            onChange={table.getToggleAllRowsSelectedHandler()}
          />
        ),
        cell: ({ row }) => (
          <input
            type="checkbox"
            aria-label={`Select ${row.original.ref}`}
            className="size-4"
            checked={row.getIsSelected()}
            onChange={row.getToggleSelectedHandler()}
            onClick={(e) => e.stopPropagation()}
          />
        ),
      },
    ];
    const cols: ColumnDef<ScheduleRow>[] = [
      ...(canEdit ? selectCol : []),
      {
        accessorKey: "ref",
        header: "Ref",
        cell: ({ row }) => (
          <Link
            href={itemHref(editionCode, row.original)}
            className="font-medium hover:underline"
            onClick={(e) => e.stopPropagation()}
          >
            {row.original.ref}
          </Link>
        ),
      },
      { accessorKey: "name", header: "Name" },
      {
        accessorKey: "status",
        header: "Status",
        cell: ({ getValue }) => <StatusBadge status={getValue<string>()} />,
      },
      {
        accessorKey: "category",
        header: "Category",
        cell: ({ getValue }) => {
          const v = getValue<string | null>();
          return v === "sponsor" ? "Sponsor" : v === "organiser" ? "Organiser" : "—";
        },
      },
      { accessorKey: "sponsorName", header: "Sponsor", cell: ({ getValue }) => getValue() ?? "—" },
      { accessorKey: "typeName", header: "Type", cell: ({ getValue }) => getValue() ?? "—" },
      {
        accessorKey: "format",
        header: "Format",
        cell: ({ row }) =>
          row.original.kind === "sponsorship_item"
            ? "Merchandise"
            : row.original.format === "digital"
              ? "Digital"
              : row.original.format === "print"
                ? "Print"
                : "—",
      },
      {
        accessorKey: "supplierName",
        header: "Supplier",
        cell: ({ getValue }) => getValue() ?? "—",
      },
      {
        id: "nextStep",
        header: "Sitting with",
        cell: ({ row }) => {
          const steps = row.original.pendingSteps;
          if (steps.length === 0) return <span className="text-muted-foreground">—</span>;
          return (
            <span className={steps.some((s) => s.overdue) ? "text-destructive font-medium" : ""}>
              {steps.map((s) => `${s.name}${s.role ? ` (${roleLabel(s.role)})` : ""}`).join(", ")}
            </span>
          );
        },
      },
      { accessorKey: "hallName", header: "Hall" },
      { accessorKey: "locationName", header: "Location" },
      {
        id: "size",
        header: "Size (mm)",
        cell: ({ row }) =>
          row.original.widthMm && row.original.heightMm
            ? `${row.original.widthMm} × ${row.original.heightMm}`
            : "—",
      },
      { accessorKey: "quantity", header: "Qty" },
      {
        accessorKey: "fixingMethod",
        header: "Fixing",
        cell: ({ getValue }) => {
          const v = getValue<string | null>();
          return v ? statusLabel(v) : "—";
        },
      },
      {
        accessorKey: "installDate",
        header: "Install",
        cell: ({ row }) =>
          row.original.installDate
            ? `${formatDate(row.original.installDate)}${row.original.installSlot ? ` ${row.original.installSlot.toUpperCase()}` : ""}`
            : "—",
      },
      {
        id: "version",
        header: "Artwork",
        cell: ({ row }) => (row.original.currentVersion ? `v${row.original.currentVersion}` : "—"),
      },
    ];
    if (canSeeCosts) {
      cols.push(
        {
          accessorKey: "costEstimate",
          header: "Estimate",
          cell: ({ getValue }) => formatMoney(getValue<string | null>()),
        },
        {
          accessorKey: "costActual",
          header: "Actual",
          cell: ({ getValue }) => formatMoney(getValue<string | null>()),
        },
        { accessorKey: "poNumber", header: "PO", cell: ({ getValue }) => getValue() ?? "—" },
      );
    }
    return cols;
  }, [editionCode, canSeeCosts, canEdit]);

  const table = useReactTable({
    data: filtered,
    columns,
    state: { sorting, columnVisibility: visibility, rowSelection: selected },
    onSortingChange: setSorting,
    onColumnVisibilityChange: setVisibility,
    onRowSelectionChange: setSelected,
    getRowId: (r) => r.id,
    getCoreRowModel: getCoreRowModel(),
    getSortedRowModel: getSortedRowModel(),
    getFilteredRowModel: getFilteredRowModel(),
    enableRowSelection: canEdit,
  });

  const selectedIds = Object.keys(selected).filter((k) => selected[k]);

  const groups = useMemo(() => {
    if (!group) return null;
    const keyOf = (r: ScheduleRow) =>
      group === "hall"
        ? (r.hallName ?? "No hall")
        : group === "type"
          ? (r.typeName ?? "No type")
          : group === "sponsor"
            ? (r.sponsorName ?? "No sponsor")
            : group === "supplier"
              ? (r.supplierName ?? "No supplier")
              : statusLabel(r.status);
    const map = new Map<string, ScheduleRow[]>();
    for (const r of filtered) {
      const k = keyOf(r);
      map.set(k, [...(map.get(k) ?? []), r]);
    }
    return [...map.entries()].sort((a, b) => a[0].localeCompare(b[0]));
  }, [filtered, group]);

  return (
    <div className="flex flex-col gap-3">
      <div className="flex flex-wrap items-center gap-2">
        <Input
          type="search"
          value={q}
          onChange={(e) => setQ(e.target.value || null)}
          placeholder="Search ref, name, location…"
          className="h-8 w-full sm:w-64"
        />
        <select
          value={status}
          onChange={(e) => setStatus(e.target.value || null)}
          className="border-input h-8 rounded-md border bg-transparent px-2 text-sm"
          aria-label="Filter by status"
        >
          <option value="">All statuses</option>
          {STATUS_ORDER.map((s) => (
            <option key={s} value={s}>
              {statusLabel(s)}
            </option>
          ))}
        </select>
        <select
          value={category}
          onChange={(e) => setCategory(e.target.value || null)}
          className="border-input h-8 rounded-md border bg-transparent px-2 text-sm"
          aria-label="Filter by category"
        >
          <option value="">Organiser &amp; sponsor</option>
          <option value="organiser">Organiser signage</option>
          <option value="sponsor">Sponsor signage</option>
        </select>
        <select
          value={format}
          onChange={(e) => setFormat(e.target.value || null)}
          className="border-input h-8 rounded-md border bg-transparent px-2 text-sm"
          aria-label="Filter by print or digital"
        >
          <option value="">Print &amp; digital</option>
          <option value="print">Print</option>
          <option value="digital">Digital</option>
        </select>
        <select
          value={group}
          onChange={(e) => setGroup(e.target.value || null)}
          className="border-input h-8 rounded-md border bg-transparent px-2 text-sm"
          aria-label="Group by"
        >
          <option value="">No grouping</option>
          <option value="hall">Group by hall</option>
          <option value="type">Group by type</option>
          <option value="sponsor">Group by sponsor</option>
          <option value="supplier">Group by supplier</option>
          <option value="status">Group by status</option>
        </select>
        <div className="ml-auto flex items-center gap-2">
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button variant="outline" size="sm">
                <Columns3 className="size-4" /> <span className="hidden sm:inline">Columns</span>
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end" className="w-48">
              <DropdownMenuLabel>Show columns</DropdownMenuLabel>
              {table
                .getAllLeafColumns()
                .filter((c) => c.getCanHide())
                .map((col) => (
                  <DropdownMenuCheckboxItem
                    key={col.id}
                    checked={col.getIsVisible()}
                    onCheckedChange={(v) => col.toggleVisibility(Boolean(v))}
                  >
                    {typeof col.columnDef.header === "string" ? col.columnDef.header : col.id}
                  </DropdownMenuCheckboxItem>
                ))}
            </DropdownMenuContent>
          </DropdownMenu>
          <Button
            variant={view === "table" ? "secondary" : "outline"}
            size="sm"
            onClick={() => setView("table")}
          >
            <Table2 className="size-4" /> <span className="hidden sm:inline">Table</span>
          </Button>
          <Button
            variant={view === "kanban" ? "secondary" : "outline"}
            size="sm"
            onClick={() => setView("kanban")}
          >
            <Kanban className="size-4" /> <span className="hidden sm:inline">Kanban</span>
          </Button>
          {canEdit && (
            <Button size="sm" asChild>
              <Link href={`/${editionCode}/signage/new`}>
                <Plus className="size-4" /> New item
              </Link>
            </Button>
          )}
        </div>
      </div>

      {selectedIds.length > 0 && (
        <BulkActionsBar
          selectedIds={selectedIds}
          suppliers={suppliers}
          canEditCosts={canEditCosts}
          canDelete={canDelete}
          onDone={() => {
            setSelected({});
            startTransition(() => router.refresh());
          }}
        />
      )}

      {rows.length === 0 ? (
        <div className="border-border text-muted-foreground flex h-40 flex-col items-center justify-center gap-2 rounded-lg border border-dashed text-sm">
          No signage yet.
          {canEdit && (
            <Button size="sm" variant="outline" asChild>
              <Link href={`/${editionCode}/signage/new`}>Create the first item</Link>
            </Button>
          )}
        </div>
      ) : filtered.length === 0 ? (
        <div className="border-border text-muted-foreground flex h-40 flex-col items-center justify-center gap-2 rounded-lg border border-dashed text-sm">
          No items match your filters.
          <Button
            size="sm"
            variant="outline"
            onClick={() => {
              void setQ(null);
              void setStatus(null);
              void setCategory(null);
              void setFormat(null);
            }}
          >
            Clear filters
          </Button>
        </div>
      ) : view === "kanban" ? (
        <KanbanView editionCode={editionCode} rows={filtered} />
      ) : (
        <>
          <CardList rows={filtered} editionCode={editionCode} className="sm:hidden" />
          <div className="hidden sm:block">
            {groups ? (
              <div className="space-y-4">
                {groups.map(([label, groupRows]) => (
                  <div key={label}>
                    <h3 className="text-muted-foreground mb-1 text-xs font-semibold tracking-wide uppercase">
                      {label} · {groupRows.length}
                    </h3>
                    <SimpleTable
                      rows={groupRows}
                      editionCode={editionCode}
                      canSeeCosts={canSeeCosts}
                    />
                  </div>
                ))}
              </div>
            ) : (
              <div className="max-h-[70vh] overflow-auto rounded-lg border">
                <table className="w-full text-sm">
                  {/* Opaque header: rows scroll underneath it inside the capped box. */}
                  <thead className="bg-muted sticky top-0 z-10">
                    {table.getHeaderGroups().map((hg) => (
                      <tr key={hg.id} className="border-b text-left">
                        {hg.headers.map((h) => (
                          <th key={h.id} className="text-muted-foreground px-3 py-2 font-medium">
                            {h.isPlaceholder ? null : h.column.getCanSort() ? (
                              <button
                                className="flex items-center gap-1 hover:underline"
                                onClick={h.column.getToggleSortingHandler()}
                              >
                                {flexRender(h.column.columnDef.header, h.getContext())}
                                <ArrowUpDown className="size-3 opacity-40" />
                              </button>
                            ) : (
                              flexRender(h.column.columnDef.header, h.getContext())
                            )}
                          </th>
                        ))}
                      </tr>
                    ))}
                  </thead>
                  <tbody>
                    {table.getRowModel().rows.map((row) => (
                      <tr
                        key={row.id}
                        className="hover:bg-muted/30 cursor-pointer border-b last:border-0"
                        onClick={() => router.push(itemHref(editionCode, row.original))}
                      >
                        {row.getVisibleCells().map((cell) => (
                          <td key={cell.id} className="px-3 py-2 whitespace-nowrap">
                            {flexRender(cell.column.columnDef.cell, cell.getContext())}
                          </td>
                        ))}
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        </>
      )}
    </div>
  );
}

/** Sponsorship-section items open under Sponsorship; everything else under Signage. */
function itemHref(editionCode: string, r: Pick<ScheduleRow, "ref" | "kind">) {
  return `/${editionCode}/${r.kind === "sponsorship_item" ? "sponsorship" : "signage"}/${r.ref}`;
}

/** Phone layout: one tappable card per item. */
function CardList({
  rows,
  editionCode,
  className,
}: {
  rows: ScheduleRow[];
  editionCode: string;
  className?: string;
}) {
  return (
    <ul className={`space-y-2 ${className ?? ""}`}>
      {rows.map((r) => (
        <li key={r.id}>
          <ItemCard r={r} editionCode={editionCode} />
        </li>
      ))}
    </ul>
  );
}

function ItemCard({
  r,
  editionCode,
  showStatus = true,
}: {
  r: ScheduleRow;
  editionCode: string;
  showStatus?: boolean;
}) {
  return (
    <Link
      href={itemHref(editionCode, r)}
      className="bg-background block rounded-md border p-3 text-sm shadow-xs hover:shadow"
    >
      <div className="flex items-center justify-between gap-2">
        <span className="font-medium">{r.ref}</span>
        {showStatus ? (
          <StatusBadge status={r.status} />
        ) : r.currentVersion ? (
          <span className="text-muted-foreground text-xs">v{r.currentVersion}</span>
        ) : null}
      </div>
      <p className="mt-0.5 line-clamp-2">{r.name}</p>
      <p className="text-muted-foreground mt-0.5 text-xs">
        {[
          r.category === "sponsor" ? `Sponsor: ${r.sponsorName ?? "—"}` : "Organiser",
          r.typeName,
          r.supplierName ? `Supplier: ${r.supplierName}` : null,
        ]
          .filter(Boolean)
          .join(" · ")}
      </p>
      <p className="text-muted-foreground mt-1 text-xs">
        {[r.hallName, r.locationName].filter(Boolean).join(" · ") || "No location"}
        {r.pendingSteps.length > 0 && (
          <>
            {" · "}
            <span className={r.pendingSteps.some((s) => s.overdue) ? "text-destructive" : ""}>
              {r.pendingSteps[0].name}
              {r.pendingSteps[0].dueAt ? ` — due ${formatDate(r.pendingSteps[0].dueAt)}` : ""}
            </span>
          </>
        )}
      </p>
    </Link>
  );
}

function SimpleTable({
  rows,
  editionCode,
  canSeeCosts,
}: {
  rows: ScheduleRow[];
  editionCode: string;
  canSeeCosts: boolean;
}) {
  return (
    <div className="max-h-[70vh] overflow-auto rounded-lg border">
      <table className="w-full text-sm">
        <thead className="bg-muted sticky top-0 z-10">
          <tr className="text-muted-foreground border-b text-left">
            <th className="px-3 py-2 font-medium">Ref</th>
            <th className="px-3 py-2 font-medium">Name</th>
            <th className="px-3 py-2 font-medium">Status</th>
            <th className="px-3 py-2 font-medium">Location</th>
            <th className="px-3 py-2 font-medium">Install</th>
            {canSeeCosts && <th className="px-3 py-2 font-medium">Estimate</th>}
          </tr>
        </thead>
        <tbody>
          {rows.map((r) => (
            <tr key={r.id} className="hover:bg-muted/30 border-b last:border-0">
              <td className="px-3 py-2 font-medium whitespace-nowrap">
                <Link href={itemHref(editionCode, r)} className="hover:underline">
                  {r.ref}
                </Link>
              </td>
              <td className="px-3 py-2">{r.name}</td>
              <td className="px-3 py-2">
                <StatusBadge status={r.status} />
              </td>
              <td className="text-muted-foreground px-3 py-2">{r.locationName ?? "—"}</td>
              <td className="px-3 py-2">{r.installDate ? formatDate(r.installDate) : "—"}</td>
              {canSeeCosts && <td className="px-3 py-2">{formatMoney(r.costEstimate)}</td>}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function KanbanView({ editionCode, rows }: { editionCode: string; rows: ScheduleRow[] }) {
  const byStatus = new Map<string, ScheduleRow[]>();
  for (const r of rows) byStatus.set(r.status, [...(byStatus.get(r.status) ?? []), r]);
  const columns = STATUS_ORDER.filter((s) => byStatus.has(s));
  return (
    <div className="flex gap-3 overflow-x-auto pb-2">
      {columns.map((statusKey) => (
        <div key={statusKey} className="bg-muted/30 w-72 shrink-0 rounded-lg border p-2">
          <div className="mb-2 flex items-center justify-between px-1">
            <StatusBadge status={statusKey} />
            <span className="text-muted-foreground text-xs">{byStatus.get(statusKey)!.length}</span>
          </div>
          <div className="space-y-2">
            {byStatus.get(statusKey)!.map((r) => (
              <ItemCard key={r.id} r={r} editionCode={editionCode} showStatus={false} />
            ))}
          </div>
        </div>
      ))}
    </div>
  );
}
