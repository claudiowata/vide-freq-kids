import { describe, expect, it } from "vitest"
import { decideAccess, isPublicPath } from "./access"

const guest = { hasUser: false, mustChangePassword: false, hasRecoveryCookie: false }
const member = { hasUser: true, mustChangePassword: false, hasRecoveryCookie: false }
const provisional = { hasUser: true, mustChangePassword: true, hasRecoveryCookie: false }
const recovery = { hasUser: true, mustChangePassword: false, hasRecoveryCookie: true }

describe("acesso das rotas de senha", () => {
  it("deixa login, esqueci-senha e o callback públicos", () => {
    expect(isPublicPath("/login")).toBe(true)
    expect(isPublicPath("/esqueci-senha")).toBe(true)
    expect(isPublicPath("/auth/callback")).toBe(true)
    expect(isPublicPath("/auth/link-invalido")).toBe(true)
    expect(decideAccess({ path: "/esqueci-senha", ...guest })).toEqual({ action: "allow" })
    expect(decideAccess({ path: "/auth/callback", ...guest })).toEqual({ action: "allow" })
    expect(decideAccess({ path: "/login", ...guest })).toEqual({ action: "allow" })
  })

  it("manda quem não tem sessão para o login, e a redefinição para pedir outro link", () => {
    expect(decideAccess({ path: "/", ...guest })).toEqual({
      action: "redirect",
      pathname: "/login",
    })
    expect(decideAccess({ path: "/redefinir-senha", ...guest })).toEqual({
      action: "redirect",
      pathname: "/esqueci-senha",
      search: "aviso=sessao",
    })
    expect(decideAccess({ path: "/redefinir-senha", ...member })).toEqual({
      action: "redirect",
      pathname: "/esqueci-senha",
      search: "aviso=sessao",
    })
  })

  it("deixa /redefinir-senha com a sessão de recuperação, mesmo na senha provisória", () => {
    expect(decideAccess({ path: "/redefinir-senha", ...recovery })).toEqual({ action: "allow" })
    expect(
      decideAccess({
        path: "/redefinir-senha",
        hasUser: true,
        mustChangePassword: true,
        hasRecoveryCookie: true,
      }),
    ).toEqual({ action: "allow" })
  })

  it("não deixa o callback ser interrompido por quem já entrou", () => {
    expect(decideAccess({ path: "/auth/callback", ...member })).toEqual({ action: "allow" })
    expect(decideAccess({ path: "/auth/callback", ...provisional })).toEqual({ action: "allow" })
  })

  it("mantém a troca obrigatória e tira quem já entrou do login", () => {
    expect(decideAccess({ path: "/", ...provisional })).toEqual({
      action: "redirect",
      pathname: "/trocar-senha",
    })
    expect(decideAccess({ path: "/login", ...member })).toEqual({
      action: "redirect",
      pathname: "/",
    })
    expect(decideAccess({ path: "/esqueci-senha", ...member })).toEqual({ action: "allow" })
  })
})
