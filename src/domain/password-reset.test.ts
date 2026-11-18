import { describe, expect, it } from "vitest"
import {
  MIN_PASSWORD_LENGTH,
  NEUTRAL_RESET_MESSAGE,
  RATE_LIMIT_COOLDOWN_SECONDS,
  RATE_LIMIT_RESET_MESSAGE,
  RESEND_COOLDOWN_SECONDS,
  isResetRateLimit,
  normalizeEmail,
  planAuthCallback,
  safeNextPath,
  validateNewPassword,
} from "./password-reset"

describe("recuperação de senha", () => {
  it("normaliza e-mail e rejeita o que não parece endereço", () => {
    expect(normalizeEmail("  Ana@Igreja.Org ")).toBe("ana@igreja.org")
    expect(normalizeEmail("sem-arroba")).toBeNull()
    expect(normalizeEmail("a@b")).toBeNull()
    expect(normalizeEmail("")).toBeNull()
  })

  it("reconhece limite de envio sem tratar os outros erros como limite", () => {
    expect(isResetRateLimit(null)).toBe(false)
    expect(isResetRateLimit({ message: "Invalid login" })).toBe(false)
    expect(isResetRateLimit({ status: 429 })).toBe(true)
    expect(isResetRateLimit({ code: "over_email_send_rate_limit" })).toBe(true)
    expect(isResetRateLimit({ code: "over_request_rate_limit" })).toBe(true)
    expect(isResetRateLimit({ message: "Email rate limit exceeded" })).toBe(true)
    expect(RATE_LIMIT_RESET_MESSAGE).toMatch(/minuto/i)
    expect(NEUTRAL_RESET_MESSAGE).toBe(
      "Se o e-mail estiver cadastrado, você vai receber um link",
    )
    expect(RESEND_COOLDOWN_SECONDS).toBeGreaterThanOrEqual(5)
    expect(RATE_LIMIT_COOLDOWN_SECONDS).toBeGreaterThan(RESEND_COOLDOWN_SECONDS)
  })

  it("exige 8 caracteres e a mesma confirmação", () => {
    expect(MIN_PASSWORD_LENGTH).toBe(8)
    expect(validateNewPassword("curta", "curta")).toMatch(/8 caracteres/)
    expect(validateNewPassword("senha-boa", "outra-senha")).toMatch(/não confere/)
    expect(validateNewPassword("senha-boa", "senha-boa")).toBeNull()
  })

  it("só aceita o próximo caminho dentro do app", () => {
    expect(safeNextPath(null)).toBe("/redefinir-senha")
    expect(safeNextPath("/redefinir-senha")).toBe("/redefinir-senha")
    expect(safeNextPath("https://evil.example/roubo")).toBe("/redefinir-senha")
    expect(safeNextPath("//evil.example")).toBe("/redefinir-senha")
    expect(safeNextPath("/\\evil.example")).toBe("/redefinir-senha")
    expect(safeNextPath("/%2F%2Fevil.example")).toBe("/redefinir-senha")
    expect(safeNextPath("/redefinir-senha?next=https://evil.example")).toBe("/redefinir-senha")
    expect(safeNextPath("/ok/../login")).toBe("/redefinir-senha")
  })

  it("planeja o callback PKCE, o token_hash de recovery e o link inválido", () => {
    expect(
      planAuthCallback({
        code: "abc",
        flowId: "flow-id-123",
        tokenHash: null,
        type: null,
        next: "/redefinir-senha",
        error: null,
        errorCode: null,
      }),
    ).toEqual({
      kind: "exchange",
      code: "abc",
      flowId: "flow-id-123",
      next: "/redefinir-senha",
    })

    expect(
      planAuthCallback({
        code: "abc",
        flowId: "../etc",
        tokenHash: null,
        type: null,
        next: "https://evil.example",
        error: null,
        errorCode: null,
      }),
    ).toEqual({ kind: "exchange", code: "abc", next: "/redefinir-senha" })

    expect(
      planAuthCallback({
        code: null,
        flowId: null,
        tokenHash: "hash",
        type: "recovery",
        next: null,
        error: null,
        errorCode: null,
      }),
    ).toEqual({ kind: "verify", tokenHash: "hash", next: "/redefinir-senha" })

    expect(
      planAuthCallback({
        code: null,
        flowId: null,
        tokenHash: "hash",
        type: "signup",
        next: null,
        error: null,
        errorCode: null,
      }).kind,
    ).toBe("invalid")

    expect(
      planAuthCallback({
        code: "abc",
        flowId: null,
        tokenHash: null,
        type: null,
        next: null,
        error: "access_denied",
        errorCode: "otp_expired",
      }).kind,
    ).toBe("invalid")
  })
})
