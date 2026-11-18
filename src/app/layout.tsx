import type { Metadata, Viewport } from "next"
import { Fraunces, Source_Sans_3 } from "next/font/google"
import { ServiceWorkerRegister } from "@/components/service-worker"
import "./globals.css"

const fraunces = Fraunces({
  variable: "--font-fraunces",
  subsets: ["latin", "latin-ext"],
})

const sourceSans = Source_Sans_3({
  variable: "--font-source-sans",
  subsets: ["latin", "latin-ext"],
})

export const metadata: Metadata = {
  title: {
    default: "Vide Freq Kids",
    template: "%s · Vide Freq Kids",
  },
  description:
    "Frequência e relatórios das células Kids e Juvenis da Igreja Videira Barra Funda.",
  applicationName: "Vide Freq Kids",
  manifest: "/manifest.webmanifest",
  appleWebApp: {
    capable: true,
    title: "Vide Freq Kids",
    statusBarStyle: "default",
  },
  icons: {
    icon: [
      { url: "/icons/icon-192.png", sizes: "192x192", type: "image/png" },
      { url: "/icons/icon-512.png", sizes: "512x512", type: "image/png" },
    ],
    apple: [{ url: "/icons/apple-touch-icon.png", sizes: "180x180" }],
  },
}

export const viewport: Viewport = {
  themeColor: "#0f766e",
  width: "device-width",
  initialScale: 1,
}

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html
      lang="pt-BR"
      className={`${fraunces.variable} ${sourceSans.variable} h-full antialiased`}
    >
      <body className="min-h-full">
        {children}
        <ServiceWorkerRegister />
      </body>
    </html>
  )
}
