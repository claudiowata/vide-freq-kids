import { Suspense } from "react"
import { ModuleCard } from "@/components/module-card"

async function PasswordChangedNotice({
  searchParams,
}: {
  searchParams: Promise<{ aviso?: string }>
}) {
  const aviso = (await searchParams).aviso
  if (aviso !== "senha-alterada") return null
  return (
    <p className="rounded-xl bg-[#F4ECFB] px-3 py-2 text-sm text-ink" role="status">
      Sua senha foi alterada.
    </p>
  )
}

export default function HomePage({
  searchParams,
}: {
  searchParams: Promise<{ aviso?: string }>
}) {
  return (
    <div className="grid gap-4">
      <Suspense fallback={null}>
        <PasswordChangedNotice searchParams={searchParams} />
      </Suspense>
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
