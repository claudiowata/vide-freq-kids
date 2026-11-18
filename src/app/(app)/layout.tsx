import { Suspense } from "react"
import { AppShell, PasswordFrame, ShellFallback } from "@/components/app-shell"
import { getCurrentProfile } from "@/lib/auth"

async function Authed({ children }: { children: React.ReactNode }) {
  const profile = await getCurrentProfile()
  if (profile.must_change_password) {
    return <PasswordFrame>{children}</PasswordFrame>
  }
  return <AppShell profile={profile}>{children}</AppShell>
}

export default function AppLayout({ children }: { children: React.ReactNode }) {
  return (
    <Suspense fallback={<ShellFallback />}>
      <Authed>{children}</Authed>
    </Suspense>
  )
}
