import "server-only";
import path from "node:path";
import {
  Document,
  Font,
  Image,
  Page,
  StyleSheet,
  Text,
  View,
  renderToBuffer,
} from "@react-pdf/renderer";
import QRCode from "qrcode";
import { formatDate, formatDateTime, statusLabel } from "@/lib/format";

// Noto Sans covers Latin (incl. Turkish, Polish, Czech…), Greek and
// Cyrillic, so names like "Şule" or "Łukasz" print correctly. The files are
// traced into the export functions via outputFileTracingIncludes.
const FONT_DIR = path.join(process.cwd(), "lib/exports/fonts");
Font.register({
  family: "Noto Sans",
  fonts: [
    { src: path.join(FONT_DIR, "NotoSans-Regular.ttf"), fontWeight: 400 },
    { src: path.join(FONT_DIR, "NotoSans-Bold.ttf"), fontWeight: 700 },
  ],
});
Font.registerHyphenationCallback((word) => [word]);

const BOLD = { fontFamily: "Noto Sans", fontWeight: 700 } as const;

const styles = StyleSheet.create({
  page: { padding: 32, fontSize: 10, fontFamily: "Noto Sans", color: "#171717" },
  brand: { fontSize: 12, ...BOLD, marginBottom: 4 },
  brandAccent: { color: "#4f46e5" },
  h1: { fontSize: 16, ...BOLD, marginBottom: 2 },
  sub: { color: "#525252", marginBottom: 12 },
  row: { flexDirection: "row", marginBottom: 3 },
  key: { width: 120, color: "#737373" },
  val: { flex: 1 },
  section: { marginTop: 12, paddingTop: 8, borderTop: "1 solid #e5e5e5" },
  stepRow: { flexDirection: "row", marginBottom: 4 },
  stepStatus: { width: 130, ...BOLD },
  small: { fontSize: 8, color: "#737373" },
  qr: { width: 72, height: 72 },
  labelPage: { padding: 16, fontSize: 9, fontFamily: "Noto Sans", color: "#171717" },
});

/** The text logo ("hallpass."): lowercase bold, second word and full stop in indigo. */
function BrandMark({ name }: { name: string }) {
  const [first, ...rest] = name.toLowerCase().split(" ");
  return (
    <Text style={styles.brand}>
      {first}
      <Text style={styles.brandAccent}>{rest.join("")}.</Text>
    </Text>
  );
}

export type CertificateStep = {
  name: string;
  status: string;
  deciderName: string | null;
  decidedAt: Date | null;
  versionLabel: string | null;
  shaPrefix: string | null;
  conditions: string | null;
};

export type CertificateInput = {
  brandName: string;
  ref: string;
  title: string;
  editionName: string;
  fields: Array<[string, string]>;
  steps: CertificateStep[];
  recordUrl: string;
};

export async function renderApprovalCertificate(input: CertificateInput): Promise<Buffer> {
  const qrDataUrl = await QRCode.toDataURL(input.recordUrl, { margin: 0, width: 144 });
  const doc = (
    <Document title={`${input.ref} approval certificate`}>
      <Page size="A4" style={styles.page}>
        <View style={{ flexDirection: "row", justifyContent: "space-between" }}>
          <View>
            <BrandMark name={input.brandName} />
            <Text style={styles.h1}>Approval certificate</Text>
            <Text style={styles.sub}>
              {input.ref} — {input.title} · {input.editionName}
            </Text>
          </View>
          {/* eslint-disable-next-line jsx-a11y/alt-text */}
          <Image src={qrDataUrl} style={styles.qr} />
        </View>

        {input.fields.map(([k, v]) => (
          <View key={k} style={styles.row}>
            <Text style={styles.key}>{k}</Text>
            <Text style={styles.val}>{v}</Text>
          </View>
        ))}

        <View style={styles.section}>
          <Text style={{ ...BOLD, marginBottom: 6 }}>Approval chain</Text>
          {input.steps.map((s, i) => (
            <View key={i} style={styles.stepRow}>
              <Text style={styles.stepStatus}>{statusLabel(s.status)}</Text>
              <View style={{ flex: 1 }}>
                <Text>{s.name}</Text>
                <Text style={styles.small}>
                  {s.deciderName ? `${s.deciderName} · ` : ""}
                  {s.decidedAt ? `${formatDateTime(s.decidedAt)} · ` : ""}
                  {s.versionLabel ? `${s.versionLabel} · ` : ""}
                  {s.shaPrefix ? `SHA-256 ${s.shaPrefix}…` : ""}
                </Text>
                {s.conditions ? <Text style={styles.small}>Conditions: {s.conditions}</Text> : null}
              </View>
            </View>
          ))}
        </View>

        <View style={styles.section}>
          <Text style={styles.small}>
            Generated {formatDateTime(new Date())} · Scan the code or visit {input.recordUrl} to
            verify against the live record.
          </Text>
        </View>
      </Page>
    </Document>
  );
  return Buffer.from(await renderToBuffer(doc));
}

export type SpecLabel = {
  ref: string;
  name: string;
  /** "Hall · Location", printed large. */
  where: string | null;
  /** "Install <date> <slot> · <contractor>". */
  when: string | null;
  fields: Array<[string, string]>;
  qrUrl: string;
};

/** A6 spec labels, one page each, with a QR code to /q/{ref}. */
export async function renderSpecLabels(input: {
  brandName: string;
  labels: SpecLabel[];
}): Promise<Buffer> {
  const qrs = await Promise.all(
    input.labels.map((l) => QRCode.toDataURL(l.qrUrl, { margin: 0, width: 160 })),
  );
  const doc = (
    <Document title={input.labels.length === 1 ? `${input.labels[0].ref} spec label` : "Spec labels"}>
      {input.labels.map((l, i) => (
        <Page key={l.ref} size="A6" style={styles.labelPage}>
          <BrandMark name={input.brandName} />
          <Text style={{ fontSize: 14, ...BOLD }}>{l.ref}</Text>
          <Text style={{ fontSize: 10, marginBottom: 6 }}>{l.name}</Text>
          {l.where ? <Text style={{ fontSize: 15, ...BOLD, marginBottom: 2 }}>{l.where}</Text> : null}
          {l.when ? <Text style={{ fontSize: 10, marginBottom: 6 }}>{l.when}</Text> : null}
          <View style={{ marginTop: 4, paddingRight: 72 }}>
            {l.fields.map(([k, v]) => (
              <View key={k} style={{ flexDirection: "row", marginBottom: 2 }}>
                <Text style={{ width: 62, color: "#737373" }}>{k}</Text>
                <Text style={{ flex: 1 }}>{v}</Text>
              </View>
            ))}
          </View>
          <View style={{ position: "absolute", bottom: 16, right: 16 }}>
            {/* eslint-disable-next-line jsx-a11y/alt-text */}
            <Image src={qrs[i]} style={{ width: 64, height: 64 }} />
          </View>
        </Page>
      ))}
    </Document>
  );
  return Buffer.from(await renderToBuffer(doc));
}

export { formatDate };
