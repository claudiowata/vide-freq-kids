/**
 * Indicadores do fim da linha na planilha de acompanhamento.
 * Espelha as colunas geradas de `monthly_reports`:
 * M = membersAverage, % = attendancePercent, V = visitorsAverage.
 * Semanas sem número (null) ficam de fora da média.
 * Semana só com "outro responsável" também fica de fora: não é falta.
 */

import type { AttendanceChoice, ChildStatus } from "@/domain/child-status"

export interface WeekCounts {
  members: number | null
  visitors: number | null
}

export interface MonthlyIndicators {
  membersAverage: number | null
  attendancePercent: number | null
  visitorsAverage: number | null
}

function roundAverage(values: Array<number | null | undefined>): number | null {
  const present = values.filter((value): value is number => value !== null && value !== undefined)
  if (present.length === 0) return null
  const mean = present.reduce((sum, value) => sum + value, 0) / present.length
  return Math.round(mean)
}

export function membersAverage(weeks: WeekCounts[]): number | null {
  return roundAverage(weeks.map((week) => week.members))
}

export function visitorsAverage(weeks: WeekCounts[]): number | null {
  return roundAverage(weeks.map((week) => week.visitors))
}

/** Percentual da média de membros sobre o total de membros da célula. */
export function attendancePercent(
  averageMembers: number | null,
  memberCount: number,
): number | null {
  if (averageMembers === null || memberCount <= 0) return null
  return Math.round((averageMembers / memberCount) * 100)
}

export function monthlyIndicators(weeks: WeekCounts[], memberCount: number): MonthlyIndicators {
  const average = membersAverage(weeks)
  return {
    membersAverage: average,
    attendancePercent: attendancePercent(average, memberCount),
    visitorsAverage: visitorsAverage(weeks),
  }
}

export interface CallMark {
  status: ChildStatus
  choice: AttendanceChoice
}

/**
 * Conta presentes da semana para M e V.
 * "Outro responsável" sai da conta. Se a semana só tem essa marca, devolve null
 * para a média ignorá-la. Falta de membro entra como semana preenchida com zero
 * naquele nome, e por isso abaixa M.
 */
export function weekCountsFromCall(marks: CallMark[]): WeekCounts | null {
  const counted = marks.filter((mark) => mark.choice !== "outro_responsavel")
  if (counted.length === 0) return null
  return {
    members: counted.filter((mark) => mark.status === "membro" && mark.choice === "presente")
      .length,
    visitors: counted.filter((mark) => mark.status === "visitante" && mark.choice === "presente")
      .length,
  }
}

export function countConvertedParents(
  children: Array<{ maeConvertida: boolean; paiConvertido: boolean }>,
): { mothers: number; fathers: number } {
  return {
    mothers: children.filter((child) => child.maeConvertida).length,
    fathers: children.filter((child) => child.paiConvertido).length,
  }
}
