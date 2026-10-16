"use client";

import Link from "next/link";
import { useMemo, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { CheckCircle2, Copy } from "lucide-react";
import { toast } from "sonner";
import type { Feature, StaffRole } from "@/lib/authz";
import { MAX_PASTED_PEOPLE, parsePeople } from "@/lib/users/paste";
import { startingChoices, type AbilityChoices } from "@/lib/users/rules";
import type { PersonTemplate, PersonTemplateId } from "@/lib/users/templates";
import {
  inviteUsers,
  previewInviteUsers,
  type InviteUsersResult,
  type PreviewInviteResult,
} from "@/app/actions/users";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { absoluteLink } from "./invite-actions";
import {
  AbilitiesFields,
  DepartmentField,
  FieldError,
  NEW_DEPARTMENT,
  RoleCards,
  SectionsPicker,
  type DepartmentOption,
} from "./person-fields";
import { TemplatePicker } from "./template-picker";
import { localToday, templateFeatures, type AddAccess } from "./add-user-form";

type Reason = PreviewInviteResult["rows"][number]["reason"];

/** What each reason means on the check table. */
function reasonText(reason: Reason, email: string): string {
  switch (reason) {
    case "ready":
      return "Ready to invite";
    case "on_team":
      return "Already on the team";
    case "invited":
      return "Already invited";
    case "other_org":
      return "Belongs to another organisation";
    case "portal":
      return "Used by a portal account";
    case "bad_email":
      return email ? "Not an email address" : "No email address";
    case "duplicate":
      return "Repeats an earlier line";
  }
}

/**
 * Users → Add several people: paste a list (from a spreadsheet or an
 * email), choose what they all get, check it, then invite everyone who is
 * ready. Nobody is invited until "Invite"; each person is checked again on
 * the server.
 */
export function AddSeveral({
  departments,
  visible,
  access,
  templates,
  initialDepartmentId,
}: {
  departments: DepartmentOption[];
  visible: Feature[];
  access: AddAccess;
  templates: PersonTemplate[];
  initialDepartmentId: string;
}) {
  const locked = access.lockedDepartment;
  const startDept = departments.find(
    (d) => d.id === (locked?.id ?? initialDepartmentId) && !d.isArchived,
  );
  const [text, setText] = useState("");
  const [templateId, setTemplateId] = useState<PersonTemplateId>("blank");
  const [dept, setDept] = useState(startDept?.id ?? "");
  const [newDept, setNewDept] = useState("");
  const [role, setRole] = useState<StaffRole | null>(null);
  const [features, setFeatures] = useState<Feature[] | null>(
    access.allSections ? null : [...visible],
  );
  const [abilities, setAbilities] = useState<AbilityChoices>({});
  const [jobTitle, setJobTitle] = useState<string | null>(null);
  const [accessEnd, setAccessEnd] = useState("");
  const [preview, setPreview] = useState<PreviewInviteResult | null>(null);
  const [done, setDone] = useState<InviteUsersResult | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const router = useRouter();

  const parsed = useMemo(() => parsePeople(text), [text]);
  const count = parsed.people.length;

  function changed() {
    // Anything changed after a check needs checking again.
    setPreview(null);
    setError(null);
  }

  function pickTemplate(t: PersonTemplate) {
    setTemplateId(t.id);
    changed();
    if (!t.role) return;
    setRole(t.role);
    const tf = templateFeatures(t, visible);
    setFeatures(tf === null && !access.allSections ? [...visible] : tf);
    setAbilities({ ...t.abilities });
    setJobTitle(t.jobTitle);
  }

  function rows() {
    return parsed.people.map((p) => ({
      line: p.line,
      name: p.name,
      email: p.email,
      jobTitle: p.jobTitle,
    }));
  }

  function check() {
    setError(null);
    if (count === 0) {
      setError("Paste at least one person: their name and email on each line");
      return;
    }
    start(async () => {
      const res = await previewInviteUsers({ rows: rows() });
      if (!res.ok) {
        setError(res.error);
        return;
      }
      setPreview(res.data!);
    });
  }

  function invite() {
    setError(null);
    if (!role) {
      setError("Choose a role for them");
      return;
    }
    if (dept === NEW_DEPARTMENT && !newDept.trim()) {
      setError("Name the new department");
      return;
    }
    const all = preview?.rows ?? [];
    const ready = all.filter((r) => r.reason === "ready");
    if (ready.length === 0) return;
    if (ready.length > MAX_PASTED_PEOPLE) {
      setError(`Invite up to ${MAX_PASTED_PEOPLE} people at a time`);
      return;
    }
    const allVisible = features !== null && visible.every((f) => features.includes(f));
    start(async () => {
      // Every row goes, so the results say what happened to each one.
      const res = await inviteUsers({
        rows: all.map((r) => ({
          line: r.line,
          name: r.name,
          email: r.email,
          jobTitle: r.jobTitle ?? jobTitle,
        })),
        shared: {
          departmentId: dept && dept !== NEW_DEPARTMENT ? dept : null,
          newDepartmentName: dept === NEW_DEPARTMENT ? newDept : null,
          role,
          features: role === "admin" || (allVisible && access.allSections) ? null : features,
          abilities: role === "admin" ? {} : abilities,
          accessEndsOn: accessEnd || null,
        },
      });
      if (!res.ok) {
        setError(res.error);
        toast.error(res.error);
        return;
      }
      if (res.data!.invited > 0) toast.success(res.message ?? "Invited");
      else toast.error(res.message ?? "Nobody was invited");
      setDone(res.data!);
      router.refresh();
    });
  }

  if (done) {
    const links = done.results.filter((r) => r.ok && r.inviteUrl);
    const allLinks = links.map((r) => `${r.name || r.email}: ${absoluteLink(r.inviteUrl!)}`);
    return (
      <section className="space-y-4 rounded-lg border p-4 sm:p-6" aria-live="polite">
        <div className="flex items-start gap-3">
          <CheckCircle2 className="mt-0.5 size-5 shrink-0 text-emerald-600" aria-hidden />
          <div className="space-y-1">
            <h2 className="font-semibold">
              {done.invited === 1 ? "1 person invited" : `${done.invited} people invited`}
            </h2>
            <p className="text-muted-foreground text-sm">
              {links.length > 0
                ? "Email isn't set up here, so send each person their own link."
                : "They'll each get an email to set up their password."}
            </p>
          </div>
        </div>
        <ResultTable
          rows={done.results.map((r) => ({
            key: `${r.line}`,
            name: r.name,
            email: r.email,
            status: r.ok
              ? r.inviteUrl
                ? "Invited — send them the link"
                : "Invited"
              : (r.error ?? reasonText(r.reason, r.email)),
            ok: r.ok,
            href:
              r.ok && r.inviteId
                ? `/users/${r.inviteId}`
                : r.existingId
                  ? `/users/${r.existingId}`
                  : null,
            link: r.ok && r.inviteUrl ? absoluteLink(r.inviteUrl) : null,
          }))}
        />
        <div className="flex flex-wrap gap-2">
          {links.length > 0 && (
            <Button
              type="button"
              variant="outline"
              className="h-11 sm:h-9"
              onClick={async () => {
                try {
                  await navigator.clipboard.writeText(allLinks.join("\n"));
                  toast.success("Links copied");
                } catch {
                  toast.error("Couldn't copy — select the links and copy them yourself");
                }
              }}
            >
              <Copy aria-hidden />
              Copy all links
            </Button>
          )}
          <Button
            type="button"
            className="h-11 sm:h-9"
            onClick={() => {
              setDone(null);
              setPreview(null);
              setText("");
            }}
          >
            Add more people
          </Button>
          <Button asChild variant="ghost" className="h-11 sm:h-9">
            <Link href="/users">Done</Link>
          </Button>
        </div>
      </section>
    );
  }

  const ready = preview?.rows.filter((r) => r.reason === "ready").length ?? 0;
  const tooMany = count > MAX_PASTED_PEOPLE;

  return (
    <div className="space-y-6">
      <section className="space-y-2 rounded-lg border p-4 sm:p-6" aria-labelledby="several-paste-h">
        <h2 id="several-paste-h" className="text-sm font-semibold">
          Who to invite
        </h2>
        <Label htmlFor="several-paste" className="text-muted-foreground text-xs font-normal">
          One person per line: name, email and (optionally) job title, separated by commas or tabs —
          pasting from a spreadsheet works. A first line naming the columns is fine.
        </Label>
        <Textarea
          id="several-paste"
          value={text}
          onChange={(e) => {
            setText(e.target.value);
            changed();
          }}
          rows={8}
          placeholder={"Sam Smith, sam@example.com, Designer\nAlex Jones, alex@example.com"}
          className="font-mono text-sm"
          autoFocus
        />
        <p className="text-muted-foreground text-sm" aria-live="polite">
          {count === 0
            ? "Nobody yet."
            : `${count} ${count === 1 ? "person" : "people"} found${parsed.hadHeader ? " (the first line is read as column names)" : ""}.`}
          {tooMany && ` Invite up to ${MAX_PASTED_PEOPLE} at a time — split the list.`}
        </p>
      </section>

      <section
        className="space-y-4 rounded-lg border p-4 sm:p-6"
        aria-labelledby="several-shared-h"
      >
        <h2 id="several-shared-h" className="text-sm font-semibold">
          What they all get
        </h2>
        <TemplatePicker
          name="several-template"
          templates={templates}
          value={templateId}
          onChange={pickTemplate}
        />
        <div className="grid gap-4 sm:grid-cols-2">
          <DepartmentField
            id="several-department"
            departments={departments}
            value={dept}
            onChange={(v) => {
              setDept(v);
              changed();
            }}
            newName={newDept}
            onNewName={setNewDept}
            disabled={Boolean(locked)}
            allowNew={access.canNewDepartment}
            allowNone={!locked}
            hint={locked ? `You add people to ${locked.name}` : null}
          />
          <div className="space-y-1.5">
            <Label htmlFor="several-end">
              Access ends <span className="text-muted-foreground font-normal">(optional)</span>
            </Label>
            <Input
              id="several-end"
              type="date"
              min={localToday()}
              value={accessEnd}
              onChange={(e) => setAccessEnd(e.target.value)}
              className="h-11 sm:h-9"
            />
            <p className="text-muted-foreground text-xs">To the end of that day, London time.</p>
          </div>
        </div>
        <RoleCards
          name="several-role"
          value={role}
          onChange={(r) => {
            setRole(r);
            setAbilities(startingChoices(r, {}, { superAdmin: access.abilities === undefined }));
            changed();
          }}
          allowed={access.roles}
        />
        {role && role !== "admin" && (
          <>
            <SectionsPicker
              id="several-sections"
              value={features}
              onChange={setFeatures}
              visible={visible}
              allowAll={access.allSections}
            />
            <AbilitiesFields
              id="several-abilities"
              role={role}
              value={abilities}
              onChange={setAbilities}
              features={features}
              assignable={access.abilities}
            />
          </>
        )}
        <p className="text-muted-foreground text-xs">
          Sign-off, manager and anything else can be set on each person&apos;s page afterwards.
        </p>
      </section>

      {preview && (
        <section className="space-y-3" aria-labelledby="several-check-h">
          <h2 id="several-check-h" className="text-sm font-semibold">
            {ready === preview.rows.length
              ? `All ${ready} ready to invite`
              : `${ready} of ${preview.rows.length} ready to invite`}
          </h2>
          <ResultTable
            rows={preview.rows.map((r) => ({
              key: `${r.line}`,
              name: r.name,
              email: r.email,
              status: reasonText(r.reason, r.email),
              ok: r.reason === "ready",
              href: r.existingId ? `/users/${r.existingId}` : null,
              link: null,
            }))}
          />
        </section>
      )}

      <FieldError message={error} />
      <div className="flex flex-wrap gap-2">
        {preview && ready > 0 ? (
          <Button
            type="button"
            className="h-11 sm:h-9"
            disabled={pending || !role}
            onClick={invite}
          >
            {pending ? "Inviting…" : `Invite ${ready === 1 ? "1 person" : `${ready} people`}`}
          </Button>
        ) : (
          <Button
            type="button"
            className="h-11 sm:h-9"
            disabled={pending || count === 0 || tooMany}
            onClick={check}
          >
            {pending ? "Checking…" : "Check"}
          </Button>
        )}
        {preview && (
          <Button type="button" variant="outline" className="h-11 sm:h-9" onClick={check}>
            Check again
          </Button>
        )}
        <Button asChild variant="ghost" className="h-11 sm:h-9">
          <Link href="/users">Cancel</Link>
        </Button>
        {preview && !role && ready > 0 && (
          <p className="text-muted-foreground self-center text-sm">Choose a role for them first.</p>
        )}
      </div>
    </div>
  );
}

function ResultTable({
  rows,
}: {
  rows: {
    key: string;
    name: string;
    email: string;
    status: string;
    ok: boolean;
    href: string | null;
    link: string | null;
  }[];
}) {
  return (
    <div className="overflow-x-auto rounded-lg border">
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Name</TableHead>
            <TableHead>Email</TableHead>
            <TableHead>Result</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {rows.map((r) => (
            <TableRow key={r.key}>
              <TableCell className="font-medium">{r.name || "—"}</TableCell>
              <TableCell className="break-all">{r.email || "—"}</TableCell>
              <TableCell>
                <span
                  className={
                    r.ok
                      ? "text-emerald-800 dark:text-emerald-300"
                      : "text-amber-900 dark:text-amber-200"
                  }
                >
                  {r.status}
                </span>
                {r.href && (
                  <>
                    {" · "}
                    <Link href={r.href} className="link">
                      Open their page
                    </Link>
                  </>
                )}
                {r.link && (
                  <span className="text-muted-foreground block font-mono text-xs break-all">
                    {r.link}
                  </span>
                )}
              </TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </div>
  );
}
