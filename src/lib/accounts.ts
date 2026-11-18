import "server-only"

import type { Role } from "@/domain/tree-access"
import { createAdminClient } from "@/lib/supabase/admin"

export interface NewAccount {
  fullName: string
  email: string
  password: string
  role: Role
  supervisorId?: string | null
  isAdmin?: boolean
  mustChangePassword?: boolean
}

export async function createLeadershipAccount(input: NewAccount) {
  const admin = createAdminClient()
  const email = input.email.trim().toLowerCase()
  const { data, error } = await admin.auth.admin.createUser({
    email,
    password: input.password,
    email_confirm: true,
    app_metadata: {
      role: input.role,
      supervisor_id: input.supervisorId ?? null,
      is_admin: input.isAdmin ?? false,
      must_change_password: input.mustChangePassword ?? true,
    },
    user_metadata: { full_name: input.fullName.trim() },
  })

  if (error || !data.user) {
    throw new Error(error?.message ?? "Não foi possível criar a conta.")
  }

  return data.user
}
