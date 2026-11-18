-- p_dia era smallint. Um literal inteiro (o 3 dos testes) e o número JSON
-- do supabase-js resolvem como integer, e o Postgres não converte integer
-- para smallint na hora de achar a função. A assinatura nova aceita integer,
-- valida 0–6 e grava smallint na célula. A assinatura antiga sai.

create or replace function public.multiplicar_celula(
  p_origem uuid,
  p_nome text,
  p_tipo text,
  p_lider uuid,
  p_dia integer,
  p_horario time,
  p_endereco text,
  p_data date,
  p_criancas uuid[] default '{}'::uuid[]
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  actor uuid := auth.uid();
  origem public.cells%rowtype;
  nova uuid;
  crianca record;
  ids uuid[];
begin
  perform internal.assert_can_manage_cell(actor, p_origem);

  if p_nome is null or length(btrim(p_nome)) < 2 then
    raise exception 'informe o nome da célula nova';
  end if;
  if p_tipo not in ('kids', 'juvenis', 'mista_juvenis') then
    raise exception 'escolha o tipo: Kids, Juvenis ou Mista com Juvenis';
  end if;
  if p_dia is null or p_dia < 0 or p_dia > 6 then
    raise exception 'escolha o dia da célula';
  end if;
  if p_horario is null then
    raise exception 'informe o horário da célula';
  end if;
  if p_endereco is null or length(btrim(p_endereco)) < 3 then
    raise exception 'informe o endereço';
  end if;
  if p_data is null then
    raise exception 'informe a data da multiplicação';
  end if;

  select * into origem from public.cells where id = p_origem;
  if not found then
    raise exception 'célula de origem não encontrada';
  end if;

  if not exists (
    select 1
    from public.profiles
    where id = p_lider
      and role = 'lider'
      and active
      and supervisor_id = origem.discipulador_id
  ) then
    raise exception 'esse líder não responde à discipuladora desta célula';
  end if;

  if not internal.can_write_cell_row(actor, p_lider, origem.discipulador_id, origem.pastor_id) then
    raise exception 'célula fora da sua árvore';
  end if;

  select coalesce(array_agg(distinct item), '{}'::uuid[])
    into ids
  from unnest(coalesce(p_criancas, '{}'::uuid[])) as item
  where item is not null;

  if exists (
    select 1
    from unnest(ids) as item
    where not exists (
      select 1 from public.children c
      where c.id = item
        and c.cell_id = p_origem
    )
  ) then
    raise exception 'há criança que não está na célula de origem';
  end if;

  insert into public.cells (
    name,
    network,
    pastor_id,
    discipulador_id,
    leader_id,
    address,
    weekday,
    meeting_time,
    cell_type,
    celula_origem_id,
    multiplied_on,
    active
  ) values (
    btrim(p_nome),
    origem.network,
    origem.pastor_id,
    origem.discipulador_id,
    p_lider,
    btrim(p_endereco),
    p_dia::smallint,
    p_horario,
    p_tipo,
    p_origem,
    p_data,
    true
  )
  returning id into nova;

  perform set_config('internal.moving_children', 'on', true);

  for crianca in
    select id, cell_id
    from public.children
    where id = any(ids)
    order by id
    for update
  loop
    update public.children
    set cell_id = nova
    where id = crianca.id;

    insert into public.child_transfers (
      child_id, from_cell_id, to_cell_id, transferred_on, transferred_by
    ) values (
      crianca.id, crianca.cell_id, nova, p_data, actor
    );
  end loop;

  perform set_config('internal.moving_children', 'off', true);
  return nova;
end;
$$;

drop function if exists public.multiplicar_celula(uuid, text, text, uuid, smallint, time, text, date, uuid[]);

revoke all on function public.multiplicar_celula(uuid, text, text, uuid, integer, time, text, date, uuid[]) from public, anon;
grant execute on function public.multiplicar_celula(uuid, text, text, uuid, integer, time, text, date, uuid[]) to authenticated;

comment on function public.multiplicar_celula(uuid, text, text, uuid, integer, time, text, date, uuid[]) is
  'Cria a célula filha, grava a mãe e a data, e move as crianças escolhidas sem levar a frequência antiga. p_dia é integer de 0 a 6.';

alter table public.cells enable row level security;
alter table public.cells force row level security;
alter table public.children enable row level security;
alter table public.children force row level security;
alter table public.child_transfers enable row level security;
alter table public.child_transfers force row level security;
