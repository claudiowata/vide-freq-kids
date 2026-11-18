"use server"

import { redirect } from "next/navigation"
import { createClient } from "@/lib/supabase/server"

export interface FormState {
  error: string | null
}

export async function closeMonth(_state: FormState, formData: FormData): Promise<FormState> {
  const year = Number(formData.get("ano"))
  const month = Number(formData.get("mes"))
  if (!Number.isInteger(year) || !Number.isInteger(month) || month < 1 || month > 12) {
    return { error: "Informe um mês válido." }
  }
  const supabase = await createClient()
  const { error } = await supabase.rpc("fechar_status_do_mes", { p_ano: year, p_mes: month })
  if (error) {
    const text = error.message.replace(/^.*ERROR:\s*/i, "").trim()
    return { error: text || "Não foi possível fechar o mês." }
  }
  redirect("/fechamento?aviso=fechado")
}
