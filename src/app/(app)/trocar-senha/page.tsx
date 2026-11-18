import { PasswordForm } from "./password-form"

export const metadata = { title: "Trocar senha" }

export default function TrocarSenhaPage() {
  return (
    <section className="rounded-3xl bg-white p-6 shadow-[0_16px_50px_rgba(92,46,145,0.10)] ring-1 ring-primary/10">
      <p className="text-xs font-semibold uppercase tracking-[0.14em] text-primary">
        Senha provisória
      </p>
      <h1 className="mt-2 font-serif text-3xl text-ink">Defina a sua senha</h1>
      <p className="mt-2 text-sm leading-6 text-ink/75">
        A liderança criou esta conta com uma senha temporária. Troque agora para entrar
        na rede.
      </p>
      <PasswordForm />
    </section>
  )
}
