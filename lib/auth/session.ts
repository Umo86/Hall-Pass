import "server-only";
import { cache } from "react";
import { headers } from "next/headers";
import { authConfigured } from "./config";
import { getAuth } from "./server";

/**
 * The Better Auth session on this request (cached per request), or null.
 * Never throws: a database hiccup reads as signed out, and is logged.
 */
export const getAuthSession = cache(async () => {
  if (!authConfigured()) return null;
  try {
    return await getAuth().api.getSession({ headers: await headers() });
  } catch (err) {
    console.error("getAuthSession", err);
    return null;
  }
});
