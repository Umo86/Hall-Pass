/* eslint-disable @next/next/no-img-element -- override photos have unknown dimensions */
import { HallScene, OfficeScene, StandScene } from "@/components/illustrations";
import { cn } from "@/lib/utils";

const SCENES = {
  hall: HallScene,
  office: OfficeScene,
  stand: StandScene,
} as const;

/**
 * A pictorial panel: renders the override photo when one exists in
 * public/images, otherwise the matching built-in vector scene.
 */
export function Scene({
  kind,
  photo,
  alt,
  className,
}: {
  kind: keyof typeof SCENES;
  photo: string | null;
  alt: string;
  className?: string;
}) {
  const Illustration = SCENES[kind];
  return (
    <div className={cn("overflow-hidden rounded-xl border", className)}>
      {photo ? (
        <img src={photo} alt={alt} className="h-full w-full object-cover" />
      ) : (
        <Illustration title={alt} className="h-full w-full object-cover" />
      )}
    </div>
  );
}
