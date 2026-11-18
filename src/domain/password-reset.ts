export const NEUTRAL_RESET_MESSAGE =
  "Se o e-mail estiver cadastrado, você vai receber um link"

export const RATE_LIMIT_RESET_MESSAGE =
  "Muitos pedidos em pouco tempo. Espere um minuto e tente de novo."

export const RESEND_COOLDOWN_SECONDS = 30
export const RATE_LIMIT_COOLDOWN_SECONDS = 60
export const MIN_PASSWORD_LENGTH = 8
export const RECOVERY_NEXT_PATH = "/redefinir-senha"

const RATE_LIMIT_CODES = new Set(["over_request_rate_limit", "over_email_send_rate_limit"])
const FLOW_ID = /^[a-zA-Z0-9_-]{8,64}$/

export interface AuthLikeError {
  status?: number
  code?: string
  message?: string
}

export function normalizeEmail(value: string): string | null {
  const email = value.trim().toLowerCase()
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return null
  return email
}

export function isResetRateLimit(error: AuthLikeError | null | undefined): boolean {
  if (!error) return false
  if (error.status === 429) return true
  if (error.code && RATE_LIMIT_CODES.has(error.code)) return true
  const message = error.message?.toLowerCase() ?? ""
  return message.includes("rate limit") || message.includes("too many requests")
}

export function validateNewPassword(password: string, confirm: string): string | null {
  if (password.length < MIN_PASSWORD_LENGTH) {
    return "A senha precisa ter pelo menos 8 caracteres."
  }
  if (password !== confirm) return "A confirmação não confere."
  return null
}

export function safeNextPath(next: string | null | undefined, fallback = RECOVERY_NEXT_PATH): string {
  if (!next) return fallback
  if (!next.startsWith("/") || next.startsWith("//") || next.startsWith("/\\")) return fallback
  if (next.includes("\\") || next.includes("\0") || next.includes("://")) return fallback

  let decoded = next
  try {
    decoded = decodeURIComponent(next)
  } catch {
    return fallback
  }
  if (!decoded.startsWith("/") || decoded.startsWith("//") || decoded.startsWith("/\\")) {
    return fallback
  }
  if (decoded.includes("\\") || decoded.includes("://") || decoded.includes("\0")) return fallback

  const pathname = decoded.split("?")[0]?.split("#")[0] ?? ""
  if (!pathname.startsWith("/") || pathname.startsWith("//") || pathname.includes("..")) {
    return fallback
  }
  return pathname
}

export type CallbackPlan =
  | { kind: "invalid" }
  | { kind: "exchange"; code: string; flowId?: string; next: string }
  | { kind: "verify"; tokenHash: string; next: string }

export function planAuthCallback(input: {
  code: string | null
  flowId: string | null
  tokenHash: string | null
  type: string | null
  next: string | null
  error: string | null
  errorCode: string | null
}): CallbackPlan {
  if (input.error || input.errorCode) return { kind: "invalid" }

  const next = safeNextPath(input.next)
  const code = input.code?.trim() ?? ""
  if (code) {
    const flowId = input.flowId && FLOW_ID.test(input.flowId) ? input.flowId : undefined
    return { kind: "exchange", code, flowId, next }
  }

  const tokenHash = input.tokenHash?.trim() ?? ""
  if (tokenHash && input.type === "recovery") {
    return { kind: "verify", tokenHash, next }
  }

  return { kind: "invalid" }
}
