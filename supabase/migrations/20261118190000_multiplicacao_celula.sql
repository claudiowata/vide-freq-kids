-- Multiplicação de célula e remanejamento de crianças.
--
-- A célula nova guarda a célula mãe e a data. A criança muda de célula
-- levando status, sequências e dados dos pais. A frequência antiga permanece
-- na célula em que a presença aconteceu, então o fechamento passado não muda.
--
-- Só discipuladora ou quem está acima, e só em célula da própria subárvore.
-- O líder não chama as funções. A mudança de célula passa pela RPC: um update
-- direto é recusado.

alter table public.cells
  add column celula_origem_id uuid references public.cells (id) on delete restrict;

comment on column public.cells.celula_origem_id is
  'Célula mãe, quando esta célula nasceu de uma multiplicação.';
comment on column public.cells.multiplied_on is
  'Data da multiplicação que gerou esta célula. Nulo quando ela não nasceu de outra.';

create index cells_celula_origem_id_idx on public.cells (celula_origem_id);

create table public.child_transfers (
  id uuid primary key default gen_random_uuid(),
  child_id uuid not null references public.children (id) on delete restrict,
  from_cell_id uuid not null references public.cells (id) on delete restrict,
  to_cell_id uuid not null references public.cells (id) on delete restrict,
  transferred_on date not null,
  transferred_by uuid not null references public.profiles (id) on delete restrict,
  created_at timestamptz not null default now(),
  constraint child_transfers_cells_differ check (from_cell_id <> to_cell_id)
);

comment on table public.child_transfers is
  'Histórico de remanejamento: criança, célula de origem, célula de destino, data e quem fez.';

create index child_transfers_child_idx on public.child_transfers (child_id, transferred_on);
create index child_transfers_from_idx on public.child_transfers (from_cell_id);
create index child_transfers_to_idx on public.child_transfers (to_cell_id);

alter table public.child_transfers enable row level security;
alter table public.child_transfers force row level security;

create policy child_transfers_select on public.child_transfers
  for select to authenticated
  using (
    internal.can_see_cell_id(auth.uid(), from_cell_id)
    or internal.can_see_cell_id(auth.uid(), to_cell_id)
  );

grant select on public.child_transfers to anon, authenticated;

create or replace function internal.protect_child_cell_move()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if tg_op = 'UPDATE' and new.cell_id is distinct from old.cell_id then
    if current_setting('internal.moving_children', true) is distinct from 'on' then
      raise exception 'criança só muda de célula pela multiplicação ou pelo remanejamento';
    end if;
  end if;
  return new;
end;
$$;

create trigger children_protect_cell_move
  before update on public.children
  for each row execute function internal.protect_child_cell_move();

create or replace function internal.assert_can_manage_cell(actor uuid, cell uuid)
returns void
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if actor is null then
    raise exception 'é preciso estar autenticado';
  end if;
  if not exists (
    select 1
    from public.profiles
    where id = actor
      and active
      and role in ('pastor', 'discipulador')
  ) then
    raise exception 'só a discipuladora ou quem está acima pode multiplicar ou remanejar';
  end if;
  if not internal.can_edit_cell_id(actor, cell) then
    raise exception 'célula fora da sua árvore';
  end if;
end;
$$;

revoke all on function internal.assert_can_manage_cell(uuid, uuid) from public, anon, authenticated;

create or replace function public.multiplicar_celula(
  p_origem uuid,
  p_nome text,
  p_tipo text,
  p_lider uuid,
  p_dia smallint,
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
    p_dia,
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

  return nova;
end;
$$;

create or replace function public.remanejar_criancas(
  p_criancas uuid[],
  p_destino uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  actor uuid := auth.uid();
  crianca record;
  ids uuid[];
  n integer;
begin
  if p_criancas is null or cardinality(p_criancas) = 0 then
    raise exception 'escolha ao menos uma criança';
  end if;

  perform internal.assert_can_manage_cell(actor, p_destino);

  select coalesce(array_agg(distinct item), '{}'::uuid[])
    into ids
  from unnest(p_criancas) as item
  where item is not null;

  n := cardinality(ids);
  if n = 0 then
    raise exception 'escolha ao menos uma criança';
  end if;

  if (
    select count(*)
    from public.children c
    where c.id = any(ids)
  ) <> n then
    raise exception 'há criança fora da sua árvore';
  end if;

  perform set_config('internal.moving_children', 'on', true);

  for crianca in
    select id, cell_id
    from public.children
    where id = any(ids)
    order by id
    for update
  loop
    if crianca.cell_id = p_destino then
      raise exception 'a criança já está nessa célula';
    end if;
    perform internal.assert_can_manage_cell(actor, crianca.cell_id);

    update public.children
    set cell_id = p_destino
    where id = crianca.id;

    insert into public.child_transfers (
      child_id, from_cell_id, to_cell_id, transferred_on, transferred_by
    ) values (
      crianca.id, crianca.cell_id, p_destino, current_date, actor
    );
  end loop;
end;
$$;

revoke all on function public.multiplicar_celula(uuid, text, text, uuid, smallint, time, text, date, uuid[]) from public;
grant execute on function public.multiplicar_celula(uuid, text, text, uuid, smallint, time, text, date, uuid[]) to authenticated;

revoke all on function public.remanejar_criancas(uuid[], uuid) from public;
grant execute on function public.remanejar_criancas(uuid[], uuid) to authenticated;

comment on function public.multiplicar_celula(uuid, text, text, uuid, smallint, time, text, date, uuid[]) is
  'Cria a célula filha, grava a mãe e a data, e move as crianças escolhidas sem levar a frequência antiga.';
comment on function public.remanejar_criancas(uuid[], uuid) is
  'Move crianças entre células da mesma subárvore e grava a movimentação.';

alter table public.cells enable row level security;
alter table public.cells force row level security;
alter table public.children enable row level security;
alter table public.children force row level security;
alter table public.child_transfers enable row level security;
alter table public.child_transfers force row level security;
