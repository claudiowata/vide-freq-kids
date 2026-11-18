import { LogOut } from "lucide-react"
import { BottomNav } from "@/components/bottom-nav"
import { Logo } from "@/components/logo"
import { Button } from "@/components/ui/button"
import { signOut } from "@/app/auth/actions"
import type { Profile } from "@/lib/profile"
import { firstName, roleBlurb, roleLabel } from "@/lib/roles"

export function AppShell({
  profile,
  children,
}: {
  profile: Profile
  children: React.ReactNode
}) {
  return (
    <div className="mx-auto flex min-h-full w-full max-w-5xl flex-col px-4 pb-28 pt-5 sm:px-6">
      <header className="flex items-center gap-3">
        <Logo />
        <div className="min-w-0 flex-1">
          <p className="truncate font-serif text-base leading-tight text-[#134e4a] sm:text-lg">
            Igreja Videira Barra Funda
          </p>
          <p className="truncate text-xs text-teal-900/65">
            Vide Freq Kids · {profile.full_name} · {roleLabel(profile.role)}
          </p>
        </div>
        <form action={signOut}>
          <Button type="submit" variant="outline" size="sm">
            <LogOut />
            Sair
          </Button>
        </form>
      </header>

      <div className="mt-8">
        <h1 className="font-serif text-4xl tracking-tight text-[#134e4a]">
          Olá, {firstName(profile.full_name)}
        </h1>
        <p className="mt-1 max-w-xl text-sm text-teal-900/70 sm:text-base">
          {roleLabel(profile.role)} · {roleBlurb(profile.role)}
        </p>
      </div>

      <div className="mt-6 flex-1">{children}</div>
      <BottomNav />
    </div>
  )
}

export function PasswordFrame({ children }: { children: React.ReactNode }) {
  return (
    <div className="mx-auto flex min-h-full w-full max-w-md flex-col justify-center px-4 py-10">
      <div className="mb-6 flex items-center gap-3">
        <Logo />
        <div>
          <p className="font-serif text-lg text-[#134e4a]">Vide Freq Kids</p>
          <p className="text-xs text-teal-900/65">Primeiro acesso</p>
        </div>
      </div>
      {children}
    </div>
  )
}

export function ShellFallback() {
  return (
    <div className="mx-auto flex min-h-full w-full max-w-5xl flex-col px-4 pt-8">
      <div className="h-10 w-64 animate-pulse rounded-xl bg-white/80" />
      <div className="mt-8 h-10 w-48 animate-pulse rounded-xl bg-white/80" />
      <p className="mt-6 text-sm text-teal-900/60">Carregando a rede…</p>
    </div>
  )
}
