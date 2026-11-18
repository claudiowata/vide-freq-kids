"use client"

import { useActionState, useMemo, useState } from "react"
import { saveCall, type FormState } from "./actions"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import type { AttendanceChoice } from "@/domain/child-status"

const initial: FormState = { error: null }

const selectClass =
  "flex h-11 w-full rounded-xl border border-input bg-white px-3 text-base text-ink shadow-sm outline-none focus-visible:border-primary focus-visible:ring-2 focus-visible:ring-primary/25"

export interface CallChild {
  id: string
  cellId: string
  fullName: string
  sharedCustody: boolean
}

export interface CallCell {
  id: string
  name: string
}

const OPTIONS: { value: AttendanceChoice; label: string; sharedOnly?: boolean }[] = [
  { value: "presente", label: "Presente" },
  { value: "falta", label: "Falta" },
  {
    value: "outro_responsavel",
    label: "Semana com o outro responsável",
    sharedOnly: true,
  },
]

export function CallForm({
  cells,
  childRows,
  today,
}: {
  cells: CallCell[]
  childRows: CallChild[]
  today: string
}) {
  const [state, action, pending] = useActionState(saveCall, initial)
  const [cellId, setCellId] = useState(cells[0]?.id ?? "")
  const listed = useMemo(
    () => childRows.filter((child) => child.cellId === cellId),
    [childRows, cellId],
  )

  return (
    <form action={action} className="space-y-4">
      <div className="space-y-2">
        <Label htmlFor="cellId">Célula</Label>
        <select
          id="cellId"
          name="cellId"
          className={selectClass}
          value={cellId}
          onChange={(event) => setCellId(event.target.value)}
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
        <Label htmlFor="date">Data da célula</Label>
        <Input id="date" name="date" type="date" required defaultValue={today} />
      </div>
      {listed.length === 0 ? (
        <p className="text-sm text-ink/70">Esta célula não tem crianças na sua lista.</p>
      ) : (
        <ul className="space-y-3">
          {listed.map((child) => (
            <li key={child.id} className="rounded-2xl bg-[#FFF8EE] px-3 py-3 ring-1 ring-primary/10">
              <p className="font-semibold text-ink">{child.fullName}</p>
              <div className="mt-2 grid gap-2">
                {OPTIONS.filter((option) => !option.sharedOnly || child.sharedCustody).map((option) => (
                  <label
                    key={option.value}
                    className="flex min-h-11 items-center gap-3 rounded-full bg-white px-3 text-sm font-semibold text-ink ring-1 ring-primary/15 has-[:checked]:bg-primary has-[:checked]:text-white"
                  >
                    <input
                      type="radio"
                      name={`mark:${child.id}`}
                      value={option.value}
                      className="size-4 accent-[#682A86]"
                    />
                    {option.label}
                  </label>
                ))}
              </div>
            </li>
          ))}
        </ul>
      )}
      {state.error ? (
        <p className="rounded-xl bg-rose-50 px-3 py-2 text-sm text-rose-800" role="alert">
          {state.error}
        </p>
      ) : null}
      <Button type="submit" className="w-full" disabled={pending || cells.length === 0}>
        {pending ? "Salvando…" : "Salvar chamada"}
      </Button>
    </form>
  )
}
