import Container from './Container';
import Logo from './Logo';

export default function Footer() {
  return (
    <footer className="relative border-t border-white/5 py-12">
      <Container>
        <div className="flex flex-col md:flex-row items-start md:items-center justify-between gap-6">
          <div className="flex items-center gap-2.5">
            <Logo size={22} />
            <span className="font-semibold tracking-tight text-[15px] text-fog-100">
              DK <span className="text-fog-400 font-medium">Software</span>
            </span>
          </div>
          <div className="flex flex-col md:flex-row md:items-center gap-2 md:gap-6 text-[12px] text-fog-400">
            <span>경기도 용인시 수지구 고기로 89</span>
            <span className="hidden md:inline text-fog-500">·</span>
            <span>사업자등록 582-35-01314</span>
            <span className="hidden md:inline text-fog-500">·</span>
            <a href="mailto:ghim2131@gmail.com" className="hover:text-fog-200">
              ghim2131@gmail.com
            </a>
          </div>
        </div>
        <div className="mt-8 text-[11.5px] text-fog-500">
          © {new Date().getFullYear()} DK Software. All rights reserved.
        </div>
      </Container>
    </footer>
  );
}
