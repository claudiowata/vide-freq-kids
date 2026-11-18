import { createServerClient } from "@supabase/ssr"
import { NextResponse, type NextRequest } from "next/server"
import { getPublicSupabaseEnv } from "@/lib/env"

const PUBLIC_PATHS = new Set(["/login", "/setup"])

function redirectTo(request: NextRequest, pathname: string, source: NextResponse) {
  const url = request.nextUrl.clone()
  url.pathname = pathname
  url.search = ""
  const redirect = NextResponse.redirect(url)
  source.cookies.getAll().forEach((cookie) => {
    redirect.cookies.set(cookie)
  })
  return redirect
}

export async function updateSession(request: NextRequest) {
  const path = request.nextUrl.pathname
  const env = getPublicSupabaseEnv()

  if (!env) {
    if (PUBLIC_PATHS.has(path)) return NextResponse.next({ request })
    const url = request.nextUrl.clone()
    url.pathname = "/login"
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

  const mustChange = user?.app_metadata?.must_change_password === true
  const isPublic = PUBLIC_PATHS.has(path)

  if (!user && !isPublic) {
    return redirectTo(request, "/login", response)
  }

  if (user && mustChange && path !== "/trocar-senha") {
    return redirectTo(request, "/trocar-senha", response)
  }

  if (user && !mustChange && (isPublic || path === "/trocar-senha")) {
    return redirectTo(request, "/", response)
  }

  return response
}
