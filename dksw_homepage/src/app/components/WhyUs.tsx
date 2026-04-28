'use client';

import { motion } from 'framer-motion';
import Container from './Container';
import SectionTag from './SectionTag';

const POINTS = [
  {
    k: 'SPEED',
    title: '홈페이지 2~4주, 앱 4~8주',
    body: '요구사항 한 페이지부터 시작해, 주 단위 빌드 · 리뷰 · 출시 사이클로 돕립니다. 분기 · 반기 끝없이 끄는 일정이 아닙니다.',
  },
  {
    k: 'PRICE',
    title: '작은 팀이라 합리적인 단가',
    body: '대형 에이전시 견적의 절반 수준에서 같은 결과물을 냅니다. PM · 디자이너 · 개발자가 분리되지 않아 오버헤드가 없습니다.',
  },
  {
    k: 'DEPTH',
    title: '데모 아닌 상용 품질',
    body: '자체 모바일 앱 2개를 직접 출시 · 운영 중. 결제 · 푸시 · 장애 대응 · 보안 — 실전에서 만든 체크리스트를 그대로 적용합니다.',
  },
  {
    k: 'PARTNER',
    title: '출시 후 운영도 같은 팀',
    body: '납품으로 끝이 아니라, 모니터링 · 기능 추가 · 사용자 CS 플로우까지 함께 봅니다. 인계 후 연락 두절 없습니다.',
  },
];

export default function WhyUs() {
  return (
    <section id="why" className="relative py-28 md:py-36 overflow-hidden">
      <div aria-hidden className="pointer-events-none absolute inset-0 -z-10">
        <div className="absolute left-[-5%] top-[10%] h-[380px] w-[380px] rounded-full bg-brand-600/15 blur-[130px]" />
        <div className="absolute right-[-5%] bottom-[10%] h-[380px] w-[380px] rounded-full bg-brand-700/15 blur-[130px]" />
      </div>

      <Container>
        <div className="text-center">
          <SectionTag>Why DK Software</SectionTag>
          <h2 className="mt-6 text-[38px] md:text-[52px] font-semibold leading-[1.08] tracking-tightest text-fog-100 max-w-[820px] mx-auto">
            큰 회사의 완성도,
            <br />
            <span className="grad-text">작은 팀의 속도.</span>
          </h2>
        </div>

        <div className="mt-16 grid grid-cols-1 md:grid-cols-2 gap-6 md:gap-8">
          {POINTS.map((p, i) => (
            <motion.div
              key={p.k}
              initial={{ opacity: 0, y: 24 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true, margin: '-60px' }}
              transition={{ duration: 0.7, delay: i * 0.08 }}
              className="relative overflow-hidden rounded-3xl border border-white/10 bg-gradient-to-br from-white/[0.035] to-white/[0.005] p-8 md:p-10 backdrop-blur-sm"
            >
              <div className="absolute inset-0 opacity-0 hover:opacity-100 transition-opacity duration-500 pointer-events-none">
                <div className="absolute top-0 left-0 h-[1px] w-full bg-gradient-to-r from-transparent via-brand-400/60 to-transparent" />
              </div>
              <div className="flex items-center gap-3">
                <span className="font-mono text-[11px] tracking-[0.2em] text-brand-300">
                  {p.k}
                </span>
                <span className="h-[1px] flex-1 bg-gradient-to-r from-white/15 to-transparent" />
              </div>
              <h3 className="mt-5 text-[24px] md:text-[28px] font-semibold leading-tight tracking-tight text-fog-100">
                {p.title}
              </h3>
              <p className="mt-3 text-[14.5px] leading-relaxed text-fog-300">{p.body}</p>
            </motion.div>
          ))}
        </div>
      </Container>
    </section>
  );
}
