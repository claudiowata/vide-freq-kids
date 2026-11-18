export function ModuleCard({
  eyebrow,
  title,
  children,
}: {
  eyebrow: string
  title: string
  children: React.ReactNode
}) {
  return (
    <section className="rounded-3xl bg-white p-6 shadow-[0_12px_40px_rgba(15,118,110,0.06)] ring-1 ring-teal-900/5">
      <p className="text-xs font-semibold uppercase tracking-[0.14em] text-[#0f766e]">
        {eyebrow}
      </p>
      <h2 className="mt-2 font-serif text-2xl text-[#134e4a]">{title}</h2>
      <div className="mt-3 space-y-3 text-[15px] leading-6 text-teal-950/75">{children}</div>
    </section>
  )
}
