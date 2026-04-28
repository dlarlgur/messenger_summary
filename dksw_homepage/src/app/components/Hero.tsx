'use client';

import { motion } from 'framer-motion';
import Container from './Container';

export default function Hero() {
  return (
    <section id="top" className="relative isolate overflow-hidden pt-32 pb-28 md:pt-40 md:pb-40">
      {/* Gradient orbs */}
      <div aria-hidden className="pointer-events-none absolute inset-0 -z-10">
        <div className="absolute left-1/2 top-[-10%] h-[720px] w-[720px] -translate-x-1/2 rounded-full bg-brand-600/40 blur-[140px] animate-gradient-shift" />
        <div className="absolute left-[15%] top-[35%] h-[420px] w-[420px] rounded-full bg-brand-500/25 blur-[120px] animate-gradient-shift" />
        <div className="absolute right-[10%] top-[10%] h-[360px] w-[360px] rounded-full bg-cyan-500/15 blur-[120px] animate-gradient-shift" />
      </div>

      {/* Grid background */}
      <div aria-hidden className="pointer-events-none absolute inset-0 -z-10 bg-grid-mask opacity-80" />

      <Container className="relative">
        {/* Badge */}
        <motion.div
          initial={{ opacity: 0, y: 14 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6 }}
          className="flex justify-center"
        >
          <span className="inline-flex items-center gap-2 rounded-full border border-white/10 bg-white/[0.03] px-3.5 py-1.5 text-[12px] font-medium tracking-wide text-fog-200 backdrop-blur">
            <span className="relative flex h-2 w-2">
              <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-brand-400 opacity-70" />
              <span className="relative inline-flex h-2 w-2 rounded-full bg-brand-400" />
            </span>
            홈페이지 리뉴얼 · 앱 개발
          </span>
        </motion.div>

        {/* Headline */}
        <motion.h1
          initial={{ opacity: 0, y: 24 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8, delay: 0.1 }}
          className="mt-8 text-center font-semibold tracking-tightest leading-[1.02]
                     text-[44px] sm:text-[64px] md:text-[84px] lg:text-[96px]"
        >
          <span className="block grad-text">홈페이지 새로 만들고,</span>
          <span className="block text-fog-100 text-glow">앱 개발해 드립니다.</span>
        </motion.h1>

        {/* Sub */}
        <motion.p
          initial={{ opacity: 0, y: 18 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8, delay: 0.25 }}
          className="mx-auto mt-8 max-w-[640px] text-center text-[16px] md:text-[18px] leading-relaxed text-fog-300"
        >
          오래된 회사 홈페이지 리뉴얼부터 모바일 앱 신규 개발까지.
          기획 · 디자인 · 개발 · 운영을 <b className="text-fog-100 font-semibold">한 팀이 처음부터 끝까지</b> 책임집니다.
          외주 재외주 없이 직접 만들고, 출시 후 운영까지 같이 봅니다.
        </motion.p>

        {/* CTAs */}
        <motion.div
          initial={{ opacity: 0, y: 14 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8, delay: 0.4 }}
          className="mt-10 flex flex-wrap items-center justify-center gap-3"
        >
          <a
            href="#products"
            className="btn-primary inline-flex items-center gap-2 rounded-full bg-brand-500 hover:bg-brand-400 px-6 py-3.5 text-[14px] font-semibold text-white shadow-[0_0_0_1px_rgba(59,130,246,0.4),0_20px_60px_-20px_rgba(59,130,246,0.8)] transition-colors"
          >
            제품 보기
            <Arrow />
          </a>
          <a
            href="#contact"
            className="inline-flex items-center gap-2 rounded-full border border-white/15 bg-white/[0.02] hover:bg-white/[0.06] px-6 py-3.5 text-[14px] font-semibold text-fog-100 backdrop-blur transition-colors"
          >
            프로젝트 문의
          </a>
        </motion.div>

        {/* Stat strip */}
        <motion.div
          initial={{ opacity: 0, y: 30 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.9, delay: 0.55 }}
          className="mt-20 grid grid-cols-2 md:grid-cols-4 gap-px rounded-2xl border border-white/10 bg-white/[0.015] backdrop-blur overflow-hidden"
        >
          <Stat label="자체 운영 앱" value="2개" sub="구글플레이 출시 · 운영 중" />
          <Stat label="대응 범위" value="홈페이지 · 앱" sub="iOS · 안드로이드 · 웹" />
          <Stat label="첫 회신" value="1영업일" sub="견적 · 로드맵 2영업일" />
          <Stat label="위치" value="용인 · 원격" sub="전국 미팅 가능" />
        </motion.div>

        {/* Scroll indicator */}
        <div className="mt-16 flex justify-center">
          <a
            href="#about"
            className="group inline-flex flex-col items-center gap-2 text-[11px] uppercase tracking-[0.2em] text-fog-400 hover:text-fog-200 transition-colors"
          >
            Scroll
            <span className="relative block h-9 w-[1px] overflow-hidden bg-white/15">
              <span className="absolute top-0 left-0 block h-4 w-full bg-brand-400 animate-[scrollLine_2s_ease-in-out_infinite]" />
            </span>
          </a>
        </div>
      </Container>

      <style jsx>{`
        @keyframes scrollLine {
          0% {
            transform: translateY(-100%);
          }
          50% {
            transform: translateY(120%);
          }
          100% {
            transform: translateY(120%);
          }
        }
      `}</style>
    </section>
  );
}

function Stat({ label, value, sub }: { label: string; value: string; sub: string }) {
  return (
    <div className="bg-ink-950/60 p-6 md:p-7">
      <div className="text-[11px] font-medium uppercase tracking-[0.18em] text-fog-400">{label}</div>
      <div className="mt-2 text-[22px] md:text-[26px] font-semibold text-fog-100 tracking-tight">
        {value}
      </div>
      <div className="mt-1 text-[12.5px] text-fog-400">{sub}</div>
    </div>
  );
}

function Arrow() {
  return (
    <svg width="14" height="14" viewBox="0 0 14 14" fill="none" aria-hidden>
      <path
        d="M3 7h8M7.5 3 11 7l-3.5 4"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}
