"use server"

import { redirect } from "next/navigation"
import { createLeadershipAccount } from "@/lib/accounts"
import { getSecretSupabaseKey } from "@/lib/env"
import { createClient } from "@/lib/supabase/server"

export interface FormState {
  error: string | null
}

export async function bootstrapRoot(
  _state: FormState,
  formData: FormData,
): Promise<FormState> {
  const fullName = String(formData.get("fullName") ?? "").trim()
  const email = String(formData.get("email") ?? "").trim().toLowerCase()
  const password = String(formData.get("password") ?? "")
  const confirm = String(formData.get("confirm") ?? "")

  if (fullName.length < 3) return { error: "Informe o nome completo." }
  if (!email.includes("@")) return { error: "Informe um e-mail válido." }
  if (password.length < 8) return { error: "A senha precisa ter pelo menos 8 caracteres." }
  if (password !== confirm) return { error: "A confirmação da senha não confere." }
  if (!getSecretSupabaseKey()) {
    return {
      error:
        "Falta SUPABASE_SECRET_KEY no servidor. Sem a chave secreta o primeiro acesso não cria a conta.",
    }
  }

  const supabase = await createClient()
  const { data: needs, error: needsError } = await supabase.rpc("needs_initial_setup")
  if (needsError) return { error: "Não foi possível verificar se a rede está vazia." }
  if (needs !== true) {
    return { error: "A rede já tem uma conta. Entre com o e-mail da liderança." }
  }

  try {
    await createLeadershipAccount({
      fullName,
      email,
      password,
      role: "discipulador",
      supervisorId: null,
      isAdmin: true,
      mustChangePassword: false,
    })
  } catch (error) {
    const message = error instanceof Error ? error.message : ""
    if (/duplicate|unique|already|profiles_one_admin_root/i.test(message)) {
      return { error: "A rede já foi configurada. Entre com o e-mail da discipuladora." }
    }
    return { error: "Não foi possível criar a primeira conta. Tente de novo em instantes." }
  }

  const { error: signInError } = await supabase.auth.signInWithPassword({ email, password })
  if (signInError) {
    redirect("/login")
  }
  redirect("/")
}
