type Props = {
  store: 'apple' | 'google';
  href: string;
  className?: string;
};

/**
 * App Store / Google Play download badge.
 * Dark-mode optimized. Clean, minimal style (not the chunky official badge).
 */
export default function StoreBadge({ store, href, className }: Props) {
  const isApple = store === 'apple';
  return (
    <a
      href={href}
      target="_blank"
      rel="noopener noreferrer"
      className={`group inline-flex items-center gap-3 rounded-xl border border-white/15 bg-white/[0.04] hover:bg-white/[0.08] hover:border-white/25 px-4 py-2.5 transition-colors ${
        className ?? ''
      }`}
    >
      <span className="text-fog-100 transition-transform duration-300 group-hover:scale-110">
        {isApple ? <AppleIcon /> : <PlayIcon />}
      </span>
      <span className="flex flex-col leading-none">
        <span className="text-[9.5px] font-medium text-fog-400 tracking-wide">
          {isApple ? 'Download on the' : 'GET IT ON'}
        </span>
        <span className="mt-1 text-[14px] font-semibold text-fog-100 tracking-tight">
          {isApple ? 'App Store' : 'Google Play'}
        </span>
      </span>
    </a>
  );
}

function AppleIcon() {
  return (
    <svg width="22" height="22" viewBox="0 0 24 24" fill="currentColor" aria-hidden>
      <path d="M17.05 20.28c-.98.95-2.05.8-3.08.35-1.09-.46-2.09-.48-3.24 0-1.44.62-2.2.44-3.06-.35C2.79 15.25 3.51 7.59 9.05 7.31c1.35.07 2.29.74 3.08.8 1.18-.24 2.31-.93 3.57-.84 1.51.12 2.65.72 3.4 1.8-3.12 1.87-2.38 5.98.48 7.13-.57 1.5-1.31 2.99-2.54 4.09zM12.03 7.25c-.15-2.23 1.66-4.07 3.74-4.25.29 2.58-2.34 4.5-3.74 4.25z" />
    </svg>
  );
}

function PlayIcon() {
  return (
    <svg width="22" height="22" viewBox="0 0 24 24" fill="none" aria-hidden>
      <defs>
        <linearGradient id="playG1" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stopColor="#00D7FE" />
          <stop offset="100%" stopColor="#0087FF" />
        </linearGradient>
        <linearGradient id="playG2" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stopColor="#FFBA00" />
          <stop offset="100%" stopColor="#FF6B00" />
        </linearGradient>
        <linearGradient id="playG3" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stopColor="#FF3D44" />
          <stop offset="100%" stopColor="#FF1744" />
        </linearGradient>
        <linearGradient id="playG4" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stopColor="#00F076" />
          <stop offset="100%" stopColor="#00C853" />
        </linearGradient>
      </defs>
      <path d="M3.6 2.4 13.6 12 3.6 21.6C3.2 21.3 3 20.9 3 20.4V3.6c0-.5.2-.9.6-1.2z" fill="url(#playG1)" />
      <path d="M17.2 15.6 13.6 12l3.6-3.6 3.9 2.2c.7.4.7 1.4 0 1.8l-3.9 2.2z" fill="url(#playG2)" />
      <path d="M13.6 12 3.6 2.4c.4-.3 1-.3 1.5 0l12.1 6.8L13.6 12z" fill="url(#playG4)" />
      <path d="m5.1 21.6 8.5-9.6 3.6 3.6-12.1 6.8c-.5.3-1.1.3-1.5 0z" fill="url(#playG3)" />
    </svg>
  );
}
