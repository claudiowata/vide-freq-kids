import { ModuleCard } from "@/components/module-card"

export const metadata = { title: "Cadastro" }

export default function CadastroPage() {
  return (
    <ModuleCard eyebrow="Ficha" title="Cadastro da rede">
      <p>
        Pessoas, vínculos, células, crianças e a ficha de recadastramento serão
        editados aqui. O líder, o líder em treinamento, o anfitrião e o endereço já
        têm lugar no banco.
      </p>
    </ModuleCard>
  )
}
