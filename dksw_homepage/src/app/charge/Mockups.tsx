import Image from 'next/image';

/**
 * /charge 랜딩 폰 목업 — 실기기 캡처(public/charge/screens/*)를 폰 프레임에 담아 렌더.
 * CSS 가짜 화면 대신 현재 배포 버전의 실제 화면을 그대로 보여준다.
 */

function PhoneFrame({
  children,
  width = 248,
}: {
  children: React.ReactNode;
  width?: number;
}) {
  return (
    <div
      className="relative shrink-0 rounded-[42px] border border-black/20 bg-[#0B1220] p-[10px] shadow-[0_30px_70px_-22px_rgba(6,78,59,0.45)]"
      style={{ width }}
    >
      {/* 노치(다이나믹 아일랜드) */}
      <div className="absolute left-1/2 top-[18px] z-10 h-[20px] w-[80px] -translate-x-1/2 rounded-full bg-black" />
      <div className="overflow-hidden rounded-[33px] bg-white">{children}</div>
    </div>
  );
}

/** 실기기 스크린샷 목업 — 홈(주유)/홈(충전)은 히어로, 나머지는 갤러리에서 사용 */
export function DeviceShot({
  src,
  alt,
  width = 248,
  ratio = 1080 / 1716, // 홈 캡처 비율 (w/h)
}: {
  src: string;
  alt: string;
  width?: number;
  ratio?: number;
}) {
  const inner = width - 20; // 프레임 패딩 10px * 2
  return (
    <PhoneFrame width={width}>
      <Image
        src={src}
        alt={alt}
        width={inner}
        height={Math.round(inner / ratio)}
        className="block h-auto w-full"
        quality={90}
      />
    </PhoneFrame>
  );
}

export function FuelMockup() {
  return (
    <DeviceShot
      src="/charge/screens/home-fuel.jpg"
      alt="전기차 기름차 — 주유소 최저가 홈 화면 (실제 앱 화면)"
    />
  );
}

export function EvMockup() {
  return (
    <DeviceShot
      src="/charge/screens/home-ev.jpg"
      alt="전기차 기름차 — 충전소 빈자리 홈 화면 (실제 앱 화면)"
    />
  );
}
