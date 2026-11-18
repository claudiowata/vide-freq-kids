import { Suspense } from "react"
import { AuthCard } from "@/components/auth-card"
import { MIN_PASSWORD_LENGTH } from "@/domain/password-reset"
import { NewPasswordForm } from "./password-form"

export const metadata = { title: "Nova senha" }

function NewPasswordScreen() {
  return (
    <AuthCard
      title="Nova senha"
      lede={`Escolha uma senha com pelo menos ${MIN_PASSWORD_LENGTH} caracteres. Ela passa a valer na hora.`}
    >
      <NewPasswordForm />
    </AuthCard>
  )
}

export default function ResetPasswordPage() {
  return (
    <Suspense
      fallback={
        <main className="mx-auto flex min-h-full max-w-md items-center px-4 text-sm text-ink/70">
          Abrindo a nova senha…
        </main>
      }
    >
      <NewPasswordScreen />
    </Suspense>
  )
}
