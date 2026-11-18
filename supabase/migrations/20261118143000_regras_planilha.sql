-- Regras confirmadas da planilha de acompanhamento.
-- O projeto remoto não liga RLS sozinho: as tabelas tocadas continuam com RLS forçado.

-- Tipos de célula: Kids, Juvenis e Mista com Juvenis ("C Mista J").
do $$
declare
  constraint_name text;
begin
  select con.conname
  into constraint_name
  from pg_constraint con
  where con.conrelid = 'public.cells'::regclass
    and con.contype = 'c'
    and pg_get_constraintdef(con.oid) ilike '%cell_type%';

  if constraint_name is not null then
    execute format('alter table public.cells drop constraint %I', constraint_name);
  end if;
end $$;

update public.cells set cell_type = 'kids' where cell_type = 'criancas';
update public.cells set cell_type = 'mista_juvenis' where cell_type = 'mista';

alter table public.cells
  add constraint cells_cell_type_check
  check (cell_type in ('kids', 'juvenis', 'mista_juvenis'));

comment on column public.cells.cell_type is
  'kids (Kids), juvenis (Juvenis) ou mista_juvenis (Mista com Juvenis, a "C Mista J" da planilha).';
comment on column public.cells.color_classification is
  'VERDE, AZUL, VERMELHA ou BEGE. Ainda não há regra nem faixas: o valor é só um campo configurável.';

-- Mãe e pai convertidos são da criança, sim ou não. Null = não informado.
alter table public.children
  add column mae_convertida boolean,
  add column pai_convertido boolean;

comment on column public.children.mae_convertida is
  'A mãe desta criança é convertida? Sim/não. Não é um total do mês.';
comment on column public.children.pai_convertido is
  'O pai desta criança é convertido? Sim/não. Não é um total do mês.';

-- M, % e V do fechamento. M e % já existiam; V entra no lugar do indicador em aberto.
alter table public.monthly_reports
  drop column indicador_final,
  drop column mothers_converted,
  drop column fathers_converted;

alter table public.monthly_reports
  add column visitors_average numeric generated always as (
    internal.media_membros(w1_visitors, w2_visitors, w3_visitors, w4_visitors, w5_visitors)
  ) stored;

comment on column public.monthly_reports.members_average is
  'M: média do mês dos membros presentes. Semanas em branco ficam de fora.';
comment on column public.monthly_reports.attendance_percent is
  '%: M dividido pelo total de membros da célula, em percentual.';
comment on column public.monthly_reports.visitors_average is
  'V: média do mês dos visitantes. Semanas em branco ficam de fora.';

create or replace function internal.contagem_pais_convertidos(p_cell uuid)
returns table (maes integer, pais integer)
language sql
stable
security invoker
set search_path = public
as $$
  select
    count(*) filter (where mae_convertida)::integer,
    count(*) filter (where pai_convertido)::integer
  from public.children
  where cell_id = p_cell
$$;

comment on function internal.contagem_pais_convertidos(uuid) is
  'Totais da célula: crianças com mãe convertida e com pai convertido.';

grant execute on function internal.contagem_pais_convertidos(uuid) to anon, authenticated, service_role;

alter table public.cells enable row level security;
alter table public.cells force row level security;
alter table public.children enable row level security;
alter table public.children force row level security;
alter table public.monthly_reports enable row level security;
alter table public.monthly_reports force row level security;

do $$
declare
  missing text;
begin
  select string_agg(c.relname, ', ' order by c.relname)
  into missing
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relkind = 'r'
    and (
      c.relrowsecurity = false
      or c.relforcerowsecurity = false
      or not exists (select 1 from pg_policy pol where pol.polrelid = c.oid)
    );

  if missing is not null then
    raise exception 'tabelas públicas sem RLS forçado e política: %', missing;
  end if;
end $$;
