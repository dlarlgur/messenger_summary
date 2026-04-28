'use client';

import { motion } from 'framer-motion';
import Container from './Container';
import SectionTag from './SectionTag';

export default function About() {
  return (
    <section id="about" className="relative py-28 md:py-36 overflow-hidden">
      <div aria-hidden className="pointer-events-none absolute inset-0 -z-10">
        <div className="absolute left-[-10%] top-1/2 h-[500px] w-[500px] rounded-full bg-brand-700/15 blur-[140px]" />
      </div>

      <Container>
        <div className="grid grid-cols-1 lg:grid-cols-[1fr_1.2fr] gap-16 lg:gap-24 items-start">
          <motion.div
            initial={{ opacity: 0, y: 24 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true, margin: '-80px' }}
            transition={{ duration: 0.7 }}
          >
            <SectionTag>About DK Software</SectionTag>
            <h2 className="mt-6 text-[38px] md:text-[52px] font-semibold leading-[1.08] tracking-tightest text-fog-100 break-keep">
              홈페이지와 앱,
              <br />
              <span className="grad-text">한 팀이 다 만듭니다.</span>
            </h2>
            <p className="mt-6 text-[15px] md:text-[16px] leading-relaxed text-fog-300 break-keep">
              회사 홈페이지 신규 제작 · 오래된 사이트 리뉴얼 · 모바일 앱 개발이 주력입니다.
              기획부터 디자인 · 프론트 · 백엔드 · 배포 · 운영까지 한 팀이 처음부터 끝까지 만듭니다.
              디자인 따로 · 개발 따로 외주 분산이 없습니다.
            </p>
            <p className="mt-4 text-[15px] md:text-[16px] leading-relaxed text-fog-400 break-keep">
              자체 모바일 앱 2개를 직접 출시 · 운영하며 쌓은 운영 노하우 — 속도, 품질, 장애 대응 —
              그대로 고객사 프로젝트에 적용합니다.
            </p>
          </motion.div>

          <motion.div
            initial={{ opacity: 0, y: 24 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true, margin: '-80px' }}
            transition={{ duration: 0.7, delay: 0.1 }}
            className="grid grid-cols-1 sm:grid-cols-2 gap-4"
          >
            <Pillar
              k="01"
              title="빠른 출시"
              body="홈페이지 2~4주, MVP 앱 4~8주. 분기·반기 끝없이 끄는 일정 없습니다."
            />
            <Pillar
              k="02"
              title="리뉴얼 전문"
              body="10년 넘은 사이트도 Next.js · React 기반 현대 스택으로 재구축. 기존 데이터 마이그레이션 포함."
            />
            <Pillar
              k="03"
              title="한 팀에서 전부"
              body="기획 · 디자인 · iOS · 안드로이드 · 웹 · 백엔드 · 배포까지. 외주 재외주 0."
            />
            <Pillar
              k="04"
              title="운영까지 책임"
              body="출시가 끝이 아닙니다. 모니터링 · 장애 대응 · 사용자 CS 플로우까지 함께 설계합니다."
            />
          </motion.div>
        </div>
      </Container>
    </section>
  );
}

function Pillar({ k, title, body }: { k: string; title: string; body: string }) {
  return (
    <div className="group relative rounded-2xl border border-white/8 bg-white/[0.015] hover:bg-white/[0.04] backdrop-blur-sm p-6 transition-colors overflow-hidden">
      <div className="absolute -top-16 -right-16 h-40 w-40 rounded-full bg-brand-500/0 group-hover:bg-brand-500/20 blur-3xl transition-all duration-500" />
      <div className="relative flex items-center justify-between">
        <span className="font-mono text-[11px] tracking-widest text-fog-400">{k}</span>
        <span className="h-[6px] w-[6px] rounded-full bg-brand-400 shadow-[0_0_10px_rgba(59,130,246,0.9)]" />
      </div>
      <h3 className="relative mt-4 text-[17px] font-semibold text-fog-100 tracking-tight">{title}</h3>
      <p className="relative mt-2 text-[13.5px] leading-relaxed text-fog-400">{body}</p>
    </div>
  );
}
