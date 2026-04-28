'use client';

import { motion } from 'framer-motion';
import Container from './Container';
import SectionTag from './SectionTag';

type Case = {
  client: string;
  industry: string;
  beforeUrl: string;
  beforeLabel: string;
  beforeNotes: string[];
  afterUrl: string;
  afterLabel: string;
  afterNotes: string[];
  highlights: string[];
};

const CASES: Case[] = [
  {
    client: '태원오토텍',
    industry: '자동차 정비 · 부품',
    beforeUrl: 'http://www.twautotek.co.kr',
    beforeLabel: 'twautotek.co.kr',
    beforeNotes: [
      '2000년대 초반 테이블 레이아웃',
      '모바일 미대응 · HTTP',
      '관리자 페이지 부재',
    ],
    afterUrl: 'https://dksw4.com/twautotek',
    afterLabel: 'dksw4.com/twautotek',
    afterNotes: [
      'Next.js · 반응형 · HTTPS',
      '관리자 콘솔 · DB 기반 콘텐츠',
      '브랜드 톤에 맞춘 풀 리디자인',
    ],
    highlights: ['Next.js', 'MySQL', 'Admin', '반응형'],
  },
];

export default function Cases() {
  return (
    <section id="cases" className="relative py-28 md:py-36 overflow-hidden">
      <div aria-hidden className="pointer-events-none absolute inset-0 -z-10">
        <div className="absolute left-1/2 top-[30%] -translate-x-1/2 h-[420px] w-[760px] rounded-full bg-brand-700/12 blur-[160px]" />
      </div>

      <Container>
        <div className="flex flex-col items-center text-center">
          <SectionTag>Renewal Showcase</SectionTag>
          <h2 className="mt-6 text-[38px] md:text-[52px] font-semibold leading-[1.08] tracking-tightest text-fog-100 max-w-[820px]">
            오래된 회사 홈페이지,
            <br className="hidden md:block" />{' '}
            <span className="grad-text">이렇게 바꿔드릴 수 있습니다.</span>
          </h2>
          <p className="mt-6 max-w-[620px] text-[15.5px] leading-relaxed text-fog-300">
            실제 운영 중인 사이트를 똑같이 새로 만들어 본 샘플입니다.
            모바일 대응 · 관리자 페이지 · HTTPS — 요즘 기준으로 통째로 재구축합니다.
          </p>
        </div>

        <div className="mt-16 space-y-12">
          {CASES.map((c, i) => (
            <CaseCard key={c.client} item={c} delay={i * 0.05} />
          ))}
        </div>
      </Container>
    </section>
  );
}

function CaseCard({ item, delay }: { item: Case; delay: number }) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 30 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true, margin: '-80px' }}
      transition={{ duration: 0.7, delay }}
      className="relative overflow-hidden rounded-[28px] border border-white/10 bg-gradient-to-br from-white/[0.04] via-white/[0.015] to-white/[0.005] p-6 md:p-10 backdrop-blur-sm"
    >
      <div aria-hidden className="absolute inset-0 -z-10 bg-grid-mask opacity-30" />

      {/* Header */}
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <div className="text-[11px] font-medium uppercase tracking-[0.18em] text-brand-300">
            {item.industry}
          </div>
          <div className="mt-1 text-[22px] md:text-[26px] font-semibold text-fog-100 tracking-tight">
            {item.client}
          </div>
        </div>
        <div className="flex flex-wrap gap-1.5">
          {item.highlights.map((h) => (
            <span
              key={h}
              className="rounded-full border border-white/10 bg-white/[0.03] px-2.5 py-1 text-[11px] font-medium text-fog-300"
            >
              {h}
            </span>
          ))}
        </div>
      </div>

      {/* Before / After */}
      <div className="mt-8 grid grid-cols-1 md:grid-cols-[1fr_auto_1fr] items-stretch gap-4 md:gap-6">
        <SitePanel
          variant="before"
          url={item.beforeUrl}
          label={item.beforeLabel}
          notes={item.beforeNotes}
        />
        <div className="flex md:flex-col items-center justify-center text-fog-500">
          <ArrowMobile />
          <ArrowDesktop />
        </div>
        <SitePanel
          variant="after"
          url={item.afterUrl}
          label={item.afterLabel}
          notes={item.afterNotes}
        />
      </div>

      {/* CTA */}
      <div className="mt-8 flex flex-wrap items-center gap-3">
        <a
          href={item.afterUrl}
          target="_blank"
          rel="noreferrer"
          className="btn-primary inline-flex items-center gap-2 rounded-full bg-brand-500 hover:bg-brand-400 px-5 py-2.5 text-[13px] font-semibold text-white transition-colors"
        >
          리뉴얼 결과 보기
          <ExternalIcon />
        </a>
        <a
          href={item.beforeUrl}
          target="_blank"
          rel="noreferrer"
          className="inline-flex items-center gap-2 rounded-full border border-white/15 bg-white/[0.02] hover:bg-white/[0.06] px-5 py-2.5 text-[13px] font-medium text-fog-200 transition-colors"
        >
          기존 사이트
          <ExternalIcon />
        </a>
      </div>
    </motion.div>
  );
}

function SitePanel({
  variant,
  url,
  label,
  notes,
}: {
  variant: 'before' | 'after';
  url: string;
  label: string;
  notes: string[];
}) {
  const isAfter = variant === 'after';
  return (
    <a
      href={url}
      target="_blank"
      rel="noreferrer"
      className={`group block rounded-2xl border p-5 md:p-6 transition-colors ${
        isAfter
          ? 'border-brand-500/40 bg-gradient-to-br from-brand-900/30 to-brand-800/10 hover:border-brand-400/60'
          : 'border-white/10 bg-white/[0.02] hover:border-white/20'
      }`}
    >
      <div className="flex items-center gap-2">
        <span
          className={`text-[10.5px] font-bold uppercase tracking-[0.16em] ${
            isAfter ? 'text-brand-300' : 'text-fog-500'
          }`}
        >
          {isAfter ? 'After' : 'Before'}
        </span>
        {isAfter && (
          <span className="rounded-full bg-brand-500/15 px-2 py-0.5 text-[10px] font-semibold text-brand-200 ring-1 ring-inset ring-brand-500/30">
            NEW
          </span>
        )}
      </div>
      <div
        className={`mt-3 font-mono text-[13.5px] md:text-[15px] tracking-tight break-all ${
          isAfter ? 'text-fog-100' : 'text-fog-400 line-through decoration-fog-600/60'
        }`}
      >
        {label}
      </div>
      <ul className="mt-4 space-y-1.5">
        {notes.map((n) => (
          <li
            key={n}
            className={`flex items-start gap-2 text-[12.5px] ${
              isAfter ? 'text-fog-200' : 'text-fog-400'
            }`}
          >
            <span
              className={`mt-[7px] inline-block h-[3px] w-[3px] shrink-0 rounded-full ${
                isAfter ? 'bg-brand-300' : 'bg-fog-500'
              }`}
            />
            <span>{n}</span>
          </li>
        ))}
      </ul>
    </a>
  );
}

function ArrowDesktop() {
  return (
    <svg
      className="hidden md:block"
      width="40"
      height="40"
      viewBox="0 0 40 40"
      fill="none"
      aria-hidden
    >
      <circle cx="20" cy="20" r="19" stroke="currentColor" strokeOpacity="0.3" strokeWidth="1" />
      <path
        d="M14 20h12M21 14l5 6-5 6"
        stroke="#86B2FF"
        strokeWidth="1.6"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}

function ArrowMobile() {
  return (
    <svg
      className="md:hidden"
      width="40"
      height="40"
      viewBox="0 0 40 40"
      fill="none"
      aria-hidden
    >
      <circle cx="20" cy="20" r="19" stroke="currentColor" strokeOpacity="0.3" strokeWidth="1" />
      <path
        d="M20 14v12M14 21l6 5 6-5"
        stroke="#86B2FF"
        strokeWidth="1.6"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}

function ExternalIcon() {
  return (
    <svg width="12" height="12" viewBox="0 0 12 12" fill="none" aria-hidden>
      <path
        d="M3 9l6-6M5 3h4v4"
        stroke="currentColor"
        strokeWidth="1.6"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}
