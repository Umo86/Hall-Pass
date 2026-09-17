export const metadata = { title: "Scan" };

// Placeholder — QR resolution to a signage item or stand submission
// (with external scoping) is built in Phase 2.
export default async function QrResolvePage({ params }: { params: Promise<{ ref: string }> }) {
  const { ref } = await params;
  return (
    <div className="flex min-h-screen items-center justify-center p-4">
      <div className="max-w-sm space-y-2 text-center">
        <h1 className="text-xl font-semibold tracking-tight">{decodeURIComponent(ref)}</h1>
        <p className="text-muted-foreground text-sm">
          QR resolution is not yet available — it arrives with Phase 2.
        </p>
      </div>
    </div>
  );
}
