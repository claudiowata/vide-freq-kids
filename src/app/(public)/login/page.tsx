import Link from "next/link"
import { Suspense } from "react"
import { Logo } from "@/components/logo"
import { getPublicSupabaseEnv } from "@/lib/env"
import { createClient } from "@/lib/supabase/server"
import { LoginForm } from "./login-form"

async function LoginScreen({
  searchParams,
}: {
  searchParams: Promise<{ aviso?: string }>
}) {
  const aviso = (await searchParams).aviso
  const env = getPublicSupabaseEnv()
  let needsSetup = false
  let setupError: string | null = null

  if (env) {
    try {
      const supabase = await createClient()
      const { data, error } = await supabase.rpc("needs_initial_setup")
      if (error) setupError = "Não foi possível consultar se a rede já tem contas."
      else needsSetup = data === true
    } catch {
      setupError = "Não foi possível consultar se a rede já tem contas."
    }
  }

  return (
    <main className="mx-auto flex min-h-full w-full max-w-md flex-col justify-center px-4 py-12">
      <div className="rounded-3xl bg-white p-6 shadow-[0_16px_50px_rgba(15,118,110,0.08)] ring-1 ring-teal-900/5 sm:p-8">
        <div className="flex items-center gap-3">
          <Logo />
          <div>
            <p className="font-serif text-xl text-[#134e4a]">Vide Freq Kids</p>
            <p className="text-xs text-teal-900/65">
              Igreja Videira Barra Funda · Radicais Kids
            </p>
          </div>
        </div>
        <h1 className="mt-6 font-serif text-3xl text-[#134e4a]">Entrar</h1>
        <p className="mt-2 text-sm leading-6 text-teal-950/70">
          Frequência e fechamento das células de crianças e juvenis. As contas são
          criadas pela liderança.
        </p>

        {!env ? (
          <p className="mt-6 rounded-xl bg-amber-50 px-3 py-2 text-sm text-amber-950" role="alert">
            Faltam NEXT_PUBLIC_SUPABASE_URL e NEXT_PUBLIC_SUPABASE_ANON_KEY. Copie
            .env.local.example para .env.local.
          </p>
        ) : (
          <LoginForm />
        )}

        {aviso === "inativa" ? (
          <p className="mt-4 text-sm text-rose-800" role="status">
            Esta conta está inativa. Fale com a discipuladora da rede.
          </p>
        ) : null}
        {setupError ? <p className="mt-4 text-sm text-rose-800">{setupError}</p> : null}
        {needsSetup ? (
          <p className="mt-6 text-sm text-teal-950/80">
            A rede ainda não tem ninguém cadastrado.{" "}
            <Link href="/setup" className="font-semibold text-[#0f766e] underline">
              Criar a primeira discipuladora
            </Link>
            .
          </p>
        ) : null}
      </div>
    </main>
  )
}

export default function LoginPage({
  searchParams,
}: {
  searchParams: Promise<{ aviso?: string }>
}) {
  return (
    <Suspense
      fallback={
        <main className="mx-auto flex min-h-full max-w-md items-center px-4 text-sm text-teal-900/70">
          Abrindo o acesso…
        </main>
      }
    >
      <LoginScreen searchParams={searchParams} />
    </Suspense>
  )
}
