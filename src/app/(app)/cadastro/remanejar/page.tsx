import Link from "next/link"
import { Suspense } from "react"
import { ModuleCard } from "@/components/module-card"
import { canManageNetwork } from "@/domain/cell-multiplication"
import { getCurrentProfile } from "@/lib/auth"
import { ReassignForm } from "../reassign-form"
import { loadCadastro } from "../load"

export const metadata = { title: "Remanejar crianças" }

async function ReassignScreen() {
  const profile = await getCurrentProfile()
  if (!canManageNetwork(profile.role)) {
    return (
      <ModuleCard eyebrow="Remanejamento" title="Só a discipuladora">
        <p>Líder não move criança de célula. Fale com a discipuladora da sua árvore.</p>
        <Link href="/cadastro" className="inline-flex min-h-11 items-center font-semibold text-primary">
          Voltar ao cadastro
        </Link>
      </ModuleCard>
    )
  }

  const data = await loadCadastro()
  return (
    <ModuleCard eyebrow="Remanejamento" title="Entre células da sua árvore">
      <p>
        Escolha duas células que você acompanha. A criança leva status, presenças e faltas
        seguidas e os dados dos pais. A frequência antiga continua na célula em que aconteceu.
      </p>
      <ReassignForm cells={data.cells} childRows={data.children} />
      <Link href="/cadastro" className="inline-flex min-h-11 items-center font-semibold text-primary">
        Voltar ao cadastro
      </Link>
    </ModuleCard>
  )
}

export default function ReassignPage() {
  return (
    <Suspense fallback={<p className="text-sm text-ink/70">Abrindo o remanejamento…</p>}>
      <ReassignScreen />
    </Suspense>
  )
}
