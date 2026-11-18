import * as React from "react"
import { cn } from "@/lib/utils"

function Input({ className, type, ...props }: React.ComponentProps<"input">) {
  return (
    <input
      type={type}
      className={cn(
        "flex h-11 w-full rounded-xl border border-input bg-white px-3 py-2 text-base text-[#134e4a] shadow-sm transition-colors outline-none placeholder:text-teal-900/35 focus-visible:border-[#0f766e] focus-visible:ring-2 focus-visible:ring-[#0f766e]/25 disabled:cursor-not-allowed disabled:opacity-50",
        className,
      )}
      {...props}
    />
  )
}

export { Input }
