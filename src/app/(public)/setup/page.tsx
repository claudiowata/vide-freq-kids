import Link from "next/link"
import { redirect } from "next/navigation"
import { Suspense } from "react"
import { Logo } from "@/components/logo"
import { getPublicSupabaseEnv } from "@/lib/env"
import { createClient } from "@/lib/supabase/server"
import { SetupForm } from "./setup-form"

async function SetupScreen() {
  const env = getPublicSupabaseEnv()
  if (!env) {
    return (
      <Notice>
        Defina as variáveis do Supabase em .env.local antes do primeiro acesso.
      </Notice>
    )
  }

  const supabase = await createClient()
  const { data, error } = await supabase.rpc("needs_initial_setup")
  if (error) {
    return <Notice>Não foi possível consultar o banco. As migrações já foram aplicadas?</Notice>
  }
  if (data !== true) redirect("/login")

  return (
    <main className="mx-auto flex min-h-full w-full max-w-md flex-col justify-center px-4 py-12">
      <div className="rounded-3xl bg-white p-6 shadow-[0_16px_50px_rgba(15,118,110,0.08)] ring-1 ring-teal-900/5 sm:p-8">
        <div className="flex items-center gap-3">
          <Logo />
          <p className="font-serif text-xl text-[#134e4a]">Vide Freq Kids</p>
        </div>
        <h1 className="mt-6 font-serif text-3xl text-[#134e4a]">Primeira discipuladora</h1>
        <p className="mt-2 text-sm leading-6 text-teal-950/70">
          A rede pode começar sem pastora. Esta conta fica como raiz e administra o
          primeiro acesso. Uma pastora pode ser ligada acima dela mais tarde, sem
          migrar células nem crianças.
        </p>
        <SetupForm />
        <p className="mt-6 text-sm">
          <Link href="/login" className="font-semibold text-[#0f766e]">
            Já tenho conta
          </Link>
        </p>
      </div>
    </main>
  )
}

function Notice({ children }: { children: React.ReactNode }) {
  return (
    <main className="mx-auto flex min-h-full w-full max-w-md flex-col justify-center px-4">
      <div className="rounded-3xl bg-white p-6 text-sm leading-6 text-teal-950/80 ring-1 ring-teal-900/5">
        {children}
      </div>
    </main>
  )
}

export default function SetupPage() {
  return (
    <Suspense
      fallback={
        <main className="mx-auto flex min-h-full max-w-md items-center px-4 text-sm text-teal-900/70">
          Verificando a rede…
        </main>
      }
    >
      <SetupScreen />
    </Suspense>
  )
}
