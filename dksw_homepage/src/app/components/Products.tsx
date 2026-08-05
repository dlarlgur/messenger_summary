'use client';

import { motion } from 'framer-motion';
import Container from './Container';
import SectionTag from './SectionTag';
import StoreBadge from './StoreBadge';
import { DeviceShot } from '../charge/Mockups';

type Product = {
  name: string;
  tagline: string;
  description: string;
  features: string[];
  gradient: string;
  badge: string;
  mockup: React.ReactNode;
  links: { appStore?: string; playStore?: string };
};

const PRODUCTS: Product[] = [
  {
    name: 'AI 톡비서',
    badge: 'B2C · Messenger AI',
    tagline: '수백 개의 메시지,\nAI가 대신 읽고 정리해요.',
    description:
      '카카오톡 · LINE · Telegram · Instagram 등 흩어진 단톡방과 오픈채팅의 놓친 메시지를 AI가 대신 읽고 핵심만 정리해서 보여줍니다. 중요한 대화 · 광고 · 스팸을 자동으로 분류해, 바쁠 때도 중요한 이야기를 놓치지 않습니다.',
    features: [
      '카카오톡 · LINE · Telegram · Instagram 통합',
      '놓친 대화를 AI가 대신 읽고 정리',
      '중요 대화 · 광고 · 스팸 자동 분류',
      '키워드 · 관심사 기반 알림 우선순위',
    ],
    gradient: 'from-[#3B82F6] via-[#1E40AF] to-[#0B1733]',
    mockup: <TokBiseoMockup />,
    links: {
      playStore: 'https://play.google.com/store/apps/details?id=com.dksw.app',
    },
  },
  {
    name: '전기차 기름차',
    badge: 'B2C · Mobility',
    tagline: '전국 주유소 · 충전소,\n한 화면에 한눈에.',
    description:
      '오피넷 주유소 가격과 환경부 충전소 현황을 한 화면에 통합. 주변 주유소 · 충전소의 가격, 이용 가능 여부, 속도, 회원 · 비회원 단가까지 한눈에 비교하고, AI가 현재 위치와 경로에 맞는 주유소 · 충전소를 찾아줍니다.',
    features: [
      '주변 충전소 실시간 가용률 · 속도 · 커넥터',
      '회원 / 비회원 단가 비교',
      '오피넷 기반 주유소 실시간 유가',
      'AI가 찾아주는 현재 위치 · 경로 맞춤 추천',
    ],
    gradient: 'from-[#22C55E] via-[#15803D] to-[#052E1C]',
    mockup: <ChargeMockup />,
    links: {
      appStore: 'https://apps.apple.com/kr/app/id6792645861',
      playStore: 'https://play.google.com/store/apps/details?id=com.dksw.charge',
    },
  },
];

export default function Products() {
  return (
    <section id="products" className="relative py-28 md:py-36 overflow-hidden">
      <div aria-hidden className="pointer-events-none absolute inset-0 -z-10">
        <div className="absolute right-[-10%] top-[20%] h-[520px] w-[520px] rounded-full bg-brand-700/15 blur-[140px]" />
      </div>

      <Container>
        <div className="flex flex-col items-center text-center">
          <SectionTag>Our Products</SectionTag>
          <h2 className="mt-6 text-[38px] md:text-[52px] font-semibold leading-[1.08] tracking-tightest text-fog-100 max-w-[820px]">
            우리가 직접 만들어
            <br className="hidden md:block" />{' '}
            <span className="grad-text">매일 쓰는 서비스.</span>
          </h2>
          <p className="mt-6 max-w-[600px] text-[15.5px] leading-relaxed text-fog-300">
            DK Software가 기획 · 개발 · 운영하는 자체 서비스 라인업입니다.
            사용자 피드백을 받고 주 단위로 업데이트하고 있습니다.
          </p>
        </div>

        <div className="mt-20 space-y-20 md:space-y-28">
          {PRODUCTS.map((p, i) => (
            <ProductRow key={p.name} product={p} reversed={i % 2 === 1} />
          ))}
        </div>
      </Container>
    </section>
  );
}

function ProductRow({ product, reversed }: { product: Product; reversed: boolean }) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 40 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true, margin: '-80px' }}
      transition={{ duration: 0.8 }}
      className={`grid grid-cols-1 lg:grid-cols-2 gap-10 lg:gap-20 items-center ${
        reversed ? 'lg:[&>div:first-child]:order-2' : ''
      }`}
    >
      <div className="relative flex items-center justify-center min-h-[540px]">
        <div
          className={`absolute inset-0 rounded-[40px] bg-gradient-to-br ${product.gradient} opacity-25 blur-3xl`}
        />
        <div className="relative">{product.mockup}</div>
      </div>

      <div>
        <span className="inline-flex items-center gap-2 rounded-full border border-white/10 bg-white/[0.03] px-3 py-1 text-[11px] font-medium tracking-[0.12em] text-fog-300 uppercase">
          {product.badge}
        </span>
        <h3 className="mt-5 text-[32px] md:text-[42px] font-semibold leading-[1.1] tracking-tight text-fog-100 whitespace-pre-line">
          {product.tagline}
        </h3>
        <p className="mt-5 text-[15.5px] leading-relaxed text-fog-300">{product.description}</p>
        <ul className="mt-7 space-y-3">
          {product.features.map((f) => (
            <li key={f} className="flex items-start gap-3 text-[14px] text-fog-200">
              <CheckIcon />
              <span>{f}</span>
            </li>
          ))}
        </ul>
        <div className="mt-8 flex flex-wrap gap-3">
          <span className="inline-flex items-center gap-2 rounded-lg border border-white/10 bg-white/[0.03] px-3.5 py-2 text-[12px] font-medium text-fog-300">
            <DotLive /> 정식 운영중
          </span>
        </div>
        <div className="mt-5 flex flex-wrap gap-3">
          {product.links.appStore && (
            <StoreBadge store="apple" href={product.links.appStore} />
          )}
          {product.links.playStore && (
            <StoreBadge store="google" href={product.links.playStore} />
          )}
        </div>
      </div>
    </motion.div>
  );
}

function CheckIcon() {
  return (
    <span className="mt-[2px] inline-flex h-[18px] w-[18px] shrink-0 items-center justify-center rounded-full bg-brand-500/15 text-brand-300 ring-1 ring-inset ring-brand-500/30">
      <svg width="10" height="10" viewBox="0 0 10 10" fill="none" aria-hidden>
        <path
          d="M1.5 5.2 4 7.5 8.5 2.5"
          stroke="currentColor"
          strokeWidth="1.8"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
      </svg>
    </span>
  );
}

function DotLive() {
  return (
    <span className="relative flex h-2 w-2">
      <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-emerald-400/70 opacity-75" />
      <span className="relative inline-flex h-2 w-2 rounded-full bg-emerald-400" />
    </span>
  );
}

/* =========================================================
   AI 톡비서 — 실제 앱 화면 재현 (형 스크린샷 기준).
   밝은 배경 + 필 탭(KakaoTalk 99+) + 광고 카드 + 채팅 목록.
   방 제목·메시지는 전부 임시 텍스트 (실제 대화 노출 금지).
   ========================================================= */
function TokBiseoMockup() {
  return (
    <PhoneFrame>
      <div className="relative h-full w-full bg-[#EEF2F8] flex flex-col text-[#111827]">
        {/* Status bar */}
        <div className="h-7 flex items-center justify-between px-4 pt-1.5 text-[10px] font-semibold text-[#111827]">
          <span>오후 4:19</span>
          <span className="flex items-center gap-1">
            <span className="text-[8px] tracking-tight text-[#374151]">LTE ▮▮▮</span>
            <span className="rounded-full border border-[#111827]/60 px-1 text-[8px] font-bold">100</span>
          </span>
        </div>
        {/* Header — 로고 칩 + 타이틀 */}
        <div className="px-3.5 pt-1 pb-2 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <span className="h-7 w-7 rounded-[9px] bg-[#3B62F6] text-white text-[12px] font-extrabold flex items-center justify-center shadow-sm">
              톡
            </span>
            <span className="text-[15px] font-extrabold tracking-tight">AI 톡비서</span>
          </div>
          <div className="flex items-center gap-2.5 text-[#374151]">
            <BellIcon />
            <CogIcon />
          </div>
        </div>
        {/* Messenger pill tabs */}
        <div className="px-3 pb-2">
          <div className="flex items-center gap-1.5 overflow-hidden">
            <MessengerPill label="KakaoTalk" badge="99+" active />
            <MessengerPill label="LINE" />
            <MessengerPill label="WhatsApp" />
            <MessengerPill label="Tel" cut />
          </div>
        </div>
        {/* 채팅 목록 — 임시 방제목·내용, 광고 요소 없음 (형 지시) */}
        <div className="flex-1 overflow-hidden bg-white">
          <ChatRow tint="#0EA5E9" emoji="🏢" name="아파트 입주민 회의" msg="관리비 안건은 다음 주에 다시 논의…" time="오후 4:11" unread={83} ai muted />
          <ChatRow tint="#F472B6" emoji="🍼" name="육아용품 공동구매" msg="사전 등록하신 분께 발송되는 안내…" time="오후 4:08" unread={2} />
          <ChatRow tint="#8B5CF6" emoji="🌆" name="소유주 정기 모임" msg="네 전문가도 그렇게 얘기하더라구요." time="오후 4:07" unread={162} ai muted />
          <ChatRow tint="#F59E0B" emoji="🏃" name="주말 러닝 크루" msg="내일 아침 7시 집결입니다" time="오후 4:05" unread={61} />
          <ChatRow tint="#10B981" emoji="📋" name="운영위원회" msg="회의록 공유드립니다" time="오후 3:58" unread={156} ai muted />
          <ChatRow tint="#64748B" emoji="🚗" name="전기차 정보공유" msg="5년 뒤엔 그냥 신형으로 갈까…" time="오후 3:56" unread={569} ai muted />
          <ChatRow tint="#0284C7" emoji="⚽" name="주말 풋살 모임" msg="이번 주 토요일 10시 확정입니다" time="오후 3:41" unread={34} ai muted />
          <ChatRow tint="#DB2777" emoji="🎂" name="가족 단톡방" msg="주말에 케이크 픽업 부탁해~" time="오후 3:12" unread={5} />
        </div>
      </div>
    </PhoneFrame>
  );
}

function MessengerPill({
  label,
  active,
  badge,
  cut,
}: {
  label: string;
  active?: boolean;
  badge?: string;
  cut?: boolean;
}) {
  return (
    <span
      className={`inline-flex shrink-0 items-center gap-1 rounded-full border px-2.5 py-1.5 text-[10px] font-bold ${
        active
          ? 'border-[#3B62F6] bg-[#EBF1FF] text-[#2F5BFF]'
          : 'border-black/10 bg-white text-[#374151]'
      } ${cut ? 'w-[34px] overflow-hidden' : ''}`}
    >
      <ChatBubbleIcon />
      {label}
      {badge && (
        <span className="rounded-full bg-[#2F5BFF] px-1.5 py-[1px] text-[7.5px] font-extrabold text-white">
          {badge}
        </span>
      )}
    </span>
  );
}

function ChatRow({
  tint,
  emoji,
  name,
  msg,
  time,
  unread,
  ai,
  muted,
}: {
  tint: string;
  emoji: string;
  name: string;
  msg: string;
  time: string;
  unread: number;
  ai?: boolean;
  muted?: boolean;
}) {
  return (
    <div className="flex items-center gap-2.5 px-3 py-2.5 border-b border-black/[0.05]">
      <span
        className="h-9 w-9 rounded-full shrink-0 flex items-center justify-center text-[15px]"
        style={{ background: `${tint}26`, boxShadow: `inset 0 0 0 1px ${tint}40` }}
      >
        {emoji}
      </span>
      <div className="flex-1 min-w-0">
        <div className="text-[10.5px] font-extrabold text-[#111827] truncate">{name}</div>
        <div className="text-[9px] text-[#6B7280] truncate mt-0.5">{msg}</div>
      </div>
      <div className="flex flex-col items-end gap-1 shrink-0">
        <div className="flex items-center gap-1">
          {ai && <SparkleIcon />}
          {muted && <MutedBellIcon />}
          <span className="text-[8.5px] text-[#9CA3AF]">{time}</span>
        </div>
        <span className="bg-[#2F5BFF] text-white text-[8.5px] font-bold rounded-full min-w-[18px] h-[15px] px-1.5 flex items-center justify-center">
          {unread}
        </span>
      </div>
    </div>
  );
}

function ChatBubbleIcon() {
  return (
    <svg width="10" height="10" viewBox="0 0 24 24" fill="none" aria-hidden>
      <path
        d="M21 12a8 8 0 0 1-8 8H4l2.3-2.7A8 8 0 1 1 21 12Z"
        stroke="currentColor"
        strokeWidth="2.2"
        strokeLinejoin="round"
      />
    </svg>
  );
}

function SparkleIcon() {
  return (
    <svg width="11" height="11" viewBox="0 0 24 24" fill="#5B8DEF" aria-hidden>
      <path d="M12 2l1.8 5.7L19.5 9l-5.7 1.8L12 16.5l-1.8-5.7L4.5 9l5.7-1.3L12 2Z" />
      <path d="M19 15l.9 2.6 2.6.9-2.6.9L19 22l-.9-2.6-2.6-.9 2.6-.9L19 15Z" />
    </svg>
  );
}

function MutedBellIcon() {
  return (
    <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="#9CA3AF" strokeWidth="1.8" strokeLinecap="round" aria-hidden>
      <path d="M6 8a6 6 0 1 1 12 0c0 7 3 7 3 9H3c0-2 3-2 3-9Zm4 13a2 2 0 0 0 4 0" />
      <path d="M3 3l18 18" />
    </svg>
  );
}

function BellIcon() {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" aria-hidden>
      <path
        d="M6 8a6 6 0 1 1 12 0c0 7 3 7 3 9H3c0-2 3-2 3-9Zm4 13a2 2 0 0 0 4 0"
        stroke="currentColor"
        strokeWidth="1.6"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}
function CogIcon() {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" aria-hidden>
      <circle cx="12" cy="12" r="3" stroke="currentColor" strokeWidth="1.6" />
      <path
        d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1A1.7 1.7 0 0 0 4.6 9a1.7 1.7 0 0 0-.3-1.8l-.1-.1A2 2 0 1 1 7 4.3l.1.1a1.7 1.7 0 0 0 1.8.3h0a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8v0a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1Z"
        stroke="currentColor"
        strokeWidth="1.4"
        strokeLinejoin="round"
      />
    </svg>
  );
}

/* =========================================================
   전기차 기름차 — 실기기 캡처 2대 (주유/충전), /charge 히어로와 동일 소스.
   CSS 재현본은 실사보다 못해서 폐기 (형 컨펌: 실사가 더 진짜 같음).
   ========================================================= */
function ChargeMockup() {
  return (
    <div className="relative flex max-w-full items-center justify-center">
      <div className="-mr-14 hidden -rotate-6 scale-[0.92] transition-transform duration-500 hover:rotate-[-3deg] min-[420px]:block">
        <DeviceShot
          src="/charge/screens/home-fuel.jpg"
          alt="전기차 기름차 — 주유소 최저가 홈 화면 (실제 앱 화면)"
        />
      </div>
      <div className="z-10 rotate-3 transition-transform duration-500 hover:rotate-1">
        <DeviceShot
          src="/charge/screens/home-ev.jpg"
          alt="전기차 기름차 — 충전소 빈자리 홈 화면 (실제 앱 화면)"
        />
      </div>
    </div>
  );
}

function PhoneFrame({ children }: { children: React.ReactNode }) {
  return (
    <div className="relative mx-auto animate-float-slow">
      <div className="relative h-[560px] w-[272px] rounded-[44px] bg-[#0B0B10] p-[10px] shadow-[0_40px_80px_-20px_rgba(0,0,0,0.7),0_0_0_1px_rgba(255,255,255,0.08),inset_0_0_0_1px_rgba(255,255,255,0.04)]">
        <div className="absolute left-1/2 top-[10px] z-20 h-[20px] w-[92px] -translate-x-1/2 rounded-full bg-black" />
        <div className="relative h-full w-full overflow-hidden rounded-[34px] bg-black">
          {children}
        </div>
        <div className="absolute -left-[3px] top-[100px] h-[46px] w-[3px] rounded-l bg-white/10" />
        <div className="absolute -left-[3px] top-[160px] h-[70px] w-[3px] rounded-l bg-white/10" />
        <div className="absolute -right-[3px] top-[130px] h-[90px] w-[3px] rounded-r bg-white/10" />
      </div>
    </div>
  );
}
