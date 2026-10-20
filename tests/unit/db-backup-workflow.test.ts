/**
 * The daily backup's connection check (.github/workflows/db-backup.yml, step
 * "Check the connection string"), run with bash as GitHub runs it: pooled
 * hosts are refused, and the log names the host and the provider it is
 * about to dump (never the credentials), so a check after the move can tell
 * a Neon backup from a stale Supabase one.
 */
import { spawnSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { afterAll, describe, expect, it } from "vitest";

const WORKFLOW = readFileSync(".github/workflows/db-backup.yml", "utf8");

/** The `run: |` block of the named step, de-indented. */
function stepScript(name: string): string {
  const lines = WORKFLOW.split("\n");
  const at = lines.findIndex((l) => l.trim() === `- name: ${name}`);
  if (at === -1) throw new Error(`no step "${name}"`);
  const run = lines.findIndex((l, i) => i > at && l.trim() === "run: |");
  const indent = lines[run].search(/\S/);
  const body: string[] = [];
  for (const line of lines.slice(run + 1)) {
    if (line.trim() !== "" && line.search(/\S/) <= indent) break;
    body.push(line);
  }
  const margin = Math.min(...body.filter((l) => l.trim()).map((l) => l.search(/\S/)));
  return body.map((l) => l.slice(margin)).join("\n");
}

const dir = mkdtempSync(path.join(tmpdir(), "hp-backup-"));
afterAll(() => rmSync(dir, { recursive: true, force: true }));

function check(url: string) {
  const githubEnv = path.join(dir, `env-${Math.random().toString(36).slice(2)}`);
  const r = spawnSync(
    "bash",
    ["--noprofile", "--norc", "-eo", "pipefail", "-c", stepScript("Check the connection string")],
    {
      env: {
        PATH: process.env.PATH,
        NODE_ENV: "test",
        DIRECT_DATABASE_URL: url,
        GITHUB_ENV: githubEnv,
      },
    },
  );
  let exported = "";
  try {
    exported = readFileSync(githubEnv, "utf8");
  } catch {
    // Nothing exported.
  }
  return { status: r.status, out: `${r.stdout}${r.stderr}`, exported };
}

describe("db-backup.yml: which database is backed up", () => {
  it.each([
    [
      "postgresql://neondb_owner:s3cret@ep-cool-sea-a1b2c3d4.eu-west-2.aws.neon.tech/neondb?sslmode=require&channel_binding=require",
      "ep-cool-sea-a1b2c3d4.eu-west-2.aws.neon.tech (Neon)",
    ],
    [
      "postgresql://postgres.uymemosqktczdjxlsryj:s3cret@aws-0-eu-central-1.pooler.supabase.com:5432/postgres",
      "aws-0-eu-central-1.pooler.supabase.com (Supabase)",
    ],
    ["postgres://postgres:s3cret@localhost:5432/hallpass", "localhost (another provider)"],
    ["postgres://localhost/hallpass", "localhost (another provider)"],
  ])("%s → %s", (url, named) => {
    const r = check(url);
    expect(r.status, r.out).toBe(0);
    expect(r.out).toContain(`Backing up the database at ${named}`);
    expect(r.exported).toContain(`BACKUP_SOURCE=${named}`);
    expect(r.out + r.exported).not.toContain("s3cret");
  });

  it.each([
    "postgresql://neondb_owner:s3cret@ep-cool-sea-a1b2c3d4-pooler.eu-west-2.aws.neon.tech/neondb",
    "postgresql://postgres.ref:s3cret@aws-0-eu-central-1.pooler.supabase.com:6543/postgres",
    "postgresql://postgres:s3cret@db.uymemosqktczdjxlsryj.supabase.co:5432/postgres",
    "",
  ])("refuses %j before naming anything", (url) => {
    const r = check(url);
    expect(r.status).toBe(1);
    expect(r.out).not.toContain("Backing up");
    expect(r.out).not.toContain("s3cret");
  });
});
