import { describe, expect, it } from "vitest"
import {
  type AttendanceMark,
  closeStatus,
  effectOfRecordingAttendance,
  initialStatus,
  replayAttendance,
} from "./child-status"

function cellDays(pattern: string, start = "2026-06-01"): AttendanceMark[] {
  const startDate = new Date(`${start}T12:00:00Z`)
  return [...pattern].map((token, index) => {
    const date = new Date(startDate)
    date.setUTCDate(startDate.getUTCDate() + index)
    return {
      meetingDate: date.toISOString().slice(0, 10),
      present: token === "P",
      choice: token === "P" ? "presente" : token === "N" ? "outro_responsavel" : "falta",
      kind: "celula" as const,
      sequence: index,
    }
  })
}

describe("status da criança", () => {
  it("começa visitante, sem sequências e sem primeira visita", () => {
    expect(initialStatus()).toEqual({
      status: "visitante",
      presenceStreak: 0,
      absenceStreak: 0,
      firstVisitOn: null,
    })
    expect(replayAttendance([]).snapshot).toEqual(initialStatus())
  })

  it("não promove com 3 presenças e promove exatamente na 4ª", () => {
    const three = replayAttendance(cellDays("PPP"))
    expect(three.snapshot.status).toBe("visitante")
    expect(three.snapshot.presenceStreak).toBe(3)
    expect(three.history).toEqual([])

    const four = replayAttendance(cellDays("PPPP"))
    expect(four.snapshot.status).toBe("membro")
    expect(four.snapshot.presenceStreak).toBe(4)
    expect(four.snapshot.absenceStreak).toBe(0)
    expect(four.snapshot.firstVisitOn).toBe("2026-06-01")
    expect(four.history).toEqual([
      {
        from: "visitante",
        to: "membro",
        on: "2026-06-04",
        reason: "quatro_presencas_consecutivas",
      },
    ])
  })

  it("mantém o membro e a sequência quando a presença continua", () => {
    const result = replayAttendance(cellDays("PPPPP"))
    expect(result.snapshot.status).toBe("membro")
    expect(result.snapshot.presenceStreak).toBe(5)
    expect(result.history).toHaveLength(1)
  })

  it("zera a sequência de presenças quando falta, e exige 4 novas presenças", () => {
    const broken = replayAttendance(cellDays("PPA"))
    expect(broken.snapshot).toMatchObject({
      status: "visitante",
      presenceStreak: 0,
      absenceStreak: 1,
      firstVisitOn: "2026-06-01",
    })

    const restarted = replayAttendance(cellDays("PPAPPPP"))
    expect(restarted.snapshot.status).toBe("membro")
    expect(restarted.snapshot.presenceStreak).toBe(4)
    expect(restarted.history[0]?.on).toBe("2026-06-07")
  })

  it("não rebaixa o membro com 7 ausências e rebaixa na 8ª", () => {
    const staying = replayAttendance(cellDays("PPPPAAAAAAA"))
    expect(staying.snapshot.status).toBe("membro")
    expect(staying.snapshot.presenceStreak).toBe(0)
    expect(staying.snapshot.absenceStreak).toBe(7)

    const demoted = replayAttendance(cellDays("PPPPAAAAAAAA"))
    expect(demoted.snapshot.status).toBe("visitante")
    expect(demoted.snapshot.absenceStreak).toBe(8)
    expect(demoted.snapshot.presenceStreak).toBe(0)
    expect(demoted.snapshot.firstVisitOn).toBe("2026-06-01")
    expect(demoted.history.map((change) => change.reason)).toEqual([
      "quatro_presencas_consecutivas",
      "oito_ausencias_consecutivas",
    ])
    expect(demoted.history[1]?.on).toBe("2026-06-12")
  })

  it("zera a sequência de ausências quando o membro comparece", () => {
    const result = replayAttendance(cellDays("PPPPAAAP"))
    expect(result.snapshot.status).toBe("membro")
    expect(result.snapshot.absenceStreak).toBe(0)
    expect(result.snapshot.presenceStreak).toBe(1)
    expect(result.history).toHaveLength(1)
  })

  it("depois de voltar a visitante, 4 presenças promovem de novo", () => {
    const result = replayAttendance(cellDays("PPPPAAAAAAAAPPPP"))
    expect(result.snapshot.status).toBe("membro")
    expect(result.snapshot.presenceStreak).toBe(4)
    expect(result.history.map((change) => change.to)).toEqual([
      "membro",
      "visitante",
      "membro",
    ])
  })

  it("presença ou falta no culto não muda a sequência da célula", () => {
    const marks: AttendanceMark[] = [
      { meetingDate: "2026-06-01", present: true, kind: "celula", sequence: 0 },
      { meetingDate: "2026-06-02", present: false, kind: "culto", sequence: 0 },
      { meetingDate: "2026-06-03", present: true, kind: "celula", sequence: 0 },
      { meetingDate: "2026-06-04", present: false, kind: "culto", sequence: 0 },
      { meetingDate: "2026-06-05", present: true, kind: "celula", sequence: 0 },
      { meetingDate: "2026-06-06", present: true, kind: "celula", sequence: 0 },
    ]
    const result = replayAttendance(marks)
    expect(result.snapshot.status).toBe("membro")
    expect(result.snapshot.presenceStreak).toBe(4)
    expect(result.snapshot.absenceStreak).toBe(0)
  })

  it("ignora culto no meio da sequência", () => {
    const marks = cellDays("PPP")
    marks.splice(2, 0, {
      meetingDate: "2026-06-02",
      present: true,
      kind: "culto",
      sequence: 0,
    })
    const result = replayAttendance(marks)
    expect(result.snapshot.status).toBe("visitante")
    expect(result.snapshot.presenceStreak).toBe(3)
  })

  it("ordena por data antes de calcular, e desempata pela sequência", () => {
    const scrambled = cellDays("PPPP").reverse()
    expect(replayAttendance(scrambled).snapshot.status).toBe("membro")

    const sameDay = replayAttendance([
      { meetingDate: "2026-06-01", present: false, sequence: 2 },
      { meetingDate: "2026-06-01", present: true, sequence: 1 },
      { meetingDate: "2026-06-02", present: true, sequence: 0 },
      { meetingDate: "2026-06-03", present: true, sequence: 0 },
      { meetingDate: "2026-06-04", present: true, sequence: 0 },
    ])
    expect(sameDay.snapshot.status).toBe("visitante")
    expect(sameDay.snapshot.presenceStreak).toBe(3)
    expect(sameDay.snapshot.absenceStreak).toBe(0)
  })

  it("semana com o outro responsável não quebra a sequência", () => {
    const interleaved = replayAttendance(cellDays("PNPNPNPN"))
    expect(interleaved.snapshot.status).toBe("membro")
    expect(interleaved.snapshot.presenceStreak).toBe(4)
    expect(interleaved.snapshot.absenceStreak).toBe(0)
    expect(interleaved.history).toEqual([
      {
        from: "visitante",
        to: "membro",
        on: "2026-06-07",
        reason: "quatro_presencas_consecutivas",
      },
    ])

    const absencesHeld = replayAttendance(cellDays("PPPPAAN"))
    expect(absencesHeld.snapshot.status).toBe("membro")
    expect(absencesHeld.snapshot.absenceStreak).toBe(2)
    expect(absencesHeld.snapshot.presenceStreak).toBe(0)
  })

  it("não grava primeira visita em ausência, e não troca a data depois", () => {
    const onlyAbsence = replayAttendance(cellDays("AAAA"))
    expect(onlyAbsence.snapshot.firstVisitOn).toBeNull()
    expect(onlyAbsence.snapshot.status).toBe("visitante")
    expect(onlyAbsence.snapshot.absenceStreak).toBe(4)

    const later = replayAttendance(cellDays("PAAA"))
    expect(later.snapshot.firstVisitOn).toBe("2026-06-01")
  })
})

describe("status só muda na virada do mês", () => {
  const june = cellDays("PPPP", "2026-06-02")

  it("lançar 4 presenças no mês aberto não altera o status", () => {
    const effect = effectOfRecordingAttendance({
      marks: june,
      storedStatus: "visitante",
      evaluatedThrough: "2026-05-31",
      today: "2026-06-18",
    })
    expect(effect.status).toBe("visitante")
    expect(effect.evaluatedThrough).toBe("2026-05-31")
    expect(effect.presenceStreak).toBe(4)
  })

  it("fechar o mês promove com 4 presenças e repetir o fechamento é igual", () => {
    const first = closeStatus({
      marks: june,
      storedStatus: "visitante",
      evaluatedThrough: "2026-05-31",
      closeThrough: "2026-06-30",
    })
    expect(first.status).toBe("membro")
    expect(first.history).toEqual([
      {
        from: "visitante",
        to: "membro",
        on: "2026-06-30",
        reason: "quatro_presencas_consecutivas",
      },
    ])
    const second = closeStatus({
      marks: june,
      storedStatus: first.status,
      evaluatedThrough: first.evaluatedThrough,
      closeThrough: "2026-06-30",
    })
    expect(second.status).toBe("membro")
    expect(second.history).toEqual(first.history)
    expect(second.evaluatedThrough).toBe("2026-06-30")

    const earlier = closeStatus({
      marks: june,
      storedStatus: "membro",
      evaluatedThrough: "2026-06-30",
      closeThrough: "2026-05-31",
    })
    expect(earlier.status).toBe("membro")
    expect(earlier.evaluatedThrough).toBe("2026-06-30")
    expect(earlier.history).toEqual(first.history)
  })

  it("7 faltas no mês fechado continuam membro e a 8ª devolve a visitante", () => {
    const seven = cellDays("PPPPAAAAAAA", "2026-06-01")
    const closedSeven = closeStatus({
      marks: seven,
      storedStatus: "visitante",
      evaluatedThrough: null,
      closeThrough: "2026-06-30",
    })
    expect(closedSeven.status).toBe("membro")

    const eight = cellDays("PPPPAAAAAAAA", "2026-06-01")
    expect(
      closeStatus({
        marks: eight,
        storedStatus: "membro",
        evaluatedThrough: "2026-06-30",
        closeThrough: "2026-06-30",
      }).status,
    ).toBe("visitante")
  })

  it("a sequência neutra atravessa meses e a semana do outro responsável não quebra", () => {
    const marks = cellDays("PNPNPNPN", "2026-05-04")
    const open = effectOfRecordingAttendance({
      marks,
      storedStatus: "visitante",
      evaluatedThrough: "2026-04-30",
      today: "2026-05-20",
    })
    expect(open.status).toBe("visitante")
    expect(open.presenceStreak).toBe(4)

    const closed = closeStatus({
      marks,
      storedStatus: "visitante",
      evaluatedThrough: "2026-04-30",
      closeThrough: "2026-06-30",
    })
    expect(closed.status).toBe("membro")
    expect(closed.presenceStreak).toBe(4)
    expect(closed.absenceStreak).toBe(0)
  })
})
