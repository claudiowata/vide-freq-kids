"use client"

import { useActionState, useState } from "react"
import { reassignChildren, type FormState } from "./actions"
import { Button } from "@/components/ui/button"
import { Label } from "@/components/ui/label"
import { statusLabel } from "@/domain/cell-multiplication"
import type { CellOption, ChildOption } from "./load"

const initial: FormState = { error: null }

const selectClass =
  "flex h-11 w-full rounded-xl border border-input bg-white px-3 text-base text-ink shadow-sm outline-none focus-visible:border-primary focus-visible:ring-2 focus-visible:ring-primary/25"

export function ReassignForm({
  cells,
  childRows,
}: {
  cells: CellOption[]
  childRows: ChildOption[]
}) {
  const [state, action, pending] = useActionState(reassignChildren, initial)
  const [originId, setOriginId] = useState(cells[0]?.id ?? "")
  const [destinationId, setDestinationId] = useState(cells[1]?.id ?? cells[0]?.id ?? "")
  const originChildren = childRows.filter((child) => child.cellId === originId)

  return (
    <form action={action} className="space-y-4">
      <div className="space-y-2">
        <Label htmlFor="origem">Da célula</Label>
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
        <Label htmlFor="destino">Para a célula</Label>
        <select
          id="destino"
          name="destino"
          className={selectClass}
          value={destinationId}
          onChange={(event) => setDestinationId(event.target.value)}
          required
        >
          {cells.map((cell) => (
            <option key={cell.id} value={cell.id}>
              {cell.name}
            </option>
          ))}
        </select>
      </div>
      <fieldset className="space-y-2">
        <legend className="text-xs font-semibold uppercase tracking-[0.14em] text-primary">
          Crianças
        </legend>
        {originChildren.length === 0 ? (
          <p className="text-sm text-ink/70">Esta célula não tem crianças para mover.</p>
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
                  <span className="text-sm leading-5 text-ink">
                    <span className="block font-semibold">{child.fullName}</span>
                    <span className="text-ink/70">
                      {statusLabel(child.status)} · {child.presenceStreak} presenças seguidas ·{" "}
                      {child.absenceStreak} faltas seguidas
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
      <Button type="submit" className="w-full" disabled={pending || cells.length < 2}>
        {pending ? "Movendo…" : "Mover crianças"}
      </Button>
    </form>
  )
}
