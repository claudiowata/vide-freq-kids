"use server"

import { redirect } from "next/navigation"
import type { AttendanceChoice } from "@/domain/child-status"
import { createClient } from "@/lib/supabase/server"

export interface FormState {
  error: string | null
}

const CHOICES = new Set<AttendanceChoice>(["presente", "falta", "outro_responsavel"])

function readable(message: string): string {
  const text = message.replace(/^.*ERROR:\s*/i, "").trim()
  return text || "Não foi possível salvar a chamada."
}

export async function saveCall(_state: FormState, formData: FormData): Promise<FormState> {
  const cellId = String(formData.get("cellId") ?? "")
  const date = String(formData.get("date") ?? "")
  if (!cellId) return { error: "Escolha a célula." }
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) return { error: "Informe a data da célula." }

  const marks: { childId: string; choice: AttendanceChoice }[] = []
  for (const [key, value] of formData.entries()) {
    if (!key.startsWith("mark:")) continue
    const choice = String(value)
    if (!CHOICES.has(choice as AttendanceChoice)) return { error: "Marca de chamada inválida." }
    marks.push({ childId: key.slice("mark:".length), choice: choice as AttendanceChoice })
  }
  if (marks.length === 0) return { error: "Marque ao menos uma criança." }

  const supabase = await createClient()
  const { data: children, error: childrenError } = await supabase
    .from("children")
    .select("id, guarda_compartilhada")
    .eq("cell_id", cellId)
  if (childrenError) return { error: readable(childrenError.message) }

  const shared = new Map((children ?? []).map((child) => [child.id, child.guarda_compartilhada === true]))
  for (const mark of marks) {
    if (!shared.has(mark.childId)) return { error: "Há criança que não está nesta célula." }
    if (mark.choice === "outro_responsavel" && !shared.get(mark.childId)) {
      return { error: "Semana com o outro responsável só vale com guarda compartilhada." }
    }
  }

  const existing = await supabase
    .from("meetings")
    .select("id")
    .eq("cell_id", cellId)
    .eq("held_on", date)
    .eq("kind", "celula")
    .maybeSingle()
  if (existing.error) return { error: readable(existing.error.message) }

  let meetingId = existing.data?.id
  if (!meetingId) {
    const created = await supabase
      .from("meetings")
      .insert({ cell_id: cellId, held_on: date, kind: "celula" })
      .select("id")
      .single()
    if (created.error || !created.data) return { error: readable(created.error?.message ?? "") }
    meetingId = created.data.id
  }

  const rows = marks.map((mark) => ({
    meeting_id: meetingId,
    child_id: mark.childId,
    present: mark.choice === "presente",
    outro_responsavel: mark.choice === "outro_responsavel",
  }))
  const saved = await supabase.from("attendance").upsert(rows, { onConflict: "meeting_id,child_id" })
  if (saved.error) return { error: readable(saved.error.message) }
  redirect("/frequencia?aviso=salva")
}
