"use client";

import { Fragment, useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import {
  flexRender,
  getCoreRowModel,
  getSortedRowModel,
  useReactTable,
  type ColumnDef,
  type Row,
  type SortingState,
  type VisibilityState,
} from "@tanstack/react-table";
import { parseAsString, useQueryState } from "nuqs";
import {
  ArrowUpDown,
  Columns3,
  Download,
  FileSpreadsheet,
  Kanban,
  ListFilter,
  Plus,
  SearchX,
  Signpost,
  Table2,
  X,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { ScrollX } from "@/components/ui/scroll-x";
import { SegmentGroup, segmentClass } from "@/components/ui/segmented";
import {
  DropdownMenu,
  DropdownMenuCheckboxItem,
  DropdownMenuContent,
  DropdownMenuLabel,
  DropdownMenuRadioGroup,
  DropdownMenuRadioItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { EmptyState } from "@/components/empty-state";
import { StatusBadge } from "@/components/status-badge";
import { cn } from "@/lib/utils";
import { formatDate, formatDayMonth, formatMoney, slotLabel, statusLabel } from "@/lib/format";
import type { ScheduleRow } from "@/lib/queries/signage";
import { itemPath } from "@/lib/edition-path";
import { BulkActionsBar, type BulkResult } from "./bulk-actions";
import { ImportSignsSheet } from "./new-sign-menu";

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

/** Rows shown at a time on a phone, per list or group. */
const PAGE = 20;

/** Kept in this browser only: which columns someone chose to see. */
const COLUMNS_KEY = "hp-signage-columns-v1";

type Props = {
  editionCode: string;
  editionId: string;
  rows: ScheduleRow[];
  suppliers: { id: string; name: string }[];
  /** The status chips, in order, with their labels (from lib/domain/signage). */
  quickFilters: { key: string; label: string }[];
  /** `?stage=` from the dashboard: each stage's label and statuses. */
  stages: Record<string, { label: string; statuses: string[] }>;
  canSeeCosts: boolean;
  /** May add signs (and so import them, and select rows for bulk actions). */
  canEdit: boolean;
  canEditCosts: boolean;
  canDelete: boolean;
  canClose: boolean;
};

// Shown by default; the rest stay one click away in the Columns menu.
const DEFAULT_HIDDEN: VisibilityState = {
  category: false,
  sponsorName: false,
  typeName: false,
  format: false,
  supplierName: false,
  standNumber: false,
  size: false,
  quantity: false,
  fixingMethod: false,
  version: false,
  costEstimate: false,
  costActual: false,
  poNumber: false,
};

/** "Hall 1 · Registration", "Hall 1", or null. */
function place(r: Pick<ScheduleRow, "hallName" | "locationName">): string | null {
  return [r.hallName, r.locationName].filter(Boolean).join(" · ") || null;
}

/** "Operations, Marketing" — who the row is waiting on. */
function waitingOn(r: ScheduleRow): string | null {
  if (r.pendingSteps.length === 0) return null;
  return [
    ...new Set(r.pendingSteps.map((s) => (s.stepKind === "confirmation" ? s.name : s.who))),
  ].join(", ");
}

/** Artwork is only "due" while it is still missing or not yet sent. */
function artworkMatters(r: ScheduleRow): boolean {
  return r.status === "draft" || r.status === "awaiting_artwork";
}

const GROUPS: { key: string; label: string }[] = [
  { key: "", label: "No grouping" },
  { key: "hall", label: "Hall" },
  { key: "status", label: "Status" },
  { key: "type", label: "Type" },
  { key: "sponsor", label: "Sponsor" },
  { key: "supplier", label: "Supplier" },
];

function groupKeyOf(group: string, r: ScheduleRow): string {
  switch (group) {
    case "hall":
      return r.hallName ?? "No hall";
    case "type":
      return r.typeName ?? "No type";
    case "sponsor":
      return r.sponsorName ?? "No sponsor";
    case "supplier":
      return r.supplierName ?? "No supplier";
    default:
      return statusLabel(r.status);
  }
}

/** Groups in a sensible order: statuses by their stage, everything else A–Z with "No …" last. */
function sortGroups(group: string, keys: string[]): string[] {
  if (group === "status") {
    const order = STATUS_ORDER.map(statusLabel);
    return [...keys].sort((a, b) => order.indexOf(a) - order.indexOf(b));
  }
  return [...keys].sort((a, b) => {
    const na = a.startsWith("No ");
    const nb = b.startsWith("No ");
    if (na !== nb) return na ? 1 : -1;
    return a.localeCompare(b, "en-GB", { numeric: true });
  });
}

export function ScheduleView({
  editionCode,
  editionId,
  rows,
  suppliers,
  quickFilters,
  stages,
  canSeeCosts,
  canEdit,
  canEditCosts,
  canDelete,
  canClose,
}: Props) {
  const [view, setView] = useQueryState("view", parseAsString.withDefault("table"));
  const [show, setShow] = useQueryState("show", parseAsString.withDefault(""));
  const [status, setStatus] = useQueryState("status", parseAsString.withDefault(""));
  const [stage, setStage] = useQueryState("stage", parseAsString.withDefault(""));
  const [category, setCategory] = useQueryState("category", parseAsString.withDefault(""));
  const [format, setFormat] = useQueryState("format", parseAsString.withDefault(""));
  const [hall, setHall] = useQueryState("hall", parseAsString.withDefault(""));
  const [location, setLocation] = useQueryState("location", parseAsString.withDefault(""));
  const [supplier, setSupplier] = useQueryState("supplier", parseAsString.withDefault(""));
  const [q, setQ] = useQueryState("q", parseAsString.withDefault(""));
  const [group, setGroup] = useQueryState("group", parseAsString.withDefault(""));
  const [sorting, setSorting] = useState<SortingState>([]);
  const [visibility, setVisibility] = useState<VisibilityState>(DEFAULT_HIDDEN);
  const [selected, setSelected] = useState<Record<string, boolean>>({});
  const [lastResult, setLastResult] = useState<BulkResult | null>(null);
  const [importOpen, setImportOpen] = useState(false);
  const router = useRouter();

  // Someone's column choice is remembered in this browser.
  useEffect(() => {
    try {
      const saved = window.localStorage.getItem(COLUMNS_KEY);
      if (saved) setVisibility({ ...DEFAULT_HIDDEN, ...JSON.parse(saved) });
    } catch {
      // No storage (private window): the defaults are fine.
    }
  }, []);
  function changeVisibility(next: VisibilityState) {
    setVisibility(next);
    try {
      window.localStorage.setItem(COLUMNS_KEY, JSON.stringify(next));
    } catch {
      // Not remembered; still applied.
    }
  }

  const stageStatuses = stage && stages[stage] ? stages[stage].statuses : null;
  const hallNames = useMemo(() => {
    const map = new Map<string, string>();
    for (const r of rows) if (r.hallId && r.hallName) map.set(r.hallId, r.hallName);
    return [...map.entries()].sort((a, b) => a[1].localeCompare(b[1], "en-GB", { numeric: true }));
  }, [rows]);
  const locationName = location
    ? location === "none"
      ? "No location"
      : (rows.find((r) => r.locationId === location)?.locationName ?? "Chosen location")
    : null;
  // The picker lists live suppliers only; an archived one is named from its rows.
  const supplierName = supplier
    ? (suppliers.find((s) => s.id === supplier)?.name ??
      rows.find((r) => r.supplierId === supplier)?.supplierName ??
      "Chosen supplier")
    : null;

  // Everything but the status chip, so each chip can show its own count.
  const base = useMemo(() => {
    const needle = q.trim().toLowerCase();
    return rows.filter((r) => {
      if (status && r.status !== status) return false;
      if (stageStatuses && !stageStatuses.includes(r.status)) return false;
      if (category && r.category !== category) return false;
      if (format && r.format !== format) return false;
      if (hall && (hall === "none" ? r.hallId !== null : r.hallId !== hall)) return false;
      if (location && (location === "none" ? r.locationId !== null : r.locationId !== location)) {
        return false;
      }
      if (supplier && r.supplierId !== supplier) return false;
      if (!needle) return true;
      return [
        r.ref,
        r.name,
        r.locationName ?? "",
        r.standNumber ?? "",
        r.hallName ?? "",
        r.typeName ?? "",
        r.sponsorName ?? "",
        r.supplierName ?? "",
      ]
        .join(" ")
        .toLowerCase()
        .includes(needle);
    });
  }, [rows, q, status, stageStatuses, category, format, hall, location, supplier]);

  const counts = useMemo(() => {
    const c: Record<string, number> = {};
    for (const r of base) for (const f of r.quick) c[f] = (c[f] ?? 0) + 1;
    return c;
  }, [base]);

  const filtered = useMemo(
    () => (show ? base.filter((r) => (r.quick as string[]).includes(show)) : base),
    [base, show],
  );

  const columns = useMemo<ColumnDef<ScheduleRow>[]>(() => {
    const selectCol: ColumnDef<ScheduleRow>[] = [
      {
        id: "select",
        enableHiding: false,
        enableSorting: false,
        header: ({ table }) => (
          <input
            type="checkbox"
            aria-label="Select all shown"
            className="size-4"
            checked={table.getIsAllRowsSelected()}
            ref={(el) => {
              if (el) el.indeterminate = table.getIsSomeRowsSelected();
            }}
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
    const dateSort = (a: string | null, b: string | null) =>
      a === b ? 0 : a === null ? 1 : b === null ? -1 : a < b ? -1 : 1;
    const cols: ColumnDef<ScheduleRow>[] = [
      ...(canEdit ? selectCol : []),
      {
        accessorKey: "ref",
        header: "Ref",
        enableHiding: false,
        cell: ({ row }) => (
          <Link
            href={itemPath(editionCode, row.original)}
            className="font-medium hover:underline"
            onClick={(e) => e.stopPropagation()}
          >
            {row.original.ref}
          </Link>
        ),
      },
      {
        accessorKey: "name",
        header: "Name",
        enableHiding: false,
        cell: ({ getValue }) => (
          <span className="block max-w-56 truncate" title={getValue<string>()}>
            {getValue<string>()}
          </span>
        ),
      },
      {
        accessorKey: "status",
        header: "Status",
        sortingFn: (a, b) =>
          STATUS_ORDER.indexOf(a.original.status) - STATUS_ORDER.indexOf(b.original.status),
        cell: ({ getValue }) => <StatusBadge status={getValue<string>()} />,
      },
      {
        id: "waitingOn",
        header: "Waiting on",
        accessorFn: (r) => waitingOn(r) ?? "",
        cell: ({ row }) => {
          const who = waitingOn(row.original);
          if (!who) return <span className="text-muted-foreground">—</span>;
          const overdue = row.original.pendingSteps.some((s) => s.overdue);
          return (
            <span
              className={cn("block max-w-56 truncate", overdue && "text-destructive font-medium")}
              title={overdue ? `${who} (overdue)` : who}
            >
              {who}
              {overdue && <span className="sr-only"> (overdue)</span>}
            </span>
          );
        },
      },
      {
        id: "place",
        header: "Hall · Location",
        accessorFn: (r) => place(r) ?? "",
        cell: ({ row }) => {
          const p = place(row.original);
          return p ? (
            <span className="block max-w-48 truncate" title={p}>
              {p}
            </span>
          ) : (
            <span className="text-muted-foreground">—</span>
          );
        },
      },
      {
        accessorKey: "standNumber",
        header: "Stand no.",
        cell: ({ row }) => row.original.standNumber ?? "—",
      },
      {
        accessorKey: "installDate",
        header: "Install",
        sortingFn: (a, b) => dateSort(a.original.installDate, b.original.installDate),
        cell: ({ row }) =>
          row.original.installDate ? (
            <span title={formatDate(row.original.installDate)}>
              {formatDayMonth(row.original.installDate)}
              {row.original.installSlot ? ` ${slotLabel(row.original.installSlot)}` : ""}
            </span>
          ) : (
            "—"
          ),
      },
      {
        accessorKey: "artworkDue",
        header: "Artwork due",
        sortingFn: (a, b) => dateSort(a.original.artworkDue, b.original.artworkDue),
        cell: ({ row }) => {
          const r = row.original;
          if (!r.artworkDue) return <span className="text-muted-foreground">—</span>;
          if (!artworkMatters(r)) {
            return (
              <span className="text-muted-foreground" title={formatDate(r.artworkDue)}>
                {formatDayMonth(r.artworkDue)}
              </span>
            );
          }
          const late = r.quick.includes("overdue") && r.currentVersion == null;
          return (
            <span
              className={late ? "text-destructive font-medium" : ""}
              title={formatDate(r.artworkDue)}
            >
              {formatDayMonth(r.artworkDue)}
              {late && " · overdue"}
            </span>
          );
        },
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
        id: "version",
        header: "Artwork",
        cell: ({ row }) => (row.original.currentVersion ? `v${row.original.currentVersion}` : "—"),
      },
    ];
    if (canSeeCosts) {
      cols.push(
        {
          accessorKey: "costEstimate",
          header: "Cost price",
          cell: ({ getValue }) => formatMoney(getValue<string | null>()),
        },
        {
          accessorKey: "costActual",
          header: "Actual cost",
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
    onColumnVisibilityChange: (updater) =>
      changeVisibility(typeof updater === "function" ? updater(visibility) : updater),
    onRowSelectionChange: setSelected,
    getRowId: (r) => r.id,
    getCoreRowModel: getCoreRowModel(),
    getSortedRowModel: getSortedRowModel(),
    enableRowSelection: canEdit,
  });

  // Only what is on screen counts as selected: a chip or search hides the rest.
  const visibleIds = new Set(filtered.map((r) => r.id));
  const selectedIds = Object.keys(selected).filter((k) => selected[k] && visibleIds.has(k));
  const sortedRows = table.getRowModel().rows;

  const grouped = useMemo(() => {
    if (!group) return null;
    const map = new Map<string, Row<ScheduleRow>[]>();
    for (const row of sortedRows) {
      const k = groupKeyOf(group, row.original);
      map.set(k, [...(map.get(k) ?? []), row]);
    }
    return sortGroups(group, [...map.keys()]).map((k) => [k, map.get(k)!] as const);
  }, [sortedRows, group]);

  function onBulkResult(result: BulkResult) {
    setLastResult(result);
    // The ones left alone stay selected, so they can be fixed and tried again.
    setSelected(Object.fromEntries(result.failures.map((f) => [f.id, true])));
    if (result.ok) toast.success(result.message);
    else if (result.failures.length > 0) toast(result.message);
    else toast.error(result.message);
    router.refresh();
  }

  function clearFilters() {
    void setQ(null);
    void setShow(null);
    void setStatus(null);
    void setStage(null);
    void setCategory(null);
    void setFormat(null);
    void setHall(null);
    void setLocation(null);
    void setSupplier(null);
    void setGroup(null);
  }

  const pills: { key: string; label: string; clear: () => void }[] = [
    ...(stage && stages[stage]
      ? [{ key: "stage", label: `Stage: ${stages[stage].label}`, clear: () => void setStage(null) }]
      : []),
    ...(status
      ? [
          {
            key: "status",
            label: `Status: ${statusLabel(status)}`,
            clear: () => void setStatus(null),
          },
        ]
      : []),
    ...(category
      ? [
          {
            key: "category",
            label: category === "sponsor" ? "Sponsor signage" : "Organiser signage",
            clear: () => void setCategory(null),
          },
        ]
      : []),
    ...(format
      ? [
          {
            key: "format",
            label: format === "digital" ? "Digital" : "Print",
            clear: () => void setFormat(null),
          },
        ]
      : []),
    ...(hall
      ? [
          {
            key: "hall",
            label: `Hall: ${hall === "none" ? "none" : (hallNames.find(([id]) => id === hall)?.[1] ?? "chosen hall")}`,
            clear: () => void setHall(null),
          },
        ]
      : []),
    ...(locationName
      ? [
          {
            key: "location",
            label: `Location: ${locationName}`,
            clear: () => void setLocation(null),
          },
        ]
      : []),
    ...(supplierName
      ? [
          {
            key: "supplier",
            label: `Supplier: ${supplierName}`,
            clear: () => void setSupplier(null),
          },
        ]
      : []),
  ];
  const filterMenuCount = [category, format, hall, group].filter(Boolean).length;
  const anyFilter = Boolean(q || show || pills.length || group);
  const chips = quickFilters.filter(
    (f) => (counts[f.key] ?? 0) > 0 || f.key === show || f.key === "mine",
  );
  const filterKey = JSON.stringify([
    q,
    show,
    status,
    stage,
    category,
    format,
    hall,
    location,
    supplier,
    group,
  ]);

  if (rows.length === 0) {
    return (
      <>
        <EmptyState
          icon={Signpost}
          title="No signs yet"
          description={
            canEdit
              ? "Add them one at a time, or import your spreadsheet."
              : "Signs appear here once Operations or Marketing add them."
          }
          action={
            canEdit && (
              <>
                <Button size="sm" asChild>
                  <Link href={`/${editionCode}/signage/new`}>
                    <Plus aria-hidden /> Add a sign
                  </Link>
                </Button>
                <Button size="sm" variant="outline" onClick={() => setImportOpen(true)}>
                  <FileSpreadsheet aria-hidden /> Import from Excel
                </Button>
                <Button size="sm" variant="ghost" asChild>
                  <a href="/api/exports/import-template" download>
                    <Download aria-hidden /> Download template
                  </a>
                </Button>
              </>
            )
          }
        />
        {canEdit && (
          <ImportSignsSheet editionId={editionId} open={importOpen} onOpenChange={setImportOpen} />
        )}
      </>
    );
  }

  return (
    <div className="flex flex-col gap-3">
      <div className="flex flex-wrap items-center gap-2">
        <Input
          type="search"
          value={q}
          onChange={(e) => void setQ(e.target.value || null)}
          placeholder="Search ref, name, location…"
          aria-label="Search signs"
          className="h-9 min-w-0 flex-1 sm:w-64 sm:flex-none"
        />
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button variant="outline" className="h-9">
              <ListFilter aria-hidden /> Filters
              {filterMenuCount > 0 && (
                <span className="bg-primary text-primary-foreground rounded-full px-1.5 text-xs tabular-nums">
                  {filterMenuCount}
                </span>
              )}
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="start" className="max-h-[70vh] w-60 overflow-y-auto">
            <DropdownMenuLabel>Whose signage</DropdownMenuLabel>
            <DropdownMenuRadioGroup
              value={category}
              onValueChange={(v) => void setCategory(v || null)}
            >
              <DropdownMenuRadioItem value="" onSelect={(e) => e.preventDefault()}>
                Organiser &amp; sponsor
              </DropdownMenuRadioItem>
              <DropdownMenuRadioItem value="organiser" onSelect={(e) => e.preventDefault()}>
                Organiser signage
              </DropdownMenuRadioItem>
              <DropdownMenuRadioItem value="sponsor" onSelect={(e) => e.preventDefault()}>
                Sponsor signage
              </DropdownMenuRadioItem>
            </DropdownMenuRadioGroup>
            <DropdownMenuSeparator />
            <DropdownMenuLabel>Print or digital</DropdownMenuLabel>
            <DropdownMenuRadioGroup value={format} onValueChange={(v) => void setFormat(v || null)}>
              <DropdownMenuRadioItem value="" onSelect={(e) => e.preventDefault()}>
                Print &amp; digital
              </DropdownMenuRadioItem>
              <DropdownMenuRadioItem value="print" onSelect={(e) => e.preventDefault()}>
                Print
              </DropdownMenuRadioItem>
              <DropdownMenuRadioItem value="digital" onSelect={(e) => e.preventDefault()}>
                Digital
              </DropdownMenuRadioItem>
            </DropdownMenuRadioGroup>
            {hallNames.length > 0 && (
              <>
                <DropdownMenuSeparator />
                <DropdownMenuLabel>Hall</DropdownMenuLabel>
                <DropdownMenuRadioGroup value={hall} onValueChange={(v) => void setHall(v || null)}>
                  <DropdownMenuRadioItem value="" onSelect={(e) => e.preventDefault()}>
                    Every hall
                  </DropdownMenuRadioItem>
                  {hallNames.map(([id, name]) => (
                    <DropdownMenuRadioItem key={id} value={id} onSelect={(e) => e.preventDefault()}>
                      {name}
                    </DropdownMenuRadioItem>
                  ))}
                  <DropdownMenuRadioItem value="none" onSelect={(e) => e.preventDefault()}>
                    No hall yet
                  </DropdownMenuRadioItem>
                </DropdownMenuRadioGroup>
              </>
            )}
            <DropdownMenuSeparator />
            <DropdownMenuLabel>Group by</DropdownMenuLabel>
            <DropdownMenuRadioGroup value={group} onValueChange={(v) => void setGroup(v || null)}>
              {GROUPS.map((g) => (
                <DropdownMenuRadioItem
                  key={g.key}
                  value={g.key}
                  onSelect={(e) => e.preventDefault()}
                >
                  {g.label}
                </DropdownMenuRadioItem>
              ))}
            </DropdownMenuRadioGroup>
          </DropdownMenuContent>
        </DropdownMenu>
        <div className="ml-auto flex items-center gap-2">
          {view !== "kanban" && (
            <DropdownMenu>
              <DropdownMenuTrigger asChild>
                <Button variant="outline" className="hidden h-9 sm:inline-flex">
                  <Columns3 aria-hidden /> Columns
                </Button>
              </DropdownMenuTrigger>
              <DropdownMenuContent align="end" className="w-52">
                <DropdownMenuLabel>Show columns</DropdownMenuLabel>
                {table
                  .getAllLeafColumns()
                  .filter((c) => c.getCanHide())
                  .map((col) => (
                    <DropdownMenuCheckboxItem
                      key={col.id}
                      checked={col.getIsVisible()}
                      onSelect={(e) => e.preventDefault()}
                      onCheckedChange={(v) => col.toggleVisibility(Boolean(v))}
                    >
                      {typeof col.columnDef.header === "string" ? col.columnDef.header : col.id}
                    </DropdownMenuCheckboxItem>
                  ))}
              </DropdownMenuContent>
            </DropdownMenu>
          )}
          <SegmentGroup label="View">
            <button
              type="button"
              className={segmentClass(view !== "kanban")}
              aria-pressed={view !== "kanban"}
              aria-label="Table view"
              onClick={() => void setView(null)}
            >
              <Table2 className="size-4" aria-hidden />
              <span className="hidden sm:inline">Table</span>
            </button>
            <button
              type="button"
              className={segmentClass(view === "kanban")}
              aria-pressed={view === "kanban"}
              aria-label="Kanban view"
              onClick={() => void setView("kanban")}
            >
              <Kanban className="size-4" aria-hidden />
              <span className="hidden sm:inline">Kanban</span>
            </button>
          </SegmentGroup>
        </div>
      </div>

      <div
        role="group"
        aria-label="Show"
        className="-mx-4 flex gap-1.5 overflow-x-auto px-4 pb-1 sm:mx-0 sm:flex-wrap sm:px-0"
      >
        <ChipButton active={!show} onClick={() => void setShow(null)} count={base.length}>
          All
        </ChipButton>
        {chips.map((c) => (
          <ChipButton
            key={c.key}
            active={show === c.key}
            tone={c.key === "overdue" ? "danger" : undefined}
            onClick={() => void setShow(show === c.key ? null : c.key)}
            count={counts[c.key] ?? 0}
          >
            {c.label}
          </ChipButton>
        ))}
      </div>

      {(pills.length > 0 || anyFilter) && (
        <div className="flex flex-wrap items-center gap-1.5 text-sm">
          {pills.map((p) => (
            <button
              key={p.key}
              type="button"
              onClick={p.clear}
              aria-label={`Remove filter: ${p.label}`}
              className="bg-muted hover:bg-accent inline-flex h-8 items-center gap-1 rounded-full px-3"
            >
              {p.label} <X className="size-3.5" aria-hidden />
            </button>
          ))}
          {anyFilter && (
            <Button size="sm" variant="ghost" onClick={clearFilters}>
              Clear filters
            </Button>
          )}
          <span className="text-muted-foreground ml-auto text-xs">
            {filtered.length === rows.length
              ? `${rows.length} signs`
              : `${filtered.length} of ${rows.length} signs`}
          </span>
        </div>
      )}

      {lastResult && (
        <div
          role="status"
          className={cn(
            "flex items-start gap-3 rounded-lg border px-3 py-2 text-sm",
            lastResult.ok
              ? "border-emerald-200 bg-emerald-50 text-emerald-900 dark:border-emerald-900 dark:bg-emerald-950 dark:text-emerald-200"
              : "border-amber-300 bg-amber-50 text-amber-900 dark:border-amber-900 dark:bg-amber-950 dark:text-amber-200",
          )}
        >
          <div className="min-w-0 flex-1 space-y-1">
            <p className="font-medium">{lastResult.message}</p>
            {lastResult.failures.length > 0 && (
              <>
                <ul className="space-y-0.5">
                  {lastResult.failures.slice(0, 8).map((f) => {
                    const row = rows.find((r) => r.id === f.id);
                    return (
                      <li key={f.id}>
                        {row ? (
                          <Link href={itemPath(editionCode, row)} className="link font-medium">
                            {f.ref}
                          </Link>
                        ) : (
                          <span className="font-medium">{f.ref}</span>
                        )}{" "}
                        — {f.reason}
                      </li>
                    );
                  })}
                </ul>
                {lastResult.failures.length > 8 && (
                  <p>…and {lastResult.failures.length - 8} more.</p>
                )}
                <p className="text-xs">
                  They are still selected, so you can fix them and try again.
                </p>
              </>
            )}
          </div>
          <button
            type="button"
            className="-m-1 rounded p-1 hover:bg-black/5"
            aria-label="Dismiss"
            onClick={() => setLastResult(null)}
          >
            <X className="size-4" aria-hidden />
          </button>
        </div>
      )}

      {canEdit && selectedIds.length > 0 && (
        <BulkActionsBar
          selectedIds={selectedIds}
          suppliers={suppliers}
          canEditCosts={canEditCosts}
          canDelete={canDelete}
          canClose={canClose}
          onResult={onBulkResult}
          onClear={() => setSelected({})}
        />
      )}

      {filtered.length === 0 ? (
        <EmptyState
          icon={SearchX}
          title="No signs match"
          description="Nothing matches this search and these filters."
          action={
            <Button size="sm" variant="outline" onClick={clearFilters}>
              Clear filters
            </Button>
          }
        />
      ) : view === "kanban" ? (
        <KanbanView editionCode={editionCode} rows={filtered} />
      ) : (
        <>
          <PhoneList
            key={filterKey}
            editionCode={editionCode}
            rows={sortedRows.map((r) => r.original)}
            group={group}
            className="sm:hidden"
          />
          <div className="hidden sm:block">
            <ScrollX className="max-h-[70vh] rounded-lg border" label="schedule">
              <table className="relative w-full text-sm">
                {/* Opaque header: rows scroll underneath it inside the capped box. */}
                <thead className="bg-muted sticky top-0 z-10">
                  {table.getHeaderGroups().map((hg) => (
                    <tr key={hg.id} className="border-b text-left">
                      {hg.headers.map((h) => {
                        const sorted = h.column.getIsSorted();
                        return (
                          <th
                            key={h.id}
                            className="text-muted-foreground px-2.5 py-2 font-medium whitespace-nowrap"
                            aria-sort={
                              sorted === "asc"
                                ? "ascending"
                                : sorted === "desc"
                                  ? "descending"
                                  : undefined
                            }
                          >
                            {h.isPlaceholder ? null : h.column.getCanSort() ? (
                              <button
                                type="button"
                                className="flex items-center gap-1 hover:underline"
                                onClick={h.column.getToggleSortingHandler()}
                              >
                                {flexRender(h.column.columnDef.header, h.getContext())}
                                <ArrowUpDown className="size-3 opacity-40" aria-hidden />
                              </button>
                            ) : (
                              flexRender(h.column.columnDef.header, h.getContext())
                            )}
                          </th>
                        );
                      })}
                    </tr>
                  ))}
                </thead>
                <tbody>
                  {(grouped ?? [["", sortedRows] as const]).map(([label, groupRows]) => (
                    <Fragment key={label || "all"}>
                      {grouped && (
                        <tr className="bg-muted/40 border-b">
                          <th
                            colSpan={table.getVisibleLeafColumns().length}
                            scope="colgroup"
                            className="text-muted-foreground px-3 py-1.5 text-left text-xs font-semibold tracking-wide uppercase"
                          >
                            {label} · {groupRows.length}
                          </th>
                        </tr>
                      )}
                      {groupRows.map((row) => (
                        <tr
                          key={row.id}
                          className={cn(
                            "hover:bg-muted/30 cursor-pointer border-b last:border-0",
                            row.getIsSelected() && "bg-primary/5",
                          )}
                          onClick={() => router.push(itemPath(editionCode, row.original))}
                        >
                          {row.getVisibleCells().map((cell) => (
                            <td key={cell.id} className="px-2.5 py-2 whitespace-nowrap">
                              {flexRender(cell.column.columnDef.cell, cell.getContext())}
                            </td>
                          ))}
                        </tr>
                      ))}
                    </Fragment>
                  ))}
                </tbody>
              </table>
            </ScrollX>
          </div>
        </>
      )}
    </div>
  );
}

function ChipButton({
  active,
  count,
  tone,
  onClick,
  children,
}: {
  active: boolean;
  count: number;
  tone?: "danger";
  onClick: () => void;
  children: React.ReactNode;
}) {
  return (
    <button
      type="button"
      aria-pressed={active}
      onClick={onClick}
      className={cn(
        "inline-flex h-9 shrink-0 items-center gap-1.5 rounded-full border px-3 text-sm whitespace-nowrap transition-colors",
        "focus-visible:ring-ring focus-visible:ring-2 focus-visible:outline-none",
        active
          ? "bg-primary text-primary-foreground border-primary"
          : "bg-background hover:bg-accent text-foreground",
      )}
    >
      {children}
      <span
        className={cn(
          "rounded-full px-1.5 text-xs tabular-nums",
          active
            ? "bg-primary-foreground/20"
            : tone === "danger" && count > 0
              ? "bg-rose-100 text-rose-800 dark:bg-rose-950 dark:text-rose-300"
              : "bg-muted",
        )}
      >
        {count}
      </span>
    </button>
  );
}

/** Phone layout: a card per item, 20 at a time, grouped when asked. */
function PhoneList({
  rows,
  editionCode,
  group,
  className,
}: {
  rows: ScheduleRow[];
  editionCode: string;
  group: string;
  className?: string;
}) {
  const [limits, setLimits] = useState<Record<string, number>>({});
  const more = (key: string) => setLimits((l) => ({ ...l, [key]: (l[key] ?? PAGE) + PAGE }));

  const list = (key: string, items: ScheduleRow[]) => {
    const limit = limits[key] ?? PAGE;
    return (
      <>
        <ul className="space-y-2">
          {items.slice(0, limit).map((r) => (
            <li key={r.id}>
              <ItemCard r={r} editionCode={editionCode} />
            </li>
          ))}
        </ul>
        {items.length > limit && (
          <div className="mt-2 flex flex-col items-center gap-1">
            <Button variant="outline" className="h-11 w-full" onClick={() => more(key)}>
              Show {Math.min(PAGE, items.length - limit)} more
            </Button>
            <p className="text-muted-foreground text-xs">
              Showing {limit} of {items.length}
            </p>
          </div>
        )}
      </>
    );
  };

  if (!group) return <div className={className}>{list("all", rows)}</div>;
  const map = new Map<string, ScheduleRow[]>();
  for (const r of rows) {
    const k = groupKeyOf(group, r);
    map.set(k, [...(map.get(k) ?? []), r]);
  }
  return (
    <div className={cn("space-y-3", className)}>
      {sortGroups(group, [...map.keys()]).map((k) => (
        <details key={k} open className="group">
          <summary className="bg-background sticky top-0 z-10 flex min-h-11 cursor-pointer items-center py-2 text-sm font-semibold select-none">
            {k} · {map.get(k)!.length}
          </summary>
          {list(k, map.get(k)!)}
        </details>
      ))}
    </div>
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
  const who = waitingOn(r);
  const overdue = r.pendingSteps.some((s) => s.overdue);
  const firstDue = r.pendingSteps.find((s) => s.dueAt)?.dueAt ?? null;
  const artworkLate = artworkMatters(r) && r.quick.includes("overdue") && r.currentVersion == null;
  return (
    <Link
      href={itemPath(editionCode, r)}
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
        {[place(r), r.standNumber ? `Stand ${r.standNumber}` : null].filter(Boolean).join(" · ") ||
          "No location"}
        {who && (
          <>
            {" · "}
            <span className={overdue ? "text-destructive font-medium" : ""}>
              Waiting on {who}
              {firstDue ? ` — due ${formatDayMonth(firstDue)}` : ""}
            </span>
          </>
        )}
        {artworkMatters(r) && r.artworkDue && (
          <>
            {" · "}
            <span className={artworkLate ? "text-destructive font-medium" : ""}>
              artwork due {formatDayMonth(r.artworkDue)}
              {artworkLate ? " (overdue)" : ""}
            </span>
          </>
        )}
      </p>
    </Link>
  );
}

function KanbanView({ editionCode, rows }: { editionCode: string; rows: ScheduleRow[] }) {
  const byStatus = new Map<string, ScheduleRow[]>();
  for (const r of rows) byStatus.set(r.status, [...(byStatus.get(r.status) ?? []), r]);
  const columns = STATUS_ORDER.filter((s) => byStatus.has(s));
  return (
    <div className="flex gap-3 overflow-x-auto pb-2">
      {columns.map((statusKey) => (
        <section
          key={statusKey}
          aria-label={statusLabel(statusKey)}
          className="bg-muted/30 w-72 shrink-0 rounded-lg border p-2"
        >
          <div className="mb-2 flex items-center justify-between px-1">
            <StatusBadge status={statusKey} />
            <span className="text-muted-foreground text-xs">{byStatus.get(statusKey)!.length}</span>
          </div>
          <div className="space-y-2">
            {byStatus.get(statusKey)!.map((r) => (
              <ItemCard key={r.id} r={r} editionCode={editionCode} showStatus={false} />
            ))}
          </div>
        </section>
      ))}
    </div>
  );
}
