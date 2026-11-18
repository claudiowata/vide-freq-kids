export const CELL_TYPES = ["kids", "juvenis", "mista_juvenis"] as const

export type CellType = (typeof CELL_TYPES)[number]

export const CELL_TYPE_LABELS: Record<CellType, string> = {
  kids: "Kids",
  juvenis: "Juvenis",
  mista_juvenis: "Mista com Juvenis (C Mista J)",
}

export function isCellType(value: string): value is CellType {
  return (CELL_TYPES as readonly string[]).includes(value)
}
