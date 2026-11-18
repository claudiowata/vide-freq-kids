import { createServerClient, type CookieOptions } from "@supabase/ssr"
import { NextResponse, type NextRequest } from "next/server"
import { planAuthCallback } from "@/domain/password-reset"
import { getPublicSupabaseEnv } from "@/lib/env"
import { RECOVERY_COOKIE, recoveryCookieOptions } from "@/lib/recovery-cookie"

interface PendingCookie {
  name: string
  value: string
  options: CookieOptions
}

function invalidLink(request: NextRequest) {
  return NextResponse.redirect(new URL("/auth/link-invalido", request.url))
}

export async function GET(request: NextRequest) {
  const params = request.nextUrl.searchParams
  const plan = planAuthCallback({
    code: params.get("code"),
    flowId: params.get("sb_flow_id"),
    tokenHash: params.get("token_hash"),
    type: params.get("type"),
    next: params.get("next"),
    error: params.get("error"),
    errorCode: params.get("error_code"),
  })

  if (plan.kind === "invalid") return invalidLink(request)

  const env = getPublicSupabaseEnv()
  if (!env) return invalidLink(request)

  const pending: PendingCookie[] = []
  let cacheHeaders: Record<string, string> = {}
  const supabase = createServerClient(env.url, env.key, {
    cookies: {
      getAll() {
        return request.cookies.getAll()
      },
      setAll(cookiesToSet, headers) {
        pending.splice(0, pending.length, ...cookiesToSet)
        cacheHeaders = headers
      },
    },
  })

  let recovered = false
  if (plan.kind === "exchange") {
    const { data, error } = await supabase.auth.exchangeCodeForSession(
      plan.code,
      plan.flowId ? { flowId: plan.flowId } : undefined,
    )
    const redirectType =
      data && typeof data === "object" && "redirectType" in data
        ? (data as { redirectType?: string | null }).redirectType
        : null
    recovered = !error && Boolean(data.session) && redirectType === "recovery"
  } else {
    const { data, error } = await supabase.auth.verifyOtp({
      type: "recovery",
      token_hash: plan.tokenHash,
    })
    recovered = !error && Boolean(data.session)
  }

  if (!recovered) return invalidLink(request)

  const response = NextResponse.redirect(new URL(plan.next, request.url))
  pending.forEach(({ name, value, options }) => {
    response.cookies.set(name, value, options)
  })
  Object.entries(cacheHeaders).forEach(([name, value]) => {
    response.headers.set(name, value)
  })
  response.cookies.set(RECOVERY_COOKIE, "1", recoveryCookieOptions())
  return response
}
