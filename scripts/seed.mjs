import { execFileSync } from "node:child_process"

// Só o banco local do CLI. Não fala com o projeto remoto.
console.log("Reaplicando migrações e o seed no Supabase local. Os dados locais são apagados.")
execFileSync("supabase", ["db", "reset"], { stdio: "inherit" })

console.log(`
Contas fictícias (domínio .test, nenhuma pessoa real):

  ana.raiz@videfreqkids.test     Senha-Raiz-123
    Discipuladora admin, raiz da árvore, sem pastora.

  bruno.leme@videfreqkids.test   Senha-Lider-123
    Líder da Ana. A senha é provisória: o app pede troca no primeiro acesso.

  clara.vento@videfreqkids.test  Senha-Lider-123
    Líder da Ana.

  diana.serra@videfreqkids.test  Senha-Raiz-123
    Outra discipuladora raiz, sem pastora. Não vê a árvore da Ana.

  edu.mar@videfreqkids.test      Senha-Lider-123
    Líder da Diana.
`)
