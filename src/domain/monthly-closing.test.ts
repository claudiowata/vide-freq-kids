import { describe, expect, it } from "vitest"
import {
  attendancePercent,
  countConvertedParents,
  membersAverage,
  monthlyIndicators,
  type WeekCounts,
  weekCountsFromCall,
} from "./monthly-closing"

const june = [
  { members: 10, visitors: 2 },
  { members: 8, visitors: 1 },
  { members: 11, visitors: 0 },
  { members: 9, visitors: 2 },
  { members: 10, visitors: 1 },
]

describe("fechamento mensal", () => {
  it("calcula M, % e V a partir das semanas", () => {
    expect(monthlyIndicators(june, 12)).toEqual({
      membersAverage: 10,
      attendancePercent: 83,
      visitorsAverage: 1,
    })
  })

  it("ignora semanas vazias e não divide por zero", () => {
    const partial = [
      { members: 4, visitors: null },
      { members: null, visitors: 3 },
      { members: 6, visitors: 1 },
    ]
    expect(monthlyIndicators(partial, 0)).toEqual({
      membersAverage: 5,
      attendancePercent: null,
      visitorsAverage: 2,
    })
    expect(attendancePercent(null, 10)).toBeNull()
  })

  it("não conta a semana do outro responsável como falta", () => {
    const neutral = weekCountsFromCall([
      { status: "membro", choice: "outro_responsavel" },
      { status: "visitante", choice: "outro_responsavel" },
    ])
    const absence = weekCountsFromCall([
      { status: "membro", choice: "falta" },
      { status: "membro", choice: "falta" },
    ])
    const mixed = weekCountsFromCall([
      { status: "membro", choice: "presente" },
      { status: "membro", choice: "outro_responsavel" },
      { status: "visitante", choice: "presente" },
    ])
    expect(neutral).toBeNull()
    expect(absence).toEqual({ members: 0, visitors: 0 })
    expect(mixed).toEqual({ members: 1, visitors: 1 })
    const withNeutral = [
      { members: 2, visitors: 0 },
      neutral,
      { members: 2, visitors: 0 },
    ].filter((week): week is WeekCounts => week !== null)
    expect(membersAverage(withNeutral)).toBe(2)
    expect(
      membersAverage([
        { members: 2, visitors: 0 },
        absence ?? { members: 0, visitors: 0 },
        { members: 2, visitors: 0 },
      ]),
    ).toBe(1)
  })

  it("soma mães e pais convertidos das crianças, não do mês", () => {
    expect(
      countConvertedParents([
        { maeConvertida: true, paiConvertido: true },
        { maeConvertida: true, paiConvertido: false },
        { maeConvertida: false, paiConvertido: false },
      ]),
    ).toEqual({ mothers: 2, fathers: 1 })
  })
})
