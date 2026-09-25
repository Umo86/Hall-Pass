import type { Metadata } from "next";
import { Inter } from "next/font/google";
import { NuqsAdapter } from "nuqs/adapters/next/app";
import { brandName } from "@/lib/config";
import "./globals.css";
import { AuthHashForwarder } from "@/components/auth/auth-hash-forwarder";

const inter = Inter({
  variable: "--font-inter",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: {
    default: brandName,
    template: `%s · ${brandName}`,
  },
  description: "Signage schedule and design sign-off for exhibitions.",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en-GB" className={`${inter.variable} h-full antialiased`}>
      <body className="font-sans min-h-full flex flex-col">
        <AuthHashForwarder />
        <NuqsAdapter>{children}</NuqsAdapter>
      </body>
    </html>
  );
}
