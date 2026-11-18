import { describe, expect, it } from "vitest"
import { canSeeCell, canSeePerson, type CellNode, type PersonNode } from "./tree-access"

const ana: PersonNode = { id: "ana", role: "discipulador", supervisorId: null }
const bruno: PersonNode = { id: "bruno", role: "lider", supervisorId: "ana" }
const clara: PersonNode = { id: "clara", role: "lider", supervisorId: "ana" }
const diana: PersonNode = { id: "diana", role: "discipulador", supervisorId: null }
const edu: PersonNode = { id: "edu", role: "lider", supervisorId: "diana" }

const withoutPastor: PersonNode[] = [ana, bruno, clara, diana, edu]

const cellBruno: CellNode = {
  id: "celula-bruno",
  leaderId: "bruno",
  discipuladorId: "ana",
  pastorId: null,
}
const cellEdu: CellNode = {
  id: "celula-edu",
  leaderId: "edu",
  discipuladorId: "diana",
  pastorId: null,
}

describe("árvore sem pastora", () => {
  it("a discipuladora raiz vê a própria árvore e não a da outra raiz", () => {
    expect(canSeePerson(withoutPastor, "ana", "ana")).toBe(true)
    expect(canSeePerson(withoutPastor, "ana", "bruno")).toBe(true)
    expect(canSeePerson(withoutPastor, "ana", "clara")).toBe(true)
    expect(canSeePerson(withoutPastor, "ana", "diana")).toBe(false)
    expect(canSeePerson(withoutPastor, "ana", "edu")).toBe(false)
    expect(canSeeCell(withoutPastor, "ana", cellBruno)).toBe(true)
    expect(canSeeCell(withoutPastor, "ana", cellEdu)).toBe(false)
  })

  it("o líder vê a si e a discipuladora, e não vê o líder irmão", () => {
    expect(canSeePerson(withoutPastor, "bruno", "bruno")).toBe(true)
    expect(canSeePerson(withoutPastor, "bruno", "ana")).toBe(true)
    expect(canSeePerson(withoutPastor, "bruno", "clara")).toBe(false)
    expect(canSeePerson(withoutPastor, "bruno", "diana")).toBe(false)
    expect(canSeeCell(withoutPastor, "bruno", cellBruno)).toBe(true)
    expect(canSeeCell(withoutPastor, "bruno", cellEdu)).toBe(false)
  })

  it("célula com pastor_id nulo continua visível para quem está na árvore", () => {
    expect(cellBruno.pastorId).toBeNull()
    expect(canSeeCell(withoutPastor, "ana", cellBruno)).toBe(true)
    expect(canSeeCell(withoutPastor, "bruno", cellBruno)).toBe(true)
    expect(withoutPastor.some((person) => person.role === "pastor")).toBe(false)
  })
})

describe("pastora ligada depois, sem reescrever a célula", () => {
  const olga: PersonNode = { id: "olga", role: "pastor", supervisorId: null }
  const linked: PersonNode[] = [
    olga,
    { ...ana, supervisorId: "olga" },
    bruno,
    clara,
    diana,
    edu,
  ]

  it("a pastora passa a ver a árvore da discipuladora com a célula ainda sem pastor_id", () => {
    expect(cellBruno.pastorId).toBeNull()
    expect(canSeePerson(linked, "olga", "ana")).toBe(true)
    expect(canSeePerson(linked, "olga", "bruno")).toBe(true)
    expect(canSeeCell(linked, "olga", cellBruno)).toBe(true)
    expect(canSeePerson(linked, "olga", "diana")).toBe(false)
    expect(canSeeCell(linked, "olga", cellEdu)).toBe(false)
  })

  it("o líder passa a ver a pastora, e a outra raiz continua isolada", () => {
    expect(canSeePerson(linked, "bruno", "olga")).toBe(true)
    expect(canSeePerson(linked, "diana", "olga")).toBe(false)
    expect(canSeeCell(linked, "diana", cellBruno)).toBe(false)
  })

  it("um atalho pastor_id na célula também revela a célula, sem exigir o vínculo das pessoas", () => {
    const onlyOnTheCell: CellNode = { ...cellBruno, pastorId: "olga" }
    expect(canSeeCell([...withoutPastor, olga], "olga", onlyOnTheCell)).toBe(true)
    expect(canSeeCell([...withoutPastor, olga], "olga", cellEdu)).toBe(false)
  })
})
