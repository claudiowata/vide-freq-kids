/**
 * Regra de visitante/membro da Célula Kids e Juvenis.
 *
 * Espelha `internal.recompute_child_status`. Se um lado mudar, o outro e os
 * testes precisam mudar junto.
 *
 * - Toda criança começa visitante.
 * - 4 presenças consecutivas em encontros de célula tornam a criança membro.
 * - 8 ausências consecutivas em encontros de célula devolvem o membro a visitante.
 * - O status gravado só muda na virada do mês. A sequência atravessa meses,
 *   mas presença lançada no mês aberto não altera o status.
 * - Presença zera a sequência de ausências; ausência zera a de presenças.
 * - "Semana com o outro responsável" é neutra: não é presença nem falta e não
 *   mexe nas sequências. Só existe para criança com guarda compartilhada.
 * - Culto não entra na conta.
 * - Linha ausente não é ausência: só conta o que foi registrado.
 * - A primeira visita é a data da primeira presença e não muda depois.
 */

export const PRESENCES_TO_BECOME_MEMBER = 4
export const ABSENCES_TO_RETURN_TO_VISITOR = 8

export type ChildStatus = "visitante" | "membro"
export type MeetingKind = "celula" | "culto"
export type AttendanceChoice = "presente" | "falta" | "outro_responsavel"

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
  reason: "quatro_presencas_consecutivas" | "oito_ausencias_consecutivas"
}

export interface AttendanceMark {
  meetingDate: string
  /** Mantido para marcas antigas. `choice` tem prioridade. */
  present?: boolean
  choice?: AttendanceChoice
  kind?: MeetingKind
  /** Desempate no mesmo dia, na ordem de gravação. */
  sequence?: number
}

export function attendanceChoice(mark: AttendanceMark): AttendanceChoice {
  if (mark.choice) return mark.choice
  return mark.present ? "presente" : "falta"
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
    const choice = attendanceChoice(mark)
    if (choice === "outro_responsavel") continue

    const previous = snapshot.status
    if (choice === "presente") {
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
            : "oito_ausencias_consecutivas",
      })
    }
  }

  return { snapshot, history }
}

export function endOfMonth(isoDate: string): string {
  const [year, month] = isoDate.split("-").map(Number)
  const last = new Date(Date.UTC(year, month, 0))
  return last.toISOString().slice(0, 10)
}

export function previousMonthEnd(isoDate: string): string {
  const [year, month] = isoDate.split("-").map(Number)
  const last = new Date(Date.UTC(year, month - 1, 0))
  return last.toISOString().slice(0, 10)
}

function nextMonthEnd(monthEnd: string): string {
  const [year, month] = monthEnd.split("-").map(Number)
  const last = new Date(Date.UTC(year, month + 1, 0))
  return last.toISOString().slice(0, 10)
}

/** Status oficial se o mês fosse fechado em `through`, olhando só a chamada até essa data. */
export function statusThrough(
  marks: AttendanceMark[],
  through: string,
): { status: ChildStatus; history: StatusChange[] } {
  const relevant = marks.filter(
    (mark) => mark.meetingDate <= through && (mark.kind ?? "celula") === "celula",
  )
  if (relevant.length === 0) return { status: "visitante", history: [] }

  const first = relevant.reduce((earliest, mark) =>
    mark.meetingDate < earliest ? mark.meetingDate : earliest,
  relevant[0].meetingDate)
  let status: ChildStatus = "visitante"
  const history: StatusChange[] = []
  for (let monthEnd = endOfMonth(first); monthEnd <= through; monthEnd = nextMonthEnd(monthEnd)) {
    const closed = replayAttendance(relevant.filter((mark) => mark.meetingDate <= monthEnd))
    if (closed.snapshot.status === status) continue
    history.push({
      from: status,
      to: closed.snapshot.status,
      on: monthEnd,
      reason:
        closed.snapshot.status === "membro"
          ? "quatro_presencas_consecutivas"
          : "oito_ausencias_consecutivas",
    })
    status = closed.snapshot.status
  }
  return { status, history }
}

/**
 * Fecha o status até `closeThrough` sem voltar um mês já avaliado.
 * Repetir a mesma data com os mesmos dados não gera outro histórico.
 * As sequências incluem o mês aberto; o status, não.
 */
export function closeStatus(input: {
  marks: AttendanceMark[]
  storedStatus: ChildStatus
  evaluatedThrough: string | null
  closeThrough: string
}): {
  status: ChildStatus
  evaluatedThrough: string
  presenceStreak: number
  absenceStreak: number
  history: StatusChange[]
} {
  const horizon =
    input.evaluatedThrough && input.evaluatedThrough > input.closeThrough
      ? input.evaluatedThrough
      : input.closeThrough
  const closed = statusThrough(input.marks, horizon)
  const live = replayAttendance(input.marks)
  return {
    status: closed.status,
    evaluatedThrough: horizon,
    presenceStreak: live.snapshot.presenceStreak,
    absenceStreak: live.snapshot.absenceStreak,
    history: closed.history,
  }
}

/** Efeito de lançar chamada hoje: fecha só o mês anterior, se ainda não foi. */
export function effectOfRecordingAttendance(input: {
  marks: AttendanceMark[]
  storedStatus: ChildStatus
  evaluatedThrough: string | null
  today: string
}): {
  status: ChildStatus
  evaluatedThrough: string
  presenceStreak: number
  absenceStreak: number
} {
  const cutoff = previousMonthEnd(input.today)
  const closed = closeStatus({
    marks: input.marks,
    storedStatus: input.storedStatus,
    evaluatedThrough: input.evaluatedThrough,
    closeThrough: input.evaluatedThrough && input.evaluatedThrough >= cutoff ? input.evaluatedThrough : cutoff,
  })
  return {
    status: closed.status,
    evaluatedThrough: closed.evaluatedThrough,
    presenceStreak: closed.presenceStreak,
    absenceStreak: closed.absenceStreak,
  }
}
