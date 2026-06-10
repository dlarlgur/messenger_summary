// Option C — AI-Native Soft, parameterized by palette so we can render
// the same design language in 3 different blue tones.

const fontC = '"Pretendard Variable", Pretendard, system-ui, sans-serif';

// ─── three blue palettes ──────────────────────────────────────────────────
const C_SOFT = {
  name: 'soft',
  bg: '#f3f6fc', surface: '#ffffff',
  text: '#0f1430', text2: '#5b6280', text3: '#9097b1',
  hair: '#e7ecf6', border: '#e1e7f3',
  accent: '#3b6dff', accentSoft: '#e7efff', accent2: '#9ab2ff',
  gradStart: '#e6eeff', gradEnd: '#f5f8ff',
  warn: '#b85a36',
};
const C_COBALT = {
  name: 'cobalt',
  bg: '#eef3fb', surface: '#ffffff',
  text: '#0a1430', text2: '#4d5778', text3: '#8a93ad',
  hair: '#e0e7f3', border: '#d6deee',
  accent: '#1953e8', accentSoft: '#dde7ff', accent2: '#7b9eff',
  gradStart: '#dde9ff', gradEnd: '#f0f5ff',
  warn: '#b85a36',
};
const C_DEEP = {
  name: 'deep',
  bg: '#eff1f8', surface: '#ffffff',
  text: '#0a0e26', text2: '#48506e', text3: '#878ea8',
  hair: '#e0e2ee', border: '#d6daea',
  accent: '#2a3aaa', accentSoft: '#dde0f6', accent2: '#7a83cf',
  gradStart: '#dde0f8', gradEnd: '#eff1fb',
  warn: '#a64a2a',
};

// shared shadow recipe per palette
function shadowFor(C) {
  return `0 1px 2px rgba(15,20,48,0.05), 0 8px 24px -12px rgba(15,20,48,0.10)`;
}

// ─── factory: build a full screen set for one palette ─────────────────────
function makeCSet(C) {
  const cardShadow = shadowFor(C);

  function HeaderC({ title, back, right, sub }) {
    return (
      <div style={{ background: C.bg, padding: '14px 16px 14px' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          {back && <button style={{ background: 'transparent', border: 0, color: C.text, padding: 6, marginLeft: -6, cursor: 'pointer' }}><I name="back" size={22}/></button>}
          <div style={{ flex: 1, fontSize: 17, fontWeight: 700, color: C.text, letterSpacing: '-0.02em', display: 'flex', alignItems: 'center', gap: 8 }}>
            <LogoMegaTok size={26} bg={C.accent} fg="#fff" shadow={false}/>
            {title}
          </div>
          {right}
        </div>
        {sub}
      </div>
    );
  }

  const iconBtn = {
    width: 36, height: 36, borderRadius: 10, border: 0, background: 'transparent',
    color: C.text2, display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer',
  };

  function Row({ m }) {
    const big = m.count >= 100;
    return (
      <div style={{
        display: 'flex', gap: 12, padding: '12px 14px',
        background: C.surface, borderRadius: 14, border: `1px solid ${C.border}`,
        boxShadow: cardShadow,
      }}>
        <div style={{
          width: 40, height: 40, borderRadius: 12, background: m.avatarBg,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          fontSize: 14, fontWeight: 700, color: '#fff', flexShrink: 0,
        }}>{m.initial}</div>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: 8 }}>
            <div style={{ fontSize: 14, fontWeight: 600, color: C.text, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', flex: 1, letterSpacing: '-0.005em' }}>{m.name}</div>
            <div style={{ fontSize: 11, color: C.text3, flexShrink: 0, fontVariantNumeric: 'tabular-nums' }}>{m.time}</div>
          </div>
          <div style={{ marginTop: 3, fontSize: 13, color: C.text2, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', lineHeight: '18px' }}>{m.preview}</div>
          <div style={{ marginTop: 7, display: 'flex', alignItems: 'center', gap: 6 }}>
            {m.ai && (
              <span style={{
                display: 'inline-flex', alignItems: 'center', gap: 4,
                fontSize: 10, fontWeight: 700, color: C.accent,
                background: C.accentSoft, padding: '2px 7px', borderRadius: 999,
              }}>
                <I name="spark" size={9}/> AI 요약
              </span>
            )}
            {m.count != null && (
              <span style={{
                fontSize: 10, fontWeight: 600, color: big ? '#fff' : C.text2,
                background: big ? C.accent : C.hair, padding: '2px 8px', borderRadius: 999,
                fontVariantNumeric: 'tabular-nums',
              }}>{m.count}개</span>
            )}
          </div>
        </div>
      </div>
    );
  }

  function AdCard({ ad }) {
    return (
      <div style={{
        display: 'flex', gap: 12, padding: '12px 14px',
        background: 'rgba(255,255,255,0.6)', borderRadius: 14, border: `1px dashed ${C.border}`,
      }}>
        <div style={{ width: 40, height: 40, borderRadius: 12, background: C.hair, color: C.text2, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
          <I name="megaphone" size={18}/>
        </div>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 2 }}>
            <span style={{ fontSize: 9, fontWeight: 700, color: C.text3, letterSpacing: '0.1em' }}>AD</span>
            <div style={{ fontSize: 13.5, fontWeight: 600, color: C.text, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', flex: 1 }}>{ad.name}</div>
          </div>
          <div style={{ fontSize: 12, color: C.text2, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{ad.preview}</div>
        </div>
        <button style={{
          alignSelf: 'center', fontSize: 11, fontWeight: 600, color: C.text2,
          background: C.surface, border: `1px solid ${C.border}`, borderRadius: 8, padding: '5px 10px', cursor: 'pointer',
        }}>더보기</button>
      </div>
    );
  }

  function Main() {
    return (
      <div style={{ background: C.bg, color: C.text, fontFamily: fontC, minHeight: '100%' }}>
        <HeaderC
          title="AI 톡비서"
          right={<div style={{ display: 'flex', gap: 2 }}>
            <button style={iconBtn}><I name="bell" size={20}/></button>
            <button style={iconBtn}><I name="gear" size={20}/></button>
          </div>}
          sub={
            <div style={{
              marginTop: 12, padding: '10px 14px', borderRadius: 12,
              background: `linear-gradient(135deg, ${C.gradStart}, ${C.gradEnd})`,
              border: `1px solid ${C.border}`,
              display: 'flex', alignItems: 'center', gap: 10,
            }}>
              <div style={{ width: 28, height: 28, borderRadius: 8, background: C.accent, color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                <I name="spark" size={15}/>
              </div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: 12, color: C.text2, lineHeight: 1.3 }}>오늘 아침 요약 완료</div>
                <div style={{ fontSize: 13, fontWeight: 600, color: C.text, lineHeight: 1.3 }}>7개 채팅방 · 195개 메시지</div>
              </div>
              <div style={{ fontSize: 11, color: C.text3, fontVariantNumeric: 'tabular-nums' }}>오전 8:13</div>
            </div>
          }
        />
        <div style={{ padding: '6px 16px 4px', display: 'flex', gap: 6, overflowX: 'auto' }}>
          {MESSENGERS.map((m, i) => {
            const active = i === 0;
            return (
              <div key={m.id} style={{
                display: 'inline-flex', alignItems: 'center', gap: 6,
                padding: '8px 12px', borderRadius: 10,
                background: active ? C.accentSoft : 'transparent',
                color: active ? C.accent : C.text2,
                border: `1px solid ${active ? C.accent : C.border}`,
                fontSize: 13, fontWeight: 600, whiteSpace: 'nowrap', flexShrink: 0,
              }}>
                {m.label}
                {m.unread > 0 && (
                  <span style={{
                    fontSize: 10, fontWeight: 700, color: active ? C.accent : C.text3,
                    background: active ? '#fff' : C.bg, padding: '0 5px', borderRadius: 999, minWidth: 16, textAlign: 'center',
                  }}>{m.unread}</span>
                )}
              </div>
            );
          })}
        </div>
        <div style={{ padding: '8px 14px 24px', display: 'flex', flexDirection: 'column', gap: 8 }}>
          {MESSAGES.map(m => m.ad ? <AdCard key={m.id} ad={m}/> : <Row key={m.id} m={m}/>)}
        </div>
      </div>
    );
  }

  function Section({ title, icon, children }) {
    return (
      <div style={{ padding: '20px 16px 0' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 7, padding: '0 4px 10px' }}>
          <I name={icon} size={14} style={{ color: C.accent }}/>
          <div style={{ fontSize: 13, fontWeight: 700, color: C.text, letterSpacing: '-0.005em' }}>{title}</div>
        </div>
        <div style={{ background: C.surface, borderRadius: 16, border: `1px solid ${C.border}`, boxShadow: cardShadow, overflow: 'hidden' }}>{children}</div>
      </div>
    );
  }

  function ToggleRow({ label, sub, on, warn, last }) {
    return (
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '14px 16px', borderBottom: last ? 'none' : `1px solid ${C.hair}` }}>
        <div style={{ flex: 1 }}>
          <div style={{ fontSize: 14, fontWeight: 500, color: C.text }}>{label}</div>
          {sub && <div style={{ marginTop: 2, fontSize: 12, color: warn ? C.warn : C.text3 }}>{sub}</div>}
        </div>
        <div style={{ width: 42, height: 24, borderRadius: 999, background: on ? C.accent : '#dedbeb', position: 'relative' }}>
          <div style={{ position: 'absolute', top: 2, left: on ? 20 : 2, width: 20, height: 20, borderRadius: '50%', background: '#fff', boxShadow: '0 1px 2px rgba(0,0,0,0.15)' }}/>
        </div>
      </div>
    );
  }

  function NavRow({ label, sub, last }) {
    return (
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '14px 16px', borderBottom: last ? 'none' : `1px solid ${C.hair}` }}>
        <div style={{ flex: 1 }}>
          <div style={{ fontSize: 14, fontWeight: 500, color: C.text }}>{label}</div>
          {sub && <div style={{ marginTop: 2, fontSize: 12, color: C.text3 }}>{sub}</div>}
        </div>
        <I name="chevron" size={16} style={{ color: C.text3 }}/>
      </div>
    );
  }

  function SettingsTop() {
    return (
      <div style={{ background: C.bg, color: C.text, fontFamily: fontC, minHeight: '100%', paddingBottom: 24 }}>
        <HeaderC title="앱 설정" back/>
        <div style={{ padding: '8px 16px 0' }}>
          <div style={{
            position: 'relative', overflow: 'hidden',
            background: `linear-gradient(140deg, ${C.gradStart} 0%, #ffffff 100%)`,
            border: `1px solid ${C.border}`,
            borderRadius: 18, padding: '18px 18px',
            boxShadow: cardShadow,
          }}>
            <div style={{ position: 'absolute', top: 14, right: 14, color: C.accent2 }}>
              <I name="spark" size={28}/>
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
              <span style={{ fontSize: 11, fontWeight: 700, color: C.accent, background: '#fff', padding: '3px 9px', borderRadius: 999, border: `1px solid ${C.border}` }}>무료 플랜</span>
            </div>
            <div style={{ marginTop: 12, fontSize: 16, fontWeight: 700, color: C.text, letterSpacing: '-0.01em', lineHeight: 1.35, maxWidth: 220 }}>
              Basic으로 업그레이드해<br/>더 많이 요약하세요
            </div>
            <div style={{ marginTop: 14, display: 'flex', flexDirection: 'column', gap: 7 }}>
              {SETTINGS_TOP.plan.items.map(it => (
                <div key={it} style={{ display: 'flex', alignItems: 'center', gap: 9, fontSize: 13, color: C.text2 }}>
                  <div style={{ width: 16, height: 16, borderRadius: '50%', background: C.accent, color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                    <I name="check" size={11}/>
                  </div>
                  {it}
                </div>
              ))}
            </div>
            <button style={{
              marginTop: 14, width: '100%',
              background: C.accent, color: '#fff', border: 0, borderRadius: 12,
              padding: '11px 14px', fontSize: 13, fontWeight: 700, cursor: 'pointer',
            }}>Basic 살펴보기</button>
          </div>
        </div>
        <Section title="알림" icon="bell">
          {SETTINGS_TOP.notif.rows.map((r, i) => <ToggleRow key={i} {...r} last={i === SETTINGS_TOP.notif.rows.length - 1}/>)}
        </Section>
        <Section title="채팅방 설정" icon="msg">
          {SETTINGS_TOP.chat.rows.map((r, i) => <NavRow key={i} {...r} last={i === SETTINGS_TOP.chat.rows.length - 1}/>)}
        </Section>
      </div>
    );
  }

  function SettingsBot() {
    return (
      <div style={{ background: C.bg, color: C.text, fontFamily: fontC, minHeight: '100%', paddingBottom: 28 }}>
        <HeaderC title="앱 설정" back/>
        <Section title="소식·도움말" icon="megaphone">
          {SETTINGS_BOT.news.rows.map((r, i) => <NavRow key={i} {...r} last={i === SETTINGS_BOT.news.rows.length - 1}/>)}
        </Section>
        <Section title="일반" icon="gear">
          {SETTINGS_BOT.general.rows.map((r, i) => <NavRow key={i} {...r} last={i === SETTINGS_BOT.general.rows.length - 1}/>)}
        </Section>
        <div style={{ marginTop: 28, textAlign: 'center', fontSize: 11, color: C.text3, lineHeight: '18px' }}>
          <div style={{ display: 'inline-flex', alignItems: 'center', gap: 5, color: C.accent, marginBottom: 6, fontWeight: 600 }}>
            <I name="spark" size={11}/> AI 톡비서
          </div>
          <div>{SETTINGS_BOT.footer.v}</div>
          <div style={{ marginTop: 2 }}>{SETTINGS_BOT.footer.c}</div>
        </div>
      </div>
    );
  }

  return { Main, SettingsTop, SettingsBot };
}

// ─── instantiate three palettes ───────────────────────────────────────────
const C1 = makeCSet(C_SOFT);
const C2 = makeCSet(C_COBALT);
const C3 = makeCSet(C_DEEP);

Object.assign(window, { C1, C2, C3, C_SOFT, C_COBALT, C_DEEP });
