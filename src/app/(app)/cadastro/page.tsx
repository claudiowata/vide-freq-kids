import Link from "next/link"
import { Suspense } from "react"
import { ModuleCard } from "@/components/module-card"
import { Button } from "@/components/ui/button"
import { CELL_TYPE_LABELS } from "@/domain/cell-type"
import { WEEKDAYS, canManageNetwork } from "@/domain/cell-multiplication"
import { getCurrentProfile } from "@/lib/auth"
import { CustodyForm } from "./custody-form"
import { loadCadastro } from "./load"

export const metadata = { title: "Cadastro" }

function weekdayLabel(value: number | null): string | null {
  return WEEKDAYS.find((day) => day.value === value)?.label ?? null
}

async function CadastroScreen({
  searchParams,
}: {
  searchParams: Promise<{ aviso?: string }>
}) {
  const aviso = (await searchParams).aviso
  const profile = await getCurrentProfile()
  const data = await loadCadastro()
  const canManage = canManageNetwork(profile.role)
  const leaderNames = new Map(data.leaders.map((leader) => [leader.id, leader.fullName]))

  return (
    <div className="grid gap-4">
      {aviso === "multiplicada" ? (
        <p className="rounded-xl bg-[#F4ECFB] px-3 py-2 text-sm text-ink" role="status">
          Célula multiplicada. As crianças marcadas já estão na célula nova.
        </p>
      ) : null}
      {aviso === "remanejada" ? (
        <p className="rounded-xl bg-[#F4ECFB] px-3 py-2 text-sm text-ink" role="status">
          Crianças remanejadas. O status e os dados dos pais foram junto.
        </p>
      ) : null}
      {aviso === "guarda" ? (
        <p className="rounded-xl bg-[#F4ECFB] px-3 py-2 text-sm text-ink" role="status">
          Guarda compartilhada atualizada.
        </p>
      ) : null}
      {data.cellsError ? (
        <p className="rounded-xl bg-rose-50 px-3 py-2 text-sm text-rose-800" role="alert">
          Não foi possível carregar as células.
        </p>
      ) : null}

      <ModuleCard eyebrow="Ficha" title="Células da sua árvore">
        <p>
          Discipuladora e quem está acima multiplicam a célula e remanejam as crianças
          dentro da própria subárvore. Líder vê só a própria célula.
        </p>
        {canManage ? (
          <div className="flex flex-col gap-2 sm:flex-row">
            <Button asChild className="w-full sm:w-auto">
              <Link href="/cadastro/multiplicar">Multiplicar célula</Link>
            </Button>
            <Button asChild variant="outline" className="w-full sm:w-auto">
              <Link href="/cadastro/remanejar">Remanejar crianças</Link>
            </Button>
          </div>
        ) : (
          <p>A multiplicação e o remanejamento ficam com a discipuladora.</p>
        )}
        {data.cells.length === 0 ? (
          <p>Nenhuma célula aparece para esta conta.</p>
        ) : (
          <ul className="space-y-2">
            {data.cells.map((cell) => (
              <li key={cell.id} className="rounded-2xl bg-[#FFF8EE] px-3 py-3 ring-1 ring-primary/10">
                <p className="font-semibold text-ink">{cell.name}</p>
                <p className="text-sm text-ink/70">
                  {CELL_TYPE_LABELS[cell.cellType]}
                  {leaderNames.get(cell.leaderId) ? ` · ${leaderNames.get(cell.leaderId)}` : ""}
                  {weekdayLabel(cell.weekday) ? ` · ${weekdayLabel(cell.weekday)}` : ""}
                  {cell.meetingTime ? ` · ${cell.meetingTime}` : ""}
                </p>
                {cell.address ? <p className="text-sm text-ink/70">{cell.address}</p> : null}
              </li>
            ))}
          </ul>
        )}
      </ModuleCard>

      <ModuleCard eyebrow="Ficha" title="Crianças">
        {data.children.length === 0 ? (
          <p>Nenhuma criança aparece para esta conta.</p>
        ) : (
          <ul className="space-y-3">
            {data.children.map((child) => (
              <li key={child.id} className="rounded-2xl bg-[#FFF8EE] px-3 py-3 ring-1 ring-primary/10">
                <p className="font-semibold text-ink">{child.fullName}</p>
                <p className="text-sm text-ink/70">
                  {data.cells.find((cell) => cell.id === child.cellId)?.name ?? "Célula"} ·{" "}
                  {child.status === "membro" ? "Membro" : "Visitante"}
                </p>
                <CustodyForm childId={child.id} shared={child.sharedCustody} />
              </li>
            ))}
          </ul>
        )}
      </ModuleCard>

      {data.transfers.length > 0 ? (
        <ModuleCard eyebrow="Histórico" title="Movimentações">
          <ul className="space-y-2">
            {data.transfers.map((transfer) => (
              <li key={transfer.id} className="text-sm text-ink">
                <span className="font-semibold">{transfer.childName}</span> saiu de{" "}
                {transfer.fromName} e foi para {transfer.toName} em{" "}
                {new Date(`${transfer.transferredOn}T12:00:00`).toLocaleDateString("pt-BR")}.
              </li>
            ))}
          </ul>
        </ModuleCard>
      ) : null}
      {data.migrationPending ? (
        <p className="text-sm text-ink/70">
          O histórico de transferências aparece depois de aplicar a migration{" "}
          <span className="font-semibold">20261118190000_multiplicacao_celula.sql</span>.
        </p>
      ) : null}
    </div>
  )
}

export default function CadastroPage({
  searchParams,
}: {
  searchParams: Promise<{ aviso?: string }>
}) {
  return (
    <Suspense fallback={<p className="text-sm text-ink/70">Carregando o cadastro…</p>}>
      <CadastroScreen searchParams={searchParams} />
    </Suspense>
  )
}
