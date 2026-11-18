import "server-only"

import { createClient } from "@supabase/supabase-js"
import { getPublicSupabaseEnv, getSecretSupabaseKey } from "@/lib/env"

export function createAdminClient() {
  const env = getPublicSupabaseEnv()
  const secret = getSecretSupabaseKey()
  if (!env || !secret) {
    throw new Error(
      "Falta SUPABASE_SECRET_KEY (ou SUPABASE_SERVICE_ROLE_KEY) para criar contas.",
    )
  }

  return createClient(env.url, secret, {
    auth: { autoRefreshToken: false, persistSession: false },
  })
}
