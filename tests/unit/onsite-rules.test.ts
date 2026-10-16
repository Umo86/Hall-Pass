import { describe, expect, it } from "vitest";
import {
  confirmLabel,
  inOnsiteView,
  matchesOnsiteSearch,
  onsiteAction,
  onsiteSection,
  parseOnsiteView,
  snagLabel,
} from "@/components/onsite/rules";

const pending = (
  over: Partial<NonNullable<Parameters<typeof onsiteAction>[0]["pending"]>> = {},
) => ({
  id: "i1",
  stepName: "Delivered",
  isInstall: false,
  who: "Big Print Co",
  canDecide: true,
  viewerHolds: true,
  ...over,
});

describe("onsiteAction", () => {
  it("offers Delivered ✓ on an item still with the printer", () => {
    expect(
      onsiteAction({
        kind: "signage",
        status: "in_production",
        pending: pending(),
        photoForSigns: true,
      }),
    ).toEqual({
      type: "confirm",
      instanceId: "i1",
      stepName: "Delivered",
      label: "Delivered ✓",
      photo: false,
    });
  });

  it("offers Installed ✓ (with the photo for signs) once delivered", () => {
    const step = pending({ stepName: "Installed", isInstall: true });
    expect(
      onsiteAction({ kind: "signage", status: "delivered", pending: step, photoForSigns: true }),
    ).toMatchObject({
      label: "Installed ✓",
      photo: true,
    });
    expect(
      onsiteAction({
        kind: "stand_panel",
        status: "delivered",
        pending: step,
        photoForSigns: true,
      }),
    ).toMatchObject({
      label: "Installed ✓",
      photo: false,
    });
  });

  it("finds the install step by position, not by name", () => {
    const fitted = pending({ stepName: "Fitted on site", isInstall: true });
    expect(
      onsiteAction({ kind: "signage", status: "delivered", pending: fitted, photoForSigns: false }),
    ).toMatchObject({
      type: "confirm",
      label: "Installed ✓",
    });
  });

  it("sponsorship items are received, then in place", () => {
    expect(
      onsiteAction({
        kind: "sponsorship_item",
        status: "in_production",
        pending: pending(),
        photoForSigns: true,
      }),
    ).toMatchObject({ label: "Received ✓", photo: false });
    expect(
      onsiteAction({
        kind: "sponsorship_item",
        status: "delivered",
        pending: pending({ stepName: "Installed", isInstall: true }),
        photoForSigns: true,
      }),
    ).toMatchObject({ label: "In place ✓" });
  });

  it("says which earlier confirmation is still open and sends them to the item", () => {
    expect(
      onsiteAction({
        kind: "signage",
        status: "delivered",
        pending: pending({ stepName: "Sent to print" }),
        photoForSigns: false,
      }),
    ).toEqual({
      type: "open_item",
      text: "Sent to print isn't confirmed yet.",
      label: "Confirm it on the item",
    });
  });

  it("names who it waits on — but never the viewer's own team", () => {
    const theirs = pending({ canDecide: false, viewerHolds: false, who: "Operations" });
    expect(
      onsiteAction({
        kind: "signage",
        status: "in_production",
        pending: theirs,
        photoForSigns: false,
      }),
    ).toEqual({ type: "waiting", text: "Waiting on Operations to confirm delivery" });
    expect(
      onsiteAction({
        kind: "signage",
        status: "delivered",
        pending: pending({
          canDecide: false,
          viewerHolds: true,
          stepName: "Installed",
          isInstall: true,
        }),
        photoForSigns: false,
      }),
    ).toBeNull();
  });

  it("has nothing to offer once installed, and says so when nothing is waiting", () => {
    expect(
      onsiteAction({ kind: "signage", status: "installed", pending: null, photoForSigns: false }),
    ).toBeNull();
    expect(
      onsiteAction({ kind: "signage", status: "delivered", pending: null, photoForSigns: false }),
    ).toMatchObject({
      type: "open_item",
    });
  });
});

describe("sections and views", () => {
  const card = (
    status: string,
    over: { kind?: string; openSnags?: number; installDate?: string | null } = {},
  ) => ({
    kind: over.kind ?? "signage",
    status,
    openSnags: over.openSnags ?? 0,
    installDate: over.installDate === undefined ? "2026-10-16" : over.installDate,
  });
  const today = "2026-10-16";

  it("puts installed, snag-free items under Ready to close and sponsorship items under Deliveries", () => {
    expect(onsiteSection(card("installed"))).toBe("ready_to_close");
    expect(onsiteSection(card("installed", { openSnags: 1 }))).toBe("place");
    expect(onsiteSection(card("in_production", { kind: "sponsorship_item" }))).toBe("deliveries");
    expect(onsiteSection(card("installed", { kind: "sponsorship_item" }))).toBe("ready_to_close");
    expect(onsiteSection(card("closed"))).toBe("done");
  });

  it("Today keeps what's due, undated, snagged and ready to close; Done is only closed", () => {
    expect(inOnsiteView(card("delivered"), "today", today)).toBe(true);
    expect(inOnsiteView(card("delivered", { installDate: null }), "today", today)).toBe(true);
    expect(inOnsiteView(card("delivered", { installDate: "2026-10-20" }), "today", today)).toBe(
      false,
    );
    expect(
      inOnsiteView(card("snagged", { installDate: "2026-10-20", openSnags: 1 }), "today", today),
    ).toBe(true);
    expect(inOnsiteView(card("installed", { installDate: "2026-10-20" }), "today", today)).toBe(
      true,
    );
    expect(inOnsiteView(card("delivered", { installDate: "2026-10-20" }), "todo", today)).toBe(
      true,
    );
    expect(inOnsiteView(card("closed"), "todo", today)).toBe(false);
    expect(inOnsiteView(card("closed"), "done", today)).toBe(true);
    expect(inOnsiteView(card("installed"), "done", today)).toBe(false);
  });

  it("reads the view from the address, including older links", () => {
    expect(parseOnsiteView("done")).toBe("done");
    expect(parseOnsiteView(null, { when: "all" })).toBe("todo");
    expect(parseOnsiteView("", { show: "all" })).toBe("todo");
    expect(parseOnsiteView("nonsense")).toBe("today");
  });

  it("finds by the ref's number or the name", () => {
    const c = { ref: "SIG-BIRM27-015", name: "Hall 2 hanging banner" };
    expect(matchesOnsiteSearch("015", c)).toBe(true);
    expect(matchesOnsiteSearch("hanging hall", c)).toBe(true);
    expect(matchesOnsiteSearch("016", c)).toBe(false);
  });
});

describe("labels", () => {
  it("reports damage on delivery, raises snags once up, never on sponsorship items", () => {
    expect(snagLabel("signage", "delivered")).toBe("Report damage");
    expect(snagLabel("stand_panel", "installed")).toBe("Raise snag");
    expect(snagLabel("signage", "snagged")).toBe("Raise snag");
    expect(snagLabel("signage", "in_production")).toBeNull();
    expect(snagLabel("sponsorship_item", "delivered")).toBeNull();
  });

  it("words confirmations for the floor", () => {
    expect(confirmLabel("signage", "Delivered", false)).toBe("Delivered ✓");
    expect(confirmLabel("signage", "Installed", true)).toBe("Installed ✓");
    expect(confirmLabel("sponsorship_item", "Delivered", false)).toBe("Received ✓");
  });
});
