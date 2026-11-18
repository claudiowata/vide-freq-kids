import Image from "next/image"
import { cn } from "@/lib/utils"

export function Logo({
  variant = "mark",
  className,
}: {
  variant?: "mark" | "full"
  className?: string
}) {
  const full = variant === "full"
  return (
    <Image
      src={full ? "/brand/logo-radicais-kids.png" : "/brand/logo-radicais-kids-mark.png"}
      alt={full ? "Radicais Kids" : ""}
      width={full ? 394 : 214}
      height={full ? 507 : 206}
      priority={full}
      className={cn(full ? "h-44 w-auto" : "size-11 w-auto shrink-0", className)}
    />
  )
}
