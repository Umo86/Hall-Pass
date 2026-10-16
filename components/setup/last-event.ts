/**
 * The cookie that remembers the last event someone opened, so pages without
 * an event in their address (My Work, Approvals…) default to it. Set in the
 * browser by the event switcher and by the create/copy actions; read by the
 * app layout. Not sensitive: an event code.
 */
export const LAST_EVENT_COOKIE = "hp-last-event";
/** 180 days, in seconds. */
export const LAST_EVENT_COOKIE_MAX_AGE = 180 * 24 * 60 * 60;
