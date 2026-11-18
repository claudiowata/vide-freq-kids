import { isCellType } from "@/domain/cell-type"
import {
  canSeeCell,
  subjectInDownwardTree,
  type CellNode,
  type PersonNode,
  type Role,
} from "@/domain/tree-access"

export const WEEKDAYS = [
  { value: 0, label: "Domingo" },
  { value: 1, label: "Segunda" },
  { value: 2, label: "Terça" },
  { value: 3, label: "Quarta" },
  { value: 4, label: "Quinta" },
  { value: 5, label: "Sexta" },
  { value: 6, label: "Sábado" },
] as const

const DATE = /^\d{4}-\d{2}-\d{2}$/
const TIME = /^([01]\d|2[0-3]):[0-5]\d(?::[0-5]\d)?$/

export function canManageNetwork(role: Role): boolean {
  return role === "pastor" || role === "discipulador"
}

/** Espelha `internal.can_write_cell_row`: discipuladora da célula, ou alguém acima, na própria árvore. */
export function canManageCell(
  people: PersonNode[],
  viewerId: string,
  cell: CellNode,
): boolean {
  const viewer = people.find((person) => person.id === viewerId)
  if (!viewer || !canManageNetwork(viewer.role)) return false
  if (cell.discipuladorId === viewerId) return true
  if (cell.pastorId !== null && cell.pastorId === viewerId) return true
  return (
    viewerId !== cell.discipuladorId &&
    subjectInDownwardTree(people, viewerId, cell.discipuladorId)
  )
}

export function leaderFitsCell(
  people: PersonNode[],
  leaderId: string,
  discipuladorId: string,
): boolean {
  const leader = people.find((person) => person.id === leaderId)
  return leader?.role === "lider" && leader.supervisorId === discipuladorId
}

export function canReassignBetween(
  people: PersonNode[],
  viewerId: string,
  from: CellNode,
  to: CellNode,
): boolean {
  if (from.id === to.id) return false
  if (!canSeeCell(people, viewerId, from) || !canSeeCell(people, viewerId, to)) return false
  return canManageCell(people, viewerId, from) && canManageCell(people, viewerId, to)
}

export interface MultiplicationDraft {
  name: string
  cellType: string
  leaderId: string
  weekday: number | null
  meetingTime: string
  address: string
  multipliedOn: string
  childIds: string[]
  sourceChildIds: string[]
}

export function validateMultiplication(draft: MultiplicationDraft): string | null {
  if (draft.name.trim().length < 2) return "Informe o nome da célula nova."
  if (!isCellType(draft.cellType)) return "Escolha o tipo: Kids, Juvenis ou Mista com Juvenis."
  if (!draft.leaderId) return "Escolha o líder da célula nova."
  if (
    draft.weekday === null ||
    !Number.isInteger(draft.weekday) ||
    draft.weekday < 0 ||
    draft.weekday > 6
  ) {
    return "Escolha o dia da célula."
  }
  if (!TIME.test(draft.meetingTime)) return "Informe o horário da célula."
  if (draft.address.trim().length < 3) return "Informe o endereço."
  if (!DATE.test(draft.multipliedOn)) return "Informe a data da multiplicação."
  const source = new Set(draft.sourceChildIds)
  const seen = new Set<string>()
  for (const childId of draft.childIds) {
    if (seen.has(childId)) return "Há criança repetida na lista."
    seen.add(childId)
    if (!source.has(childId)) return "Há criança que não está na célula de origem."
  }
  return null
}

export function statusLabel(status: "membro" | "visitante"): string {
  return status === "membro" ? "Membro" : "Visitante"
}
