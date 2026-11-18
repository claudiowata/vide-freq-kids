"use client"

import { useEffect, useState } from "react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import {
  NEUTRAL_RESET_MESSAGE,
  RATE_LIMIT_COOLDOWN_SECONDS,
  RATE_LIMIT_RESET_MESSAGE,
  RESEND_COOLDOWN_SECONDS,
  isResetRateLimit,
  normalizeEmail,
} from "@/domain/password-reset"
import { createBrowserSupabase } from "@/lib/supabase/browser"

type Tone = "neutral" | "rate_limit" | "invalid"

export function ResetRequestForm() {
  const [message, setMessage] = useState<string | null>(null)
  const [tone, setTone] = useState<Tone>("neutral")
  const [pending, setPending] = useState(false)
  const [left, setLeft] = useState(0)

  useEffect(() => {
    if (left <= 0) return
    const id = window.setTimeout(() => setLeft((value) => value - 1), 1000)
    return () => window.clearTimeout(id)
  }, [left])

  async function onSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault()
    if (pending || left > 0) return

    const email = normalizeEmail(String(new FormData(event.currentTarget).get("email") ?? ""))
    if (!email) {
      setTone("invalid")
      setMessage("Informe um e-mail válido.")
      return
    }

    setPending(true)
    try {
      const origin = window.location.origin
      const supabase = createBrowserSupabase()
      const { error } = await supabase.auth.resetPasswordForEmail(email, {
        redirectTo: `${origin}/auth/callback?next=/redefinir-senha`,
      })
      if (isResetRateLimit(error)) {
        setTone("rate_limit")
        setMessage(RATE_LIMIT_RESET_MESSAGE)
        setLeft(RATE_LIMIT_COOLDOWN_SECONDS)
      } else {
        setTone("neutral")
        setMessage(NEUTRAL_RESET_MESSAGE)
        setLeft(RESEND_COOLDOWN_SECONDS)
      }
    } catch {
      setTone("neutral")
      setMessage(NEUTRAL_RESET_MESSAGE)
      setLeft(RESEND_COOLDOWN_SECONDS)
    } finally {
      setPending(false)
    }
  }

  const alert = tone !== "neutral"

  return (
    <form onSubmit={onSubmit} className="mt-6 space-y-4">
      <div className="space-y-2">
        <Label htmlFor="email">E-mail</Label>
        <Input
          id="email"
          name="email"
          type="email"
          autoComplete="email"
          inputMode="email"
          required
          disabled={pending || left > 0}
        />
      </div>
      {message ? (
        <p
          className={
            alert
              ? "rounded-xl bg-rose-50 px-3 py-2 text-sm text-rose-800"
              : "rounded-xl bg-[#F4ECFB] px-3 py-2 text-sm text-ink"
          }
          role="status"
        >
          {message}
        </p>
      ) : null}
      <Button type="submit" className="w-full" disabled={pending || left > 0}>
        {pending ? "Enviando…" : left > 0 ? `Espere ${left}s` : "Enviar link"}
      </Button>
    </form>
  )
}
