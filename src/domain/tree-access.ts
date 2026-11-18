/**
 * Quem enxerga quem na rede Radicais Kids.
 *
 * A pastora é opcional. A árvore é a cadeia `supervisorId`:
 * pastor(a) → discipulador(a) → líder. Uma discipuladora também pode
 * ficar abaixo de outra discipuladora. Quem está acima lê toda a
 * subárvore; o líder só a própria célula. Uma discipuladora com
 * supervisor nulo é raiz e a rede funciona sem nenhuma pastora.
 *
 * `pastorId` na célula é um atalho anulável. A visibilidade não
 * depende dele: quando uma pastora é ligada depois, basta apontar
 * o supervisor da discipuladora. As células não precisam ser reescritas.
 *
 * Espelha `internal.subject_in_downward_tree` e `internal.can_see_cell`.
 */

export type Role = "pastor" | "discipulador" | "lider"

export interface PersonNode {
  id: string
  role: Role
  supervisorId: string | null
}

export interface CellNode {
  id: string
  leaderId: string
  discipuladorId: string
  pastorId: string | null
}

const MAX_DEPTH = 8

export function subjectInDownwardTree(
  people: PersonNode[],
  viewerId: string | null,
  subjectId: string | null,
): boolean {
  if (!viewerId || !subjectId) return false
  const byId = new Map(people.map((person) => [person.id, person]))
  let current = byId.get(subjectId)
  let depth = 0
  while (current && depth < MAX_DEPTH) {
    if (current.id === viewerId) return true
    if (!current.supervisorId) return false
    current = byId.get(current.supervisorId)
    depth += 1
  }
  return false
}

export function canSeePerson(
  people: PersonNode[],
  viewerId: string,
  subjectId: string,
): boolean {
  if (subjectInDownwardTree(people, viewerId, subjectId)) return true
  return viewerId !== subjectId && subjectInDownwardTree(people, subjectId, viewerId)
}

export function canSeeCell(
  people: PersonNode[],
  viewerId: string,
  cell: CellNode,
): boolean {
  return (
    subjectInDownwardTree(people, viewerId, cell.leaderId) ||
    subjectInDownwardTree(people, viewerId, cell.discipuladorId) ||
    (cell.pastorId !== null && cell.pastorId === viewerId)
  )
}
