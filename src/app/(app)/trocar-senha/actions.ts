"use server"

import { redirect } from "next/navigation"
import { createAdminClient } from "@/lib/supabase/admin"
import { createClient } from "@/lib/supabase/server"

export interface FormState {
  error: string | null
}

export async function changePassword(
  _state: FormState,
  formData: FormData,
): Promise<FormState> {
  const password = String(formData.get("password") ?? "")
  const confirm = String(formData.get("confirm") ?? "")
  if (password.length < 8) return { error: "A senha precisa ter pelo menos 8 caracteres." }
  if (password !== confirm) return { error: "A confirmação não confere." }

  const supabase = await createClient()
  const {
    data: { user },
  } = await supabase.auth.getUser()
  if (!user) redirect("/login")

  const { error } = await supabase.auth.updateUser({ password })
  if (error) return { error: "Não foi possível trocar a senha. Tente outra." }

  const admin = createAdminClient()
  const appMetadata = {
    ...(user.app_metadata ?? {}),
    must_change_password: false,
  }
  const { error: metaError } = await admin.auth.admin.updateUserById(user.id, {
    app_metadata: appMetadata,
  })
  if (metaError) return { error: "A senha mudou, mas a liberação do acesso falhou." }

  await admin.from("profiles").update({ must_change_password: false }).eq("id", user.id)
  await supabase.auth.refreshSession()
  redirect("/")
}
