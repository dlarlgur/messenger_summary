export default function SectionTag({ children }: { children: React.ReactNode }) {
  return (
    <span className="inline-flex items-center gap-2 rounded-full border border-white/10 bg-white/[0.03] px-3 py-1 text-[11px] font-medium tracking-[0.14em] text-brand-300 uppercase backdrop-blur">
      <span className="h-1.5 w-1.5 rounded-full bg-brand-400 shadow-[0_0_12px_rgba(59,130,246,0.9)]" />
      {children}
    </span>
  );
}
