import "server-only"

import { redirect } from "next/navigation"
import { isRole, type Profile } from "@/lib/profile"
import { createClient } from "@/lib/supabase/server"

export async function getCurrentProfile(): Promise<Profile> {
  const supabase = await createClient()
  const {
    data: { user },
  } = await supabase.auth.getUser()

  if (!user) redirect("/login")

  const { data } = await supabase
    .from("profiles")
    .select(
      "id, full_name, email, role, supervisor_id, pastor_id, is_admin, must_change_password, active, phone",
    )
    .eq("id", user.id)
    .maybeSingle()

  if (!data || !isRole(data.role)) redirect("/login")

  if (!data.active) {
    await supabase.auth.signOut()
    redirect("/login?aviso=inativa")
  }

  return data
}
