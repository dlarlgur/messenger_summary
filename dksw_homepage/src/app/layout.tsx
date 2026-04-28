import type { Metadata, Viewport } from 'next';
import { GeistSans } from 'geist/font/sans';
import { GeistMono } from 'geist/font/mono';
import './globals.css';

export const metadata: Metadata = {
  metadataBase: new URL('https://dksw4.com'),
  title: {
    default: 'DK Software — 홈페이지 리뉴얼 · 앱 개발',
    template: '%s · DK Software',
  },
  description:
    '회사 홈페이지 신규 제작 · 오래된 사이트 리뉴얼 · 모바일 앱 개발. 기획부터 디자인 · 개발 · 운영까지 한 팀에서 끝냅니다. 홈페이지 2~4주, 앱 4~8주.',
  keywords: [
    'DK Software',
    '홈페이지 제작',
    '홈페이지 리뉴얼',
    '회사 홈페이지',
    '모바일 앱 개발',
    '안드로이드 앱 개발',
    'iOS 앱 개발',
    '관리자 페이지 제작',
    '용인 소프트웨어',
    '소프트웨어 개발 외주',
  ],
  authors: [{ name: 'DK Software' }],
  openGraph: {
    type: 'website',
    locale: 'ko_KR',
    url: 'https://dksw4.com',
    siteName: 'DK Software',
    title: 'DK Software — 홈페이지 리뉴얼 · 앱 개발',
    description:
      '회사 홈페이지 제작 · 리뉴얼 · 모바일 앱 개발. 기획 · 디자인 · 개발 · 운영을 한 팀에서.',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'DK Software',
    description: '홈페이지 만들고, 앱 개발해 드립니다.',
  },
  robots: { index: true, follow: true },
};

export const viewport: Viewport = {
  themeColor: '#07070A',
  width: 'device-width',
  initialScale: 1,
  maximumScale: 5,
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html
      lang="ko"
      className={`${GeistSans.variable} ${GeistMono.variable}`}
      suppressHydrationWarning
    >
      <body className="noise">{children}</body>
    </html>
  );
}
