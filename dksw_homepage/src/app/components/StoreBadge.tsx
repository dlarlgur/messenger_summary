type Props = {
  store: 'apple' | 'google';
  href: string;
  className?: string;
  /** light = 밝은 배경(charge 랜딩)용. 기본 dark 는 기존 홈 그대로. */
  variant?: 'dark' | 'light';
};

/**
 * App Store / Google Play download badge.
 * Clean, minimal style (not the chunky official badge). dark/light variants.
 */
export default function StoreBadge({ store, href, className, variant = 'dark' }: Props) {
  const isApple = store === 'apple';
  const light = variant === 'light';
  return (
    <a
      href={href}
      target="_blank"
      rel="noopener noreferrer"
      className={`group inline-flex shrink-0 items-center gap-3 whitespace-nowrap rounded-xl border px-4 py-2.5 transition-colors ${
        light
          ? 'border-black/10 bg-white shadow-sm hover:border-emerald-500/40 hover:shadow'
          : 'border-white/15 bg-white/[0.04] hover:bg-white/[0.08] hover:border-white/25'
      } ${className ?? ''}`}
    >
      <span className={`${light ? 'text-slate-900' : 'text-fog-100'} transition-transform duration-300 group-hover:scale-110`}>
        {isApple ? <AppleIcon /> : <PlayIcon />}
      </span>
      <span className="flex flex-col leading-none">
        <span className={`text-[9.5px] font-medium tracking-wide ${light ? 'text-slate-500' : 'text-fog-400'}`}>
          {isApple ? 'Download on the' : 'GET IT ON'}
        </span>
        <span className={`mt-1 text-[14px] font-semibold tracking-tight ${light ? 'text-slate-900' : 'text-fog-100'}`}>
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
  // 그라데이션 defs + url(#id) 참조는 모바일에서 display:none 사본의 defs 를 참조해
  // 검정으로 그려지는 버그가 있어 플랫 4색으로 렌더.
  return (
    <svg width="22" height="22" viewBox="0 0 24 24" fill="none" aria-hidden>
      <path d="M3.6 2.4 13.6 12 3.6 21.6C3.2 21.3 3 20.9 3 20.4V3.6c0-.5.2-.9.6-1.2z" fill="#00A9FF" />
      <path d="M17.2 15.6 13.6 12l3.6-3.6 3.9 2.2c.7.4.7 1.4 0 1.8l-3.9 2.2z" fill="#FFB900" />
      <path d="M13.6 12 3.6 2.4c.4-.3 1-.3 1.5 0l12.1 6.8L13.6 12z" fill="#00D96C" />
      <path d="m5.1 21.6 8.5-9.6 3.6 3.6-12.1 6.8c-.5.3-1.1.3-1.5 0z" fill="#FF3A44" />
    </svg>
  );
}
