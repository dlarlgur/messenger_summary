type Props = { size?: number; className?: string };

/**
 * DK Software monogram.
 * D  — solid rounded letterform with inner negative space
 * K  — vertical bar + two diagonal strokes, all as fills
 * Shares a single blue gradient for the whole mark.
 */
export default function Logo({ size = 28, className }: Props) {
  const id = 'dkGrad';
  return (
    <svg
      viewBox="0 0 46 32"
      height={size}
      className={className}
      role="img"
      aria-label="DK Software"
    >
      <defs>
        <linearGradient id={id} x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stopColor="#93BBFF" />
          <stop offset="55%" stopColor="#3B82F6" />
          <stop offset="100%" stopColor="#1D4ED8" />
        </linearGradient>
        <linearGradient id={`${id}-soft`} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor="#FFFFFF" stopOpacity="0.2" />
          <stop offset="100%" stopColor="#FFFFFF" stopOpacity="0" />
        </linearGradient>
      </defs>

      {/* D (hollow geometric) */}
      <path
        fill={`url(#${id})`}
        fillRule="evenodd"
        clipRule="evenodd"
        d="
          M2 2
          H11.5
          A14 14 0 0 1 11.5 30
          H2
          V2 Z
          M8 8
          V24
          H11.5
          A8 8 0 0 0 11.5 8
          H8 Z
        "
      />

      {/* K */}
      {/* vertical bar */}
      <rect x="24" y="2" width="5" height="28" rx="1.2" fill={`url(#${id})`} />
      {/* upper arm */}
      <path
        fill={`url(#${id})`}
        d="M29 14.5 L40 2.5 L34 2.5 L24 13 V18 L34 29.5 L40 29.5 L29 17.5 Z"
      />

      {/* subtle inner highlight for depth */}
      <path
        fill={`url(#${id}-soft)`}
        d="M2 2 H11.5 A14 14 0 0 1 25 16 H8 V8 H2 Z"
        opacity="0.25"
        style={{ mixBlendMode: 'screen' }}
      />
    </svg>
  );
}
