import { Suspense } from "react"
import { ModuleCard } from "@/components/module-card"
import { canManageNetwork } from "@/domain/cell-multiplication"
import { getCurrentProfile } from "@/lib/auth"
import { CloseMonthForm } from "./close-form"

export const metadata = { title: "Fechamento" }

function previousMonth(today: Date): { year: number; month: number } {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: "America/Sao_Paulo",
    year: "numeric",
    month: "2-digit",
  }).formatToParts(today)
  const year = Number(parts.find((part) => part.type === "year")?.value)
  const month = Number(parts.find((part) => part.type === "month")?.value)
  if (month === 1) return { year: year - 1, month: 12 }
  return { year, month: month - 1 }
}

async function FechamentoScreen({
  searchParams,
}: {
  searchParams: Promise<{ aviso?: string }>
}) {
  const aviso = (await searchParams).aviso
  const profile = await getCurrentProfile()
  const { year, month } = previousMonth(new Date())

  return (
    <div className="grid gap-4">
      {aviso === "fechado" ? (
        <p className="rounded-xl bg-[#F4ECFB] px-3 py-2 text-sm text-ink" role="status">
          Status do mês aplicado na sua árvore.
        </p>
      ) : null}
      <ModuleCard eyebrow="Mês" title="Fechamento mensal">
        <p>
          M, % e V continuam a média das semanas preenchidas. Semana só com o outro
          responsável não entra como falta. O status da criança muda aqui, na virada do
          mês: quatro presenças seguidas viram membro e oito faltas seguidas devolvem a
          visitante. A sequência atravessa meses. Lançar a chamada no meio do mês não
          muda o status.
        </p>
        {canManageNetwork(profile.role) ? (
          <CloseMonthForm year={year} month={month} />
        ) : (
          <p>Quem aplica o status do mês é a discipuladora ou alguém acima dela.</p>
        )}
      </ModuleCard>
    </div>
  )
}

export default function FechamentoPage({
  searchParams,
}: {
  searchParams: Promise<{ aviso?: string }>
}) {
  return (
    <Suspense fallback={<p className="text-sm text-ink/70">Abrindo o fechamento…</p>}>
      <FechamentoScreen searchParams={searchParams} />
    </Suspense>
  )
}
