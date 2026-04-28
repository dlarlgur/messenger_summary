'use client';

import { motion } from 'framer-motion';
import Container from './Container';
import SectionTag from './SectionTag';
import StoreBadge from './StoreBadge';

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
    name: '모두의 주유충전',
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
   AI 톡비서 — Multi-messenger aggregated feed
   Matches actual app: blue header, 4 messenger tabs,
   chat room rows with AI 3-line summaries
   ========================================================= */
function TokBiseoMockup() {
  return (
    <PhoneFrame>
      <div className="relative h-full w-full bg-[#F5F6F8] flex flex-col text-[#111827]">
        {/* Status bar */}
        <div className="h-7 flex items-center justify-between px-5 pt-1.5 text-[10px] font-semibold text-white bg-[#3B82F6]">
          <span>오후 2:04</span>
          <span>●●● 5G 96</span>
        </div>
        {/* Header */}
        <div className="bg-[#3B82F6] px-4 pt-2 pb-3 text-white">
          <div className="flex items-center justify-between">
            <div className="text-[15px] font-bold tracking-tight">AI 톡비서</div>
            <div className="flex items-center gap-3">
              <div className="relative">
                <BellIcon />
                <span className="absolute -top-0.5 -right-0.5 h-1.5 w-1.5 rounded-full bg-red-500 ring-2 ring-[#3B82F6]" />
              </div>
              <CogIcon />
            </div>
          </div>
        </div>
        {/* Messenger tabs */}
        <div className="bg-white border-b border-black/5 px-3">
          <div className="flex items-center gap-1 overflow-x-auto no-scrollbar">
            <MessengerTab label="카카오톡" badge="N" active />
            <MessengerTab label="LINE" />
            <MessengerTab label="Telegram" />
            <MessengerTab label="Instagram" />
          </div>
        </div>
        {/* Rooms list — AI summary previews */}
        <div className="flex-1 overflow-hidden bg-white">
          <RoomRow
            color="#3B82F6"
            emoji="🏢"
            name="회사 공지방"
            summary="AI 요약 · 금요일 전사 미팅 오후 3시 · 신규 복지 공지 · 워크샵 장소 변경"
            time="오후 2:01"
            unread={42}
          />
          <RoomRow
            color="#10B981"
            emoji="💼"
            name="프로젝트 A 단톡"
            summary="AI 요약 · 디자인 v2 완료, 내일 리뷰 · 서버 배포 지연 이슈 공유"
            time="오후 1:48"
            unread={17}
          />
          <RoomRow
            color="#F59E0B"
            emoji="📣"
            name="오픈채팅 · 부동산 정보"
            summary="쇼핑몰 쿠폰 안내 · 보험 가입 권유"
            time=""
            ad
          />
          <RoomRow
            color="#EC4899"
            emoji="🎮"
            name="게임 길드 모임"
            summary="AI 요약 · 주말 레이드 8시 집결 · 신규 장비 공유 · 길드전 일정 확정"
            time="오후 1:12"
            unread={28}
          />
          <RoomRow
            color="#8B5CF6"
            emoji="📚"
            name="독서 모임"
            summary="AI 요약 · 이번 주 책 선정 완료 · 모임 장소 카페 N · 출석 확인"
            time="오전 11:54"
            unread={6}
          />
          <RoomRow
            color="#06B6D4"
            emoji="👨‍👩‍👧"
            name="가족 단톡"
            summary="AI 요약 · 주말 식사 약속 · 어머니 생신 선물 논의"
            time="오전 10:32"
            unread={3}
          />
        </div>
        {/* Page indicator */}
        <div className="h-6 flex items-center justify-center bg-white border-t border-black/5">
          <span className="text-[9px] font-bold text-white bg-black/80 rounded-full px-2 py-0.5">
            📷 1/2
          </span>
        </div>
      </div>
    </PhoneFrame>
  );
}

function MessengerTab({ label, active, badge }: { label: string; active?: boolean; badge?: string }) {
  return (
    <div className="relative shrink-0 px-3 py-2.5">
      <div className="flex items-center gap-1">
        <span
          className={`text-[11px] font-semibold ${active ? 'text-[#111827]' : 'text-[#9CA3AF]'}`}
        >
          {label}
        </span>
        {badge && (
          <span className="h-3 w-3 rounded-full bg-red-500 text-white text-[7.5px] font-bold flex items-center justify-center">
            {badge}
          </span>
        )}
      </div>
      {active && (
        <div className="absolute left-1 right-1 bottom-0 h-[2px] rounded-full bg-[#FBBF24]" />
      )}
    </div>
  );
}

function RoomRow({
  color,
  emoji,
  name,
  summary,
  time,
  unread,
  ad,
}: {
  color: string;
  emoji: string;
  name: string;
  summary: string;
  time?: string;
  unread?: number;
  ad?: boolean;
}) {
  return (
    <div className="flex items-center gap-2.5 px-3 py-2.5 border-b border-black/[0.04]">
      <div
        className="h-9 w-9 rounded-lg shrink-0 flex items-center justify-center text-[13px] text-white font-bold"
        style={{ background: color }}
      >
        {emoji}
      </div>
      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-1">
          <div className="text-[11.5px] font-bold text-[#111827] truncate">{name}</div>
          <span className="inline-flex h-2.5 w-2.5 items-center justify-center text-[8px]">
            ✨
          </span>
          {ad && (
            <span className="bg-gray-200 text-gray-600 text-[8px] font-bold px-1 py-0 rounded">
              광고
            </span>
          )}
        </div>
        <div className="text-[10px] leading-tight text-[#4B5563] truncate mt-0.5">{summary}</div>
      </div>
      <div className="flex flex-col items-end gap-0.5 shrink-0">
        {time && <div className="text-[8.5px] text-[#9CA3AF]">{time}</div>}
        {unread != null && (
          <div className="bg-[#3B82F6] text-white text-[9px] font-bold rounded-full min-w-[16px] h-[16px] px-1 flex items-center justify-center">
            {unread}
          </div>
        )}
      </div>
    </div>
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
   모두의 주유충전 — Charging/Gas station aggregator
   Matches actual app: 충전/주유 toggle, station count card,
   detailed station rows with price & availability
   ========================================================= */
function ChargeMockup() {
  return (
    <PhoneFrame>
      <div className="relative h-full w-full bg-[#F3F4F6] flex flex-col text-[#111827]">
        {/* Status bar */}
        <div className="h-7 flex items-center justify-between px-5 pt-1.5 text-[10px] font-semibold text-[#111827]">
          <span>오후 2:04</span>
          <span>●●● 5G 96</span>
        </div>
        {/* Header */}
        <div className="px-4 py-2 flex items-center justify-between bg-[#F3F4F6]">
          <div className="text-[15px] font-bold">모두의 주유충전</div>
          <div className="relative">
            <BellIcon />
            <span className="absolute -top-0.5 -right-0.5 h-1.5 w-1.5 rounded-full bg-red-500" />
          </div>
        </div>
        {/* Toggle */}
        <div className="px-3">
          <div className="flex gap-2">
            <button className="flex-1 flex items-center justify-center gap-1 bg-[#10B981] text-white rounded-xl py-2 text-[12px] font-bold shadow-sm">
              <span>⚡</span> 충전
            </button>
            <button className="flex-1 flex items-center justify-center gap-1 bg-white text-[#6B7280] rounded-xl py-2 text-[12px] font-semibold border border-black/5">
              <span>⛽</span> 주유
            </button>
          </div>
        </div>
        {/* Search + sort */}
        <div className="px-3 mt-2 flex gap-2">
          <div className="flex-1 flex items-center gap-1.5 bg-white rounded-xl px-3 py-1.5 border border-black/5">
            <span className="text-[10px]">🔍</span>
            <span className="text-[10px] text-[#9CA3AF]">충전소 검색</span>
          </div>
          <div className="flex items-center gap-1 bg-white rounded-xl px-2.5 py-1.5 border border-[#10B981]/30 text-[#059669]">
            <span className="text-[10px]">↕</span>
            <span className="text-[10px] font-semibold">거리순</span>
          </div>
        </div>
        {/* Summary card */}
        <div className="mx-3 mt-2 bg-[#ECFDF5] rounded-xl border border-[#10B981]/20 px-3 py-2">
          <div className="text-[9.5px] font-semibold text-[#047857]">주변 충전소</div>
          <div className="flex items-end justify-between mt-0.5">
            <div>
              <span className="text-[14px] font-bold text-[#111827]">1009개</span>
              <span className="text-[9.5px] text-[#4B5563] ml-1">· 이용가능 864개</span>
            </div>
            <div className="flex flex-col items-end">
              <div className="text-[12px] font-bold text-[#059669]">85%</div>
              <div className="text-[8.5px] text-[#047857]">가용률</div>
            </div>
          </div>
        </div>
        {/* Station list */}
        <div className="flex-1 overflow-hidden px-2 mt-1.5 space-y-1.5">
          <Station
            brand="에버온"
            brandColor="#10B981"
            name="시청 공영주차장"
            meta="32m · 에버온 · AC완속"
            avail="5/5"
            power="7kW"
            nonMember="380원/kWh"
            member="296원/kWh"
            faved
          />
          <Station
            brand="EV"
            brandColor="#9CA3AF"
            name="중앙도서관 주차장"
            meta="48m · 아이파킹 · AC완속"
            avail="3/6"
            power="7kW"
            nonMember="400원/kWh"
            member="285원/kWh"
          />
          <Station
            brand="EV"
            brandColor="#9CA3AF"
            name="스타필드 하남점"
            meta="87m · LG유플러스 · AC완속"
            avail="5/9"
            power="7kW"
            nonMember="450원/kWh"
            member="295원/kWh"
          />
          <Station
            brand="GS"
            brandColor="#1E3A8A"
            name="GS타워 지하주차장"
            meta="112m · GS차지비 · AC완속"
            avail="1/1"
            power="7kW"
            nonMember="470원/kWh"
            member="219원/kWh"
          />
        </div>
        {/* Bottom nav */}
        <div className="border-t border-black/5 bg-white px-3 py-1.5 flex items-center justify-around">
          <NavItem icon="⌂" label="홈" />
          <NavItem icon="◉" label="지도" />
          <NavItem icon="🤍" label="즐겨찾기" />
          <NavItem icon="⚙" label="설정" />
        </div>
      </div>
    </PhoneFrame>
  );
}

function Station({
  brand,
  brandColor,
  name,
  meta,
  avail,
  power,
  nonMember,
  member,
  faved,
}: {
  brand: string;
  brandColor: string;
  name: string;
  meta: string;
  avail: string;
  power: string;
  nonMember: string;
  member: string;
  faved?: boolean;
}) {
  return (
    <div className="bg-white rounded-lg border border-black/5 p-2 flex items-center gap-2 shadow-[0_1px_2px_rgba(0,0,0,0.03)]">
      <div
        className="h-8 w-8 rounded-md shrink-0 flex items-center justify-center text-[9px] font-bold text-white"
        style={{ background: brandColor }}
      >
        {brand}
      </div>
      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-1">
          <div className="text-[10.5px] font-bold truncate">{name}</div>
          <span className="bg-[#ECFDF5] text-[#059669] text-[8px] font-bold px-1 py-0 rounded">
            {avail}
          </span>
        </div>
        <div className="text-[8.5px] text-[#6B7280] truncate mt-0.5">{meta}</div>
        <div className="flex items-center gap-2 mt-0.5">
          <span className="text-[8.5px] text-[#9CA3AF]">비회원</span>
          <span className="text-[8.5px] font-semibold text-[#374151]">{nonMember}</span>
          <span className="text-[8.5px] text-[#9CA3AF]">회원</span>
          <span className="text-[8.5px] font-semibold text-[#059669]">{member}</span>
        </div>
      </div>
      <div className="flex flex-col items-end gap-0.5 shrink-0">
        <div className="text-[11px] font-bold">{power}</div>
        <span className={`text-[11px] ${faved ? 'text-[#10B981]' : 'text-[#D1D5DB]'}`}>
          {faved ? '♥' : '♡'}
        </span>
      </div>
    </div>
  );
}

function NavItem({ icon, label }: { icon: string; label: string }) {
  return (
    <div className="flex flex-col items-center gap-0.5">
      <span className="text-[12px] text-[#6B7280]">{icon}</span>
      <span className="text-[8px] text-[#9CA3AF]">{label}</span>
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
