import { describe, expect, it } from "vitest";
import {
  itemProgress,
  missingSubmitFields,
  newArtworkSinceChanges,
  nextStep,
  signoffReadiness,
  signoffRequiredFields,
  specLocked,
  submitBlockedReason,
  type NextStepInput,
} from "@/lib/domain/signage";

const ready = {
  kind: "signage" as const,
  hallId: "h",
  locationId: "l",
  itemTypeId: "t",
  widthMm: 1000,
  heightMm: 500,
  quantity: 1,
  fixingMethod: "rigged",
  supplierId: "s",
  currentArtworkVersionId: "v1",
};

describe("sign-off readiness checklist", () => {
  it("a complete sign with artwork and a supplier is ready", () => {
    const r = signoffReadiness(ready);
    expect(r.fieldsReady).toBe(true);
    expect(r.hasArtwork).toBe(true);
    expect(r.lines.every((l) => l.done)).toBe(true);
  });

  it("lists what a sign still needs, each pointing at its field", () => {
    const r = signoffReadiness({
      ...ready,
      locationId: null,
      widthMm: null,
      fixingMethod: null,
      supplierId: null,
      currentArtworkVersionId: null,
    });
    expect(r.fieldsReady).toBe(false);
    const missing = r.lines.filter((l) => !l.done);
    expect(missing.map((l) => l.label)).toEqual([
      "Hall and location",
      "Size",
      "Fixing method",
      "Artwork",
      "Supplier (needed before print)",
    ]);
    expect(missing.find((l) => l.key === "size")?.field).toBe("widthMm");
    expect(missing.find((l) => l.key === "where")?.field).toBe("locationId");
    // Artwork and supplier don't stop it going for sign-off.
    expect(missing.filter((l) => l.blocking).map((l) => l.key)).toEqual([
      "where",
      "size",
      "fixing",
    ]);
  });

  it("agrees with the server's submit check for every kind", () => {
    const blank = {
      hallId: null,
      locationId: null,
      itemTypeId: null,
      widthMm: null,
      heightMm: null,
      quantity: 1,
      fixingMethod: null,
      supplierId: null,
      currentArtworkVersionId: null,
    };
    for (const kind of ["signage", "sponsorship_item", "stand_design", "stand_panel"] as const) {
      for (const item of [
        { ...blank, kind },
        { ...ready, kind },
      ]) {
        const r = signoffReadiness(item);
        expect(r.fieldsReady, kind).toBe(missingSubmitFields(item).length === 0);
        expect(
          r.lines.some((l) => l.blocking && !l.done),
          kind,
        ).toBe(!r.fieldsReady);
      }
    }
  });

  it("sponsorship items need no hall, size or fixing; stand designs need only the design", () => {
    const sponsorship = signoffReadiness({ ...ready, kind: "sponsorship_item", hallId: null });
    expect(sponsorship.lines.map((l) => l.key)).toEqual(["type", "artwork", "supplier"]);
    const stand = signoffReadiness({ ...ready, kind: "stand_design" });
    expect(stand.lines.map((l) => l.label)).toEqual(["Design"]);
  });

  it("says what to add before it can be sent", () => {
    const r = signoffReadiness({ ...ready, widthMm: null, fixingMethod: null });
    expect(submitBlockedReason(r)).toBe("Add size and fixing method first");
    expect(submitBlockedReason(signoffReadiness(ready))).toBeNull();
  });

  it("names the form fields that sign-off needs", () => {
    expect(signoffRequiredFields("signage")).toEqual([
      "hallId",
      "locationId",
      "itemTypeId",
      "widthMm",
      "heightMm",
      "fixingMethod",
    ]);
    expect(signoffRequiredFields("sponsorship_item")).toEqual(["itemTypeId"]);
    expect(signoffRequiredFields("stand_design")).toEqual([]);
  });
});

describe("new artwork since changes were asked for", () => {
  it("is new when the current version differs from the one the request was made on", () => {
    expect(newArtworkSinceChanges("v1", "v2")).toBe(true);
    expect(newArtworkSinceChanges(null, "v1")).toBe(true);
  });
  it("is not new when nothing was uploaded since", () => {
    expect(newArtworkSinceChanges("v1", "v1")).toBe(false);
    expect(newArtworkSinceChanges(null, null)).toBe(false);
  });
});

describe("spec lock", () => {
  it("locks the spec once installed", () => {
    expect(specLocked("installed")).toBe(true);
    expect(specLocked("snagged")).toBe(true);
    expect(specLocked("closed")).toBe(true);
    expect(specLocked("delivered")).toBe(false);
    expect(specLocked("draft")).toBe(false);
  });
});

const can = { edit: true, submit: true, upload: true, close: true, reopen: true, resume: true };
const input = (over: Partial<NextStepInput> = {}): NextStepInput => ({
  kind: "signage",
  status: "draft",
  onHoldReason: null,
  readiness: signoffReadiness(ready),
  pending: [],
  changeRequest: null,
  rejection: null,
  newArtworkSinceChanges: false,
  openSnags: 0,
  can,
  now: new Date("2026-10-16T10:00:00Z"),
  ...over,
});

describe("next step", () => {
  it("a draft missing fields asks for them, with the checklist", () => {
    const s = nextStep(
      input({ readiness: signoffReadiness({ ...ready, widthMm: null, fixingMethod: null }) }),
    );
    expect(s.title).toBe("Next: add size and fixing method so it can go for sign-off");
    expect(s.action).toEqual({ type: "link", label: "Edit details", href: "?tab=details&edit=1" });
    expect(s.secondary).toEqual({
      type: "submit",
      label: "Send for sign-off",
      disabledReason: "Add size and fixing method first",
    });
    expect(s.showChecklist).toBe(true);
  });

  it("a ready draft without artwork asks for it; with artwork it can be sent", () => {
    const noArt = nextStep(
      input({ readiness: signoffReadiness({ ...ready, currentArtworkVersionId: null }) }),
    );
    expect(noArt.title).toBe("Next: upload the artwork");
    expect(noArt.action).toEqual({
      type: "link",
      label: "Upload artwork",
      href: "?tab=artwork#upload",
    });
    expect(noArt.secondary).toEqual({ type: "submit", label: "Ready for artwork" });
    const withArt = nextStep(input());
    expect(withArt.action).toEqual({ type: "submit", label: "Send for sign-off" });
  });

  it("without the right to act, a draft only explains", () => {
    const s = nextStep(input({ can: { ...can, submit: false, upload: false, edit: false } }));
    expect(s.action).toBeNull();
  });

  it("in sign-off: says who it waits on, and when overdue", () => {
    const s = nextStep(
      input({
        status: "in_review",
        pending: [
          {
            id: "i1",
            stepName: "Operations sign-off",
            stepKind: "approval",
            who: "Anyone in Operations",
            dueAt: new Date("2026-09-23T17:00:00Z"),
            canDecide: false,
          },
        ],
      }),
    );
    expect(s.title).toBe("Waiting on Anyone in Operations");
    expect(s.detail).toBe("Operations sign-off — overdue since 23 Sept 2026");
    expect(s.tone).toBe("warning");
    expect(s.action).toBeNull();
  });

  it("in sign-off and it's my turn: review the artwork", () => {
    const s = nextStep(
      input({
        status: "in_review",
        pending: [
          {
            id: "i1",
            stepName: "Marketing sign-off",
            stepKind: "approval",
            who: "Anyone in Marketing",
            dueAt: null,
            canDecide: true,
          },
        ],
      }),
    );
    expect(s.title).toBe("Your sign-off: Marketing sign-off");
    expect(s.action).toEqual({
      type: "link",
      label: "Review artwork",
      href: "?tab=artwork#your-decision",
    });
  });

  it("changes requested: upload the corrected version, or resubmit once uploaded", () => {
    const changeRequest = {
      stepName: "Marketing sign-off",
      deciderName: "Mia Marketing",
      comment: "Please revise",
    };
    const s = nextStep(input({ status: "changes_requested", changeRequest }));
    expect(s.title).toBe("Mia Marketing asked for changes");
    expect(s.detail).toBe("“Please revise”");
    expect(s.action).toEqual({
      type: "link",
      label: "Upload new version",
      href: "?tab=artwork#upload",
    });
    expect(s.secondary).toEqual({
      type: "resubmit",
      label: "Resubmit without changes",
      confirm: true,
    });
    const uploaded = nextStep(
      input({ status: "changes_requested", changeRequest, newArtworkSinceChanges: true }),
    );
    expect(uploaded.action).toEqual({
      type: "resubmit",
      label: "Send back for sign-off",
      confirm: false,
    });
  });

  it("approved: confirm print, but only with a supplier", () => {
    const pending = [
      {
        id: "p1",
        stepName: "Sent to print",
        stepKind: "confirmation" as const,
        who: "Big Print Co",
        dueAt: null,
        canDecide: true,
      },
    ];
    const s = nextStep(input({ status: "approved", pending }));
    expect(s.title).toBe("Signed off. Next: confirm it has gone to print");
    expect(s.action).toEqual({
      type: "confirm",
      instanceId: "p1",
      stepName: "Sent to print",
      label: "Confirm sent to print",
    });
    const noSupplier = nextStep(
      input({
        status: "approved",
        pending,
        readiness: signoffReadiness({ ...ready, supplierId: null }),
      }),
    );
    expect(noSupplier.detail).toBe("Set the supplier first — nothing goes to print without one.");
    expect(noSupplier.action).toEqual({
      type: "link",
      label: "Set the supplier",
      href: "?tab=details&edit=1#supplierId",
    });
  });

  it("walks through delivery, install, snags and completion", () => {
    const confirm = (stepName: string) => [
      {
        id: "c",
        stepName,
        stepKind: "confirmation" as const,
        who: "Operations",
        dueAt: null,
        canDecide: true,
      },
    ];
    expect(
      nextStep(input({ status: "in_production", pending: confirm("Delivered") })).action,
    ).toMatchObject({ type: "confirm", label: "Confirm delivered" });
    expect(
      nextStep(input({ status: "delivered", pending: confirm("Installed") })).action,
    ).toMatchObject({ type: "confirm", label: "Confirm installed" });
    expect(nextStep(input({ status: "installed" })).action).toEqual({
      type: "close",
      label: "Mark complete",
    });
    const snagged = nextStep(input({ status: "snagged", openSnags: 2 }));
    expect(snagged.title).toBe("2 snags open — fix them to finish");
    expect(snagged.action).toEqual({
      type: "link",
      label: "View snags",
      href: "?tab=details#snags",
    });
    expect(nextStep(input({ status: "closed" })).tone).toBe("done");
  });

  it("someone else's confirmation: says who it waits on", () => {
    const s = nextStep(
      input({
        status: "in_production",
        pending: [
          {
            id: "c",
            stepName: "Delivered",
            stepKind: "confirmation",
            who: "Big Print Co",
            dueAt: null,
            canDecide: false,
          },
        ],
      }),
    );
    expect(s.title).toBe("Sent to print. Waiting on Big Print Co to confirm delivery");
    expect(s.action).toBeNull();
  });

  it("on hold and rejected offer the way back", () => {
    const held = nextStep(input({ status: "on_hold", onHoldReason: "Sponsor undecided" }));
    expect(held.title).toBe("On hold: Sponsor undecided");
    expect(held.action).toEqual({ type: "resume", label: "Resume" });
    const rejected = nextStep(
      input({
        status: "rejected",
        rejection: { stepName: "Venue approval", deciderName: "Vic Venue", comment: "No rigging" },
      }),
    );
    expect(rejected.title).toBe("Rejected by Vic Venue");
    expect(rejected.action).toEqual({ type: "reopen", label: "Reopen as a draft" });
  });

  it("an approved stand design moves on to its panels", () => {
    const s = nextStep(input({ kind: "stand_design", status: "approved" }));
    expect(s.action).toEqual({ type: "link", label: "Add panels", href: "?tab=panels" });
  });
});

describe("progress stepper", () => {
  const states = (p: ReturnType<typeof itemProgress>) => p.map((s) => `${s.label}:${s.state}`);

  it("follows a sign from details to complete", () => {
    expect(
      states(itemProgress("signage", "draft", { fieldsReady: false, hasArtwork: false })),
    ).toEqual([
      "Details:current",
      "Artwork:todo",
      "Sign-off:todo",
      "Print:todo",
      "Delivered:todo",
      "Installed:todo",
      "Complete:todo",
    ]);
    expect(
      itemProgress("signage", "draft", { fieldsReady: true, hasArtwork: false }).find(
        (s) => s.state === "current",
      )?.label,
    ).toBe("Artwork");
    const current = (status: string) =>
      itemProgress("signage", status, { fieldsReady: true, hasArtwork: true }).find(
        (s) => s.state === "current",
      )?.label;
    expect(current("in_review")).toBe("Sign-off");
    expect(current("approved")).toBe("Print");
    expect(current("in_production")).toBe("Delivered");
    expect(current("delivered")).toBe("Installed");
    expect(current("snagged")).toBe("Complete");
    expect(
      itemProgress("signage", "closed", { fieldsReady: true, hasArtwork: true }).every(
        (s) => s.state === "done",
      ),
    ).toBe(true);
  });

  it("an item on hold shows where it was", () => {
    const p = itemProgress("signage", "on_hold", {
      fieldsReady: true,
      hasArtwork: true,
      previousStatus: "in_production",
    });
    expect(p.find((s) => s.state === "current")?.label).toBe("Delivered");
  });

  it("a stand design has its own stages", () => {
    expect(
      itemProgress("stand_design", "in_review", { fieldsReady: true, hasArtwork: true }).map(
        (s) => s.label,
      ),
    ).toEqual(["Stand", "Design", "Sign-off", "Panels"]);
  });
});
