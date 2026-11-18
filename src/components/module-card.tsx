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
    <section className="rounded-3xl bg-white p-6 shadow-[0_12px_40px_rgba(92,46,145,0.08)] ring-1 ring-primary/10">
      <p className="text-xs font-semibold uppercase tracking-[0.14em] text-primary">
        {eyebrow}
      </p>
      <h2 className="mt-2 font-serif text-2xl text-ink">{title}</h2>
      <div className="mt-3 space-y-3 text-[15px] leading-6 text-ink/75">{children}</div>
    </section>
  )
}
