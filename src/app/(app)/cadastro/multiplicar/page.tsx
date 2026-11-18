import Link from "next/link"
import { Suspense } from "react"
import { ModuleCard } from "@/components/module-card"
import { canManageNetwork } from "@/domain/cell-multiplication"
import { getCurrentProfile } from "@/lib/auth"
import { MultiplyForm } from "../multiply-form"
import { loadCadastro } from "../load"

export const metadata = { title: "Multiplicar célula" }

async function MultiplyScreen() {
  const profile = await getCurrentProfile()
  if (!canManageNetwork(profile.role)) {
    return (
      <ModuleCard eyebrow="Multiplicação" title="Só a discipuladora">
        <p>Líder não multiplica célula. Fale com a discipuladora da sua árvore.</p>
        <Link href="/cadastro" className="inline-flex min-h-11 items-center font-semibold text-primary">
          Voltar ao cadastro
        </Link>
      </ModuleCard>
    )
  }

  const data = await loadCadastro()
  return (
    <ModuleCard eyebrow="Multiplicação" title="Nova célula">
      <p>
        A célula nova fica na mesma árvore. As crianças marcadas mudam de célula com o
        status, as sequências e os dados dos pais. A chamada antiga não muda de lugar.
      </p>
      <MultiplyForm cells={data.cells} leaders={data.leaders} childRows={data.children} />
      <Link href="/cadastro" className="inline-flex min-h-11 items-center font-semibold text-primary">
        Voltar ao cadastro
      </Link>
    </ModuleCard>
  )
}

export default function MultiplyPage() {
  return (
    <Suspense fallback={<p className="text-sm text-ink/70">Abrindo a multiplicação…</p>}>
      <MultiplyScreen />
    </Suspense>
  )
}
