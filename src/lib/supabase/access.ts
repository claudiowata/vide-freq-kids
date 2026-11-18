export const RECOVERY_PATH = "/redefinir-senha"

const PUBLIC_PATHS = new Set(["/login", "/setup", "/esqueci-senha", "/auth/link-invalido"])
const LOGGED_IN_BOUNCE = new Set(["/login", "/setup"])

export function isAuthCallback(path: string): boolean {
  return path === "/auth/callback" || path.startsWith("/auth/callback/")
}

export function isPublicPath(path: string): boolean {
  return PUBLIC_PATHS.has(path) || isAuthCallback(path)
}

export type AccessDecision =
  | { action: "allow" }
  | { action: "redirect"; pathname: string; search?: string }

export function decideAccess(input: {
  path: string
  hasUser: boolean
  mustChangePassword: boolean
  hasRecoveryCookie: boolean
}): AccessDecision {
  const { path, hasUser, mustChangePassword, hasRecoveryCookie } = input

  if (isAuthCallback(path)) return { action: "allow" }

  if (path === RECOVERY_PATH) {
    if (hasUser && hasRecoveryCookie) return { action: "allow" }
    return { action: "redirect", pathname: "/esqueci-senha", search: "aviso=sessao" }
  }

  if (!hasUser) {
    if (isPublicPath(path)) return { action: "allow" }
    return { action: "redirect", pathname: "/login" }
  }

  if (mustChangePassword && path !== "/trocar-senha") {
    return { action: "redirect", pathname: "/trocar-senha" }
  }

  if (!mustChangePassword && (LOGGED_IN_BOUNCE.has(path) || path === "/trocar-senha")) {
    return { action: "redirect", pathname: "/" }
  }

  return { action: "allow" }
}
