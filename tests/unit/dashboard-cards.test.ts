/**
 * Dashboard money cards rendered to HTML: an event without packages reads
 * exactly as it did before packages existed (DECISIONS packages 16).
 */
import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";
import { SponsorshipCard } from "@/components/dashboard/money-cards";

const summary = {
  forSale: 0,
  sold: 0,
  available: 0,
  inPackage: 2,
  sales: 0,
  urgent: 0,
  urgentUnsold: 0,
};

const card = (props: Partial<Parameters<typeof SponsorshipCard>[0]>) =>
  renderToStaticMarkup(
    createElement(SponsorshipCard, { code: "BIRM27", summary, canAdd: false, ...props }),
  );

describe("Sponsorship card", () => {
  it("without packages, keeps '0 of 0 sold' and its bar when only sponsor signs are in packages", () => {
    const html = card({ packages: null, revenue: null });
    expect(html).toContain("0 of 0 sold");
    expect(html).toContain("0% of sponsorship items sold");
    expect(html).toContain("2 sponsor signs in packages");
  });

  it("with packages and nothing for sale, leaves the items line out", () => {
    const html = card({
      packages: { count: 2, sold: 1, placesLeft: 3, unlimited: 0 },
      revenue: null,
    });
    expect(html).not.toContain("0 of 0 sold");
  });

  it("shows sold of for sale whenever items are for sale", () => {
    const html = card({ summary: { ...summary, forSale: 4, sold: 1, available: 3 } });
    expect(html).toContain("1 of 4 sold");
    expect(html).toContain("25% of sponsorship items sold");
  });
});
