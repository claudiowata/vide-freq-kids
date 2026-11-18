import { describe, expect, it } from "vitest"
import {
  attendancePercent,
  countConvertedParents,
  monthlyIndicators,
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
