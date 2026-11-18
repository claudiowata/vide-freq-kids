import Link from "next/link"
import { AuthCard } from "@/components/auth-card"
import { Button } from "@/components/ui/button"

export const metadata = { title: "Link inválido" }

export default function InvalidLinkPage() {
  return (
    <AuthCard
      title="Link inválido"
      lede="Este link é inválido ou já expirou. Peça outro para criar uma nova senha."
    >
      <div className="mt-6">
        <Button asChild className="w-full">
          <Link href="/esqueci-senha">Pedir um link novo</Link>
        </Button>
      </div>
      <p className="mt-6 text-sm">
        <Link href="/login" className="inline-flex min-h-11 items-center font-semibold text-primary">
          Voltar ao login
        </Link>
      </p>
    </AuthCard>
  )
}
