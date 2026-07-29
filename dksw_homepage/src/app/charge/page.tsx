import type { Metadata } from 'next';
import Image from 'next/image';
import Link from 'next/link';
import Container from '../components/Container';
import StoreBadge from '../components/StoreBadge';
import Logo from '../components/Logo';
import SmartInstall, { APP_STORE_URL, PLAY_STORE_URL } from './SmartInstall';
import { FuelMockup, EvMockup, DeviceShot } from './Mockups';

export const metadata: Metadata = {
  title: '전기차 기름차 — 주유소 최저가 · 충전소 빈자리',
  description:
    '전국 주유소 실시간 유가와 충전소 빈자리를 한 화면에. 내 차를 등록하면 AI가 경로·경유지 위에서 가장 이득인 주유소·충전소를 찾아드립니다. iOS · Android 무료.',
  openGraph: {
    title: '전기차 기름차 — 주유소 최저가 · 충전소 빈자리',
    description:
      '전국 주유소 실시간 유가와 충전소 빈자리를 한 화면에. AI 경로 추천까지, 무료.',
    url: 'https://dksw4.com/charge',
    images: [{ url: '/charge/icon.png', width: 1024, height: 1024 }],
  },
  alternates: { canonical: 'https://dksw4.com/charge' },
};

/* ─────────────────────────────────────────────────────────────
 * /charge 랜딩 — 사이트(다크)와 달리 이 페이지만 라이트 · 친환경(민트) 테마.
 * 전역 body 가 다크라 최하단 고정 레이어로 페이지 전체를 라이트로 덮는다.
 * ──────────────────────────────────────────────────────────── */

export default function ChargePage() {
  return (
    // isolate: 새 스태킹 컨텍스트 — 데코(-z-10)가 main 배경 위·콘텐츠 아래에 깔리고,
    // 다크 전역 body 배경을 main 자체 배경(bg)이 확실히 덮는다.
    <main className="relative isolate min-h-screen overflow-hidden bg-[#F7FBF8] text-slate-900">
      <div aria-hidden className="pointer-events-none absolute inset-0 -z-10">
        <div className="absolute inset-x-0 top-0 h-[560px] bg-gradient-to-b from-emerald-100/70 via-teal-50/40 to-transparent" />
        <div className="absolute left-1/2 top-[-220px] h-[560px] w-[860px] -translate-x-1/2 rounded-full bg-emerald-300/25 blur-[140px]" />
        <div className="absolute right-[-12%] top-[42%] h-[420px] w-[420px] rounded-full bg-teal-200/30 blur-[130px]" />
        <div className="absolute left-[-10%] bottom-[6%] h-[380px] w-[380px] rounded-full bg-lime-200/25 blur-[130px]" />
        {/* 연한 그리드 */}
        <div
          className="absolute inset-0 opacity-[0.5]"
          style={{
            backgroundImage:
              'linear-gradient(to right, rgba(5,150,105,0.05) 1px, transparent 1px), linear-gradient(to bottom, rgba(5,150,105,0.05) 1px, transparent 1px)',
            backgroundSize: '56px 56px',
            maskImage: 'radial-gradient(ellipse at center, black 35%, transparent 78%)',
            WebkitMaskImage: 'radial-gradient(ellipse at center, black 35%, transparent 78%)',
          }}
        />
      </div>

      <TopBar />
      <Hero />
      <Stats />
      <Features />
      <Screens />
      <HowItWorks />
      <Faq />
      <FinalCta />
      <PageFooter />
    </main>
  );
}

/* ───────────────────────── sections ───────────────────────── */

const NAV_LINKS = [
  { href: '#features', label: '기능' },
  { href: '#how', label: '이용 방법' },
  { href: '#faq', label: 'FAQ' },
];

/** 친환경 그라데이션 헤드라인 텍스트 */
function GradText({ children }: { children: React.ReactNode }) {
  return (
    <span className="bg-gradient-to-r from-emerald-600 via-teal-500 to-emerald-500 bg-clip-text text-transparent">
      {children}
    </span>
  );
}

function TopBar() {
  return (
    <header className="relative z-20">
      <Container>
        <div className="flex h-[72px] items-center justify-between gap-3">
          <div className="flex min-w-0 items-center gap-2.5">
            <Image
              src="/charge/icon.png"
              alt="전기차 기름차"
              width={30}
              height={30}
              className="shrink-0 rounded-[8px]"
              priority
            />
            <span className="hidden truncate text-[15px] font-bold tracking-tight text-slate-900 min-[400px]:inline">
              전기차 기름차
            </span>
          </div>

          <nav className="hidden items-center gap-1.5 md:flex">
            {NAV_LINKS.map((l) => (
              <a
                key={l.href}
                href={l.href}
                className="rounded-full border border-black/8 bg-white/80 px-4 py-2 text-[13px] font-medium text-slate-600 shadow-sm transition-colors hover:border-emerald-500/40 hover:text-emerald-700"
              >
                {l.label}
              </a>
            ))}
            <div className="ml-2 flex items-center gap-2">
              <StoreBadge store="google" href={PLAY_STORE_URL} variant="light" className="!rounded-full !px-3.5 !py-2" />
              <StoreBadge store="apple" href={APP_STORE_URL} variant="light" className="!rounded-full !px-3.5 !py-2" />
            </div>
          </nav>

          {/* 모바일: 아이콘+스토어명 미니 배지 — 웹과 동일 정보, 잘림 없음 */}
          <div className="flex shrink-0 items-center gap-1.5 md:hidden">
            <a
              href={PLAY_STORE_URL}
              target="_blank"
              rel="noopener noreferrer"
              aria-label="Google Play에서 설치"
              className="inline-flex shrink-0 items-center gap-1.5 whitespace-nowrap rounded-full border border-black/10 bg-white px-3 py-2 shadow-sm"
            >
              <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor" className="text-slate-800" aria-hidden>
                <path d="M3.6 2.4 13.6 12 3.6 21.6C3.2 21.3 3 20.9 3 20.4V3.6c0-.5.2-.9.6-1.2zm13.6 13.2L13.6 12l3.6-3.6 3.9 2.2c.7.4.7 1.4 0 1.8l-3.9 2.2zM13.6 12 3.6 2.4c.4-.3 1-.3 1.5 0l12.1 6.8L13.6 12zm-8.5 9.6 8.5-9.6 3.6 3.6-12.1 6.8c-.5.3-1.1.3-1.5 0z" />
              </svg>
              <span className="text-[12px] font-semibold text-slate-800">Google Play</span>
            </a>
            <a
              href={APP_STORE_URL}
              target="_blank"
              rel="noopener noreferrer"
              aria-label="App Store에서 설치"
              className="inline-flex shrink-0 items-center gap-1.5 whitespace-nowrap rounded-full border border-black/10 bg-white px-3 py-2 shadow-sm"
            >
              <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor" className="text-slate-800" aria-hidden>
                <path d="M17.05 20.28c-.98.95-2.05.8-3.08.35-1.09-.46-2.09-.48-3.24 0-1.44.62-2.2.44-3.06-.35C2.79 15.25 3.51 7.59 9.05 7.31c1.35.07 2.29.74 3.08.8 1.18-.24 2.31-.93 3.57-.84 1.51.12 2.65.72 3.4 1.8-3.12 1.87-2.38 5.98.48 7.13-.57 1.5-1.31 2.99-2.54 4.09zM12.03 7.25c-.15-2.23 1.66-4.07 3.74-4.25.29 2.58-2.34 4.5-3.74 4.25z" />
              </svg>
              <span className="text-[12px] font-semibold text-slate-800">App Store</span>
            </a>
          </div>
        </div>
      </Container>
    </header>
  );
}

function Hero() {
  return (
    <section className="relative pb-20 pt-8 md:pb-28 md:pt-14">
      <Container>
        <div className="flex flex-col items-center gap-14 lg:flex-row lg:items-center lg:justify-between">
          {/* 좌: 카피 */}
          <div className="flex max-w-[560px] flex-col items-center text-center lg:items-start lg:text-left">
            <div className="flex items-center gap-3">
              <Image
                src="/charge/icon.png"
                alt="전기차 기름차 앱 아이콘"
                width={56}
                height={56}
                className="rounded-[14px] shadow-[0_10px_28px_-8px_rgba(16,185,129,0.5)]"
                priority
              />
              <div className="text-left">
                <div className="text-[17px] font-bold text-slate-900">전기차 기름차</div>
                <div className="text-[12px] text-slate-500">iOS · Android 무료</div>
              </div>
            </div>

            <h1 className="mt-8 text-[38px] font-semibold leading-[1.1] tracking-tightest text-slate-900 md:text-[56px]">
              주유소 최저가,
              <br />
              충전소 빈자리
              <br />
              <GradText>한 화면에.</GradText>
            </h1>

            <p className="mt-6 max-w-[460px] text-[15.5px] leading-relaxed text-slate-600">
              전기차든 기름차든 하이브리드든. 내 차를 등록하면 실시간 유가와 충전 현황 위에서,
              AI가 내 경로 그대로 <strong className="font-semibold text-slate-900">가장 이득인 곳</strong>을 찾아드립니다.
            </p>

            <div className="mt-9 flex flex-col items-center gap-4 sm:flex-row lg:items-start">
              <SmartInstall />
              {/* 배지는 PC에서만 — 모바일은 스마트 버튼이 이미 해당 스토어로 감 (CTA 중복 방지) */}
              <div className="hidden flex-wrap justify-center gap-2.5 sm:flex">
                <StoreBadge store="apple" href={APP_STORE_URL} variant="light" />
                <StoreBadge store="google" href={PLAY_STORE_URL} variant="light" />
              </div>
            </div>
          </div>

          {/* 우: 실기기 목업 2대 — 모바일에선 1대만(가로 넘침 방지) */}
          <div className="relative flex max-w-full items-center justify-center">
            <div
              aria-hidden
              className="absolute inset-0 -z-10 scale-125 rounded-full bg-[radial-gradient(circle,rgba(16,185,129,0.16),transparent_65%)]"
            />
            <div className="-mr-14 hidden -rotate-6 scale-[0.92] transition-transform duration-500 hover:rotate-[-3deg] min-[480px]:block">
              <FuelMockup />
            </div>
            <div className="z-10 rotate-3 transition-transform duration-500 hover:rotate-1">
              <EvMockup />
            </div>
          </div>
        </div>
      </Container>
    </section>
  );
}

const STATS = [
  { value: '11,000+', label: '전국 주유소 실시간 유가' },
  { value: '400,000+', label: '전국 충전기 현황' },
  { value: '실시간', label: '가격 · 빈자리 갱신' },
  { value: 'AI', label: '경로 · 경유지 맞춤 추천' },
];

function Stats() {
  return (
    <section className="relative border-y border-emerald-900/5 bg-white/60 py-10 backdrop-blur-sm">
      <Container>
        <div className="grid grid-cols-2 gap-8 md:grid-cols-4">
          {STATS.map((s) => (
            <div key={s.label} className="flex flex-col items-center text-center">
              <span className="font-mono text-[26px] font-bold tracking-tight text-emerald-700 md:text-[30px]">
                {s.value}
              </span>
              <span className="mt-1.5 text-[12.5px] text-slate-500">{s.label}</span>
            </div>
          ))}
        </div>
      </Container>
    </section>
  );
}

const FEATURES = [
  {
    icon: 'fuel',
    title: '실시간 최저가 주유소',
    desc: '오피넷 공식 데이터 기반. 상세 화면은 실시간 단건 조회로 방금 바뀐 가격까지 잡아냅니다. 어제 대비 · 지역 평균 대비 · 지역 순위까지.',
    accent: '#2563EB',
  },
  {
    icon: 'bolt',
    title: '충전소 실시간 빈자리',
    desc: '환경부 실시간 현황으로 지금 충전 가능한 자리를 확인. 커넥터 타입 · 충전 속도(kW) · 운영사별 회원/비회원 단가까지 비교합니다.',
    accent: '#059669',
  },
  {
    icon: 'car',
    title: '내 차량 등록은 검색 한 번',
    desc: '차종을 검색하면 유종 · 공인 연비 · 탱크 용량이 자동 입력됩니다. 전기차는 배터리 용량과 전비로 도착 시 잔량까지 계산해요.',
    accent: '#0EA5E9',
  },
  {
    icon: 'route',
    title: 'AI 경로 · 경유지 추천',
    desc: '목적지 가는 길, 경유지를 최대 3곳 추가해도 그 길 그대로. 우회 시간과 가격을 함께 계산해 "여기서 넣는 게 제일 이득"을 알려드립니다.',
    accent: '#8B5CF6',
  },
  {
    icon: 'chart',
    title: '가격 추이 그래프',
    desc: '주유소별 1주 · 4주 · 3개월 · 1년 가격 추이를 그래프로. 오르는 추세인지 내리는 추세인지 보고 주유 타이밍을 잡으세요.',
    accent: '#F59E0B',
  },
  {
    icon: 'bell',
    title: '즐겨찾기 · 빈자리 알림',
    desc: '자주 가는 주유소 · 충전소를 즐겨찾기. 만석인 충전소에 자리가 나면 알림으로 알려드립니다. 집 · 회사 등록으로 목적지 설정은 한 번의 탭.',
    accent: '#EC4899',
  },
];

/** 기능 카드 라인 아이콘 — 이모지 대신 SVG (일관된 스트로크 스타일) */
function FeatureIcon({ name }: { name: string }) {
  const common = {
    width: 21,
    height: 21,
    viewBox: '0 0 24 24',
    fill: 'none',
    stroke: 'currentColor',
    strokeWidth: 1.9,
    strokeLinecap: 'round' as const,
    strokeLinejoin: 'round' as const,
    'aria-hidden': true,
  };
  switch (name) {
    case 'fuel':
      return (
        <svg {...common}>
          <path d="M4 21V6a2 2 0 0 1 2-2h5a2 2 0 0 1 2 2v15" />
          <path d="M3 21h11" />
          <path d="M13 9h2.5a1.5 1.5 0 0 1 1.5 1.5v6a1.5 1.5 0 0 0 3 0V9l-2.5-2.5" />
          <path d="M6.5 8h4" />
        </svg>
      );
    case 'bolt':
      return (
        <svg {...common}>
          <path d="M13 2 4.5 13.5H11l-1 8.5L18.5 10.5H12l1-8.5z" />
        </svg>
      );
    case 'car':
      return (
        <svg {...common}>
          <path d="M5 11 6.5 6.5A2 2 0 0 1 8.4 5h7.2a2 2 0 0 1 1.9 1.5L19 11" />
          <path d="M4 11h16a1 1 0 0 1 1 1v4.5a1 1 0 0 1-1 1h-1.5" />
          <path d="M3 12v4.5a1 1 0 0 0 1 1h1.5" />
          <circle cx="7.5" cy="17.5" r="1.8" />
          <circle cx="16.5" cy="17.5" r="1.8" />
        </svg>
      );
    case 'route':
      return (
        <svg {...common}>
          <circle cx="6" cy="19" r="2.2" />
          <circle cx="18" cy="5" r="2.2" />
          <path d="M8.2 19H15a3 3 0 0 0 0-6H9a3 3 0 0 1 0-6h6.8" />
        </svg>
      );
    case 'chart':
      return (
        <svg {...common}>
          <path d="M3 3v18h18" />
          <path d="m6.5 15 4-5 3.5 3 4.5-6" />
        </svg>
      );
    case 'bell':
      return (
        <svg {...common}>
          <path d="M6 9a6 6 0 0 1 12 0c0 5 2 6.5 2 6.5H4S6 14 6 9z" />
          <path d="M10.2 20a2 2 0 0 0 3.6 0" />
        </svg>
      );
    default:
      return null;
  }
}

function Features() {
  return (
    <section id="features" className="relative scroll-mt-20 py-24 md:py-32">
      <Container>
        <div className="flex flex-col items-center text-center">
          <span className="rounded-full border border-emerald-600/25 bg-emerald-50 px-4 py-1.5 text-[12px] font-semibold tracking-wide text-emerald-700">
            FEATURES
          </span>
          <h2 className="mt-6 max-w-[720px] text-[32px] font-semibold leading-[1.12] tracking-tightest text-slate-900 md:text-[44px]">
            기름값도 충전비도,
            <br />
            <GradText>아끼는 데 필요한 전부.</GradText>
          </h2>
        </div>

        <div className="mt-16 grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
          {FEATURES.map((f) => (
            <div
              key={f.title}
              className="group rounded-2xl border border-black/5 bg-white p-6 shadow-[0_2px_14px_-6px_rgba(6,78,59,0.08)] transition-shadow hover:shadow-[0_10px_30px_-10px_rgba(6,78,59,0.18)]"
            >
              <span
                className="flex h-11 w-11 items-center justify-center rounded-xl"
                style={{ background: `${f.accent}14`, border: `1px solid ${f.accent}33`, color: f.accent }}
              >
                <FeatureIcon name={f.icon} />
              </span>
              <h3 className="mt-5 text-[16.5px] font-semibold text-slate-900">{f.title}</h3>
              <p className="mt-2.5 text-[13.5px] leading-relaxed text-slate-600">{f.desc}</p>
            </div>
          ))}
        </div>
      </Container>
    </section>
  );
}

const SCREENS = [
  {
    src: '/charge/screens/ai-route.jpg',
    alt: 'AI 탭 — 목적지 경로 미리보기와 추천경로·고속도로우선 비교',
    label: 'AI 경로 비교',
    desc: '추천경로 vs 고속도로우선, 시간·거리 한눈에',
  },
  {
    src: '/charge/screens/ai-result.jpg',
    alt: 'AI 주유소 추천 결과 — 경로상 최저가와 절약 리포트',
    label: 'AI 추천 결과',
    desc: '경로상 최저가 · 우회 시간까지 계산',
  },
  {
    src: '/charge/screens/map.jpg',
    alt: '지도 탭 — 주유소 가격과 충전소 빈자리 마커',
    label: '한눈에 지도',
    desc: '가격 · 빈자리를 마커로, 지역 추천 1·2·3위',
  },
];

/** 실제 앱 화면 갤러리 — 실기기 캡처 */
function Screens() {
  return (
    <section className="relative border-t border-emerald-900/5 py-24 md:py-32">
      <Container>
        <div className="flex flex-col items-center text-center">
          <span className="rounded-full border border-emerald-600/25 bg-emerald-50 px-4 py-1.5 text-[12px] font-semibold tracking-wide text-emerald-700">
            SCREENS
          </span>
          <h2 className="mt-6 text-[32px] font-semibold tracking-tightest text-slate-900 md:text-[40px]">
            실제 화면 그대로
          </h2>
          <p className="mt-4 max-w-[520px] text-[14.5px] leading-relaxed text-slate-600">
            보정 없는 실사용 화면입니다. 목적지를 입력하면 이 흐름 그대로 추천을 받아요.
          </p>
        </div>

        <div className="mt-14 flex snap-x snap-mandatory gap-8 overflow-x-auto px-2 pb-4 md:justify-center md:overflow-visible">
          {SCREENS.map((sc) => (
            <div key={sc.src} className="flex shrink-0 snap-center flex-col items-center">
              <DeviceShot src={sc.src} alt={sc.alt} width={236} ratio={1080 / 2316} />
              <div className="mt-5 text-[14.5px] font-semibold text-slate-900">{sc.label}</div>
              <div className="mt-1 max-w-[236px] text-center text-[12.5px] text-slate-500">{sc.desc}</div>
            </div>
          ))}
        </div>
      </Container>
    </section>
  );
}

const STEPS = [
  {
    n: '01',
    title: '내 차부터 등록',
    desc: '차종을 검색하면 유종 · 연비 · 탱크 용량이 자동으로 채워집니다. 전기차는 배터리 용량으로 도착 잔량까지 계산해요.',
  },
  {
    n: '02',
    title: '목적지를 입력하면',
    desc: 'AI가 경로 위 주유소 · 충전소를 전부 비교합니다. 경유지를 추가해도 그 길 그대로, 우회 시간 대비 절약 금액까지 계산.',
  },
  {
    n: '03',
    title: '가장 이득인 곳으로',
    desc: '추천 지점을 티맵 · 네이버 · 카카오 내비로 바로 안내. 얼마나 아꼈는지 절약 리포트로 확인하세요.',
  },
];

function HowItWorks() {
  return (
    <section id="how" className="relative scroll-mt-20 border-t border-emerald-900/5 py-24 md:py-32">
      <Container>
        <div className="flex flex-col items-center text-center">
          <span className="rounded-full border border-black/8 bg-white px-4 py-1.5 text-[12px] font-semibold tracking-wide text-slate-500 shadow-sm">
            HOW IT WORKS
          </span>
          <h2 className="mt-6 text-[32px] font-semibold tracking-tightest text-slate-900 md:text-[40px]">
            쓰는 법은 3초면 배워요
          </h2>
        </div>

        <div className="mt-14 grid gap-5 md:grid-cols-3">
          {STEPS.map((s) => (
            <div
              key={s.n}
              className="relative rounded-2xl border border-black/5 bg-white p-7 shadow-[0_2px_14px_-6px_rgba(6,78,59,0.08)]"
            >
              <span className="font-mono text-[13px] font-bold text-emerald-600">{s.n}</span>
              <h3 className="mt-3 text-[17px] font-semibold text-slate-900">{s.title}</h3>
              <p className="mt-2.5 text-[13.5px] leading-relaxed text-slate-600">{s.desc}</p>
            </div>
          ))}
        </div>
      </Container>
    </section>
  );
}

const FAQS = [
  {
    q: '무료인가요?',
    a: '네, 모든 기능이 무료입니다.',
  },
  {
    q: '가격 · 충전소 정보는 어디서 오나요?',
    a: '주유소 가격은 한국석유공사 오피넷 공식 데이터, 충전소 현황은 환경부 공식 데이터를 사용합니다. 앱 자체적으로 실시간 갱신 구조를 갖춰 반영이 빠릅니다.',
  },
  {
    q: '경유지도 지원하나요?',
    a: '네. 목적지까지 가는 길에 경유지를 최대 3곳까지 추가할 수 있고, AI 추천도 그 경로를 그대로 따라갑니다. 경로 계산 기준(티맵 · 네이버 · 카카오)도 직접 고를 수 있어요.',
  },
  {
    q: '아이폰도 되나요?',
    a: '네. App Store와 Google Play 모두에서 무료로 설치할 수 있습니다.',
  },
];

function Faq() {
  return (
    <section id="faq" className="relative scroll-mt-20 border-t border-emerald-900/5 py-24 md:py-28">
      <Container>
        <div className="mx-auto max-w-[720px]">
          <h2 className="text-center text-[28px] font-semibold tracking-tightest text-slate-900 md:text-[34px]">
            자주 묻는 질문
          </h2>
          <div className="mt-10 space-y-3">
            {FAQS.map((f) => (
              <details
                key={f.q}
                className="group rounded-2xl border border-black/5 bg-white px-6 py-4 shadow-[0_2px_10px_-6px_rgba(6,78,59,0.08)] transition-colors open:border-emerald-500/25"
              >
                <summary className="flex cursor-pointer list-none items-center justify-between text-[15px] font-semibold text-slate-900 [&::-webkit-details-marker]:hidden">
                  {f.q}
                  <span className="ml-4 text-slate-400 transition-transform duration-200 group-open:rotate-45">＋</span>
                </summary>
                <p className="mt-3 text-[14px] leading-relaxed text-slate-600">{f.a}</p>
              </details>
            ))}
          </div>
        </div>
      </Container>
    </section>
  );
}

function FinalCta() {
  return (
    <section id="download" className="relative py-24 md:py-32">
      <div aria-hidden className="pointer-events-none absolute inset-0 -z-10">
        <div className="absolute left-1/2 top-1/2 h-[420px] w-[720px] -translate-x-1/2 -translate-y-1/2 rounded-full bg-emerald-300/25 blur-[130px]" />
      </div>
      <Container>
        <div className="flex flex-col items-center text-center">
          <Image
            src="/charge/icon.png"
            alt="전기차 기름차"
            width={76}
            height={76}
            className="rounded-[18px] shadow-[0_14px_40px_-10px_rgba(16,185,129,0.5)]"
          />
          <h2 className="mt-8 text-[32px] font-semibold leading-[1.12] tracking-tightest text-slate-900 md:text-[44px]">
            오늘 넣을 기름값부터
            <br />
            <GradText>아껴보세요.</GradText>
          </h2>
          <div className="mt-9">
            <SmartInstall />
          </div>
          {/* 데스크톱: 양쪽 배지 / 모바일: 스마트 버튼이 이미 해당 스토어로 감 */}
          <div className="mt-5 hidden flex-wrap justify-center gap-2.5 sm:flex">
            <StoreBadge store="apple" href={APP_STORE_URL} variant="light" />
            <StoreBadge store="google" href={PLAY_STORE_URL} variant="light" />
          </div>
        </div>
      </Container>
    </section>
  );
}

function PageFooter() {
  return (
    <footer className="relative border-t border-emerald-900/5 bg-white/60 py-10">
      <Container>
        <div className="flex flex-col items-center justify-between gap-4 md:flex-row">
          <div className="flex items-center gap-2">
            <Logo size={18} />
            <span className="text-[13px] font-semibold text-slate-900">
              DK <span className="font-medium text-slate-500">Software</span>
            </span>
          </div>
          <div className="flex items-center gap-5 text-[12px] text-slate-500">
            <a href="https://console.dksw4.com/console/privacy/view/charge" target="_blank" rel="noopener noreferrer" className="hover:text-emerald-700">
              개인정보처리방침
            </a>
            <a href="mailto:ghim2131@gmail.com" className="hover:text-emerald-700">
              문의
            </a>
            <Link href="/" className="hover:text-emerald-700">
              회사 소개
            </Link>
          </div>
          <div className="text-[11.5px] text-slate-400">© {new Date().getFullYear()} DK Software</div>
        </div>
      </Container>
    </footer>
  );
}
