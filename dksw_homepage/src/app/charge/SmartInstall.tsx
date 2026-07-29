'use client';

import { useEffect, useState } from 'react';

export const APP_STORE_URL = 'https://apps.apple.com/kr/app/id6792645861';
export const PLAY_STORE_URL =
  'https://play.google.com/store/apps/details?id=com.dksw.charge';

type Platform = 'ios' | 'android' | 'other';

function detectPlatform(): Platform {
  if (typeof navigator === 'undefined') return 'other';
  const ua = navigator.userAgent;
  // iPadOS 13+ 는 Mac UA 로 위장 → 터치 지원 여부로 판별
  if (/iPhone|iPad|iPod/.test(ua)) return 'ios';
  if (/Macintosh/.test(ua) && navigator.maxTouchPoints > 1) return 'ios';
  if (/Android/.test(ua)) return 'android';
  return 'other';
}

/**
 * 기기 감지 원클릭 설치 버튼.
 * - iOS → App Store, Android → Play Store
 * - 데스크톱 → 하단 다운로드 섹션으로 스크롤 (양쪽 배지 노출)
 */
export default function SmartInstall({ className }: { className?: string }) {
  const [platform, setPlatform] = useState<Platform>('other');

  useEffect(() => {
    setPlatform(detectPlatform());
  }, []);

  const href =
    platform === 'ios'
      ? APP_STORE_URL
      : platform === 'android'
        ? PLAY_STORE_URL
        : '#download';

  return (
    <a
      href={href}
      target={platform === 'other' ? undefined : '_blank'}
      rel={platform === 'other' ? undefined : 'noopener noreferrer'}
      className={`btn-primary inline-flex items-center justify-center gap-2.5 rounded-2xl bg-gradient-to-r from-[#10B981] to-[#059669] px-8 py-4 text-[16px] font-bold text-white shadow-[0_8px_32px_-8px_rgba(16,185,129,0.55)] transition-transform hover:scale-[1.02] active:scale-[0.98] ${className ?? ''}`}
    >
      <DownloadIcon />
      무료로 설치하기
    </a>
  );
}

function DownloadIcon() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
      <path d="M12 3v12" />
      <path d="m7 11 5 5 5-5" />
      <path d="M5 21h14" />
    </svg>
  );
}
