"use client"

export default function AppError({
  reset,
}: {
  error: Error & { digest?: string }
  reset: () => void
}) {
  return (
    <main className="mx-auto flex min-h-full max-w-md flex-col justify-center px-4">
      <div className="rounded-3xl bg-white p-6 ring-1 ring-primary/10">
        <h1 className="font-serif text-2xl text-ink">Não foi possível abrir a rede</h1>
        <p className="mt-2 text-sm leading-6 text-ink/75">
          O Supabase não respondeu. Confira se o projeto local está no ar ou se o
          .env.local aponta para o endereço certo.
        </p>
        <button
          type="button"
          onClick={reset}
          className="mt-4 h-11 rounded-full bg-primary px-5 text-sm font-semibold text-white"
        >
          Tentar de novo
        </button>
      </div>
    </main>
  )
}
