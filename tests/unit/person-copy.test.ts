/**
 * Person form copy before a name is typed: "This person sees…" and "until
 * this person accepts", never "They sees…" or "until They accepts" (the
 * Events card and the main-approver note, rendered as the Add form shows
 * them).
 */
import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";
import { EventsField, type EventOption } from "@/components/users/person-fields";
import { mainApproverNote, nameInSentence } from "@/lib/users/rules";

const A: EventOption = {
  id: "a",
  code: "BIRM27",
  name: "UKCW Birmingham 2027",
  line: "BIRM27 · 9–11 Mar 2027 · NEC Birmingham",
  archived: false,
};

const field = (props: Partial<Parameters<typeof EventsField>[0]>) =>
  renderToStaticMarkup(
    createElement(EventsField, {
      id: "f",
      personName: "",
      value: null,
      onChange: () => {},
      events: [A],
      allowAll: true,
      ...props,
    }),
  )
    .replace(/<!-- -->/g, "")
    .replace(/&#x27;/g, "'");

const BAD = /They (sees|also has|accepts|takes|only works)/;

describe("Events card before a name is typed", () => {
  it("reads 'This person sees every event' on All events", () => {
    const html = field({});
    expect(html).toContain("This person sees every event, and any event created later.");
    expect(html).not.toMatch(BAD);
  });

  it("reads 'This person sees only…' and 'This person also has…' on Only these events", () => {
    const html = field({ value: ["a"], hiddenCount: 2 });
    expect(html).toContain("This person sees every event, and any event created later.");
    expect(html).toContain("This person sees only the events ticked here.");
    expect(html).toContain("This person also has 2 other events you can't open");
    expect(html).not.toMatch(BAD);
  });

  it("says 'this person' mid-sentence when there are no events yet", () => {
    const html = field({ value: [], events: [] });
    expect(html).toContain(
      "There are no events yet — this person will see every event once they're created.",
    );
  });

  it("uses the name once one is typed", () => {
    expect(field({ personName: "Sam" })).toContain("Sam sees every event");
  });
});

describe("main-approver note before a name is typed", () => {
  it("names nobody as 'They'", () => {
    expect(nameInSentence("", "")).toBe("this person");
    expect(nameInSentence("  ", undefined)).toBe("this person");
    expect(nameInSentence("Sam Smith", "")).toBe("Sam");
    expect(nameInSentence("", "sam@x.test")).toBe("sam");
    const note = mainApproverNote({
      person: nameInSentence("", ""),
      department: "Marketing",
      invited: true,
      current: { name: "Dana", canSign: true },
      pending: null,
      newMainEvents: "BIRM27 only",
    });
    expect(note).toBe(
      "Dana stays main approver until this person accepts, then this person takes over. This person only works on BIRM27, so Marketing sign-offs in other events go to everyone in Marketing.",
    );
    expect(note).not.toMatch(BAD);
  });
});
