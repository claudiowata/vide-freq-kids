"use server"

import { redirect } from "next/navigation"
import { createClient } from "@/lib/supabase/server"

export interface FormState {
  error: string | null
}

export async function signIn(_state: FormState, formData: FormData): Promise<FormState> {
  const email = String(formData.get("email") ?? "").trim().toLowerCase()
  const password = String(formData.get("password") ?? "")

  if (!email || !password) {
    return { error: "Preencha o e-mail e a senha." }
  }

  const supabase = await createClient()
  const { error } = await supabase.auth.signInWithPassword({ email, password })
  if (error) {
    return { error: "E-mail ou senha não conferem." }
  }

  redirect("/")
}
