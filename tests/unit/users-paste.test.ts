/**
 * "Add several people": the paste parser (lib/users/paste.ts) — tabs or
 * commas, an optional header that sets the column order, the email found
 * wherever it is, "Name <email>", quoted commas, repeats marked by
 * lower-cased email, and names made from emails.
 */
import { describe, expect, it } from "vitest";
import { looksLikeEmail, nameFromEmail, parsePeople } from "@/lib/users/paste";

describe("parsePeople", () => {
  it("reads comma-separated lines as name, email, job title", () => {
    const { people, hadHeader } = parsePeople(
      "Sam Smith, sam@example.com, Designer\nAlex Jones,alex@example.com",
    );
    expect(hadHeader).toBe(false);
    expect(people).toEqual([
      {
        line: 1,
        name: "Sam Smith",
        email: "sam@example.com",
        jobTitle: "Designer",
        nameFromEmail: false,
        duplicateOf: null,
      },
      {
        line: 2,
        name: "Alex Jones",
        email: "alex@example.com",
        jobTitle: null,
        nameFromEmail: false,
        duplicateOf: null,
      },
    ]);
  });

  it("reads tab-separated lines pasted from a spreadsheet, keeping commas in a field", () => {
    const { people } = parsePeople("Sam Smith\tsam@example.com\tHead of Design, North\n");
    expect(people[0]).toMatchObject({
      name: "Sam Smith",
      email: "sam@example.com",
      jobTitle: "Head of Design, North",
    });
  });

  it("uses a header line to set the column order and skips it", () => {
    const { people, hadHeader } = parsePeople(
      "Email,Job title,Full name\nsam@example.com,Designer,Sam Smith",
    );
    expect(hadHeader).toBe(true);
    expect(people).toHaveLength(1);
    expect(people[0]).toMatchObject({
      line: 2,
      name: "Sam Smith",
      email: "sam@example.com",
      jobTitle: "Designer",
    });
  });

  it("finds the email wherever it is when there is no header", () => {
    const { people } = parsePeople("sam@example.com, Sam Smith, Designer");
    expect(people[0]).toMatchObject({
      name: "Sam Smith",
      email: "sam@example.com",
      jobTitle: "Designer",
    });
  });

  it("reads “Name <email>” as copied from an email", () => {
    const { people } = parsePeople("Sam Smith <Sam.Smith@Example.com>");
    expect(people[0]).toMatchObject({ name: "Sam Smith", email: "sam.smith@example.com" });
  });

  it("keeps quoted commas inside a field", () => {
    const { people } = parsePeople('"Smith, Sam",sam@example.com,"Designer, print"');
    expect(people[0]).toMatchObject({
      name: "Smith, Sam",
      email: "sam@example.com",
      jobTitle: "Designer, print",
    });
  });

  it("lower-cases emails and marks a repeat of an earlier line", () => {
    const { people } = parsePeople(
      "Sam, sam@example.com\nAlex, alex@example.com\nSam again, SAM@Example.com",
    );
    expect(people.map((p) => p.email)).toEqual([
      "sam@example.com",
      "alex@example.com",
      "sam@example.com",
    ]);
    expect(people[2].duplicateOf).toBe(1);
    expect(people[0].duplicateOf).toBeNull();
  });

  it("makes a name from the email when the line has none", () => {
    const { people } = parsePeople("jo.bloggs@example.com");
    expect(people[0]).toMatchObject({ name: "Jo Bloggs", nameFromEmail: true });
  });

  it("keeps lines without a usable email so the check can say why", () => {
    const { people } = parsePeople("Sam Smith, not-an-email\nAlex, alex@nowhere\nJo Bloggs");
    // No @ on the line: read in the usual order, showing what was typed.
    expect(people[0]).toMatchObject({ name: "Sam Smith", email: "not-an-email", jobTitle: null });
    expect(people[1].email).toBe("alex@nowhere");
    expect(looksLikeEmail(people[1].email)).toBe(false);
    expect(people[2]).toMatchObject({ name: "Jo Bloggs", email: "" });
  });

  it("skips blank lines, Windows line endings and mailto: prefixes", () => {
    const { people } = parsePeople("\r\nSam, mailto:sam@example.com\r\n\r\n  \n");
    expect(people).toHaveLength(1);
    expect(people[0]).toMatchObject({ line: 2, email: "sam@example.com" });
  });

  it("returns nothing for an empty paste", () => {
    expect(parsePeople("").people).toEqual([]);
    expect(parsePeople("   \n\n").people).toEqual([]);
  });
});

describe("email helpers", () => {
  it("accept plausible emails only", () => {
    expect(looksLikeEmail("sam@example.com")).toBe(true);
    expect(looksLikeEmail("sam.o'neil+events@sub.example.co.uk")).toBe(true);
    for (const bad of ["", "sam", "sam@", "@example.com", "sam@example", "sam smith@example.com"]) {
      expect(looksLikeEmail(bad)).toBe(false);
    }
  });

  it("make names from the part before the @", () => {
    expect(nameFromEmail("sam_smith-jones@x.com")).toBe("Sam Smith Jones");
    expect(nameFromEmail("info@x.com")).toBe("Info");
  });
});
