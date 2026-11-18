-- Vide Freq Kids — base de dados
--
-- O projeto remoto expõe tabelas novas automaticamente e NÃO liga RLS sozinho.
-- Cada tabela criada aqui habilita RLS (e FORCE) e recebe políticas no mesmo arquivo.
-- O schema `internal` fica fora da Data API (config.toml só publica `public`).

create schema if not exists internal;

revoke all on schema internal from public;
grant usage on schema internal to anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Funções de apoio
-- ---------------------------------------------------------------------------

create or replace function internal.touch_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- Idade em anos completos. Não é coluna gravada: depende da data de hoje.
create or replace function internal.idade_anos(nascimento date)
returns integer
language sql
stable
set search_path = public
as $$
  select case
    when nascimento is null or nascimento > current_date then null
    else extract(year from age(current_date, nascimento))::integer
  end
$$;

comment on function internal.idade_anos(date) is
  'Idade em anos completos. Calculada, nunca armazenada.';

-- Média dos membros presentes nas semanas preenchidas (planilha: coluna Média).
create or replace function internal.media_membros(
  w1 integer,
  w2 integer,
  w3 integer,
  w4 integer,
  w5 integer
)
returns numeric
language sql
immutable
set search_path = public
as $$
  select case
    when count(v) = 0 then null
    else round(avg(v), 0)
  end
  from unnest(array[w1, w2, w3, w4, w5]) as v
  where v is not null
$$;

create or replace function internal.percentual_presenca(media numeric, membros integer)
returns numeric
language sql
immutable
set search_path = public
as $$
  select case
    when media is null or membros is null or membros <= 0 then null
    else round((media / membros) * 100, 0)
  end
$$;

-- ---------------------------------------------------------------------------
-- Pessoas com login: pastor(a) > discipulador(a) > líder
-- A pastora é opcional. Uma discipuladora pode ser a raiz da árvore.
-- A fonte da árvore é supervisor_id. pastor_id é um atalho anulável,
-- preenchido pelo trigger quando existe pastora — não é obrigatório
-- para enxergar a célula.
-- ---------------------------------------------------------------------------

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text not null,
  email text not null,
  phone text,
  birth_date date,
  role text not null check (role in ('pastor', 'discipulador', 'lider')),
  supervisor_id uuid references public.profiles (id) on delete restrict,
  pastor_id uuid references public.profiles (id) on delete set null,
  has_ctl boolean,
  is_admin boolean not null default false,
  must_change_password boolean not null default true,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_supervisor_not_self check (supervisor_id is null or supervisor_id <> id),
  constraint profiles_pastor_not_self check (pastor_id is null or pastor_id <> id),
  constraint profiles_email_unique unique (email)
);

comment on table public.profiles is
  'Contas da liderança. A pastora pode não existir: discipulador com supervisor_id nulo é raiz.';
comment on column public.profiles.pastor_id is
  'Atalho anulável. A visibilidade usa a cadeia supervisor_id e continua valendo quando isto é nulo.';
comment on column public.profiles.is_admin is
  'A primeira discipuladora da rede nasce como admin raiz. Não amplia a árvore que ela enxerga.';

create index profiles_supervisor_id_idx on public.profiles (supervisor_id);
create index profiles_pastor_id_idx on public.profiles (pastor_id);
create index profiles_role_idx on public.profiles (role);

-- No máximo uma discipuladora admin sem pastora (o primeiro acesso).
create unique index profiles_one_admin_root
  on public.profiles ((true))
  where is_admin and role = 'discipulador' and supervisor_id is null;

create trigger profiles_touch
  before update on public.profiles
  for each row execute function internal.touch_updated_at();

-- Sujeito está na árvore para baixo do observador (inclui o próprio).
create or replace function internal.subject_in_downward_tree(viewer uuid, subject uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  with recursive chain as (
    select id, supervisor_id, 1 as depth
    from public.profiles
    where id = subject
      and viewer is not null
    union all
    select p.id, p.supervisor_id, c.depth + 1
    from public.profiles p
    join chain c on c.supervisor_id = p.id
    where c.depth < 8
  )
  select exists (select 1 from chain where id = viewer);
$$;

create or replace function internal.is_ancestor(ancestor uuid, person uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select ancestor is not null
    and person is not null
    and ancestor <> person
    and internal.subject_in_downward_tree(ancestor, person);
$$;

-- Vê a si, quem está abaixo e quem está no caminho até a raiz.
-- Não vê irmãos nem a árvore de outra discipuladora raiz.
create or replace function internal.can_see_profile(viewer uuid, subject uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select internal.subject_in_downward_tree(viewer, subject)
    or internal.is_ancestor(subject, viewer);
$$;

create or replace function internal.actor_can_manage_person(viewer uuid, subject uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles me
    where me.id = viewer
      and me.active
      and me.role in ('pastor', 'discipulador')
      and internal.is_ancestor(viewer, subject)
  );
$$;

create or replace function internal.sync_pastor_link()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  parent_pastor uuid;
begin
  if new.role = 'pastor' then
    new.supervisor_id := null;
    new.pastor_id := null;
  elsif new.role = 'discipulador' then
    if new.supervisor_id is null then
      new.pastor_id := null;
    else
      select id into parent_pastor
      from public.profiles
      where id = new.supervisor_id
        and role = 'pastor';
      new.pastor_id := parent_pastor;
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

create trigger profiles_sync_pastor
  before insert or update on public.profiles
  for each row execute function internal.sync_pastor_link();

-- Papel, vínculo e senha provisória não mudam pelo cliente.
-- service_role e postgres (trigger de auth, seed, vincular_pastor) podem.
create or replace function internal.protect_profile_privileges()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if current_user in ('postgres', 'supabase_admin', 'service_role', 'supabase_auth_admin')
     or current_setting('internal.managing_accounts', true) = 'on' then
    return new;
  end if;
  if tg_op = 'INSERT' then
    raise exception 'criação de conta é feita pela liderança';
  end if;
  new.role := old.role;
  new.supervisor_id := old.supervisor_id;
  new.pastor_id := old.pastor_id;
  new.is_admin := old.is_admin;
  new.must_change_password := old.must_change_password;
  return new;
end;
$$;

create trigger profiles_protect_privileges
  before insert or update on public.profiles
  for each row execute function internal.protect_profile_privileges();

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
      select role into sup_role from public.profiles where id = new.supervisor_id;
      if sup_role is distinct from 'pastor' then
        raise exception 'discipulador só pode responder a um pastor';
      end if;
      if new.pastor_id is distinct from new.supervisor_id then
        raise exception 'pastor_id do discipulador deve ser o próprio pastor';
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

create trigger profiles_validate_hierarchy
  after insert or update on public.profiles
  for each row execute function internal.validate_profile_hierarchy();

-- Quando a discipuladora passa a ter pastora, os líderes herdam o atalho.
-- Células não são reescritas: pastor_id da célula pode continuar nulo.
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
      and role = 'lider';
  end if;
  return new;
end;
$$;

create trigger profiles_cascade_pastor
  after update on public.profiles
  for each row execute function internal.cascade_pastor_to_leaders();

alter table public.profiles enable row level security;
alter table public.profiles force row level security;

create policy profiles_select on public.profiles
  for select to authenticated
  using (internal.can_see_profile(auth.uid(), id));

create policy profiles_update on public.profiles
  for update to authenticated
  using (
    id = auth.uid()
    or internal.actor_can_manage_person(auth.uid(), id)
  )
  with check (
    id = auth.uid()
    or internal.actor_can_manage_person(auth.uid(), id)
  );

-- ---------------------------------------------------------------------------
-- Células — ficha de recadastramento
-- ---------------------------------------------------------------------------

create table public.cells (
  id uuid primary key default gen_random_uuid(),
  name text,
  network text not null default 'Radicais Kids',
  pastor_id uuid references public.profiles (id) on delete set null,
  discipulador_id uuid not null references public.profiles (id) on delete restrict,
  leader_id uuid not null references public.profiles (id) on delete restrict,
  leader_birth_date date,
  leader_has_ctl boolean,
  trainee_name text,
  trainee_birth_date date,
  trainee_encontro boolean,
  trainee_batismo boolean,
  trainee_maturidade boolean,
  trainee_ctl boolean,
  trainee_profile_id uuid references public.profiles (id) on delete set null,
  host_name text,
  host_is_believer boolean,
  address text,
  weekday smallint check (weekday is null or weekday between 0 and 6),
  meeting_time time,
  is_parallel boolean not null default false,
  started_on date,
  multiplied_on date,
  cell_type text not null check (cell_type in ('criancas', 'juvenis', 'mista')),
  color_classification text check (
    color_classification is null
    or color_classification in ('verde', 'azul', 'vermelha', 'bege')
  ),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.cells is
  'Ficha da Célula Kids e Juvenis. pastor_id é anulável de propósito.';
comment on column public.cells.weekday is '0 = domingo … 6 = sábado.';
comment on column public.cells.color_classification is
  'VERDE, AZUL, VERMELHA ou BEGE. A regra de cálculo ainda não está definida; o valor é gravado.';
comment on column public.cells.cell_type is
  'criancas, juvenis ou mista. "C Mista J" da planilha corresponde a mista.';
comment on column public.cells.leader_has_ctl is 'CTL do líder, como na ficha (sim/não).';
comment on column public.cells.trainee_name is 'Líder em treinamento (LT).';
comment on column public.cells.host_name is 'Anfitrião.';
comment on column public.cells.host_is_believer is 'Anfitrião é crente?';
comment on column public.cells.is_parallel is 'Paralela ou não paralela.';

create index cells_discipulador_id_idx on public.cells (discipulador_id);
create index cells_leader_id_idx on public.cells (leader_id);
create index cells_pastor_id_idx on public.cells (pastor_id);

create trigger cells_touch
  before update on public.cells
  for each row execute function internal.touch_updated_at();

create or replace function internal.can_see_cell(
  viewer uuid,
  leader uuid,
  discipulador uuid,
  pastor uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select internal.subject_in_downward_tree(viewer, leader)
    or internal.subject_in_downward_tree(viewer, discipulador)
    or (pastor is not null and pastor = viewer);
$$;

create or replace function internal.can_see_cell_id(viewer uuid, cell uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.cells c
    where c.id = cell
      and internal.can_see_cell(viewer, c.leader_id, c.discipulador_id, c.pastor_id)
  );
$$;

create or replace function internal.can_write_cell_row(
  viewer uuid,
  leader uuid,
  discipulador uuid,
  pastor uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles me
    where me.id = viewer
      and me.active
      and me.role in ('pastor', 'discipulador')
      and (
        discipulador = viewer
        or internal.is_ancestor(viewer, discipulador)
        or (pastor is not null and pastor = viewer)
      )
  )
  and exists (
    select 1
    from public.profiles l
    where l.id = leader
      and l.role = 'lider'
      and l.supervisor_id = discipulador
  );
$$;

create or replace function internal.can_edit_cell_id(viewer uuid, cell uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.cells c
    where c.id = cell
      and internal.can_write_cell_row(viewer, c.leader_id, c.discipulador_id, c.pastor_id)
  );
$$;

-- Líder da célula, a discipuladora dela, ou a pastora acima (mesmo com pastor_id nulo).
create or replace function internal.can_take_attendance(viewer uuid, cell uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.cells c
    where c.id = cell
      and (
        c.leader_id = viewer
        or c.discipulador_id = viewer
        or internal.is_ancestor(viewer, c.discipulador_id)
        or (c.pastor_id is not null and c.pastor_id = viewer)
      )
  );
$$;

alter table public.cells enable row level security;
alter table public.cells force row level security;

create policy cells_select on public.cells
  for select to authenticated
  using (internal.can_see_cell(auth.uid(), leader_id, discipulador_id, pastor_id));

create policy cells_insert on public.cells
  for insert to authenticated
  with check (internal.can_write_cell_row(auth.uid(), leader_id, discipulador_id, pastor_id));

create policy cells_update on public.cells
  for update to authenticated
  using (internal.can_edit_cell_id(auth.uid(), id))
  with check (internal.can_write_cell_row(auth.uid(), leader_id, discipulador_id, pastor_id));

create policy cells_delete on public.cells
  for delete to authenticated
  using (internal.can_edit_cell_id(auth.uid(), id));

-- ---------------------------------------------------------------------------
-- Crianças e jovens da ficha
-- ---------------------------------------------------------------------------

create table public.children (
  id uuid primary key default gen_random_uuid(),
  cell_id uuid not null references public.cells (id) on delete cascade,
  full_name text not null,
  birth_date date,
  parents_are_believers boolean,
  phone text,
  guardians text,
  authorized_pickup text,
  allergies_medication text,
  image_authorization boolean,
  encontro boolean,
  batismo boolean,
  culto boolean,
  status text not null default 'visitante' check (status in ('visitante', 'membro')),
  presence_streak integer not null default 0 check (presence_streak >= 0),
  absence_streak integer not null default 0 check (absence_streak >= 0),
  first_visit_on date,
  registered_on date not null default current_date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.children is
  'Crianças e jovens. Toda pessoa começa visitante. Status e sequências são calculados.';
comment on column public.children.parents_are_believers is 'Pais crentes, como na ficha.';
comment on column public.children.guardians is 'Responsáveis.';
comment on column public.children.authorized_pickup is 'Quem pode buscar.';
comment on column public.children.allergies_medication is 'Alergias e medicação.';
comment on column public.children.image_authorization is 'Autorização de imagem.';
comment on column public.children.culto is 'Frequenta o culto (flag da ficha, não é a chamada).';

create index children_cell_id_idx on public.children (cell_id);
create index children_status_idx on public.children (status);

create trigger children_touch
  before update on public.children
  for each row execute function internal.touch_updated_at();

create or replace function internal.protect_child_status()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if current_setting('internal.recomputing', true) = 'on' then
    return new;
  end if;
  if tg_op = 'INSERT' then
    new.status := 'visitante';
    new.presence_streak := 0;
    new.absence_streak := 0;
    new.first_visit_on := null;
    return new;
  end if;
  if new.status is distinct from old.status
     or new.presence_streak is distinct from old.presence_streak
     or new.absence_streak is distinct from old.absence_streak
     or new.first_visit_on is distinct from old.first_visit_on then
    raise exception 'status, sequências e primeira visita são calculados pela frequência';
  end if;
  return new;
end;
$$;

create trigger children_protect_status
  before insert or update on public.children
  for each row execute function internal.protect_child_status();

create table public.child_status_history (
  id uuid primary key default gen_random_uuid(),
  child_id uuid not null references public.children (id) on delete cascade,
  from_status text check (from_status is null or from_status in ('visitante', 'membro')),
  to_status text not null check (to_status in ('visitante', 'membro')),
  changed_on date not null,
  reason text not null check (
    reason in (
      'cadastro_inicial',
      'quatro_presencas_consecutivas',
      'quatro_ausencias_consecutivas'
    )
  ),
  created_at timestamptz not null default now()
);

comment on table public.child_status_history is
  'Mudanças datadas de visitante/membro. A chamada da célula reescreve as transições calculadas.';

create index child_status_history_child_id_idx
  on public.child_status_history (child_id, changed_on);

create or replace function internal.on_child_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.child_status_history (child_id, from_status, to_status, changed_on, reason)
  values (new.id, null, 'visitante', coalesce(new.registered_on, current_date), 'cadastro_inicial');
  return new;
end;
$$;

create trigger children_history_on_insert
  after insert on public.children
  for each row execute function internal.on_child_insert();

create or replace function internal.can_see_child(viewer uuid, child uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.children ch
    join public.cells c on c.id = ch.cell_id
    where ch.id = child
      and internal.can_see_cell(viewer, c.leader_id, c.discipulador_id, c.pastor_id)
  );
$$;

alter table public.children enable row level security;
alter table public.children force row level security;

create policy children_select on public.children
  for select to authenticated
  using (internal.can_see_child(auth.uid(), id));

create policy children_insert on public.children
  for insert to authenticated
  with check (internal.can_take_attendance(auth.uid(), cell_id));

create policy children_update on public.children
  for update to authenticated
  using (internal.can_take_attendance(auth.uid(), cell_id))
  with check (internal.can_take_attendance(auth.uid(), cell_id));

create policy children_delete on public.children
  for delete to authenticated
  using (
    exists (
      select 1 from public.cells c
      where c.id = cell_id
        and internal.can_edit_cell_id(auth.uid(), c.id)
    )
  );

alter table public.child_status_history enable row level security;
alter table public.child_status_history force row level security;

create policy child_status_history_select on public.child_status_history
  for select to authenticated
  using (internal.can_see_child(auth.uid(), child_id));

-- ---------------------------------------------------------------------------
-- Encontros e frequência
-- Só encontro de célula (kind = celula) mexe em visitante/membro.
-- Ausência só conta quando existe linha com present = false.
-- ---------------------------------------------------------------------------

create table public.meetings (
  id uuid primary key default gen_random_uuid(),
  cell_id uuid not null references public.cells (id) on delete cascade,
  held_on date not null,
  kind text not null default 'celula' check (kind in ('celula', 'culto')),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (cell_id, held_on, kind)
);

comment on table public.meetings is
  'Encontros da célula ou culto. O culto não altera o status da criança.';

create index meetings_cell_held_idx on public.meetings (cell_id, held_on);

create trigger meetings_touch
  before update on public.meetings
  for each row execute function internal.touch_updated_at();

alter table public.meetings enable row level security;
alter table public.meetings force row level security;

create policy meetings_select on public.meetings
  for select to authenticated
  using (internal.can_see_cell_id(auth.uid(), cell_id));

create policy meetings_insert on public.meetings
  for insert to authenticated
  with check (internal.can_take_attendance(auth.uid(), cell_id));

create policy meetings_update on public.meetings
  for update to authenticated
  using (internal.can_take_attendance(auth.uid(), cell_id))
  with check (internal.can_take_attendance(auth.uid(), cell_id));

create policy meetings_delete on public.meetings
  for delete to authenticated
  using (internal.can_take_attendance(auth.uid(), cell_id));

create table public.attendance (
  id uuid primary key default gen_random_uuid(),
  meeting_id uuid not null references public.meetings (id) on delete cascade,
  child_id uuid not null references public.children (id) on delete cascade,
  present boolean not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (meeting_id, child_id)
);

comment on table public.attendance is
  'Chamada. present = false é ausência explícita e entra na sequência.';

create index attendance_child_id_idx on public.attendance (child_id);

create trigger attendance_touch
  before update on public.attendance
  for each row execute function internal.touch_updated_at();

-- 4 presenças consecutivas de célula: visitante vira membro.
-- 4 ausências consecutivas de célula: membro volta a visitante.
-- Uma presença zera a sequência de ausências, e o contrário também.
-- O algoritmo espelha src/domain/child-status.ts.
create or replace function internal.recompute_child_status(p_child uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  mark record;
  v_status text := 'visitante';
  v_presence integer := 0;
  v_absence integer := 0;
  v_first date := null;
  v_prev text;
begin
  perform set_config('internal.recomputing', 'on', true);

  delete from public.child_status_history
  where child_id = p_child
    and reason <> 'cadastro_inicial';

  for mark in
    select a.present, m.held_on
    from public.attendance a
    join public.meetings m on m.id = a.meeting_id
    where a.child_id = p_child
      and m.kind = 'celula'
    order by m.held_on, m.created_at, a.created_at
  loop
    v_prev := v_status;
    if mark.present then
      if v_first is null then
        v_first := mark.held_on;
      end if;
      v_presence := v_presence + 1;
      v_absence := 0;
      if v_status = 'visitante' and v_presence >= 4 then
        v_status := 'membro';
      end if;
    else
      v_presence := 0;
      v_absence := v_absence + 1;
      if v_status = 'membro' and v_absence >= 4 then
        v_status := 'visitante';
      end if;
    end if;

    if v_status is distinct from v_prev then
      insert into public.child_status_history (
        child_id, from_status, to_status, changed_on, reason
      )
      values (
        p_child,
        v_prev,
        v_status,
        mark.held_on,
        case
          when v_status = 'membro' then 'quatro_presencas_consecutivas'
          else 'quatro_ausencias_consecutivas'
        end
      );
    end if;
  end loop;

  update public.children
  set status = v_status,
      presence_streak = v_presence,
      absence_streak = v_absence,
      first_visit_on = v_first
  where id = p_child;
end;
$$;

create or replace function internal.attendance_same_cell()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  meeting_cell uuid;
  child_cell uuid;
begin
  select cell_id into meeting_cell from public.meetings where id = new.meeting_id;
  select cell_id into child_cell from public.children where id = new.child_id;
  if meeting_cell is null or child_cell is null or meeting_cell <> child_cell then
    raise exception 'a criança não pertence à célula deste encontro';
  end if;
  return new;
end;
$$;

create trigger attendance_same_cell
  before insert or update on public.attendance
  for each row execute function internal.attendance_same_cell();

create or replace function internal.on_attendance_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'DELETE' then
    perform internal.recompute_child_status(old.child_id);
    return old;
  end if;
  perform internal.recompute_child_status(new.child_id);
  if tg_op = 'UPDATE' and old.child_id is distinct from new.child_id then
    perform internal.recompute_child_status(old.child_id);
  end if;
  return new;
end;
$$;

create trigger attendance_recompute
  after insert or update or delete on public.attendance
  for each row execute function internal.on_attendance_change();

create or replace function internal.on_meeting_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  cid uuid;
begin
  if tg_op = 'UPDATE'
     and (old.held_on is distinct from new.held_on or old.kind is distinct from new.kind) then
    for cid in
      select child_id from public.attendance where meeting_id = new.id
    loop
      perform internal.recompute_child_status(cid);
    end loop;
  end if;
  return coalesce(new, old);
end;
$$;

create trigger meetings_recompute_status
  after update on public.meetings
  for each row execute function internal.on_meeting_change();

create or replace function internal.can_see_attendance(viewer uuid, meeting uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.meetings m
    where m.id = meeting
      and internal.can_see_cell_id(viewer, m.cell_id)
  );
$$;

create or replace function internal.can_write_attendance(viewer uuid, meeting uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.meetings m
    where m.id = meeting
      and internal.can_take_attendance(viewer, m.cell_id)
  );
$$;

alter table public.attendance enable row level security;
alter table public.attendance force row level security;

create policy attendance_select on public.attendance
  for select to authenticated
  using (internal.can_see_attendance(auth.uid(), meeting_id));

create policy attendance_insert on public.attendance
  for insert to authenticated
  with check (internal.can_write_attendance(auth.uid(), meeting_id));

create policy attendance_update on public.attendance
  for update to authenticated
  using (internal.can_write_attendance(auth.uid(), meeting_id))
  with check (internal.can_write_attendance(auth.uid(), meeting_id));

create policy attendance_delete on public.attendance
  for delete to authenticated
  using (internal.can_write_attendance(auth.uid(), meeting_id));

-- ---------------------------------------------------------------------------
-- Relatório mensal — colunas da planilha de acompanhamento
-- ---------------------------------------------------------------------------

create table public.monthly_reports (
  id uuid primary key default gen_random_uuid(),
  cell_id uuid not null references public.cells (id) on delete cascade,
  year integer not null check (year between 2000 and 2100),
  month integer not null check (month between 1 and 12),
  members_count integer not null default 0 check (members_count >= 0),
  sent_to_encontro integer not null default 0 check (sent_to_encontro >= 0),
  youth_baptized integer not null default 0 check (youth_baptized >= 0),
  is_project_cell boolean not null default false,
  bridge_event_visitors integer not null default 0 check (bridge_event_visitors >= 0),
  mothers_converted integer not null default 0 check (mothers_converted >= 0),
  fathers_converted integer not null default 0 check (fathers_converted >= 0),
  color_classification text check (
    color_classification is null
    or color_classification in ('verde', 'azul', 'vermelha', 'bege')
  ),
  is_parallel boolean,
  w1_members integer,
  w1_visitors integer,
  w2_members integer,
  w2_visitors integer,
  w3_members integer,
  w3_visitors integer,
  w4_members integer,
  w4_visitors integer,
  w5_members integer,
  w5_visitors integer,
  members_average numeric generated always as (
    internal.media_membros(w1_members, w2_members, w3_members, w4_members, w5_members)
  ) stored,
  attendance_percent numeric generated always as (
    internal.percentual_presenca(
      internal.media_membros(w1_members, w2_members, w3_members, w4_members, w5_members),
      members_count
    )
  ) stored,
  indicador_final integer,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (cell_id, year, month),
  constraint monthly_reports_weeks_nonneg check (
    (w1_members is null or w1_members >= 0)
    and (w1_visitors is null or w1_visitors >= 0)
    and (w2_members is null or w2_members >= 0)
    and (w2_visitors is null or w2_visitors >= 0)
    and (w3_members is null or w3_members >= 0)
    and (w3_visitors is null or w3_visitors >= 0)
    and (w4_members is null or w4_members >= 0)
    and (w4_visitors is null or w4_visitors >= 0)
    and (w5_members is null or w5_members >= 0)
    and (w5_visitors is null or w5_visitors >= 0)
  )
);

comment on table public.monthly_reports is
  'Fechamento mensal no formato da planilha Acompanhamento de Células.';
comment on column public.monthly_reports.sent_to_encontro is 'Enviados para o Encontro.';
comment on column public.monthly_reports.youth_baptized is 'Jovens batizados no mês.';
comment on column public.monthly_reports.is_project_cell is 'É projeto célula?';
comment on column public.monthly_reports.bridge_event_visitors is 'Visitantes no Evento Ponte.';
comment on column public.monthly_reports.mothers_converted is 'Mães convertidas no mês (contagem).';
comment on column public.monthly_reports.fathers_converted is 'Pais convertidos no mês (contagem).';
comment on column public.monthly_reports.indicador_final is
  'Inteiro estreito ao lado do percentual na planilha. O significado exato ainda será confirmado.';

create index monthly_reports_cell_idx on public.monthly_reports (cell_id, year, month);

create trigger monthly_reports_touch
  before update on public.monthly_reports
  for each row execute function internal.touch_updated_at();

alter table public.monthly_reports enable row level security;
alter table public.monthly_reports force row level security;

create policy monthly_reports_select on public.monthly_reports
  for select to authenticated
  using (internal.can_see_cell_id(auth.uid(), cell_id));

create policy monthly_reports_insert on public.monthly_reports
  for insert to authenticated
  with check (internal.can_take_attendance(auth.uid(), cell_id));

create policy monthly_reports_update on public.monthly_reports
  for update to authenticated
  using (internal.can_take_attendance(auth.uid(), cell_id))
  with check (internal.can_take_attendance(auth.uid(), cell_id));

create policy monthly_reports_delete on public.monthly_reports
  for delete to authenticated
  using (internal.can_edit_cell_id(auth.uid(), cell_id));

-- Idade junto da criança, respeitando o RLS da tabela (security_invoker).
create view public.children_with_age
with (security_invoker = true) as
select
  c.*,
  internal.idade_anos(c.birth_date) as age_years
from public.children c;

comment on view public.children_with_age is
  'Crianças com age_years calculado. security_invoker para não furar o RLS.';

-- ---------------------------------------------------------------------------
-- Auth: ficha nasce com o usuário. Sem cadastro público.
-- ---------------------------------------------------------------------------

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role text := coalesce(new.raw_app_meta_data->>'role', 'lider');
  v_supervisor uuid := nullif(new.raw_app_meta_data->>'supervisor_id', '')::uuid;
  v_admin boolean := coalesce((new.raw_app_meta_data->>'is_admin')::boolean, false);
  v_must boolean := coalesce((new.raw_app_meta_data->>'must_change_password')::boolean, true);
  v_name text := coalesce(nullif(new.raw_user_meta_data->>'full_name', ''), split_part(new.email, '@', 1));
begin
  perform set_config('internal.managing_accounts', 'on', true);
  insert into public.profiles (
    id,
    full_name,
    email,
    role,
    supervisor_id,
    is_admin,
    must_change_password
  )
  values (
    new.id,
    v_name,
    coalesce(new.email, ''),
    v_role,
    v_supervisor,
    v_admin,
    v_must
  )
  on conflict (id) do update
  set full_name = excluded.full_name,
      email = excluded.email,
      role = excluded.role,
      supervisor_id = excluded.supervisor_id,
      is_admin = excluded.is_admin,
      must_change_password = excluded.must_change_password;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create or replace function public.needs_initial_setup()
returns boolean
language sql
security definer
set search_path = public
as $$
  select not exists (select 1 from public.profiles);
$$;

comment on function public.needs_initial_setup() is
  'Verdadeiro enquanto não existe nenhuma conta. O primeiro acesso cria a discipuladora raiz.';

-- Liga uma pastora acima de uma discipuladora já existente.
-- Não reescreve células, crianças, encontros nem relatórios.
create or replace function public.vincular_pastor(p_pastor uuid, p_discipulador uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  actor uuid := auth.uid();
begin
  if actor is null then
    raise exception 'é preciso estar autenticado';
  end if;
  if not exists (
    select 1 from public.profiles
    where id = p_pastor and role = 'pastor' and active
  ) then
    raise exception 'pastor inválido';
  end if;
  if not exists (
    select 1 from public.profiles
    where id = p_discipulador and role = 'discipulador' and active
  ) then
    raise exception 'discipulador inválido';
  end if;
  if not exists (
    select 1 from public.profiles
    where id = actor
      and active
      and (is_admin or id = p_pastor or id = p_discipulador)
  ) then
    raise exception 'sem permissão para vincular';
  end if;

  update public.profiles
  set supervisor_id = p_pastor
  where id = p_discipulador
    and role = 'discipulador'
    and (supervisor_id is null or supervisor_id = p_pastor);

  if not found then
    raise exception 'discipulador já está vinculado a outra pessoa';
  end if;
end;
$$;

comment on function public.vincular_pastor(uuid, uuid) is
  'Coloca uma pastora acima de uma discipuladora. As células podem continuar com pastor_id nulo.';

revoke all on function public.handle_new_user() from public, anon, authenticated;
revoke all on function public.needs_initial_setup() from public;
grant execute on function public.needs_initial_setup() to anon, authenticated;
revoke all on function public.vincular_pastor(uuid, uuid) from public;
grant execute on function public.vincular_pastor(uuid, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Privilégios
-- O projeto remoto concede acesso à Data API em tabela nova. As políticas
-- é que limitam. anon não tem política: mesmo com GRANT, não lê nem grava.
-- ---------------------------------------------------------------------------

grant select, insert, update, delete on
  public.profiles,
  public.cells,
  public.children,
  public.child_status_history,
  public.meetings,
  public.attendance,
  public.monthly_reports
to anon, authenticated;

grant select on public.children_with_age to anon, authenticated;

grant all on
  public.profiles,
  public.cells,
  public.children,
  public.child_status_history,
  public.meetings,
  public.attendance,
  public.monthly_reports
to service_role;

grant select on public.children_with_age to service_role;

grant execute on all functions in schema internal to anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Garantia: nenhuma tabela pública fica sem RLS e sem política.
-- ---------------------------------------------------------------------------

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
      or not exists (
        select 1
        from pg_policy pol
        where pol.polrelid = c.oid
      )
    );

  if missing is not null then
    raise exception 'tabelas públicas sem RLS forçado e política: %', missing;
  end if;
end;
$$;
