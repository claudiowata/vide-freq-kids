export const RECOVERY_COOKIE = "vfk_recovery"
export const RECOVERY_COOKIE_MAX_AGE = 15 * 60

export function recoveryCookieOptions(maxAge = RECOVERY_COOKIE_MAX_AGE) {
  return {
    httpOnly: true,
    sameSite: "lax" as const,
    secure: process.env.NODE_ENV === "production",
    path: "/",
    maxAge,
  }
}
