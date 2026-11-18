"use client"

import { useActionState } from "react"
import { resetPassword, type FormState } from "./actions"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { MIN_PASSWORD_LENGTH } from "@/domain/password-reset"

const initial: FormState = { error: null }

export function NewPasswordForm() {
  const [state, action, pending] = useActionState(resetPassword, initial)

  return (
    <form action={action} className="mt-6 space-y-4">
      <div className="space-y-2">
        <Label htmlFor="password">Nova senha</Label>
        <Input
          id="password"
          name="password"
          type="password"
          autoComplete="new-password"
          minLength={MIN_PASSWORD_LENGTH}
          required
        />
      </div>
      <div className="space-y-2">
        <Label htmlFor="confirm">Confirmar</Label>
        <Input
          id="confirm"
          name="confirm"
          type="password"
          autoComplete="new-password"
          minLength={MIN_PASSWORD_LENGTH}
          required
        />
      </div>
      {state.error ? (
        <p className="rounded-xl bg-rose-50 px-3 py-2 text-sm text-rose-800" role="alert">
          {state.error}
        </p>
      ) : null}
      <Button type="submit" className="w-full" disabled={pending}>
        {pending ? "Salvando…" : "Salvar senha"}
      </Button>
    </form>
  )
}
