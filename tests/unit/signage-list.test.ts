import { describe, expect, it } from "vitest";
import {
  QUICK_FILTERS,
  SIGNAGE_STAGES,
  bulkConfirmSkipReason,
  isMineRow,
  quickFiltersFor,
  stageOf,
  stageStatuses,
  stepStillDue,
} from "@/lib/domain/signage";
import type { StaffActor } from "@/lib/authz";
import type { SignageStatus } from "@/lib/status/signage";

const ALL: SignageStatus[] = [
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

describe("dashboard stages (?stage=)", () => {
  it("maps each stage to its statuses", () => {
    expect(stageStatuses("getting_ready")).toEqual(["draft", "awaiting_artwork", "on_hold"]);
    expect(stageStatuses("in_signoff")).toEqual(["in_review", "changes_requested"]);
    expect(stageStatuses("production")).toEqual([
      "approved",
      "approved_with_conditions",
      "in_production",
      "delivered",
    ]);
    expect(stageStatuses("onsite")).toEqual(["installed", "snagged", "closed"]);
  });

  it("ignores an unknown stage rather than hiding everything", () => {
    expect(stageStatuses("nonsense")).toBeNull();
    expect(stageStatuses(null)).toBeNull();
    expect(stageStatuses("")).toBeNull();
  });

  it("puts every status but Rejected in exactly one stage", () => {
    for (const status of ALL) {
      const stages = Object.entries(SIGNAGE_STAGES).filter(([, list]) =>
        (list as readonly string[]).includes(status),
      );
      expect(stages.length, status).toBe(status === "rejected" ? 0 : 1);
      expect(stageOf(status)).toBe(stages[0]?.[0] ?? null);
    }
  });
});

const row = (over: Partial<Parameters<typeof quickFiltersFor>[0]> = {}) => ({
  status: "draft" as string,
  hasArtwork: false,
  overdue: false,
  mine: false,
  ...over,
});

describe("quick filters (status chips)", () => {
  it("a draft without artwork needs artwork; with artwork it is not sent yet", () => {
    expect(quickFiltersFor(row())).toEqual(["needs_artwork"]);
    expect(quickFiltersFor(row({ status: "awaiting_artwork" }))).toEqual(["needs_artwork"]);
    expect(quickFiltersFor(row({ hasArtwork: true }))).toEqual(["not_sent"]);
  });

  it("maps the later statuses to one chip each", () => {
    const one = (status: string) => quickFiltersFor(row({ status, hasArtwork: true }));
    expect(one("in_review")).toEqual(["in_signoff"]);
    expect(one("changes_requested")).toEqual(["changes_requested"]);
    expect(one("approved")).toEqual(["ready_to_print"]);
    expect(one("approved_with_conditions")).toEqual(["ready_to_print"]);
    expect(one("in_production")).toEqual(["sent_to_print"]);
    expect(one("delivered")).toEqual(["delivered"]);
    expect(one("installed")).toEqual(["onsite"]);
    expect(one("snagged")).toEqual(["onsite"]);
    expect(one("closed")).toEqual([]);
    expect(one("rejected")).toEqual([]);
    expect(one("on_hold")).toEqual([]);
  });

  it("adds Overdue and Mine on top of the status chip", () => {
    expect(quickFiltersFor(row({ status: "in_review", overdue: true, mine: true }))).toEqual([
      "in_signoff",
      "overdue",
      "mine",
    ]);
  });

  it("only uses known chip keys", () => {
    for (const status of ALL) {
      for (const f of quickFiltersFor(row({ status, overdue: true, mine: true }))) {
        expect(QUICK_FILTERS).toContain(f);
      }
    }
  });
});

const actor = (over: Partial<StaffActor> = {}): StaffActor => ({
  kind: "staff",
  userId: "me",
  organisationId: "org",
  role: "marketing",
  signoffDepartmentIds: ["dept-mkt"],
  ...over,
});

const step = (over: Partial<Parameters<typeof isMineRow>[0]["pendingSteps"][number]> = {}) => ({
  stepKind: "approval" as const,
  assignedRole: null as string | null,
  assignedUserId: null as string | null,
  assignedDepartmentId: null as string | null,
  ...over,
});

describe("Mine", () => {
  it("is mine when I own it", () => {
    expect(isMineRow({ ownerUserId: "me", pendingSteps: [] }, actor())).toBe(true);
    expect(isMineRow({ ownerUserId: "you", pendingSteps: [] }, actor())).toBe(false);
  });

  it("is mine when a waiting sign-off names me or my department", () => {
    expect(
      isMineRow({ ownerUserId: null, pendingSteps: [step({ assignedUserId: "me" })] }, actor()),
    ).toBe(true);
    expect(
      isMineRow(
        { ownerUserId: null, pendingSteps: [step({ assignedDepartmentId: "dept-mkt" })] },
        actor(),
      ),
    ).toBe(true);
    expect(
      isMineRow(
        { ownerUserId: null, pendingSteps: [step({ assignedDepartmentId: "dept-ops" })] },
        actor(),
      ),
    ).toBe(false);
  });

  it("a step named for someone else is not mine, even in my department", () => {
    expect(
      isMineRow(
        {
          ownerUserId: null,
          pendingSteps: [step({ assignedUserId: "you", assignedDepartmentId: "dept-mkt" })],
        },
        actor(),
      ),
    ).toBe(false);
  });

  it("an admin's power to decide anything does not make everything theirs", () => {
    expect(
      isMineRow(
        { ownerUserId: null, pendingSteps: [step({ assignedRole: "ops" })] },
        actor({ role: "admin", signoffDepartmentIds: [] }),
      ),
    ).toBe(false);
  });

  it("operations count the supplier confirmations they can do themselves", () => {
    const supplierStep = step({ stepKind: "confirmation", assignedRole: "supplier" });
    expect(
      isMineRow({ ownerUserId: null, pendingSteps: [supplierStep] }, actor({ role: "ops" })),
    ).toBe(true);
    expect(isMineRow({ ownerUserId: null, pendingSteps: [supplierStep] }, actor())).toBe(false);
  });

  it("role-assigned steps belong to that role", () => {
    expect(
      isMineRow(
        { ownerUserId: null, pendingSteps: [step({ assignedRole: "marketing" })] },
        actor(),
      ),
    ).toBe(true);
  });
});

describe("bulk confirmations: why an item is skipped", () => {
  const base = {
    status: "approved",
    supplierId: "sup",
    pendingStepNames: ["Sent to print"],
    canDecide: true,
  };

  it("confirms an approved item with a supplier", () => {
    expect(bulkConfirmSkipReason("Sent to print", base)).toBeNull();
  });

  it("explains each skip for Sent to print", () => {
    expect(bulkConfirmSkipReason("Sent to print", { ...base, status: "in_review" })).toBe(
      "not signed off yet",
    );
    expect(bulkConfirmSkipReason("Sent to print", { ...base, status: "in_production" })).toBe(
      "already sent to print",
    );
    expect(bulkConfirmSkipReason("Sent to print", { ...base, status: "on_hold" })).toBe("on hold");
    expect(bulkConfirmSkipReason("Sent to print", { ...base, supplierId: null })).toBe(
      "no supplier set",
    );
    expect(bulkConfirmSkipReason("Sent to print", { ...base, pendingStepNames: [] })).toBe(
      "nothing waiting to confirm",
    );
    expect(bulkConfirmSkipReason("Sent to print", { ...base, canDecide: false })).toBe(
      "not yours to confirm",
    );
  });

  it("explains each skip for Delivered", () => {
    const delivered = { ...base, status: "in_production", pendingStepNames: ["Delivered"] };
    expect(bulkConfirmSkipReason("Delivered", delivered)).toBeNull();
    // The supplier is not needed to confirm a delivery.
    expect(bulkConfirmSkipReason("Delivered", { ...delivered, supplierId: null })).toBeNull();
    expect(bulkConfirmSkipReason("Delivered", { ...delivered, status: "approved" })).toBe(
      "not sent to print yet",
    );
    expect(bulkConfirmSkipReason("Delivered", { ...delivered, status: "draft" })).toBe(
      "not signed off yet",
    );
    expect(bulkConfirmSkipReason("Delivered", { ...delivered, status: "installed" })).toBe(
      "already delivered",
    );
  });
});

describe("what a row is really waiting on", () => {
  const confirmation = (stepName: string) => ({ stepKind: "confirmation" as const, stepName });
  it("a production confirmation waits only at its own stage", () => {
    expect(stepStillDue(confirmation("Sent to print"), "approved")).toBe(true);
    expect(stepStillDue(confirmation("Sent to print"), "installed")).toBe(false);
    expect(stepStillDue(confirmation("Delivered"), "in_production")).toBe(true);
    expect(stepStillDue(confirmation("Delivered"), "closed")).toBe(false);
    expect(stepStillDue(confirmation("Installed"), "delivered")).toBe(true);
  });
  it("sign-offs, unknown confirmations and held items are left as they are", () => {
    expect(stepStillDue({ stepKind: "approval", stepName: "Operations sign-off" }, "draft")).toBe(
      true,
    );
    expect(stepStillDue(confirmation("Build check"), "installed")).toBe(true);
    expect(stepStillDue(confirmation("Sent to print"), "on_hold")).toBe(true);
  });
});
