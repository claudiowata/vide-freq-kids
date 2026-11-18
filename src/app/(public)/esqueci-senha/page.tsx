import Link from "next/link"
import { Suspense } from "react"
import { AuthCard } from "@/components/auth-card"
import { getPublicSupabaseEnv } from "@/lib/env"
import { ResetRequestForm } from "./reset-request-form"

export const metadata = { title: "Esqueci minha senha" }

async function ForgotScreen({
  searchParams,
}: {
  searchParams: Promise<{ aviso?: string }>
}) {
  const aviso = (await searchParams).aviso
  const env = getPublicSupabaseEnv()

  return (
    <AuthCard
      title="Esqueci minha senha"
      lede="Informe o e-mail da conta. Se ele estiver cadastrado, você recebe um link para criar outra senha."
    >
      {aviso === "sessao" ? (
        <p className="mt-4 rounded-xl bg-rose-50 px-3 py-2 text-sm text-rose-800" role="status">
          Este link expirou ou a sessão de recuperação não é mais válida. Peça um novo.
        </p>
      ) : null}
      {!env ? (
        <p className="mt-6 rounded-xl bg-amber-50 px-3 py-2 text-sm text-amber-950" role="alert">
          Faltam NEXT_PUBLIC_SUPABASE_URL e NEXT_PUBLIC_SUPABASE_ANON_KEY. Copie
          .env.local.example para .env.local.
        </p>
      ) : (
        <ResetRequestForm />
      )}
      <p className="mt-6 text-sm">
        <Link href="/login" className="inline-flex min-h-11 items-center font-semibold text-primary">
          Voltar ao login
        </Link>
      </p>
    </AuthCard>
  )
}

export default function ForgotPasswordPage({
  searchParams,
}: {
  searchParams: Promise<{ aviso?: string }>
}) {
  return (
    <Suspense
      fallback={
        <main className="mx-auto flex min-h-full max-w-md items-center px-4 text-sm text-ink/70">
          Abrindo a recuperação…
        </main>
      }
    >
      <ForgotScreen searchParams={searchParams} />
    </Suspense>
  )
}
