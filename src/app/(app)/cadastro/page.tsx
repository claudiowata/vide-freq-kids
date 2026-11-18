import { ModuleCard } from "@/components/module-card"

export const metadata = { title: "Cadastro" }

export default function CadastroPage() {
  return (
    <ModuleCard eyebrow="Ficha" title="Cadastro da rede">
      <p>
        Pessoas, vínculos, células e a ficha serão editados aqui. O tipo da célula
        é Kids, Juvenis ou Mista com Juvenis. Em cada criança ficam mãe convertida
        e pai convertido, sim ou não.
      </p>
    </ModuleCard>
  )
}
