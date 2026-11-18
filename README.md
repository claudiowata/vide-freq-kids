# Vide Freq Kids

Frequência e fechamento mensal das células de crianças e juvenis da rede **Radicais Kids**, na Igreja Videira Barra Funda. O app é um PWA em português, pensado primeiro para o celular, no mesmo espírito visual do VideFreq.

Esta unidade é a base: visual, login, banco e a regra de visitante/membro. As telas de chamada, fechamento, acompanhamento e cadastro ainda são lugares reservados.

## O que já funciona

- Visual em verde-água, cartões brancos e a barra inferior com Início, Frequência, Fechamento, Acompanhar e Cadastro.
- Login por e-mail e senha. Não há cadastro público.
- Contas criadas pela liderança, com senha provisória e troca obrigatória no primeiro acesso.
- A rede pode existir **sem pastora**. A primeira discipuladora nasce como raiz e admin.
- Uma pastora pode ser colocada acima das discipuladoras que já existem, sem reescrever células, crianças ou relatórios.
- Cada pessoa vê só a própria árvore.
- Criança começa visitante, vira membro com 4 presenças consecutivas de célula e volta a visitante com 4 faltas consecutivas.

## Requisitos

- Node.js 22
- npm
- [Supabase CLI](https://supabase.com/docs/guides/cli) e Docker, para o banco local
- Um projeto Supabase. O de produção está em São Paulo (`sa-east-1`), ref `zvsomzsifdiqdnpywyul`

## Variáveis

Copie o exemplo e preencha a chave secreta:

```bash
cp .env.local.example .env.local
```

| Variável | Uso |
| --- | --- |
| `NEXT_PUBLIC_SUPABASE_URL` | URL do projeto. No exemplo: `https://zvsomzsifdiqdnpywyul.supabase.co` |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Chave publicável (`sb_publishable_...`). É pública e já está no exemplo. |
| `SUPABASE_SECRET_KEY` | Chave secreta do servidor (`sb_secret_...` no painel, ou a `service_role` do CLI local). Não commitar. |

`SUPABASE_SERVICE_ROLE_KEY` também é aceita, com o nome antigo.

Para desenvolver contra o **Supabase local**, troque a URL e as chaves pelos valores de `supabase status` (em geral `http://127.0.0.1:54321`).

O app usa `@supabase/supabase-js` 2.119, que aceita a chave publicável nova sem exigir um JWT.

## Rodar o app

```bash
npm install
npm run dev
```

O servidor de desenvolvimento sobe em [http://127.0.0.1:3847](http://127.0.0.1:3847).

```bash
npm test          # regras de status e de árvore
npm run lint
npm run build
npm run test:db   # RLS e status no Postgres local, depois do Supabase subir
npm run seed      # recria o banco local e carrega os dados fictícios
```

## Supabase local

O `config.toml` deixa o cadastro público desligado e não sobe Studio, Storage, Realtime nem Analytics, para o stack local ficar só com o que esta base usa (API, Auth e Postgres).

```bash
supabase start
supabase db reset     # migrações + supabase/seed.sql
supabase status       # URL, anon/publishable e service_role
```

O primeiro acesso da rede, com o banco vazio (sem o seed), fica em `/setup`: cria a discipuladora raiz, sem pastora. Isso exige `SUPABASE_SECRET_KEY`.

## Aplicar no projeto remoto

As migrações **não** foram enviadas daqui. Quem aplica é você, depois de revisar:

```bash
supabase link --project-ref zvsomzsifdiqdnpywyul
supabase db push
```

`db push` só envia o que está em `supabase/migrations`. O seed não vai junto.

No painel do projeto, em Authentication → Providers → Email, desligue os novos cadastros. O `enable_signup = false` do `config.toml` vale para o CLI local; o push do banco não altera essa chave do Auth.

A chave secreta fica só no `.env.local` (e, em produção, no ambiente do servidor). Não entra no repositório.

O projeto remoto expõe tabelas novas na Data API e não liga RLS sozinho. Cada tabela da migração habilita RLS, força RLS e cria políticas no mesmo arquivo. O `anon` não tem política: mesmo exposto, não lê nem grava.

## Seed

`supabase/seed.sql` cria uma rede fictícia, sem pastora e sem nomes reais:

- Ana Raiz e os líderes Bruno e Clara, com crianças em situações diferentes de presença.
- Diana Serra, outra discipuladora raiz, com o líder Edu. As duas árvores não se enxergam.
- Um relatório de junho de 2026 na célula do Bruno.
- Células com `pastor_id` nulo.

Senhas e e-mails estão no final da saída de `npm run seed`. São dados de desenvolvimento.

Para ligar uma pastora depois, sem migração de dados, veja `supabase/scripts/vincular-pastora.example.sql`.

## Regra de status

Vale para encontros de **célula**. Culto não entra. Só conta a chamada registrada: falta é uma linha com presença falsa; linha ausente não é falta.

| Situação | Efeito |
| --- | --- |
| Cadastro | visitante, sequências zeradas |
| 4 presenças consecutivas | vira membro; a sequência de presenças permanece |
| 4 ausências consecutivas de um membro | volta a visitante |
| Presença | zera a sequência de ausências |
| Ausência | zera a sequência de presenças |
| Primeira presença | grava `first_visit_on` e não muda mais |

O histórico fica em `child_status_history`. A função `internal.recompute_child_status` refaz o cálculo quando a chamada muda. O mesmo algoritmo está em `src/domain/child-status.ts`, coberto por teste.

A idade não é gravada. A view `children_with_age` calcula `age_years` e respeita o RLS.

## Hierarquia

`pastor` → `discipulador` → `lider`. O elo da pastora é opcional.

- Discipuladora com `supervisor_id` nulo é raiz.
- Líder sempre aponta para uma discipuladora.
- Cada um vê a si, quem está abaixo e o caminho até a raiz. Não vê a árvore ao lado.
- Ser admin não abre a árvore da outra discipuladora. O admin só cria o primeiro acesso e pode vincular uma pastora.
- `pastor_id` em pessoas e células pode ficar nulo. A visibilidade usa `supervisor_id`.

## Decisões em aberto

- A cor da célula (verde, azul, vermelha, bege) é um campo gravado. A regra que a define ainda não existe.
- A planilha tem um inteiro estreito ao lado do percentual. Ele está em `monthly_reports.indicador_final` até confirmarmos o que significa.
- "C Mista J" da planilha foi mapeado para o tipo `mista`. O resumo da planilha só separa crianças, juvenis e mistas.
- Mãe convertida e pai convertido estão como contagem do mês, porque a planilha mostra números.
- Falta só conta se alguém registrar a ausência. A tela de chamada, que pode marcar o restante como falta, vem depois.
