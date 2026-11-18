"use client"

import { useActionState } from "react"
import { saveSharedCustody, type FormState } from "./actions"
import { Button } from "@/components/ui/button"

const initial: FormState = { error: null }

export function CustodyForm({
  childId,
  shared,
}: {
  childId: string
  shared: boolean
}) {
  const [state, action, pending] = useActionState(saveSharedCustody, initial)

  return (
    <form action={action} className="mt-2 space-y-2">
      <input type="hidden" name="childId" value={childId} />
      <label className="flex min-h-11 items-start gap-3 text-sm leading-5 text-ink">
        <input
          type="checkbox"
          name="guarda"
          defaultChecked={shared}
          className="mt-1 size-5 accent-[#682A86]"
        />
        <span>Guarda compartilhada (uma semana com cada responsável)</span>
      </label>
      {state.error ? (
        <p className="text-sm text-rose-800" role="alert">
          {state.error}
        </p>
      ) : null}
      <Button type="submit" size="sm" variant="outline" disabled={pending}>
        {pending ? "Salvando…" : "Salvar guarda"}
      </Button>
    </form>
  )
}
