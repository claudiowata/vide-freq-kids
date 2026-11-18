import { describe, expect, it } from "vitest"
import {
  canManageCell,
  canManageNetwork,
  canReassignBetween,
  leaderFitsCell,
  validateMultiplication,
  type MultiplicationDraft,
} from "./cell-multiplication"
import type { CellNode, PersonNode } from "./tree-access"

const ana: PersonNode = { id: "ana", role: "discipulador", supervisorId: null }
const bruno: PersonNode = { id: "bruno", role: "lider", supervisorId: "ana" }
const clara: PersonNode = { id: "clara", role: "lider", supervisorId: "ana" }
const diana: PersonNode = { id: "diana", role: "discipulador", supervisorId: null }
const edu: PersonNode = { id: "edu", role: "lider", supervisorId: "diana" }
const olga: PersonNode = { id: "olga", role: "pastor", supervisorId: null }
const people: PersonNode[] = [
  olga,
  { ...ana, supervisorId: "olga" },
  bruno,
  clara,
  diana,
  edu,
]

const cellBruno: CellNode = {
  id: "celula-bruno",
  leaderId: "bruno",
  discipuladorId: "ana",
  pastorId: null,
}
const cellClara: CellNode = {
  id: "celula-clara",
  leaderId: "clara",
  discipuladorId: "ana",
  pastorId: null,
}
const cellEdu: CellNode = {
  id: "celula-edu",
  leaderId: "edu",
  discipuladorId: "diana",
  pastorId: null,
}

const draft = (patch: Partial<MultiplicationDraft> = {}): MultiplicationDraft => ({
  name: "Célula Nova",
  cellType: "mista_juvenis",
  leaderId: "clara",
  weekday: 3,
  meetingTime: "19:30",
  address: "Rua Nova, 10",
  multipliedOn: "2026-07-01",
  childIds: ["lia"],
  sourceChildIds: ["lia", "caio"],
  ...patch,
})

describe("quem pode multiplicar e remanejar", () => {
  it("só discipuladora e quem está acima, e só na própria subárvore", () => {
    expect(canManageNetwork("discipulador")).toBe(true)
    expect(canManageNetwork("pastor")).toBe(true)
    expect(canManageNetwork("lider")).toBe(false)
    expect(canManageCell(people, "ana", cellBruno)).toBe(true)
    expect(canManageCell(people, "olga", cellBruno)).toBe(true)
    expect(canManageCell(people, "bruno", cellBruno)).toBe(false)
    expect(canManageCell(people, "diana", cellBruno)).toBe(false)
    expect(canManageCell(people, "ana", cellEdu)).toBe(false)
  })

  it("o líder da célula nova precisa responder à mesma discipuladora", () => {
    expect(leaderFitsCell(people, "clara", "ana")).toBe(true)
    expect(leaderFitsCell(people, "edu", "ana")).toBe(false)
    expect(leaderFitsCell(people, "ana", "ana")).toBe(false)
  })

  it("o remanejamento exige as duas células na mesma árvore de quem manda", () => {
    expect(canReassignBetween(people, "ana", cellBruno, cellClara)).toBe(true)
    expect(canReassignBetween(people, "olga", cellBruno, cellClara)).toBe(true)
    expect(canReassignBetween(people, "bruno", cellBruno, cellClara)).toBe(false)
    expect(canReassignBetween(people, "diana", cellBruno, cellEdu)).toBe(false)
    expect(canReassignBetween(people, "ana", cellBruno, cellEdu)).toBe(false)
    expect(canReassignBetween(people, "ana", cellBruno, cellBruno)).toBe(false)
  })
})

describe("dados da célula nova", () => {
  it("aceita C Mista J e uma lista de crianças da origem", () => {
    expect(validateMultiplication(draft())).toBeNull()
    expect(validateMultiplication(draft({ childIds: [] }))).toBeNull()
  })

  it("recusa tipo, horário, endereço e criança de outra célula", () => {
    expect(validateMultiplication(draft({ cellType: "mista" }))).toMatch(/Mista com Juvenis/)
    expect(validateMultiplication(draft({ meetingTime: "19h" }))).toMatch(/horário/)
    expect(validateMultiplication(draft({ address: "a" }))).toMatch(/endereço/)
    expect(validateMultiplication(draft({ childIds: ["de-outra"] }))).toMatch(/não está na célula/)
    expect(validateMultiplication(draft({ name: " " }))).toMatch(/nome/)
  })
})
