# Vide Freq Kids

Frequência e fechamento mensal das células de crianças e juvenis da rede **Radicais Kids**, na Igreja Videira Barra Funda. O app é um PWA em português, pensado primeiro para o celular, no mesmo espírito visual do VideFreq.

Esta unidade é a base: visual, login, banco e a regra de visitante/membro. As telas de chamada, fechamento e acompanhamento ainda são lugares reservados. No cadastro já dá para multiplicar uma célula e remanejar as crianças.

## O que já funciona

- Visual em verde-água, cartões brancos e a barra inferior com Início, Frequência, Fechamento, Acompanhar e Cadastro.
- Login por e-mail e senha. Não há cadastro público.
- Quem esquece a senha pede um link em `/esqueci-senha` e define outra em `/redefinir-senha`.
- Contas criadas pela liderança, com senha provisória e troca obrigatória no primeiro acesso.
- A rede pode existir **sem pastora**. A primeira discipuladora nasce como raiz e admin.
- Uma pastora pode ser colocada acima das discipuladoras que já existem, sem reescrever células, crianças ou relatórios.
- Cada pessoa vê só a própria árvore.
- Criança começa visitante, vira membro com 4 presenças consecutivas de célula e volta a visitante com 8 faltas consecutivas.

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

## Recuperação de senha no painel

O app pede o e-mail em `/esqueci-senha` e chama `resetPasswordForEmail` com retorno em `/auth/callback?next=/redefinir-senha`. O callback troca o `code` (PKCE) pela sessão, ou o `token_hash` com `type=recovery`, e só então abre `/redefinir-senha`. Nada disso entra no repositório como chave secreta.

O projeto remoto ainda não tem um site Netlify publicado. Use a origem real do site no Netlify, sem barra no final, no lugar de `https://SEU-SITE.netlify.app`.

Em Authentication → URL Configuration:

| Campo | Valor |
| --- | --- |
| Site URL | `https://SEU-SITE.netlify.app` |
| Redirect URLs | `https://SEU-SITE.netlify.app/**` |
| Redirect URLs | `http://127.0.0.1:3847/**` |
| Redirect URLs | `http://localhost:3847/**` |

O `redirectTo` leva query (`next` e, no fluxo PKCE, `sb_flow_id`). O curinga `/**` cobre o caminho `/auth/callback` e essa query. Se o projeto só aceitar URL exata, acrescente também:

- `https://SEU-SITE.netlify.app/auth/callback`
- `http://127.0.0.1:3847/auth/callback`
- `http://localhost:3847/auth/callback`

Salve. Sem essas URLs o Supabase ignora o retorno do app e o link do e-mail não abre a tela de nova senha.

Em Authentication → Emails (ou Email Templates) → Reset Password, assunto:

```
Redefinir a senha do Vide Freq Kids
```

Corpo, em HTML:

```html
<h2>Redefinir senha</h2>
<p>Recebemos um pedido para criar uma nova senha no Vide Freq Kids.</p>
<p><a href="{{ .ConfirmationURL }}">Criar uma nova senha</a></p>
<p>Se você não pediu isso, ignore este e-mail. O link vale por 1 hora e só pode ser usado uma vez.</p>
```

`{{ .ConfirmationURL }}` é o fluxo PKCE: o Supabase devolve o navegador para `/auth/callback` com `code`. O mesmo arquivo está em `supabase/templates/recovery.html` para o Supabase local.

Se o template for o formato `token_hash`, o app também aceita. O link precisa apontar para o callback com `type=recovery`:

```html
<p><a href="{{ .SiteURL }}/auth/callback?token_hash={{ .TokenHash }}&type=recovery&next=/redefinir-senha">Criar uma nova senha</a></p>
```

Nesse caso a Site URL tem de ser a origem do app (Netlify ou `http://127.0.0.1:3847`), sem barra no final.

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
| 8 ausências consecutivas de um membro | volta a visitante |
| Presença | zera a sequência de ausências |
| Ausência | zera a sequência de presenças |
| Semana com o outro responsável | neutra: não é presença nem falta e não quebra a sequência |
| Primeira presença | grava `first_visit_on` e não muda mais |

Guarda compartilhada fica no cadastro da criança (`guarda_compartilhada`, rótulo "Guarda compartilhada (uma semana com cada responsável)"). Na chamada, só essa criança vê a terceira opção, **Semana com o outro responsável**. Quatro presenças intercaladas com essas semanas neutras contam como quatro seguidas. Sem o campo marcado, a opção não aparece.

No fechamento, M, % e V ignoram a semana que só tem essa marca neutra: ela não entra como falta nem como semana zerada. Uma falta registrada continua abaixando a média de membros presentes.

A guarda compartilhada e a volta com 8 faltas estão em `supabase/migrations/20261118210000_status_guarda_compartilhada.sql`. O status gravado só muda na virada do mês. Lançar frequência no mês aberto atualiza as sequências e não o status. No fechamento, ou na primeira avaliação de um mês novo, a sequência é lida até o fim do mês anterior — e ela atravessa meses. `children.status_avaliado_ate` guarda esse fim de mês: fechar de novo o mesmo período, com a mesma chamada, não altera o resultado, e fechar um mês anterior não volta o horizonte. A volta a visitante grava `oito_ausencias_consecutivas`. O algoritmo está em `src/domain/child-status.ts` e em `public.fechar_status_do_mes`. A migration da virada é `supabase/migrations/20261118220000_status_virada_mes.sql`.

A idade não é gravada. A view `children_with_age` calcula `age_years` e respeita o RLS.

## Hierarquia

`pastor` → `discipulador` → `lider`. Uma discipuladora também pode ficar abaixo de outra discipuladora. O elo da pastora é opcional.

- Discipuladora com `supervisor_id` nulo é raiz.
- Líder sempre aponta para uma discipuladora.
- Cada um vê a si, quem está abaixo e o caminho até a raiz. Não vê a árvore ao lado.
- Discipuladora, a raiz dessa árvore e quem está acima (a pastora, quando existe) têm leitura de todo o cadastro das células abaixo. Entram a ficha da célula, os líderes, as crianças com responsáveis, telefones, mãe e pai convertidos e status, a frequência e os fechamentos. A subárvore de uma discipuladora subordinada entra nessa leitura.
- Líder de célula vê só a própria célula: não vê a célula ao lado nem a de uma discipuladora subordinada.
- Discipuladora de outro ramo não vê essa árvore.
- Ser admin não abre a árvore da outra discipuladora. O admin só cria o primeiro acesso e pode vincular uma pastora.
- `pastor_id` em pessoas e células pode ficar nulo. A visibilidade usa `supervisor_id`.

A hierarquia que aceita discipuladora subordinada está em `supabase/migrations/20261118180000_acesso_leitura_discipuladora.sql`. As políticas de leitura da foundation já percorrem `supervisor_id`; essa migration não as substitui. O teste de RLS está em `supabase/tests/acesso-discipuladora.sql`.

## Multiplicação de célula

No cadastro, a discipuladora (ou quem está acima dela) abre **Multiplicar célula**. A célula nova recebe nome, tipo — Kids, Juvenis ou Mista com Juvenis (C Mista J) —, líder da mesma discipuladora, dia, horário e endereço. Ela guarda a célula mãe em `celula_origem_id` e a data em `multiplied_on`.

As crianças marcadas vão para a célula nova com status, presenças e faltas seguidas e os dados dos pais. A frequência antiga permanece nos encontros da célula de origem, então o fechamento daquele mês não muda. O mesmo vale para **Remanejar crianças** entre duas células que já existem na subárvore.

Cada mudança fica em `child_transfers` (criança, de, para, data, quem fez). Líder não multiplica nem remaneja, e uma discipuladora não mexe em célula de outro ramo. As funções `multiplicar_celula` e `remanejar_criancas` fazem a checagem e a gravação na mesma transação. Um update direto de `children.cell_id` é recusado.

A migration é `supabase/migrations/20261118190000_multiplicacao_celula.sql`. O teste de RLS está em `supabase/tests/multiplicacao-celula.sql`.

## Fechamento e ficha

No fim de cada linha do mês:

- **M** (`members_average`): média dos membros presentes nas semanas preenchidas.
- **%** (`attendance_percent`): essa média dividida pelo total de membros da célula.
- **V** (`visitors_average`): média dos visitantes nas semanas preenchidas.

`mae_convertida` e `pai_convertido` ficam em cada criança. O fechamento pode somar quantas têm mãe ou pai convertido (`internal.contagem_pais_convertidos`).

O tipo da célula é `kids` (Kids), `juvenis` (Juvenis) ou `mista_juvenis` (Mista com Juvenis, o "C Mista J" da planilha).

## Identidade

O logo oficial está em `public/brand/logo-radicais-kids.png` (personagem e a palavra KIDS). O recorte só do personagem, usado no cabeçalho e nos ícones, está em `public/brand/logo-radicais-kids-mark.png`.

Paleta amostrada do arquivo, com contraste AA no texto e nos botões:

| Papel | Cor |
| --- | --- |
| Texto | `#3E145C` |
| Botão e roxo do contorno | `#682A86` |
| Amarelo | `#FFC50F` |
| Teal do olho e do D | `#0098B5` |
| Magenta do sorriso e do I | `#C31A77` |
| Fundo | `#FFF8EE` |

O amarelo e o teal claro ficam em destaque e no logo. Texto pequeno usa o roxo, que passa de 8:1 sobre o branco.

## Decisões em aberto

- A cor da célula (verde, azul, vermelha, bege) continua só um campo gravado. Ainda não há faixas nem regra.
- Falta só conta se alguém registrar a ausência. A chamada marca presente, falta ou, na guarda compartilhada, a semana com o outro responsável.
