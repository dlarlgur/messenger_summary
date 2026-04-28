'use client';

import { useEffect, useState } from 'react';
import { cn } from '@/lib/utils';
import Logo from './Logo';

const LINKS = [
  { href: '#about', label: 'About' },
  { href: '#products', label: 'Products' },
  { href: '#cases', label: 'Cases' },
  { href: '#services', label: 'Services' },
  { href: '#why', label: 'Why DK' },
  { href: '#contact', label: 'Contact' },
];

export default function Navbar() {
  const [scrolled, setScrolled] = useState(false);

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 12);
    onScroll();
    window.addEventListener('scroll', onScroll, { passive: true });
    return () => window.removeEventListener('scroll', onScroll);
  }, []);

  return (
    <header
      className={cn(
        'fixed inset-x-0 top-0 z-50 transition-all duration-300',
        scrolled
          ? 'backdrop-blur-xl bg-ink-950/70 border-b border-white/5'
          : 'bg-transparent border-b border-transparent',
      )}
    >
      <div className="mx-auto flex w-full max-w-[1240px] items-center justify-between px-6 md:px-10 h-16">
        <a href="#top" className="flex items-center gap-2.5 group">
          <Logo size={22} className="transition-transform duration-300 group-hover:scale-[1.04]" />
          <span className="font-semibold tracking-tight text-[15px] text-fog-100">
            DK <span className="text-fog-400 font-medium">Software</span>
          </span>
        </a>
        <nav className="hidden md:flex items-center gap-8">
          {LINKS.map((l) => (
            <a
              key={l.href}
              href={l.href}
              className="text-[13px] font-medium text-fog-300 hover:text-fog-100 transition-colors"
            >
              {l.label}
            </a>
          ))}
        </nav>
        <a
          href="#contact"
          className="btn-primary hidden md:inline-flex items-center gap-1.5 rounded-full bg-brand-500 hover:bg-brand-400 px-4 py-2 text-[13px] font-semibold text-white shadow-[0_0_0_1px_rgba(59,130,246,0.4),0_10px_40px_-10px_rgba(59,130,246,0.7)] transition-colors"
        >
          프로젝트 문의
          <svg width="12" height="12" viewBox="0 0 12 12" fill="none" aria-hidden>
            <path
              d="M2.5 6h7M6.5 2.5 10 6 6.5 9.5"
              stroke="currentColor"
              strokeWidth="1.6"
              strokeLinecap="round"
              strokeLinejoin="round"
            />
          </svg>
        </a>
        <a
          href="#contact"
          className="md:hidden rounded-full bg-brand-500 px-3.5 py-1.5 text-xs font-semibold text-white"
        >
          문의
        </a>
      </div>
    </header>
  );
}

