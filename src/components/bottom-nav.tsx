"use client"

import {
  ClipboardCheck,
  House,
  LineChart,
  UserRound,
  CalendarCheck,
} from "lucide-react"
import Link from "next/link"
import { usePathname } from "next/navigation"
import { cn } from "@/lib/utils"

const tabs = [
  { href: "/", label: "Início", icon: House },
  { href: "/frequencia", label: "Frequência", icon: ClipboardCheck },
  { href: "/fechamento", label: "Fechamento", icon: CalendarCheck },
  { href: "/acompanhar", label: "Acompanhar", icon: LineChart },
  { href: "/cadastro", label: "Cadastro", icon: UserRound },
]

export function BottomNav() {
  const pathname = usePathname()

  return (
    <nav
      aria-label="Seções"
      className="fixed inset-x-0 bottom-3 z-20 mx-auto flex w-[min(100%-1rem,36rem)] items-stretch justify-between gap-0.5 rounded-full bg-white/95 p-1 shadow-[0_10px_40px_rgba(59,33,92,0.16)] ring-1 ring-primary/10 backdrop-blur"
    >
      {tabs.map((tab) => {
        const active = pathname === tab.href
        const Icon = tab.icon
        return (
          <Link
            key={tab.href}
            href={tab.href}
            aria-current={active ? "page" : undefined}
            className={cn(
              "flex min-w-0 flex-1 flex-col items-center gap-0.5 rounded-full px-1 py-2 text-[10px] font-semibold leading-none sm:text-[11px]",
              active ? "bg-primary text-white" : "text-ink/70 hover:bg-[#F4ECFB]",
            )}
          >
            <Icon className="size-4" />
            <span className="truncate">{tab.label}</span>
          </Link>
        )
      })}
    </nav>
  )
}
