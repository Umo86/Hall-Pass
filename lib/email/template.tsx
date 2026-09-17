import {
  Body,
  Button,
  Container,
  Head,
  Heading,
  Html,
  Preview,
  Section,
  Text,
} from "@react-email/components";
import { render } from "@react-email/components";

export type NotificationEmailProps = {
  brandName: string;
  title: string;
  bodyText: string;
  ctaLabel?: string;
  ctaUrl?: string;
};

/**
 * The one transactional template: brand name, one clear call-to-action deep
 * link, plain-text fallback. Subject and intro copy vary per notification.
 */
export function NotificationEmail({ brandName, title, bodyText, ctaLabel, ctaUrl }: NotificationEmailProps) {
  return (
    <Html lang="en-GB">
      <Head />
      <Preview>{title}</Preview>
      <Body style={{ backgroundColor: "#f5f5f5", fontFamily: "Inter, Arial, sans-serif" }}>
        <Container
          style={{
            backgroundColor: "#ffffff",
            borderRadius: 8,
            margin: "24px auto",
            maxWidth: 560,
            padding: 32,
          }}
        >
          <Text style={{ color: "#737373", fontSize: 12, letterSpacing: 1, margin: 0 }}>
            {brandName.toUpperCase()}
          </Text>
          <Heading as="h1" style={{ fontSize: 20, margin: "8px 0 16px" }}>
            {title}
          </Heading>
          <Text style={{ color: "#404040", fontSize: 14, lineHeight: "22px" }}>{bodyText}</Text>
          {ctaUrl && (
            <Section style={{ marginTop: 24 }}>
              <Button
                href={ctaUrl}
                style={{
                  backgroundColor: "#171717",
                  borderRadius: 6,
                  color: "#ffffff",
                  fontSize: 14,
                  padding: "10px 20px",
                }}
              >
                {ctaLabel ?? "Open"}
              </Button>
            </Section>
          )}
          <Text style={{ color: "#a3a3a3", fontSize: 12, marginTop: 32 }}>
            You are receiving this because of your role on an event run with {brandName}. Manage
            notification preferences in your profile.
          </Text>
        </Container>
      </Body>
    </Html>
  );
}

export async function renderNotificationEmail(props: NotificationEmailProps) {
  const html = await render(<NotificationEmail {...props} />);
  const text = [
    props.brandName,
    "",
    props.title,
    "",
    props.bodyText,
    props.ctaUrl ? `\n${props.ctaLabel ?? "Open"}: ${props.ctaUrl}` : "",
  ].join("\n");
  return { html, text };
}
