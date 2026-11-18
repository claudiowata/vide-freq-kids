import { createServerClient } from "@supabase/ssr"
import { NextResponse, type NextRequest } from "next/server"
import { getPublicSupabaseEnv } from "@/lib/env"
import { RECOVERY_COOKIE } from "@/lib/recovery-cookie"
import { decideAccess } from "@/lib/supabase/access"

function redirectTo(
  request: NextRequest,
  pathname: string,
  source: NextResponse,
  search = "",
) {
  const url = request.nextUrl.clone()
  url.pathname = pathname
  url.search = search
  const redirect = NextResponse.redirect(url)
  source.cookies.getAll().forEach((cookie) => {
    redirect.cookies.set(cookie)
  })
  return redirect
}

export async function updateSession(request: NextRequest) {
  const path = request.nextUrl.pathname
  const env = getPublicSupabaseEnv()
  const hasRecoveryCookie = request.cookies.get(RECOVERY_COOKIE)?.value === "1"

  if (!env) {
    const decision = decideAccess({
      path,
      hasUser: false,
      mustChangePassword: false,
      hasRecoveryCookie,
    })
    if (decision.action === "allow") return NextResponse.next({ request })
    const url = request.nextUrl.clone()
    url.pathname = decision.pathname
    url.search = decision.search ?? ""
    return NextResponse.redirect(url)
  }

  let response = NextResponse.next({ request })
  const supabase = createServerClient(env.url, env.key, {
    cookies: {
      getAll() {
        return request.cookies.getAll()
      },
      setAll(cookiesToSet) {
        cookiesToSet.forEach(({ name, value }) => {
          request.cookies.set(name, value)
        })
        response = NextResponse.next({ request })
        cookiesToSet.forEach(({ name, value, options }) => {
          response.cookies.set(name, value, options)
        })
      },
    },
  })

  const {
    data: { user },
  } = await supabase.auth.getUser()

  const decision = decideAccess({
    path,
    hasUser: Boolean(user),
    mustChangePassword: user?.app_metadata?.must_change_password === true,
    hasRecoveryCookie,
  })

  if (decision.action === "redirect") {
    return redirectTo(request, decision.pathname, response, decision.search ?? "")
  }

  return response
}
