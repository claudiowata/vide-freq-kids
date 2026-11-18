import { Suspense } from "react"
import { ModuleCard } from "@/components/module-card"
import { loadCadastro } from "@/app/(app)/cadastro/load"
import { CallForm } from "./call-form"

export const metadata = { title: "Frequência" }

function todayInSaoPaulo(): string {
  return new Intl.DateTimeFormat("en-CA", { timeZone: "America/Sao_Paulo" }).format(new Date())
}

async function FrequenciaScreen({
  searchParams,
}: {
  searchParams: Promise<{ aviso?: string }>
}) {
  const aviso = (await searchParams).aviso
  const data = await loadCadastro()

  return (
    <div className="grid gap-4">
      {aviso === "salva" ? (
        <p className="rounded-xl bg-[#F4ECFB] px-3 py-2 text-sm text-ink" role="status">
          Chamada salva. O status deste mês não muda até o fechamento.
        </p>
      ) : null}
      <ModuleCard eyebrow="Reunião" title="Registrar frequência">
        <p>
          Quatro presenças seguidas na célula tornam a criança membro e oito faltas
          seguidas devolvem o membro a visitante, mas o status gravado só muda na virada
          do mês. A sequência atravessa meses. O culto não entra. Quem tem guarda
          compartilhada pode marcar a semana com o outro responsável: essa semana não
          conta como presença nem como falta e não quebra a sequência.
        </p>
        <CallForm
          cells={data.cells.map((cell) => ({ id: cell.id, name: cell.name }))}
          childRows={data.children.map((child) => ({
            id: child.id,
            cellId: child.cellId,
            fullName: child.fullName,
            sharedCustody: child.sharedCustody,
          }))}
          today={todayInSaoPaulo()}
        />
      </ModuleCard>
    </div>
  )
}

export default function FrequenciaPage({
  searchParams,
}: {
  searchParams: Promise<{ aviso?: string }>
}) {
  return (
    <Suspense fallback={<p className="text-sm text-ink/70">Abrindo a chamada…</p>}>
      <FrequenciaScreen searchParams={searchParams} />
    </Suspense>
  )
}
