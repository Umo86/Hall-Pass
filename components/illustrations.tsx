import { cn } from "@/lib/utils";

/**
 * Flat vector scenes of event professionals at work, in the brand palette.
 * Light/dark aware via Tailwind fill classes. Each public page renders these
 * unless a real photo exists in public/images (see lib/brand-images.ts) —
 * drop AI-generated photography there to replace them without code changes.
 */

function Person({
  x,
  y,
  scale = 1,
  skin,
  top,
  flip = false,
  arm = "down",
}: {
  x: number;
  y: number;
  scale?: number;
  skin: string;
  top: string;
  flip?: boolean;
  arm?: "down" | "up" | "point";
}) {
  return (
    <g transform={`translate(${x} ${y}) scale(${flip ? -scale : scale} ${scale})`}>
      {/* legs */}
      <rect x={-9} y={38} width={7} height={26} rx={3} className="fill-slate-600 dark:fill-slate-400" />
      <rect x={2} y={38} width={7} height={26} rx={3} className="fill-slate-700 dark:fill-slate-500" />
      {/* torso */}
      <rect x={-13} y={8} width={26} height={34} rx={9} className={top} />
      {/* head */}
      <circle cx={0} cy={-6} r={10} className={skin} />
      {/* arm */}
      {arm === "up" && <rect x={8} y={-14} width={6} height={28} rx={3} className={skin} transform="rotate(18 11 0)" />}
      {arm === "point" && <rect x={10} y={12} width={26} height={6} rx={3} className={skin} />}
      {arm === "down" && <rect x={11} y={12} width={6} height={24} rx={3} className={skin} />}
    </g>
  );
}

const SKIN_A = "fill-[#c98a5e]";
const SKIN_B = "fill-[#8d5a3b]";
const SKIN_C = "fill-[#e8b48c]";
const HIVIS = "fill-amber-400";
const SHIRT_INDIGO = "fill-indigo-500";
const SHIRT_SKY = "fill-sky-500";
const SHIRT_EMERALD = "fill-emerald-500";

/** Exhibition hall: riggers on a scissor lift hanging a banner, stands below. */
export function HallScene({ className, title = "Crew installing event signage in an exhibition hall" }: { className?: string; title?: string }) {
  return (
    <svg viewBox="0 0 800 420" role="img" aria-label={title} className={cn("h-auto w-full", className)}>
      <rect width="800" height="420" className="fill-slate-100 dark:fill-slate-800/60" />
      {/* floor */}
      <rect y="360" width="800" height="60" className="fill-slate-200 dark:fill-slate-700/70" />
      {/* roof trusses */}
      <rect x="0" y="34" width="800" height="6" className="fill-slate-300 dark:fill-slate-600" />
      <rect x="0" y="64" width="800" height="6" className="fill-slate-300 dark:fill-slate-600" />
      {Array.from({ length: 16 }).map((_, i) => (
        <path
          key={i}
          d={`M${i * 50} 40 l25 24 l25 -24`}
          className="stroke-slate-300 dark:stroke-slate-600"
          strokeWidth="4"
          fill="none"
        />
      ))}
      {/* hanging banners */}
      <line x1="140" y1="70" x2="140" y2="120" className="stroke-slate-400" strokeWidth="3" />
      <line x1="220" y1="70" x2="220" y2="120" className="stroke-slate-400" strokeWidth="3" />
      <rect x="120" y="120" width="120" height="150" rx="6" className="fill-indigo-500" />
      <rect x="138" y="150" width="84" height="10" rx="5" className="fill-indigo-200" />
      <rect x="138" y="172" width="60" height="10" rx="5" className="fill-indigo-300" />

      <line x1="420" y1="70" x2="420" y2="104" className="stroke-slate-400" strokeWidth="3" />
      <line x1="500" y1="70" x2="500" y2="104" className="stroke-slate-400" strokeWidth="3" />
      <rect x="398" y="104" width="124" height="86" rx="6" className="fill-amber-400" />
      <rect x="416" y="128" width="88" height="10" rx="5" className="fill-amber-100" />
      <rect x="416" y="150" width="56" height="10" rx="5" className="fill-amber-200" />

      {/* banner being lifted into place */}
      <line x1="640" y1="70" x2="640" y2="96" className="stroke-slate-400" strokeWidth="3" strokeDasharray="6 5" />
      <rect x="600" y="96" width="110" height="74" rx="6" className="fill-sky-500" />
      <rect x="616" y="118" width="78" height="10" rx="5" className="fill-sky-200" />

      {/* scissor lift */}
      <rect x="560" y="196" width="130" height="12" rx="4" className="fill-slate-500 dark:fill-slate-400" />
      <path d="M572 208 l106 56 M678 208 l-106 56 M572 264 l106 56 M678 264 l-106 56" className="stroke-slate-500 dark:stroke-slate-400" strokeWidth="7" />
      <rect x="560" y="320" width="130" height="26" rx="6" className="fill-amber-500" />
      <circle cx="582" cy="356" r="12" className="fill-slate-700 dark:fill-slate-300" />
      <circle cx="668" cy="356" r="12" className="fill-slate-700 dark:fill-slate-300" />
      <rect x="556" y="168" width="138" height="8" rx="4" className="fill-slate-500 dark:fill-slate-400" />
      <Person x={610} y={130} skin={SKIN_B} top={HIVIS} arm="up" />
      <Person x={662} y={132} skin={SKIN_C} top={HIVIS} arm="up" flip />

      {/* stand booth */}
      <rect x="60" y="264" width="230" height="96" rx="8" className="fill-violet-200 dark:fill-violet-900" />
      <rect x="82" y="286" width="80" height="14" rx="7" className="fill-violet-500" />
      <circle cx="256" cy="300" r="16" className="fill-violet-400" />
      <rect x="96" y="322" width="120" height="38" rx="6" className="fill-white dark:fill-slate-300" />
      <Person x={140} y={300} skin={SKIN_A} top={SHIRT_INDIGO} />
      <Person x={320} y={306} skin={SKIN_C} top={SHIRT_EMERALD} arm="point" flip />
      {/* clipboard for the ops manager */}
      <rect x="286" y="316" width="18" height="24" rx="3" className="fill-white stroke-slate-400 dark:fill-slate-200" strokeWidth="2" />

      {/* walking visitor */}
      <Person x={452} y={306} skin={SKIN_B} top={SHIRT_SKY} />
    </svg>
  );
}

/** Planning office: team reviewing the live schedule wall. */
export function OfficeScene({ className, title = "Event operations team planning at a schedule wall" }: { className?: string; title?: string }) {
  const cols: Array<[string, number[]]> = [
    ["fill-slate-300 dark:fill-slate-500", [16, 16, 16]],
    ["fill-sky-400", [16, 16]],
    ["fill-amber-400", [16]],
    ["fill-emerald-400", [16, 16, 16, 16]],
  ];
  return (
    <svg viewBox="0 0 800 420" role="img" aria-label={title} className={cn("h-auto w-full", className)}>
      <rect width="800" height="420" className="fill-indigo-50 dark:fill-indigo-950/40" />
      <rect y="356" width="800" height="64" className="fill-indigo-100/80 dark:fill-indigo-900/40" />
      {/* window with hall silhouette */}
      <rect x="52" y="52" width="180" height="130" rx="10" className="fill-sky-100 dark:fill-slate-800" />
      <path d="M62 150 l40 -34 l30 22 l44 -40 l44 46 v18 h-158 z" className="fill-sky-300 dark:fill-sky-800" />
      <rect x="52" y="52" width="180" height="130" rx="10" fill="none" className="stroke-indigo-200 dark:stroke-indigo-800" strokeWidth="6" />
      {/* schedule wall screen */}
      <rect x="300" y="44" width="420" height="240" rx="12" className="fill-white dark:fill-slate-900" />
      <rect x="300" y="44" width="420" height="240" rx="12" fill="none" className="stroke-indigo-200 dark:stroke-indigo-800" strokeWidth="6" />
      <rect x="324" y="66" width="150" height="14" rx="7" className="fill-indigo-500" />
      {cols.map(([fill, cards], c) => (
        <g key={c}>
          <rect x={324 + c * 100} y={96} width={80} height={10} rx={5} className="fill-slate-200 dark:fill-slate-700" />
          {cards.map((h, r) => (
            <rect key={r} x={324 + c * 100} y={116 + r * 26} width={80} height={h} rx={5} className={fill} />
          ))}
        </g>
      ))}
      {/* desk */}
      <rect x="70" y="300" width="250" height="14" rx="6" className="fill-indigo-300 dark:fill-indigo-800" />
      <rect x="86" y="314" width="10" height="52" className="fill-indigo-300 dark:fill-indigo-800" />
      <rect x="294" y="314" width="10" height="52" className="fill-indigo-300 dark:fill-indigo-800" />
      {/* laptop */}
      <path d="M150 300 h56 l10 -34 h-56 z" className="fill-slate-600 dark:fill-slate-400" />
      <circle cx="248" cy="290" r="7" className="fill-amber-500" />
      {/* people */}
      <Person x={130} y={244} skin={SKIN_C} top={SHIRT_INDIGO} />
      <Person x={560} y={300} skin={SKIN_B} top={SHIRT_SKY} arm="point" flip />
      <Person x={640} y={302} skin={SKIN_A} top={SHIRT_EMERALD} />
    </svg>
  );
}

/** Stand build: contractor placing a panel, manager checking the list. */
export function StandScene({ className, title = "Contractor and operations manager checking a stand build" }: { className?: string; title?: string }) {
  return (
    <svg viewBox="0 0 600 300" role="img" aria-label={title} className={cn("h-auto w-full", className)}>
      <rect width="600" height="300" className="fill-slate-100 dark:fill-slate-800/60" />
      <rect y="252" width="600" height="48" className="fill-slate-200 dark:fill-slate-700/70" />
      {/* stand frame */}
      <rect x="90" y="60" width="10" height="192" className="fill-slate-500 dark:fill-slate-400" />
      <rect x="330" y="60" width="10" height="192" className="fill-slate-500 dark:fill-slate-400" />
      <rect x="84" y="52" width="262" height="12" rx="4" className="fill-slate-500 dark:fill-slate-400" />
      {/* placed panel + panel being carried */}
      <rect x="100" y="64" width="112" height="188" className="fill-emerald-300 dark:fill-emerald-800" />
      <rect x="120" y="96" width="70" height="12" rx="6" className="fill-emerald-600 dark:fill-emerald-400" />
      <rect x="218" y="110" width="90" height="142" className="fill-emerald-200 dark:fill-emerald-900" transform="rotate(6 218 110)" />
      <Person x={252} y={182} skin={SKIN_B} top={HIVIS} arm="up" />
      {/* ops manager with tablet */}
      <Person x={452} y={192} skin={SKIN_C} top={SHIRT_INDIGO} arm="point" flip />
      <rect x="398" y="196" width="26" height="34" rx="4" className="fill-white stroke-slate-400 dark:fill-slate-200" strokeWidth="2" />
      <path d="M404 212 l6 6 l10 -12" className="stroke-emerald-600" strokeWidth="3" fill="none" />
      {/* toolbox */}
      <rect x="520" y="234" width="44" height="20" rx="4" className="fill-amber-500" />
      <path d="M532 234 v-8 h20 v8" className="stroke-amber-600" strokeWidth="4" fill="none" />
    </svg>
  );
}
