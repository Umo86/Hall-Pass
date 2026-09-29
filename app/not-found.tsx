import Link from "next/link";

export default function RootNotFound() {
  return (
    <main className="mx-auto flex min-h-screen max-w-md flex-col items-start justify-center gap-3 p-6">
      <h1 className="text-xl font-semibold tracking-tight">Not found</h1>
      <p className="text-muted-foreground text-sm">This page doesn&apos;t exist.</p>
      <Link href="/" className="text-primary text-sm underline">
        Back to the start
      </Link>
    </main>
  );
}
