"use client"

import { useActionState, useMemo, useState } from "react"
import { multiplyCell, type FormState } from "./actions"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { CELL_TYPES, CELL_TYPE_LABELS } from "@/domain/cell-type"
import { WEEKDAYS, statusLabel } from "@/domain/cell-multiplication"
import type { CellOption, ChildOption, LeaderOption } from "./load"

const initial: FormState = { error: null }

const selectClass =
  "flex h-11 w-full rounded-xl border border-input bg-white px-3 text-base text-ink shadow-sm outline-none focus-visible:border-primary focus-visible:ring-2 focus-visible:ring-primary/25"

function parentBit(label: "Mãe" | "Pai", value: boolean | null): string {
  const feminine = label === "Mãe"
  if (value === null) return `${label} não informad${feminine ? "a" : "o"}`
  return `${label} ${value ? "convertid" : "não convertid"}${feminine ? "a" : "o"}`
}

export function MultiplyForm({
  cells,
  leaders,
  childRows,
}: {
  cells: CellOption[]
  leaders: LeaderOption[]
  childRows: ChildOption[]
}) {
  const [state, action, pending] = useActionState(multiplyCell, initial)
  const [originId, setOriginId] = useState(cells[0]?.id ?? "")
  const origin = cells.find((cell) => cell.id === originId) ?? null
  const leaderChoices = useMemo(
    () => leaders.filter((leader) => leader.supervisorId === origin?.discipuladorId),
    [leaders, origin?.discipuladorId],
  )
  const originChildren = childRows.filter((child) => child.cellId === originId)

  return (
    <form action={action} className="space-y-4">
      <div className="space-y-2">
        <Label htmlFor="origem">Célula de origem</Label>
        <select
          id="origem"
          name="origem"
          className={selectClass}
          value={originId}
          onChange={(event) => setOriginId(event.target.value)}
          required
        >
          {cells.length === 0 ? <option value="">Nenhuma célula na sua árvore</option> : null}
          {cells.map((cell) => (
            <option key={cell.id} value={cell.id}>
              {cell.name}
            </option>
          ))}
        </select>
      </div>
      <div className="space-y-2">
        <Label htmlFor="nome">Nome da célula nova</Label>
        <Input id="nome" name="nome" required minLength={2} autoComplete="off" />
      </div>
      <div className="space-y-2">
        <Label htmlFor="tipo">Tipo</Label>
        <select id="tipo" name="tipo" className={selectClass} defaultValue="kids" required>
          {CELL_TYPES.map((type) => (
            <option key={type} value={type}>
              {CELL_TYPE_LABELS[type]}
            </option>
          ))}
        </select>
      </div>
      <div className="space-y-2">
        <Label htmlFor="lider">Líder</Label>
        <select
          id="lider"
          name="lider"
          key={originId}
          className={selectClass}
          required
          disabled={leaderChoices.length === 0}
        >
          {leaderChoices.length === 0 ? (
            <option value="">Nenhum líder desta discipuladora</option>
          ) : (
            leaderChoices.map((leader) => (
              <option key={leader.id} value={leader.id}>
                {leader.fullName}
              </option>
            ))
          )}
        </select>
      </div>
      <div className="grid grid-cols-2 gap-3">
        <div className="space-y-2">
          <Label htmlFor="dia">Dia</Label>
          <select id="dia" name="dia" className={selectClass} defaultValue="1" required>
            {WEEKDAYS.map((day) => (
              <option key={day.value} value={day.value}>
                {day.label}
              </option>
            ))}
          </select>
        </div>
        <div className="space-y-2">
          <Label htmlFor="horario">Horário</Label>
          <Input id="horario" name="horario" type="time" required />
        </div>
      </div>
      <div className="space-y-2">
        <Label htmlFor="endereco">Endereço</Label>
        <Input id="endereco" name="endereco" required minLength={3} autoComplete="street-address" />
      </div>
      <div className="space-y-2">
        <Label htmlFor="data">Data da multiplicação</Label>
        <Input id="data" name="data" type="date" required />
      </div>

      <fieldset className="space-y-2">
        <legend className="text-xs font-semibold uppercase tracking-[0.14em] text-primary">
          Crianças que vão para a célula nova
        </legend>
        <p className="text-sm leading-6 text-ink/75">
          Quem for marcado leva o status, as presenças e faltas seguidas e os dados dos pais.
          A frequência antiga fica na célula de origem.
        </p>
        {originChildren.length === 0 ? (
          <p className="text-sm text-ink/70">Esta célula não tem crianças. A nova pode nascer vazia.</p>
        ) : (
          <ul className="space-y-2">
            {originChildren.map((child) => (
              <li key={child.id}>
                <label className="flex min-h-11 items-start gap-3 rounded-2xl bg-[#FFF8EE] px-3 py-3 ring-1 ring-primary/10">
                  <input
                    type="checkbox"
                    name="crianca"
                    value={child.id}
                    className="mt-1 size-5 accent-[#682A86]"
                  />
                  <span className="min-w-0 text-sm leading-5 text-ink">
                    <span className="block font-semibold">{child.fullName}</span>
                    <span className="text-ink/70">
                      {statusLabel(child.status)} · {child.presenceStreak} presenças seguidas ·{" "}
                      {child.absenceStreak} faltas seguidas
                    </span>
                    <span className="block text-ink/70">
                      {parentBit("Mãe", child.motherConverted)} · {parentBit("Pai", child.fatherConverted)}
                      {child.guardians ? ` · ${child.guardians}` : ""}
                    </span>
                  </span>
                </label>
              </li>
            ))}
          </ul>
        )}
      </fieldset>

      {state.error ? (
        <p className="rounded-xl bg-rose-50 px-3 py-2 text-sm text-rose-800" role="alert">
          {state.error}
        </p>
      ) : null}
      <Button type="submit" className="w-full" disabled={pending || cells.length === 0 || leaderChoices.length === 0}>
        {pending ? "Multiplicando…" : "Multiplicar célula"}
      </Button>
    </form>
  )
}
