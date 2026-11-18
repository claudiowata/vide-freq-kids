import type { Role } from "@/domain/tree-access"

export interface Profile {
  id: string
  full_name: string
  email: string
  role: Role
  supervisor_id: string | null
  pastor_id: string | null
  is_admin: boolean
  must_change_password: boolean
  active: boolean
  phone: string | null
}

export function isRole(value: string): value is Role {
  return value === "pastor" || value === "discipulador" || value === "lider"
}
