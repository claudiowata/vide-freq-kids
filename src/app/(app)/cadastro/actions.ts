"use server"

import { redirect } from "next/navigation"
import { validateMultiplication } from "@/domain/cell-multiplication"
import { createClient } from "@/lib/supabase/server"

export interface FormState {
  error: string | null
}

function readable(message: string): string {
  const text = message.replace(/^.*ERROR:\s*/i, "").trim()
  return text || "Não foi possível concluir. Tente de novo."
}

export async function multiplyCell(_state: FormState, formData: FormData): Promise<FormState> {
  const childIds = formData.getAll("crianca").map((value) => String(value))
  const draft = {
    name: String(formData.get("nome") ?? ""),
    cellType: String(formData.get("tipo") ?? ""),
    leaderId: String(formData.get("lider") ?? ""),
    weekday: formData.get("dia") === null || formData.get("dia") === "" ? null : Number(formData.get("dia")),
    meetingTime: String(formData.get("horario") ?? ""),
    address: String(formData.get("endereco") ?? ""),
    multipliedOn: String(formData.get("data") ?? ""),
    childIds,
    sourceChildIds: childIds,
  }
  const invalid = validateMultiplication(draft)
  if (invalid) return { error: invalid }
  if (!draft.leaderId) return { error: "Escolha o líder da célula nova." }

  const origem = String(formData.get("origem") ?? "")
  if (!origem) return { error: "Escolha a célula de origem." }

  const supabase = await createClient()
  const { error } = await supabase.rpc("multiplicar_celula", {
    p_origem: origem,
    p_nome: draft.name.trim(),
    p_tipo: draft.cellType,
    p_lider: draft.leaderId,
    p_dia: draft.weekday,
    p_horario: draft.meetingTime,
    p_endereco: draft.address.trim(),
    p_data: draft.multipliedOn,
    p_criancas: childIds,
  })
  if (error) return { error: readable(error.message) }
  redirect("/cadastro?aviso=multiplicada")
}

export async function reassignChildren(
  _state: FormState,
  formData: FormData,
): Promise<FormState> {
  const childIds = formData.getAll("crianca").map((value) => String(value))
  const destino = String(formData.get("destino") ?? "")
  const origem = String(formData.get("origem") ?? "")
  if (!origem || !destino) return { error: "Escolha as duas células." }
  if (origem === destino) return { error: "Escolha outra célula de destino." }
  if (childIds.length === 0) return { error: "Escolha ao menos uma criança." }

  const supabase = await createClient()
  const { error } = await supabase.rpc("remanejar_criancas", {
    p_criancas: childIds,
    p_destino: destino,
  })
  if (error) return { error: readable(error.message) }
  redirect("/cadastro?aviso=remanejada")
}
