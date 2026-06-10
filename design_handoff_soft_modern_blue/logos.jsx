// Logos v2 — five fully different directions.

const LOGO_RADIUS_RATIO = 0.225;

function LogoFrame({ size, bg, children, shadow = true, border }) {
  return (
    <div style={{
      width: size, height: size, borderRadius: size * LOGO_RADIUS_RATIO,
      background: bg, display: 'flex', alignItems: 'center', justifyContent: 'center',
      boxShadow: shadow ? '0 8px 24px -8px rgba(15,30,90,0.25), 0 2px 6px -2px rgba(15,30,90,0.12)' : 'none',
      overflow: 'hidden', position: 'relative',
      border: border || 'none',
      fontFamily: 'Pretendard Variable, Pretendard, system-ui, sans-serif',
    }}>{children}</div>
  );
}

// ── ① AI톡 wordmark — type IS the logo. Two-line stack, tight tracking.
function LogoAITok({ size = 144, bg = '#1953e8', fg = '#fff', shadow = true }) {
  return (
    <LogoFrame size={size} bg={bg} shadow={shadow}>
      <div style={{
        color: fg, lineHeight: 0.92, letterSpacing: '-0.06em',
        textAlign: 'left', fontWeight: 800,
      }}>
        <div style={{ fontSize: size * 0.30, opacity: 0.85, fontWeight: 700 }}>AI</div>
        <div style={{ fontSize: size * 0.48, marginTop: size * 0.02 }}>톡<span style={{ opacity: 0.65, fontWeight: 600 }}>.</span></div>
      </div>
    </LogoFrame>
  );
}

// ── ② Mega 톡 — single Korean letter fills the canvas. Confident monogram.
function LogoMegaTok({ size = 144, bg = '#1953e8', fg = '#fff', shadow = true }) {
  return (
    <LogoFrame size={size} bg={bg} shadow={shadow}>
      <div style={{
        color: fg, fontSize: size * 0.72, fontWeight: 800, lineHeight: 1,
        letterSpacing: '-0.04em', transform: `translateY(${size * 0.01}px)`,
      }}>톡</div>
    </LogoFrame>
  );
}

// ── ③ Korean quote brackets 「AI」 — frames small AI text, summary metaphor.
function LogoBracketAI({ size = 144, bg = '#1953e8', fg = '#fff', shadow = true }) {
  const stroke = size * 0.06;
  const half = size / 2;
  return (
    <LogoFrame size={size} bg={bg} shadow={shadow}>
      <svg width={size * 0.74} height={size * 0.74} viewBox="0 0 100 100">
        {/* left bracket 「 */}
        <path d={`M 18 28 H 32 V 36 H 26 V 60`} stroke={fg} strokeWidth="9" fill="none" strokeLinejoin="miter" strokeLinecap="butt"/>
        {/* right bracket 」 */}
        <path d={`M 82 72 H 68 V 64 H 74 V 40`} stroke={fg} strokeWidth="9" fill="none" strokeLinejoin="miter" strokeLinecap="butt"/>
        {/* AI text centered */}
        <text x="50" y="58" textAnchor="middle" fill={fg}
              fontFamily="Pretendard Variable, Pretendard, sans-serif"
              fontSize="22" fontWeight="800" letterSpacing="-1">AI</text>
      </svg>
    </LogoFrame>
  );
}

// ── ④ Conversation Curl — single continuous curve ending in a dot.
function LogoCurl({ size = 144, bg = '#1953e8', fg = '#fff', shadow = true }) {
  return (
    <LogoFrame size={size} bg={bg} shadow={shadow}>
      <svg width={size * 0.66} height={size * 0.66} viewBox="0 0 100 100">
        {/* a curl: starts top-right, sweeps down-left, ends at a dot lower-left */}
        <path
          d="M 78 22 C 78 8, 50 8, 30 22 C 8 38, 12 70, 36 78 C 52 84, 62 76, 60 64 C 58 56, 48 56, 44 62"
          stroke={fg} strokeWidth="11" strokeLinecap="round" fill="none"
        />
        <circle cx="42" cy="70" r="6.5" fill={fg}/>
      </svg>
    </LogoFrame>
  );
}

// ── ⑤ Inverted Light — white surface, blue mark. Premium / "Pro" feel.
function LogoLight({ size = 144, bg = '#1953e8', fg = '#fff', shadow = true }) {
  // ignore passed bg/fg — this variant is locked light
  const blue = bg; // use given bg as the mark color
  return (
    <LogoFrame size={size} bg="#ffffff" shadow={shadow} border="1px solid #e3e9f7">
      <svg width={size * 0.62} height={size * 0.62} viewBox="0 0 64 64">
        {/* speech bubble outline */}
        <path d="M14 10 H50 a8 8 0 0 1 8 8 V40 a8 8 0 0 1 -8 8 H30 L18 58 L22 48 H14 a8 8 0 0 1 -8 -8 V18 a8 8 0 0 1 8 -8 Z"
          fill={blue}/>
        {/* sparkle inside in white negative */}
        <path d="M32 17 L34.2 27 L44 29 L34.2 31 L32 41 L29.8 31 L20 29 L29.8 27 Z" fill="#ffffff"/>
      </svg>
    </LogoFrame>
  );
}

Object.assign(window, {
  LogoAITok, LogoMegaTok, LogoBracketAI, LogoCurl, LogoLight,
});
