"use client"

export default function RootError({
  reset,
}: {
  error: Error & { digest?: string }
  reset: () => void
}) {
  return (
    <main className="mx-auto flex min-h-full max-w-md flex-col justify-center px-4">
      <div className="rounded-3xl bg-white p-6 ring-1 ring-teal-900/5">
        <h1 className="font-serif text-2xl text-[#134e4a]">Algo saiu do lugar</h1>
        <p className="mt-2 text-sm leading-6 text-teal-950/70">
          Não consegui completar esta tela. Se o banco local acabou de subir, tente de novo.
        </p>
        <button
          type="button"
          onClick={reset}
          className="mt-4 h-11 rounded-full bg-[#0f766e] px-5 text-sm font-semibold text-white"
        >
          Tentar de novo
        </button>
      </div>
    </main>
  )
}
