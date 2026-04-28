'use client';

import { motion } from 'framer-motion';
import { Mail, MapPin, Building2 } from 'lucide-react';
import Container from './Container';
import SectionTag from './SectionTag';

export default function Contact() {
  return (
    <section id="contact" className="relative py-28 md:py-36 overflow-hidden">
      <div aria-hidden className="pointer-events-none absolute inset-0 -z-10">
        <div className="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 h-[600px] w-[900px] rounded-full bg-brand-700/20 blur-[160px]" />
      </div>

      <Container>
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.7 }}
          className="relative overflow-hidden rounded-[32px] border border-white/10 bg-gradient-to-br from-brand-900/30 via-ink-900 to-ink-950 p-10 md:p-16"
        >
          {/* Decorative grid */}
          <div aria-hidden className="absolute inset-0 bg-grid-mask opacity-30" />
          <div aria-hidden className="absolute -top-20 -right-20 h-80 w-80 rounded-full bg-brand-500/25 blur-3xl" />

          <div className="relative grid grid-cols-1 lg:grid-cols-[1.2fr_1fr] gap-10 lg:gap-20 items-start">
            <div>
              <SectionTag>Start a project</SectionTag>
              <h2 className="mt-6 text-[40px] md:text-[60px] font-semibold leading-[1.04] tracking-tightest text-fog-100">
                아이디어가 있으신가요?
                <br />
                <span className="grad-text">함께 만들어봐요.</span>
              </h2>
              <p className="mt-6 text-[15.5px] md:text-[17px] leading-relaxed text-fog-300 max-w-[520px]">
                한 줄 아이디어부터 기획안까지, 어떤 상태여도 괜찮습니다.
                하루 안에 첫 답장을 드리고, 2영업일 안에 간단 견적·로드맵을 드립니다.
              </p>

              <a
                href="mailto:ghim2131@gmail.com?subject=%5BDK%20Software%5D%20%ED%94%84%EB%A1%9C%EC%A0%9D%ED%8A%B8%20%EB%AC%B8%EC%9D%98"
                className="btn-primary mt-10 inline-flex items-center gap-2 rounded-full bg-brand-500 hover:bg-brand-400 px-7 py-4 text-[15px] font-semibold text-white shadow-[0_0_0_1px_rgba(59,130,246,0.4),0_20px_60px_-20px_rgba(59,130,246,0.9)] transition-colors"
              >
                <Mail size={16} strokeWidth={2} />
                ghim2131@gmail.com
              </a>
              <p className="mt-3 text-[12px] text-fog-400">
                클릭하면 메일 클라이언트가 열립니다. 간단히 요구사항만 남겨주세요.
              </p>
            </div>

            <div className="space-y-4">
              <InfoCard
                icon={<Building2 size={18} strokeWidth={1.8} />}
                label="Company"
                value={<>DK Software<br /><span className="text-fog-400 text-[12.5px]">사업자등록번호 · 582-35-01314</span></>}
              />
              <InfoCard
                icon={<MapPin size={18} strokeWidth={1.8} />}
                label="Address"
                value={
                  <>
                    경기도 용인시 수지구
                    <br />
                    고기로 89
                  </>
                }
              />
              <InfoCard
                icon={<Mail size={18} strokeWidth={1.8} />}
                label="Email"
                value={
                  <a href="mailto:ghim2131@gmail.com" className="hover:text-brand-300">
                    ghim2131@gmail.com
                  </a>
                }
              />
            </div>
          </div>
        </motion.div>
      </Container>
    </section>
  );
}

function InfoCard({
  icon,
  label,
  value,
}: {
  icon: React.ReactNode;
  label: string;
  value: React.ReactNode;
}) {
  return (
    <div className="rounded-2xl border border-white/10 bg-white/[0.025] p-5 backdrop-blur-sm">
      <div className="flex items-center gap-2.5">
        <span className="inline-flex h-8 w-8 items-center justify-center rounded-lg bg-brand-500/15 text-brand-300 ring-1 ring-inset ring-brand-400/30">
          {icon}
        </span>
        <span className="text-[11px] font-medium uppercase tracking-[0.18em] text-fog-400">
          {label}
        </span>
      </div>
      <div className="mt-3 text-[15px] leading-relaxed text-fog-100">{value}</div>
    </div>
  );
}
