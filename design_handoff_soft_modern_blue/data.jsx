// Shared data + tiny SVG icons used across all three design directions.

const MESSAGES = [
  { id: '1',  initial: '원', avatarBg: '#ffd2e0', name: '내사랑원이❤️', preview: '응', time: '오전 8:09', count: 17,  source: 'kakao', ai: true },
  { id: '2',  initial: '동', avatarBg: '#cfe8d4', name: '동천자이아파트 소통 및 정보 나눔', preview: '우와 수고 많으셨습니다. 스티커 없는 차량이 이렇게나 많다니 심각하네요...', time: '오전 7:52', count: 111, source: 'kakao', ai: true },
  { id: '3',  initial: '운', avatarBg: '#dfe2ea', name: '운영위원회', preview: '이건 혹시 세금 미납으로 변호인 뺏긴거라나요?', time: '오후 11:23', count: 25, source: 'kakao', ai: true },
  { id: 'ad1', ad: true, name: '테스트 광고 : KMS·AI기반 지식관리...', preview: '보이는ARS·웹보이스 임대' },
  { id: '5',  initial: '5', avatarBg: '#ffe2c2', name: '♡ 동천자이 5기 입대의 공식...', preview: 'ㅋㅋ', time: '오후 9:54', count: 21, source: 'kakao', ai: true },
  { id: '6',  initial: '입', avatarBg: '#d8d4ee', name: '[동천자이] 입대의 + 송주법', preview: '한천에 문의 / 1. 2026년 동천자이 최종 사업비 재확인', time: '오후 7:40', source: 'kakao' },
  { id: '7',  initial: '소', avatarBg: '#cfe0ee', name: '동천자이 소유주 모임', preview: '동족혐오네요 완전ㅋ', time: '오후 6:36', source: 'kakao' },
];

const MESSENGERS = [
  { id: 'kakao',    label: '카카오톡',  unread: 3 },
  { id: 'line',     label: 'LINE',      unread: 0 },
  { id: 'telegram', label: 'Telegram',  unread: 2 },
  { id: 'instagram',label: 'Instagram', unread: 0 },
];

const SETTINGS_TOP = {
  plan: {
    badge: '무료 플랜',
    headline: 'Basic으로 업그레이드해 더 많이 요약하세요',
    items: ['하루 최대 5회 무료 요약', '메시지 최대 50개 요약', '3회 광고 시청 시 제공'],
  },
  notif: {
    title: 'AI 톡비서 알림',
    rows: [
      { label: '자동 요약 알림', sub: '알림 권한이 필요합니다', on: false, warn: true },
      { label: '소리',           sub: '알림이 꺼져 있습니다',   on: false },
      { label: '진동',           sub: '알림이 꺼져 있습니다',   on: false },
    ],
  },
  chat: {
    title: '채팅방 설정',
    rows: [
      { icon: 'msg',    label: '메신저 관리',       sub: '사용할 메신저 선택 및 순서 변경' },
      { icon: 'block',  label: '차단된 채팅방 관리', sub: '요약에서 제외할 채팅방' },
      { icon: 'spark',  label: '요약 관리',         sub: '요약 표시 방식 설정' },
    ],
  },
};

const SETTINGS_BOT = {
  news: {
    title: '소식·도움말',
    rows: [
      { icon: 'megaphone', tint: '#dbeafe', tintFg: '#1d4ed8', label: '공지사항',     sub: '새 공지를 확인해보세요' },
      { icon: 'party',     tint: '#ffe2d6', tintFg: '#c2410c', label: '이벤트',       sub: '진행 중 이벤트가 있을 수 있어요' },
      { icon: 'help',      tint: '#d6f5e1', tintFg: '#047857', label: '자주 묻는 질문', sub: '15건 등록됨' },
    ],
  },
  general: {
    title: '일반',
    rows: [
      { icon: 'star',    tint: '#fff4c4', tintFg: '#b45309', label: '리뷰를 남겨주세요',   sub: '소중한 리뷰가 큰 힘이 됩니다' },
      { icon: 'share',   tint: '#dfeae2', tintFg: '#15803d', label: '친구에게 추천하기',   sub: '앱을 친구와 공유해보세요' },
      { icon: 'qmark',   tint: '#dbeafe', tintFg: '#1d4ed8', label: 'AI 톡비서 사용방법', sub: '앱 사용 가이드' },
      { icon: 'info',    tint: '#dbeafe', tintFg: '#1d4ed8', label: 'AI 톡비서 란',       sub: '앱 소개 및 기능 안내' },
      { icon: 'policy',  tint: '#d6f5e1', tintFg: '#047857', label: '정책 및 약관',       sub: '개인정보처리방침·이용약관 등' },
    ],
  },
  footer: { v: 'App version: 1.0.30', c: 'Copyright 2026. 동키소프트웨어 All rights reserved.' },
};

// ─────────────────────────────────────────────────────────────
// Icons — single-stroke, currentColor. Pass size as prop.
// ─────────────────────────────────────────────────────────────
const stroke = { stroke: 'currentColor', strokeWidth: 1.6, strokeLinecap: 'round', strokeLinejoin: 'round', fill: 'none' };

function I({ name, size = 18, style }) {
  const p = { width: size, height: size, viewBox: '0 0 24 24', style };
  switch (name) {
    case 'bell':      return <svg {...p}><path {...stroke} d="M6 9a6 6 0 0112 0v4l1.5 2.5H4.5L6 13V9z"/><path {...stroke} d="M10 19a2 2 0 004 0"/></svg>;
    case 'gear':      return <svg {...p}><circle {...stroke} cx="12" cy="12" r="3"/><path {...stroke} d="M19.4 13.5a1.6 1.6 0 010-3l1-.5-1.5-2.6-1.1.3a1.6 1.6 0 01-2.6-1.5l.3-1L13 4l-.5 1a1.6 1.6 0 01-3 0L9 4 6.4 5.7l.3 1.1a1.6 1.6 0 01-2.6 1.5L3 8l-1.5 2.6 1 .5a1.6 1.6 0 010 3l-1 .5L3 17l1.1-.3a1.6 1.6 0 012.6 1.5l-.3 1.1L9 20l.5-1a1.6 1.6 0 013 0l.5 1 2.6-1.7-.3-1.1a1.6 1.6 0 012.6-1.5l1.1.3 1.5-2.6-1-.5z"/></svg>;
    case 'back':      return <svg {...p}><path {...stroke} d="M15 5l-7 7 7 7"/></svg>;
    case 'play':      return <svg {...p}><path {...stroke} d="M8 5l11 7-11 7V5z" fill="currentColor"/></svg>;
    case 'spark':     return <svg {...p}><path {...stroke} d="M12 3l1.6 5L19 9.5l-5 1.7L12 17l-1.7-5.8L5 9.5l5.4-1.5L12 3z" fill="currentColor"/></svg>;
    case 'sparkLine': return <svg {...p}><path {...stroke} d="M12 3l1.6 5L19 9.5l-5 1.7L12 17l-1.7-5.8L5 9.5l5.4-1.5L12 3z"/></svg>;
    case 'bellOff':   return <svg {...p}><path {...stroke} d="M6 9a6 6 0 019.6-4.8M18 13V9c0-.7-.1-1.3-.3-2M6 13V9l-1.5 4.5h12M4 4l16 16"/><path {...stroke} d="M10 19a2 2 0 004 0"/></svg>;
    case 'speakerOff':return <svg {...p}><path {...stroke} d="M3 10v4h3l4 3V7L6 10H3zM17 9c1.2 1.2 1.2 5.8 0 7M4 4l16 16"/></svg>;
    case 'phone':     return <svg {...p}><rect {...stroke} x="7" y="3" width="10" height="18" rx="2"/><path {...stroke} d="M11 18h2"/></svg>;
    case 'msg':       return <svg {...p}><path {...stroke} d="M4 6a2 2 0 012-2h12a2 2 0 012 2v9a2 2 0 01-2 2H9l-5 4V6z"/></svg>;
    case 'block':     return <svg {...p}><circle {...stroke} cx="12" cy="12" r="8"/><path {...stroke} d="M6 6l12 12"/></svg>;
    case 'megaphone': return <svg {...p}><path {...stroke} d="M4 10v4l11 5V5L4 10zM4 10H3a2 2 0 000 4h1"/></svg>;
    case 'party':     return <svg {...p}><path {...stroke} d="M5 19l3-10 7 7-10 3zM13 4l1 2M18 5l2 1M16 9l3-1"/></svg>;
    case 'help':      return <svg {...p}><circle {...stroke} cx="12" cy="12" r="8"/><path {...stroke} d="M9.5 9.5a2.5 2.5 0 015 0c0 1.5-2.5 2-2.5 3.5"/><circle cx="12" cy="17" r="1" fill="currentColor"/></svg>;
    case 'star':      return <svg {...p}><path {...stroke} d="M12 3l2.6 6L21 10l-5 4.5L17.5 21 12 17.5 6.5 21 8 14.5 3 10l6.4-1L12 3z" fill="currentColor"/></svg>;
    case 'share':     return <svg {...p}><circle {...stroke} cx="6" cy="12" r="2.5"/><circle {...stroke} cx="18" cy="6" r="2.5"/><circle {...stroke} cx="18" cy="18" r="2.5"/><path {...stroke} d="M8.2 11l7.6-3.7M8.2 13l7.6 3.7"/></svg>;
    case 'qmark':     return <svg {...p}><circle {...stroke} cx="12" cy="12" r="8"/><path {...stroke} d="M9.5 9.5a2.5 2.5 0 015 0c0 1.5-2.5 2-2.5 3.5"/><circle cx="12" cy="17" r="1" fill="currentColor"/></svg>;
    case 'info':      return <svg {...p}><circle {...stroke} cx="12" cy="12" r="8"/><path {...stroke} d="M12 11v5"/><circle cx="12" cy="8" r="1" fill="currentColor"/></svg>;
    case 'policy':    return <svg {...p}><path {...stroke} d="M12 3l8 3v6c0 5-4 8-8 9-4-1-8-4-8-9V6l8-3z"/><path {...stroke} d="M9 12l2 2 4-4"/></svg>;
    case 'chevron':   return <svg {...p}><path {...stroke} d="M9 6l6 6-6 6"/></svg>;
    case 'check':     return <svg {...p}><path {...stroke} d="M5 12l4 4 10-10"/></svg>;
    case 'dot':       return <svg {...p}><circle cx="12" cy="12" r="4" fill="currentColor"/></svg>;
    case 'reorder':   return <svg {...p}><path {...stroke} d="M3 12h14M3 6h14M3 18h14M19 12l2-2 2 2M19 6l2-2 2 2M19 18l2 2 2-2" /></svg>;
    default: return null;
  }
}

Object.assign(window, { MESSAGES, MESSENGERS, SETTINGS_TOP, SETTINGS_BOT, I });
