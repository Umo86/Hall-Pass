/**
 * Brand configuration. The public brand name is a config value so the
 * product can be renamed without a code hunt (non-negotiable 7). After
 * login, organisations.brand_name overrides this default.
 */
export const brandName = process.env.NEXT_PUBLIC_BRAND_NAME ?? "Hall Pass";

export const appTimezone = process.env.APP_TIMEZONE ?? "Europe/London";

/**
 * Stand design approvals are hidden for now (owner decision 2026-09-24): the
 * module stays in the codebase but is not offered in navigation, dashboards,
 * reports, invites, My Work or the daily chasers. Set STANDS_ENABLED=1 to
 * switch it back on.
 */
export const standsEnabled = process.env.STANDS_ENABLED === "1";
