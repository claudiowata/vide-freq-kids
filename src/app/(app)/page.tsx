import { ModuleCard } from "@/components/module-card"

export default function HomePage() {
  return (
    <div className="grid gap-4">
      <ModuleCard eyebrow="Cobrança semanal" title="A rede Radicais Kids entra aqui">
        <p>
          A lista de células e cultos pendentes da semana fica nesta tela na próxima
          etapa. A base já guarda a hierarquia, a ficha e a regra de visitante e membro.
        </p>
        <p>
          A rede funciona sem pastora: a discipuladora pode ser a raiz. Quando uma
          pastora entrar, ela se liga acima das discipuladoras que já existem.
        </p>
      </ModuleCard>
    </div>
  )
}
