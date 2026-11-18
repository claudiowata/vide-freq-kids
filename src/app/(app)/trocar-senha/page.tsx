import { PasswordForm } from "./password-form"

export const metadata = { title: "Trocar senha" }

export default function TrocarSenhaPage() {
  return (
    <section className="rounded-3xl bg-white p-6 shadow-[0_16px_50px_rgba(15,118,110,0.08)] ring-1 ring-teal-900/5">
      <p className="text-xs font-semibold uppercase tracking-[0.14em] text-[#0f766e]">
        Senha provisória
      </p>
      <h1 className="mt-2 font-serif text-3xl text-[#134e4a]">Defina a sua senha</h1>
      <p className="mt-2 text-sm leading-6 text-teal-950/70">
        A liderança criou esta conta com uma senha temporária. Troque agora para entrar
        na rede.
      </p>
      <PasswordForm />
    </section>
  )
}
