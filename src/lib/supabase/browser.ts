import { createBrowserClient } from "@supabase/ssr"
import { getPublicSupabaseEnv } from "@/lib/env"

export function createBrowserSupabase() {
  const env = getPublicSupabaseEnv()
  if (!env) {
    throw new Error("Defina NEXT_PUBLIC_SUPABASE_URL e NEXT_PUBLIC_SUPABASE_ANON_KEY.")
  }
  return createBrowserClient(env.url, env.key)
}
