import type { Role } from "@/domain/tree-access"

export function roleLabel(role: Role): string {
  switch (role) {
    case "pastor":
      return "Pastor(a)"
    case "discipulador":
      return "Discipulador(a)"
    case "lider":
      return "Líder"
  }
}

export function roleBlurb(role: Role): string {
  switch (role) {
    case "pastor":
      return "Visão da rede Radicais Kids, fechamento e acompanhamento."
    case "discipulador":
      return "Fechamento, acompanhamento da rede e cobrança dos líderes."
    case "lider":
      return "Frequência da célula e os dados das crianças."
  }
}

export function firstName(fullName: string): string {
  const [name] = fullName.trim().split(/\s+/)
  return name || fullName
}
