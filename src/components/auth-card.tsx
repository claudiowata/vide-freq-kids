import { Logo } from "@/components/logo"

export function AuthCard({
  title,
  lede,
  children,
}: {
  title: string
  lede: string
  children: React.ReactNode
}) {
  return (
    <main className="mx-auto flex min-h-full w-full max-w-md flex-col justify-center px-4 py-12">
      <div className="rounded-3xl bg-white p-6 shadow-[0_16px_50px_rgba(92,46,145,0.10)] ring-1 ring-primary/10 sm:p-8">
        <div className="flex flex-col items-center text-center">
          <Logo variant="full" className="h-44" />
          <p className="mt-2 font-serif text-xl text-ink">Vide Freq Kids</p>
          <p className="text-xs text-ink/65">Igreja Videira Barra Funda</p>
        </div>
        <h1 className="mt-6 font-serif text-3xl text-ink">{title}</h1>
        <p className="mt-2 text-sm leading-6 text-ink/75">{lede}</p>
        {children}
      </div>
    </main>
  )
}
