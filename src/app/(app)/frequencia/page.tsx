import { ModuleCard } from "@/components/module-card"

export const metadata = { title: "Frequência" }

export default function FrequenciaPage() {
  return (
    <ModuleCard eyebrow="Reunião" title="Registrar frequência">
      <p>
        A chamada da célula — presença das crianças e dos visitantes — será marcada
        aqui. Quatro presenças seguidas tornam a criança membro; quatro faltas
        seguidas devolvem o membro a visitante.
      </p>
    </ModuleCard>
  )
}
