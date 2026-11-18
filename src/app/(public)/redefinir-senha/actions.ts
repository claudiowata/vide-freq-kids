"use server"

import { cookies } from "next/headers"
import { redirect } from "next/navigation"
import { validateNewPassword } from "@/domain/password-reset"
import { RECOVERY_COOKIE, recoveryCookieOptions } from "@/lib/recovery-cookie"
import { createAdminClient } from "@/lib/supabase/admin"
import { createClient } from "@/lib/supabase/server"

export interface FormState {
  error: string | null
}

export async function resetPassword(
  _state: FormState,
  formData: FormData,
): Promise<FormState> {
  const password = String(formData.get("password") ?? "")
  const confirm = String(formData.get("confirm") ?? "")
  const invalid = validateNewPassword(password, confirm)
  if (invalid) return { error: invalid }

  const jar = await cookies()
  if (jar.get(RECOVERY_COOKIE)?.value !== "1") {
    redirect("/esqueci-senha?aviso=sessao")
  }

  const supabase = await createClient()
  const {
    data: { user },
  } = await supabase.auth.getUser()
  if (!user) redirect("/esqueci-senha?aviso=sessao")

  const { error } = await supabase.auth.updateUser({ password })
  if (error) {
    if (error.code === "weak_password") {
      return { error: "Escolha uma senha mais forte, com pelo menos 8 caracteres." }
    }
    return { error: "Não foi possível salvar a senha. Tente outra." }
  }

  const mustChange = user.app_metadata?.must_change_password === true
  try {
    const admin = createAdminClient()
    if (mustChange) {
      const appMetadata = {
        ...(user.app_metadata ?? {}),
        must_change_password: false,
      }
      const { error: metaError } = await admin.auth.admin.updateUserById(user.id, {
        app_metadata: appMetadata,
      })
      if (metaError) return { error: "A senha mudou, mas a liberação do acesso falhou." }
    }
    await admin.from("profiles").update({ must_change_password: false }).eq("id", user.id)
  } catch {
    if (mustChange) return { error: "A senha mudou, mas a liberação do acesso falhou." }
  }

  await supabase.auth.refreshSession()
  jar.set(RECOVERY_COOKIE, "", recoveryCookieOptions(0))
  redirect("/?aviso=senha-alterada")
}
