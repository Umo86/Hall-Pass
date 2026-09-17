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
import { formatDate, formatMoney, statusLabel } from "@/lib/format";
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
};

export function ScheduleView({ editionCode, rows, suppliers, canSeeCosts, canEdit }: Props) {
  const [view, setView] = useQueryState("view", parseAsString.withDefault("table"));
  const [status, setStatus] = useQueryState("status", parseAsString.withDefault(""));
  const [q, setQ] = useQueryState("q", parseAsString.withDefault(""));
  const [group, setGroup] = useQueryState("group", parseAsString.withDefault(""));
  const [sorting, setSorting] = useState<SortingState>([]);
  const [visibility, setVisibility] = useState<VisibilityState>({});
  const [selected, setSelected] = useState<Record<string, boolean>>({});
  const router = useRouter();
  const [, startTransition] = useTransition();

  const filtered = useMemo(() => {
    const needle = q.trim().toLowerCase();
    return rows.filter((r) => {
      if (status && r.status !== status) return false;
      if (!needle) return true;
      return [r.ref, r.name, r.locationName ?? "", r.hallName ?? "", r.typeName ?? ""]
        .join(" ")
        .toLowerCase()
        .includes(needle);
    });
  }, [rows, q, status]);

  const columns = useMemo<ColumnDef<ScheduleRow>[]>(() => {
    const cols: ColumnDef<ScheduleRow>[] = [
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
      {
        accessorKey: "ref",
        header: "Ref",
        cell: ({ row }) => (
          <Link
            href={`/${editionCode}/signage/${row.original.ref}`}
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
        id: "nextStep",
        header: "Sitting with",
        cell: ({ row }) => {
          const steps = row.original.pendingSteps;
          if (steps.length === 0) return <span className="text-muted-foreground">—</span>;
          return (
            <span className={steps.some((s) => s.overdue) ? "text-destructive font-medium" : ""}>
              {steps.map((s) => `${s.name}${s.role ? ` (${statusLabel(s.role)})` : ""}`).join(", ")}
            </span>
          );
        },
      },
      { accessorKey: "typeName", header: "Type" },
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
      { accessorKey: "sponsorName", header: "Sponsor", cell: ({ getValue }) => getValue() ?? "—" },
      { accessorKey: "supplierName", header: "Supplier", cell: ({ getValue }) => getValue() ?? "—" },
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
  }, [editionCode, canSeeCosts]);

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
          className="h-8 w-64"
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
                <Columns3 className="size-4" /> Columns
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
            <Table2 className="size-4" /> Table
          </Button>
          <Button
            variant={view === "kanban" ? "secondary" : "outline"}
            size="sm"
            onClick={() => setView("kanban")}
          >
            <Kanban className="size-4" /> Kanban
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
          onDone={() => {
            setSelected({});
            startTransition(() => router.refresh());
          }}
        />
      )}

      {filtered.length === 0 ? (
        <div className="border-border text-muted-foreground flex h-40 flex-col items-center justify-center gap-2 rounded-lg border border-dashed text-sm">
          No items match.
          {canEdit && (
            <Button size="sm" variant="outline" asChild>
              <Link href={`/${editionCode}/signage/new`}>Create the first item</Link>
            </Button>
          )}
        </div>
      ) : view === "kanban" ? (
        <KanbanView editionCode={editionCode} rows={filtered} />
      ) : groups ? (
        <div className="space-y-4">
          {groups.map(([label, groupRows]) => (
            <div key={label}>
              <h3 className="text-muted-foreground mb-1 text-xs font-semibold tracking-wide uppercase">
                {label} · {groupRows.length}
              </h3>
              <SimpleTable rows={groupRows} editionCode={editionCode} canSeeCosts={canSeeCosts} />
            </div>
          ))}
        </div>
      ) : (
        <div className="overflow-x-auto rounded-lg border">
          <table className="w-full text-sm">
            <thead className="bg-muted/50 sticky top-0">
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
                  onClick={() => router.push(`/${editionCode}/signage/${row.original.ref}`)}
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
    <div className="overflow-x-auto rounded-lg border">
      <table className="w-full text-sm">
        <tbody>
          {rows.map((r) => (
            <tr key={r.id} className="hover:bg-muted/30 border-b last:border-0">
              <td className="px-3 py-2 font-medium whitespace-nowrap">
                <Link href={`/${editionCode}/signage/${r.ref}`} className="hover:underline">
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
              <Link
                key={r.id}
                href={`/${editionCode}/signage/${r.ref}`}
                className="bg-background block rounded-md border p-3 text-sm shadow-xs hover:shadow"
              >
                <div className="flex items-center justify-between">
                  <span className="font-medium">{r.ref}</span>
                  {r.currentVersion && (
                    <span className="text-muted-foreground text-xs">v{r.currentVersion}</span>
                  )}
                </div>
                <p className="mt-0.5 line-clamp-2">{r.name}</p>
                <p className="text-muted-foreground mt-1 text-xs">
                  {r.hallName ?? "No hall"}
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
            ))}
          </div>
        </div>
      ))}
    </div>
  );
}
