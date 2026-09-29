/** Shown while a page loads, so the screen isn't blank. */
export default function Loading() {
  return (
    <div className="flex flex-col gap-4 p-4 sm:p-6" aria-busy="true" aria-label="Loading">
      <div className="bg-muted h-7 w-64 animate-pulse rounded" />
      <div className="bg-muted h-4 w-96 max-w-full animate-pulse rounded" />
      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
        {[0, 1, 2].map((i) => (
          <div key={i} className="bg-muted h-28 animate-pulse rounded-lg" />
        ))}
      </div>
    </div>
  );
}
