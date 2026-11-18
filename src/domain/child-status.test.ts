import { describe, expect, it } from "vitest"
import {
  type AttendanceMark,
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

  it("não rebaixa o membro com 3 ausências e rebaixa na 4ª", () => {
    const staying = replayAttendance(cellDays("PPPPAAA"))
    expect(staying.snapshot.status).toBe("membro")
    expect(staying.snapshot.presenceStreak).toBe(0)
    expect(staying.snapshot.absenceStreak).toBe(3)

    const demoted = replayAttendance(cellDays("PPPPAAAA"))
    expect(demoted.snapshot.status).toBe("visitante")
    expect(demoted.snapshot.absenceStreak).toBe(4)
    expect(demoted.snapshot.presenceStreak).toBe(0)
    expect(demoted.snapshot.firstVisitOn).toBe("2026-06-01")
    expect(demoted.history.map((change) => change.reason)).toEqual([
      "quatro_presencas_consecutivas",
      "quatro_ausencias_consecutivas",
    ])
    expect(demoted.history[1]?.on).toBe("2026-06-08")
  })

  it("zera a sequência de ausências quando o membro comparece", () => {
    const result = replayAttendance(cellDays("PPPPAAAP"))
    expect(result.snapshot.status).toBe("membro")
    expect(result.snapshot.absenceStreak).toBe(0)
    expect(result.snapshot.presenceStreak).toBe(1)
    expect(result.history).toHaveLength(1)
  })

  it("depois de voltar a visitante, 4 presenças promovem de novo", () => {
    const result = replayAttendance(cellDays("PPPPAAAAPPPP"))
    expect(result.snapshot.status).toBe("membro")
    expect(result.snapshot.presenceStreak).toBe(4)
    expect(result.history.map((change) => change.to)).toEqual([
      "membro",
      "visitante",
      "membro",
    ])
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

  it("não grava primeira visita em ausência, e não troca a data depois", () => {
    const onlyAbsence = replayAttendance(cellDays("AAAA"))
    expect(onlyAbsence.snapshot.firstVisitOn).toBeNull()
    expect(onlyAbsence.snapshot.status).toBe("visitante")
    expect(onlyAbsence.snapshot.absenceStreak).toBe(4)

    const later = replayAttendance(cellDays("PAAA"))
    expect(later.snapshot.firstVisitOn).toBe("2026-06-01")
  })
})
