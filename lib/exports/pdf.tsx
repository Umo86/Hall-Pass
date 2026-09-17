import "server-only";
import { Document, Image, Page, StyleSheet, Text, View, renderToBuffer } from "@react-pdf/renderer";
import QRCode from "qrcode";
import { formatDate, formatDateTime, statusLabel } from "@/lib/format";

const styles = StyleSheet.create({
  page: { padding: 32, fontSize: 10, fontFamily: "Helvetica", color: "#171717" },
  brand: { fontSize: 8, letterSpacing: 2, color: "#737373", marginBottom: 4 },
  h1: { fontSize: 16, fontFamily: "Helvetica-Bold", marginBottom: 2 },
  sub: { color: "#525252", marginBottom: 12 },
  row: { flexDirection: "row", marginBottom: 3 },
  key: { width: 120, color: "#737373" },
  val: { flex: 1 },
  section: { marginTop: 12, paddingTop: 8, borderTop: "1 solid #e5e5e5" },
  stepRow: { flexDirection: "row", marginBottom: 4 },
  stepStatus: { width: 130, fontFamily: "Helvetica-Bold" },
  small: { fontSize: 8, color: "#737373" },
  qr: { width: 72, height: 72 },
  labelPage: { padding: 16, fontSize: 9, fontFamily: "Helvetica", color: "#171717" },
});

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
            <Text style={styles.brand}>{input.brandName.toUpperCase()}</Text>
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
          <Text style={{ fontFamily: "Helvetica-Bold", marginBottom: 6 }}>Approval chain</Text>
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

export type SpecLabelInput = {
  brandName: string;
  ref: string;
  name: string;
  fields: Array<[string, string]>;
  qrUrl: string;
};

/** A6 spec label with a QR code to /q/{ref}. */
export async function renderSpecLabel(input: SpecLabelInput): Promise<Buffer> {
  const qrDataUrl = await QRCode.toDataURL(input.qrUrl, { margin: 0, width: 160 });
  const doc = (
    <Document title={`${input.ref} spec label`}>
      <Page size="A6" style={styles.labelPage}>
        <Text style={styles.brand}>{input.brandName.toUpperCase()}</Text>
        <Text style={{ fontSize: 14, fontFamily: "Helvetica-Bold" }}>{input.ref}</Text>
        <Text style={{ fontSize: 10, marginBottom: 8 }}>{input.name}</Text>
        {input.fields.map(([k, v]) => (
          <View key={k} style={{ flexDirection: "row", marginBottom: 2 }}>
            <Text style={{ width: 70, color: "#737373" }}>{k}</Text>
            <Text style={{ flex: 1 }}>{v}</Text>
          </View>
        ))}
        <View style={{ position: "absolute", bottom: 16, right: 16 }}>
          {/* eslint-disable-next-line jsx-a11y/alt-text */}
          <Image src={qrDataUrl} style={{ width: 64, height: 64 }} />
        </View>
      </Page>
    </Document>
  );
  return Buffer.from(await renderToBuffer(doc));
}

export { formatDate };
