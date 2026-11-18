import { cn } from "@/lib/utils"

export function Logo({ className }: { className?: string }) {
  return (
    <span
      className={cn(
        "grid size-10 shrink-0 place-items-center rounded-xl bg-[#134e4a] text-white shadow-sm",
        className,
      )}
      aria-hidden
    >
      <svg viewBox="0 0 32 32" className="size-6" fill="none">
        <path
          d="M16 26c0-6 4.2-9.2 8.2-11.2C20.6 13.2 18 10.4 16 6c-2 4.4-4.6 7.2-8.2 8.8C11.8 16.8 16 20 16 26Z"
          fill="#99f6e4"
        />
        <path
          d="M16 26c0-4.2 2.2-6.6 4.6-8.2"
          stroke="#f59e0b"
          strokeWidth="1.6"
          strokeLinecap="round"
        />
      </svg>
    </span>
  )
}
