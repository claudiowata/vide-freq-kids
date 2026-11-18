import { ModuleCard } from "@/components/module-card"

export const metadata = { title: "Frequência" }

export default function FrequenciaPage() {
  return (
    <ModuleCard eyebrow="Reunião" title="Registrar frequência">
      <p>
        A chamada da célula — presença das crianças e dos visitantes — será marcada
        aqui.         Quatro presenças seguidas na célula tornam a criança membro; quatro faltas
        seguidas na célula devolvem o membro a visitante. O culto não entra nessa conta.
      </p>
    </ModuleCard>
  )
}
