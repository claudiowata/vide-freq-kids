-- Leitura do cadastro para discipuladora e quem está acima.
--
-- A discipuladora, a raiz da árvore dela e os papéis acima (a pastora, se
-- existir) leem todo o cadastro das células abaixo na cadeia supervisor_id.
-- Isso inclui a subárvore de uma discipuladora subordinada: ficha da célula,
-- líder, crianças (responsáveis, telefones, mãe e pai convertidos, status),
-- frequência e fechamento.
--
-- O líder continua vendo só a própria célula. Outro ramo não entra.
-- Ser admin não abre a árvore ao lado.
--
-- As políticas de SELECT da foundation já caminham por supervisor_id
-- (internal.subject_in_downward_tree). O que faltava era a hierarquia aceitar
-- uma discipuladora abaixo de outra. Esta migration não reescreve dados já
-- gravados e não edita as migrations anteriores.

-- Discipuladora herda o atalho pastor_id de quem está acima:
-- pastora direta, ou a discipuladora superior (que pode ter pastor_id nulo).
create or replace function internal.sync_pastor_link()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  parent_role text;
  parent_pastor uuid;
begin
  if new.role = 'pastor' then
    new.supervisor_id := null;
    new.pastor_id := null;
  elsif new.role = 'discipulador' then
    if new.supervisor_id is null then
      new.pastor_id := null;
    else
      select role, pastor_id into parent_role, parent_pastor
      from public.profiles
      where id = new.supervisor_id;
      if parent_role = 'pastor' then
        new.pastor_id := new.supervisor_id;
      elsif parent_role = 'discipulador' then
        new.pastor_id := parent_pastor;
      else
        new.pastor_id := null;
      end if;
    end if;
  elsif new.role = 'lider' then
    select pastor_id into parent_pastor
    from public.profiles
    where id = new.supervisor_id;
    new.pastor_id := parent_pastor;
  end if;
  return new;
end;
$$;

create or replace function internal.validate_profile_hierarchy()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  sup_role text;
  sup_pastor uuid;
begin
  if new.role = 'pastor' then
    if new.supervisor_id is not null or new.pastor_id is not null then
      raise exception 'pastor não tem superior';
    end if;
  elsif new.role = 'discipulador' then
    if new.supervisor_id is null then
      if new.pastor_id is not null then
        raise exception 'discipulador sem superior não pode apontar para uma pastora';
      end if;
    else
      select role, pastor_id into sup_role, sup_pastor
      from public.profiles
      where id = new.supervisor_id;
      if sup_role = 'pastor' then
        if new.pastor_id is distinct from new.supervisor_id then
          raise exception 'pastor_id do discipulador deve ser o próprio pastor';
        end if;
      elsif sup_role = 'discipulador' then
        if new.pastor_id is distinct from sup_pastor then
          raise exception 'pastor_id do discipulador deve acompanhar quem está acima, e pode ser nulo';
        end if;
      else
        raise exception 'discipulador só pode responder a um pastor ou a outro discipulador';
      end if;
    end if;
  elsif new.role = 'lider' then
    if new.supervisor_id is null then
      raise exception 'líder precisa de um discipulador';
    end if;
    select role, pastor_id into sup_role, sup_pastor
    from public.profiles
    where id = new.supervisor_id;
    if sup_role is distinct from 'discipulador' then
      raise exception 'líder responde a um discipulador';
    end if;
    if new.pastor_id is distinct from sup_pastor then
      raise exception 'pastor_id do líder deve acompanhar o discipulador, e pode ser nulo';
    end if;
  end if;

  if new.supervisor_id is not null
     and internal.subject_in_downward_tree(new.id, new.supervisor_id) then
    raise exception 'ciclo na hierarquia';
  end if;
  return new;
end;
$$;

-- O atalho pastor_id desce para líderes e para discipuladoras subordinadas.
-- Células não são reescritas.
create or replace function internal.cascade_pastor_to_leaders()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.role = 'discipulador'
     and new.pastor_id is distinct from old.pastor_id then
    update public.profiles
    set pastor_id = new.pastor_id
    where supervisor_id = new.id
      and role in ('lider', 'discipulador');
  end if;
  return new;
end;
$$;

comment on function internal.can_see_profile(uuid, uuid) is
  'Leitura: a pessoa vê a si, quem está abaixo na cadeia supervisor_id (inclusive discipuladora subordinada e os líderes dela) e o caminho até a raiz. Não vê outro ramo.';

comment on function internal.can_see_cell(uuid, uuid, uuid, uuid) is
  'Leitura da ficha da célula para quem está acima do líder ou da discipuladora na árvore, ou é a pastora gravada na célula. O líder só alcança a própria célula.';

-- As tabelas já existentes continuam com RLS forçado. Nenhuma fica aberta.
alter table public.profiles enable row level security;
alter table public.profiles force row level security;
alter table public.cells enable row level security;
alter table public.cells force row level security;
alter table public.children enable row level security;
alter table public.children force row level security;
alter table public.child_status_history enable row level security;
alter table public.child_status_history force row level security;
alter table public.meetings enable row level security;
alter table public.meetings force row level security;
alter table public.attendance enable row level security;
alter table public.attendance force row level security;
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
