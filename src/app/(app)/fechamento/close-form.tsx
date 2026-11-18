"use client"

import { useActionState } from "react"
import { closeMonth, type FormState } from "./actions"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"

const initial: FormState = { error: null }

export function CloseMonthForm({ year, month }: { year: number; month: number }) {
  const [state, action, pending] = useActionState(closeMonth, initial)

  return (
    <form action={action} className="grid grid-cols-2 gap-3">
      <div className="space-y-2">
        <Label htmlFor="mes">Mês</Label>
        <Input id="mes" name="mes" type="number" min={1} max={12} required defaultValue={month} />
      </div>
      <div className="space-y-2">
        <Label htmlFor="ano">Ano</Label>
        <Input id="ano" name="ano" type="number" min={2000} max={2100} required defaultValue={year} />
      </div>
      {state.error ? (
        <p className="col-span-2 rounded-xl bg-rose-50 px-3 py-2 text-sm text-rose-800" role="alert">
          {state.error}
        </p>
      ) : null}
      <Button type="submit" className="col-span-2 w-full" disabled={pending}>
        {pending ? "Fechando…" : "Aplicar status do mês"}
      </Button>
    </form>
  )
}
