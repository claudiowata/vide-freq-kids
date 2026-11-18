import { ModuleCard } from "@/components/module-card"

export const metadata = { title: "Fechamento" }

export default function FechamentoPage() {
  return (
    <ModuleCard eyebrow="Mês" title="Fechamento mensal">
      <p>
        Os indicadores da planilha de acompanhamento — semanas, enviados ao Encontro,
        evento Ponte, conversões e a cor da célula — serão confirmados nesta tela.
      </p>
    </ModuleCard>
  )
}
