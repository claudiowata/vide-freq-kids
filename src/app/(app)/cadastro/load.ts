import { isCellType, type CellType } from "@/domain/cell-type"
import { createClient } from "@/lib/supabase/server"

export interface CellOption {
  id: string
  name: string
  cellType: CellType
  weekday: number | null
  meetingTime: string | null
  address: string | null
  leaderId: string
  discipuladorId: string
}

export interface LeaderOption {
  id: string
  fullName: string
  supervisorId: string | null
}

export interface ChildOption {
  id: string
  cellId: string
  fullName: string
  status: "membro" | "visitante"
  presenceStreak: number
  absenceStreak: number
  motherConverted: boolean | null
  fatherConverted: boolean | null
  guardians: string | null
  sharedCustody: boolean
}

export interface TransferRow {
  id: string
  childName: string
  fromName: string
  toName: string
  transferredOn: string
}

function timeLabel(value: string | null): string | null {
  if (!value) return null
  return value.slice(0, 5)
}

export async function loadCadastro() {
  const supabase = await createClient()
  const [cellsResult, leadersResult, childrenResult, transfersResult] = await Promise.all([
    supabase
      .from("cells")
      .select("id, name, cell_type, weekday, meeting_time, address, leader_id, discipulador_id")
      .order("name"),
    supabase.from("profiles").select("id, full_name, supervisor_id").eq("role", "lider").order("full_name"),
    supabase
      .from("children")
      .select(
        "id, cell_id, full_name, status, presence_streak, absence_streak, mae_convertida, pai_convertido, guardians, guarda_compartilhada",
      )
      .order("full_name"),
    supabase
      .from("child_transfers")
      .select("id, child_id, from_cell_id, to_cell_id, transferred_on")
      .order("transferred_on", { ascending: false })
      .limit(8),
  ])

  const cells: CellOption[] = (cellsResult.data ?? []).flatMap((row) => {
    if (!isCellType(row.cell_type)) return []
    return [
      {
        id: row.id,
        name: row.name?.trim() || "Célula sem nome",
        cellType: row.cell_type,
        weekday: row.weekday,
        meetingTime: timeLabel(row.meeting_time),
        address: row.address,
        leaderId: row.leader_id,
        discipuladorId: row.discipulador_id,
      },
    ]
  })

  const leaders: LeaderOption[] = (leadersResult.data ?? []).map((row) => ({
    id: row.id,
    fullName: row.full_name,
    supervisorId: row.supervisor_id,
  }))

  const children: ChildOption[] = (childrenResult.data ?? []).flatMap((row) => {
    if (row.status !== "membro" && row.status !== "visitante") return []
    return [
      {
        id: row.id,
        cellId: row.cell_id,
        fullName: row.full_name,
        status: row.status,
        presenceStreak: row.presence_streak,
        absenceStreak: row.absence_streak,
        motherConverted: row.mae_convertida,
        fatherConverted: row.pai_convertido,
        guardians: row.guardians,
        sharedCustody: row.guarda_compartilhada === true,
      },
    ]
  })

  const names = new Map(cells.map((cell) => [cell.id, cell.name]))
  const childNames = new Map(children.map((child) => [child.id, child.fullName]))
  const transfers: TransferRow[] = (transfersResult.error ? [] : (transfersResult.data ?? [])).map(
    (row) => ({
      id: row.id,
      childName: childNames.get(row.child_id) ?? "Criança",
      fromName: names.get(row.from_cell_id) ?? "Célula de origem",
      toName: names.get(row.to_cell_id) ?? "Célula de destino",
      transferredOn: row.transferred_on,
    }),
  )

  return {
    cells,
    leaders,
    children,
    transfers,
    cellsError: cellsResult.error?.message ?? null,
    migrationPending: Boolean(transfersResult.error),
  }
}
