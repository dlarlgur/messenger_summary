'use client';

import { motion } from 'framer-motion';
import {
  Smartphone,
  MonitorSmartphone,
  Server,
  LifeBuoy,
} from 'lucide-react';
import Container from './Container';
import SectionTag from './SectionTag';

const SERVICES = [
  {
    icon: MonitorSmartphone,
    title: '회사 홈페이지 제작 · 리뉴얼',
    desc: '오래된 HTML 사이트를 현대적인 반응형으로 재구축. 회사소개 · 제품 카탈로그 · 채용 페이지까지.',
    tags: ['Next.js', 'React', 'SEO', '반응형'],
  },
  {
    icon: Smartphone,
    title: '모바일 앱 개발 (iOS · 안드로이드)',
    desc: '신규 앱 기획부터 스토어 심사 · 출시까지. Flutter 크로스플랫폼으로 양 OS 동시 개발.',
    tags: ['Flutter', 'iOS', 'Android', '스토어 심사'],
  },
  {
    icon: Server,
    title: '관리자 페이지 · 백엔드',
    desc: '직원이 직접 콘텐츠 · 회원 · 주문을 관리하는 어드민 콘솔. API 서버 · DB 설계 포함.',
    tags: ['Node.js', 'MySQL', 'Admin', 'API'],
  },
  {
    icon: LifeBuoy,
    title: '출시 후 운영 · 유지보수',
    desc: '출시가 끝이 아닙니다. 서버 모니터링 · 장애 대응 · 기능 추가 · 사용자 CS 플로우까지.',
    tags: ['모니터링', '유지보수', '기능 추가', 'CS'],
  },
];

export default function Services() {
  return (
    <section id="services" className="relative py-28 md:py-36 overflow-hidden">
      <div aria-hidden className="pointer-events-none absolute inset-0 -z-10">
        <div className="absolute left-[50%] top-[20%] -translate-x-1/2 h-[420px] w-[820px] rounded-full bg-brand-700/10 blur-[160px]" />
      </div>

      <Container>
        <div className="grid grid-cols-1 lg:grid-cols-[1fr_1.5fr] gap-10 lg:gap-20 items-end mb-14">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.7 }}
          >
            <SectionTag>What We Do</SectionTag>
            <h2 className="mt-6 text-[38px] md:text-[52px] font-semibold leading-[1.08] tracking-tightest text-fog-100">
              필요한 거,
              <br />
              <span className="grad-text">다 만들어 드립니다.</span>
            </h2>
          </motion.div>
          <motion.p
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.7, delay: 0.1 }}
            className="text-[16px] md:text-[18px] leading-[1.7] tracking-[-0.01em] text-fog-300 max-w-[580px] lg:justify-self-end break-keep font-normal"
          >
            <span className="font-semibold text-fog-100">홈페이지 신규 제작 · 리뉴얼 · 앱 개발</span>이 주력입니다.
            관리자 페이지 · AI 챗봇 · 운영까지 한 팀에서 끝냅니다.
            디자인 따로 · 개발 따로 외주 분산 없이.
          </motion.p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {SERVICES.map((s, i) => (
            <ServiceCard key={s.title} {...s} delay={i * 0.05} />
          ))}
        </div>

        {/* Process strip */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.7 }}
          className="mt-20 rounded-2xl border border-white/10 bg-gradient-to-br from-white/[0.03] to-white/[0.01] p-8 md:p-10 backdrop-blur-sm"
        >
          <div className="text-[11px] font-medium uppercase tracking-[0.2em] text-brand-300">
            Process
          </div>
          <div className="mt-4 grid grid-cols-2 md:grid-cols-5 gap-6">
            {[
              { k: '01', t: 'Discovery', d: '문제 · 지표 · 제약 정의' },
              { k: '02', t: 'Design', d: '플로우 · UI · 프로토타입' },
              { k: '03', t: 'Build', d: '주 단위 릴리즈 스프린트' },
              { k: '04', t: 'Ship', d: '스토어 · 배포 · QA' },
              { k: '05', t: 'Operate', d: '지표 · 개선 · 인계' },
            ].map((s) => (
              <div key={s.k} className="group relative">
                <div className="flex items-baseline gap-2">
                  <span className="font-mono text-[11px] text-fog-500">{s.k}</span>
                  <span className="h-[1px] flex-1 bg-gradient-to-r from-white/20 to-transparent" />
                </div>
                <div className="mt-2 text-[15px] font-semibold text-fog-100 tracking-tight">{s.t}</div>
                <div className="mt-1 text-[12.5px] text-fog-400">{s.d}</div>
              </div>
            ))}
          </div>
        </motion.div>
      </Container>
    </section>
  );
}

function ServiceCard({
  icon: Icon,
  title,
  desc,
  tags,
  delay,
}: {
  icon: typeof Smartphone;
  title: string;
  desc: string;
  tags: string[];
  delay: number;
}) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 24 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true, margin: '-60px' }}
      transition={{ duration: 0.6, delay }}
      className="group relative overflow-hidden rounded-2xl border border-white/8 bg-white/[0.015] hover:bg-white/[0.04] p-7 transition-colors"
    >
      <div className="absolute -top-24 -right-24 h-48 w-48 rounded-full bg-brand-500/0 group-hover:bg-brand-500/20 blur-3xl transition-all duration-500" />
      <div className="relative">
        <div className="inline-flex h-11 w-11 items-center justify-center rounded-xl bg-gradient-to-br from-brand-500/20 to-brand-700/10 ring-1 ring-inset ring-brand-400/30 text-brand-300">
          <Icon size={20} strokeWidth={1.8} />
        </div>
        <h3 className="mt-5 text-[18px] font-semibold text-fog-100 tracking-tight">{title}</h3>
        <p className="mt-2 text-[13.5px] leading-relaxed text-fog-400">{desc}</p>
        <div className="mt-5 flex flex-wrap gap-1.5">
          {tags.map((t) => (
            <span
              key={t}
              className="rounded-md border border-white/10 bg-white/[0.03] px-2 py-0.5 text-[10.5px] font-medium text-fog-300"
            >
              {t}
            </span>
          ))}
        </div>
      </div>
    </motion.div>
  );
}
