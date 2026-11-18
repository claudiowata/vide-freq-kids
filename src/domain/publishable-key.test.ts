import { createClient } from "@supabase/supabase-js"
import { describe, expect, it } from "vitest"

describe("chave publicável", () => {
  it("o supabase-js aceita a chave sb_publishable sem tratar como JWT", () => {
    const client = createClient(
      "https://zvsomzsifdiqdnpywyul.supabase.co",
      "sb_publishable_LYFjsaZmnu-Pc-5-cz0p_A_TCBTbchT",
      { auth: { persistSession: false, autoRefreshToken: false } },
    )
    expect(client).toBeTruthy()
  })
})
