"use server";

import { revalidatePath } from "next/cache";
import { unstable_rethrow } from "next/navigation";
import { z } from "zod";
import { eq } from "drizzle-orm";
import { db } from "@/lib/db/client";
import { organisations } from "@/lib/db/schema";
import { can, missingAbilityMessage } from "@/lib/authz";
import { writeAudit } from "@/lib/audit";
import { requireSession } from "@/lib/auth/actor";
import { fail, success, type ActionResult } from "@/lib/actions/result";

// The currency isn't changed here: costs, labels and exports all show
// pounds today, so it stays as stored until they use it (DECISIONS.md).
const schema = z.object({
  brandName: z
    .string()
    .trim()
    .min(1, "Give your organisation a name")
    .max(60, "Keep the name to 60 characters"),
  escalateAfterDays: z.coerce
    .number({ message: "Enter a number of days" })
    .int("Enter a whole number of days")
    .min(1, "Chase after at least 1 day")
    .max(14, "Chase within 14 days"),
  installPhotoRequired: z.boolean(),
});

/**
 * Settings → Organisation: the name shown in the app and emails, when
 * overdue sign-offs are chased and whether installers must add a photo.
 * The currency is shown but not changed here yet. Admins and Operations.
 */
export async function updateOrganisationSettings(input: unknown): Promise<ActionResult> {
  const parsed = schema.safeParse(input);
  if (!parsed.success) return fail(parsed.error.issues[0].message);
  const session = await requireSession();
  if (!can(session.actor, { type: "organisation.manage" })) {
    return fail(missingAbilityMessage("organisation.manage"));
  }
  const orgId = session.organisation.id;
  const data = parsed.data;
  try {
    const name = await db.transaction(async (tx) => {
      const [org] = await tx
        .select()
        .from(organisations)
        .where(eq(organisations.id, orgId))
        .for("update");
      if (!org) throw new Error("Organisation not found");
      const settings = {
        ...org.settings,
        escalate_after_days: data.escalateAfterDays,
        install_photo_required: data.installPhotoRequired,
      };
      await tx
        .update(organisations)
        .set({ brandName: data.brandName, settings, updatedAt: new Date() })
        .where(eq(organisations.id, orgId));
      const before = { brandName: org.brandName, ...org.settings };
      const after = { brandName: data.brandName, ...settings };
      const changed = Object.keys(after).filter(
        (k) =>
          JSON.stringify((before as Record<string, unknown>)[k]) !==
          JSON.stringify((after as Record<string, unknown>)[k]),
      );
      await writeAudit(tx, {
        organisationId: orgId,
        actorUserId: session.user.id,
        entityType: "organisation",
        entityId: orgId,
        action: "settings_change",
        before,
        after,
        summary: changed.length
          ? `Changed organisation settings (${changed.join(", ")})`
          : "Saved organisation settings (no changes)",
      });
      return data.brandName;
    });
    revalidatePath("/", "layout");
    return success(undefined, `Settings for ${name} saved`);
  } catch (err) {
    unstable_rethrow(err);
    console.error("updateOrganisationSettings", err);
    return fail("Could not save — please try again");
  }
}
