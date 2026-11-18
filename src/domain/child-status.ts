/**
 * Regra de visitante/membro da Célula Kids e Juvenis.
 *
 * Espelha `internal.recompute_child_status` na migração. Se um lado mudar,
 * o outro e os testes precisam mudar junto.
 *
 * - Toda criança começa visitante.
 * - 4 presenças consecutivas em encontros de célula tornam a criança membro.
 * - 4 ausências consecutivas em encontros de célula devolvem o membro a visitante.
 * - Presença zera a sequência de ausências; ausência zera a de presenças.
 * - Culto não entra na conta.
 * - Linha ausente não é ausência: só conta o que foi registrado.
 * - A primeira visita é a data da primeira presença e não muda depois.
 */

export const PRESENCES_TO_BECOME_MEMBER = 4
export const ABSENCES_TO_RETURN_TO_VISITOR = 4

export type ChildStatus = "visitante" | "membro"
export type MeetingKind = "celula" | "culto"

export interface StatusSnapshot {
  status: ChildStatus
  presenceStreak: number
  absenceStreak: number
  firstVisitOn: string | null
}

export interface StatusChange {
  from: ChildStatus
  to: ChildStatus
  on: string
  reason: "quatro_presencas_consecutivas" | "quatro_ausencias_consecutivas"
}

export interface AttendanceMark {
  meetingDate: string
  present: boolean
  kind?: MeetingKind
  /** Desempate no mesmo dia, na ordem de gravação. */
  sequence?: number
}

export function initialStatus(): StatusSnapshot {
  return {
    status: "visitante",
    presenceStreak: 0,
    absenceStreak: 0,
    firstVisitOn: null,
  }
}

export function replayAttendance(marks: AttendanceMark[]): {
  snapshot: StatusSnapshot
  history: StatusChange[]
} {
  const ordered = [...marks].sort((a, b) => {
    if (a.meetingDate !== b.meetingDate) {
      return a.meetingDate < b.meetingDate ? -1 : 1
    }
    return (a.sequence ?? 0) - (b.sequence ?? 0)
  })

  const snapshot = initialStatus()
  const history: StatusChange[] = []

  for (const mark of ordered) {
    if ((mark.kind ?? "celula") !== "celula") continue

    const previous = snapshot.status
    if (mark.present) {
      if (!snapshot.firstVisitOn) snapshot.firstVisitOn = mark.meetingDate
      snapshot.presenceStreak += 1
      snapshot.absenceStreak = 0
      if (
        snapshot.status === "visitante" &&
        snapshot.presenceStreak >= PRESENCES_TO_BECOME_MEMBER
      ) {
        snapshot.status = "membro"
      }
    } else {
      snapshot.presenceStreak = 0
      snapshot.absenceStreak += 1
      if (
        snapshot.status === "membro" &&
        snapshot.absenceStreak >= ABSENCES_TO_RETURN_TO_VISITOR
      ) {
        snapshot.status = "visitante"
      }
    }

    if (snapshot.status !== previous) {
      history.push({
        from: previous,
        to: snapshot.status,
        on: mark.meetingDate,
        reason:
          snapshot.status === "membro"
            ? "quatro_presencas_consecutivas"
            : "quatro_ausencias_consecutivas",
      })
    }
  }

  return { snapshot, history }
}
