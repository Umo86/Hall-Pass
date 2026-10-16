"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { Download, Loader2 } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { exportErrorText, fileNameFromDisposition } from "./report-rules";

/**
 * A real download button: fetches the file (showing "Preparing…" while the
 * server builds it), then saves it under the name the server gives. A
 * refusal ("Your role can't…") comes back as a toast, not a new page.
 */
export function DownloadButton({
  href,
  label,
  reportName,
  fallbackName,
  variant = "outline",
  size = "sm",
  ariaLabel,
}: {
  href: string;
  label: string;
  /** For the toast: "Signage schedule downloaded". */
  reportName: string;
  fallbackName: string;
  variant?: "default" | "outline" | "ghost";
  size?: "sm" | "default";
  ariaLabel?: string;
}) {
  const [pending, setPending] = useState(false);
  const router = useRouter();

  async function download() {
    setPending(true);
    try {
      const res = await fetch(href, { credentials: "same-origin" });
      if (res.redirected && new URL(res.url).pathname.startsWith("/login")) {
        toast.error("You've been signed out. Sign in again, then download it.");
        return;
      }
      const type = res.headers.get("content-type") ?? "";
      if (!res.ok || type.includes("text/html")) {
        const reason = exportErrorText(await res.text().catch(() => ""));
        toast.error(reason ?? `${reportName} couldn't be downloaded. Try again in a moment.`);
        return;
      }
      const blob = await res.blob();
      const name = fileNameFromDisposition(res.headers.get("content-disposition")) ?? fallbackName;
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = name;
      document.body.appendChild(a);
      a.click();
      a.remove();
      setTimeout(() => URL.revokeObjectURL(url), 30_000);
      toast.success(`${reportName} downloaded`);
      // "Last downloaded by" and the history now include this one.
      router.refresh();
    } catch {
      toast.error("The download didn't finish. Check your connection and try again.");
    } finally {
      setPending(false);
    }
  }

  return (
    <Button
      type="button"
      variant={variant}
      size={size}
      onClick={download}
      disabled={pending}
      aria-label={ariaLabel}
      aria-busy={pending || undefined}
    >
      {pending ? <Loader2 className="animate-spin" aria-hidden /> : <Download aria-hidden />}
      {pending ? "Preparing…" : label}
    </Button>
  );
}
