import type { BrowserContext } from "@playwright/test";

/** Development sign-in: the harness assumes a seeded user via cookie. */
export async function signInAs(context: BrowserContext, email: string, baseURL: string) {
  const url = new URL(baseURL);
  await context.addCookies([
    {
      name: "hp-dev-user",
      value: email,
      domain: url.hostname,
      path: "/",
      httpOnly: true,
      sameSite: "Lax",
    },
  ]);
}
