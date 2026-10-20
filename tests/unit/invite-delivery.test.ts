/**
 * How invitations reach people: our own email through Resend, or — when
 * that isn't set up or fails — the link handed back to pass on (Users shows
 * "Copy link").
 */
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const state = vi.hoisted(() => ({
  ok: true,
  sent: [] as { to: string; template: string; subject: string }[],
}));
vi.mock("@/lib/email/send", () => ({
  sendEmail: async (m: { to: string; template: string; subject: string }) => {
    state.sent.push(m);
    return state.ok;
  },
}));

const { deliverInvite } = await import("@/lib/auth/staff-invite");
const { deliverPartnerInvite } = await import("@/lib/users/external");
const { invitesCanBeEmailed } = await import("@/lib/users/email");
const { emailConfigured } = await import("@/lib/email/dispatch");

const INVITE = "https://hall-pass.test/invite/abc123";

/** Answers deliverPartnerInvite's one lookup: does this email have an account? */
function stubDb(existing: boolean) {
  const rows = existing ? [{ id: "user-1" }] : [];
  const chain = { from: () => chain, where: () => chain, limit: async () => rows };
  return { select: () => chain } as never;
}

const ENV = { ...process.env };
beforeEach(() => {
  state.ok = true;
  state.sent.length = 0;
});
afterEach(() => {
  process.env = { ...ENV };
});

describe("staff invitations", () => {
  const opts = {
    email: "new@example.test",
    name: "New Person",
    inviterName: "Alex",
    reason: "You'll work on signage.",
    inviteUrl: INVITE,
    inviteId: "11111111-1111-4111-8111-111111111111",
  };

  it("emailed when the email goes out", async () => {
    expect(await deliverInvite(opts)).toEqual({ emailed: true });
    expect(state.sent).toMatchObject([{ to: "new@example.test", template: "staff_invite" }]);
  });

  it("handed back to pass on when it can't be sent (email off or refused)", async () => {
    state.ok = false;
    expect(await deliverInvite(opts)).toEqual({ emailed: false, fallbackUrl: INVITE });
  });
});

describe("partner invitations", () => {
  const opts = {
    email: "Partner@Example.test",
    name: "Pat",
    inviterName: "Alex",
    reason: "Media10 has given you access to UKCW as a sponsor.",
    inviteUrl: INVITE,
    grantId: "22222222-2222-4222-8222-222222222222",
  };

  it("someone with an account gets the new-access email", async () => {
    expect(await deliverPartnerInvite({ ...opts, db: stubDb(true) })).toEqual({ emailed: true });
    expect(state.sent).toMatchObject([{ to: "partner@example.test", template: "partner_access" }]);
  });

  it("…or the link to pass on when it fails", async () => {
    state.ok = false;
    expect(await deliverPartnerInvite({ ...opts, db: stubDb(true) })).toEqual({
      emailed: false,
      fallbackUrl: INVITE,
    });
    expect(state.sent).toHaveLength(1);
  });

  it("someone new gets the invitation email, or the link to pass on", async () => {
    expect(await deliverPartnerInvite({ ...opts, db: stubDb(false) })).toEqual({ emailed: true });
    expect(state.sent).toMatchObject([{ to: "partner@example.test", template: "staff_invite" }]);
    state.ok = false;
    expect(await deliverPartnerInvite({ ...opts, db: stubDb(false) })).toEqual({
      emailed: false,
      fallbackUrl: INVITE,
    });
  });
});

describe("can invitations be emailed here?", () => {
  it("only when both RESEND_API_KEY and EMAIL_FROM are set, exactly like email itself", () => {
    for (const [key, from, expected] of [
      [undefined, undefined, false],
      ["re_x", undefined, false],
      [undefined, "Hall Pass <noreply@example.test>", false],
      ["re_x", "Hall Pass <noreply@example.test>", true],
    ] as const) {
      if (key === undefined) delete process.env.RESEND_API_KEY;
      else process.env.RESEND_API_KEY = key;
      if (from === undefined) delete process.env.EMAIL_FROM;
      else process.env.EMAIL_FROM = from;
      expect(emailConfigured()).toBe(expected);
      expect(invitesCanBeEmailed()).toBe(expected);
    }
  });
});
