-- Testes do banco local. Roda com `npm run test:db` e desfaz o que cria.
\set ON_ERROR_STOP on

-- Toda tabela pública tem RLS forçado e ao menos uma política.
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
      not c.relrowsecurity
      or not c.relforcerowsecurity
      or not exists (select 1 from pg_policy pol where pol.polrelid = c.oid)
    );
  if missing is not null then
    raise exception 'tabelas sem RLS: %', missing;
  end if;
end $$;

-- O seed não tem pastora, e as células nascem sem esse vínculo.
do $$
declare
  pastors int;
  cells_with_pastor int;
begin
  select count(*) into pastors from public.profiles where role = 'pastor';
  select count(*) into cells_with_pastor from public.cells where pastor_id is not null;
  if pastors <> 0 then
    raise exception 'o seed deveria funcionar sem pastora';
  end if;
  if cells_with_pastor <> 0 then
    raise exception 'as células do seed deveriam ter pastor_id nulo';
  end if;
end $$;

-- Status calculado pelo banco, inclusive o culto que não entra na conta.
do $$
declare
  lia public.children%rowtype;
  nico public.children%rowtype;
  bia public.children%rowtype;
  caio public.children%rowtype;
  duda public.children%rowtype;
begin
  select * into lia from public.children where full_name = 'Lia Presença';
  select * into nico from public.children where full_name = 'Nico Intervalo';
  select * into bia from public.children where full_name = 'Bia Queda';
  select * into caio from public.children where full_name = 'Caio Quase';
  select * into duda from public.children where full_name = 'Duda Visita';

  if lia.status <> 'membro' or lia.presence_streak <> 4 or lia.first_visit_on <> date '2026-05-04' then
    raise exception 'Lia deveria ser membro com 4 presenças';
  end if;
  if nico.status <> 'visitante' or nico.presence_streak <> 1 or nico.absence_streak <> 0 then
    raise exception 'Nico deveria continuar visitante depois da falta no meio';
  end if;
  if bia.status <> 'visitante' or bia.absence_streak <> 4 or bia.first_visit_on is null then
    raise exception 'Bia deveria voltar a visitante depois de 4 faltas';
  end if;
  if caio.status <> 'visitante' or caio.presence_streak <> 3 then
    raise exception 'Caio não deveria ser promovido com 3 presenças';
  end if;
  if duda.status <> 'visitante' or duda.first_visit_on is not null then
    raise exception 'Duda ainda não visitou';
  end if;

  if (select count(*) from public.child_status_history h
      where h.child_id = bia.id and h.reason = 'quatro_ausencias_consecutivas') <> 1 then
    raise exception 'histórico da Bia sem a volta a visitante';
  end if;
end $$;

-- anon, mesmo com GRANT da Data API, não lê nada.
begin;
set local role anon;
do $$
declare
  n int;
begin
  select count(*) into n from public.profiles;
  if n <> 0 then raise exception 'anon leu profiles'; end if;
  select count(*) into n from public.cells;
  if n <> 0 then raise exception 'anon leu cells'; end if;
  select count(*) into n from public.children;
  if n <> 0 then raise exception 'anon leu children'; end if;
  select count(*) into n from public.children_with_age;
  if n <> 0 then raise exception 'a view furou o RLS'; end if;
end $$;
rollback;

begin;
set local role anon;
do $$
begin
  insert into public.meetings (cell_id, held_on)
  values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', '2026-07-01');
  raise exception 'anon inseriu encontro';
exception
  when insufficient_privilege then
    null;
end $$;
rollback;

-- Ana, raiz sem pastora, vê a própria árvore e não a da Diana.
begin;
select set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}',
  true
);
set local role authenticated;
do $$
declare
  n int;
begin
  select count(*) into n from public.cells;
  if n <> 2 then raise exception 'Ana deveria ver 2 células, viu %', n; end if;
  select count(*) into n from public.children;
  if n <> 4 then raise exception 'Ana deveria ver 4 crianças, viu %', n; end if;
  select count(*) into n from public.profiles where full_name = 'Diana Serra';
  if n <> 0 then raise exception 'Ana não deveria ver a outra raiz'; end if;
  select count(*) into n from public.profiles where role = 'pastor';
  if n <> 0 then raise exception 'não há pastora para Ana ver'; end if;
end $$;
rollback;

-- Bruno vê a própria célula e a Ana, não a Clara.
begin;
select set_config('request.jwt.claim.sub', '22222222-2222-4222-8222-222222222222', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"22222222-2222-4222-8222-222222222222","role":"authenticated"}',
  true
);
set local role authenticated;
do $$
declare
  n int;
  papel text;
begin
  select count(*) into n from public.cells;
  if n <> 1 then raise exception 'Bruno deveria ver 1 célula, viu %', n; end if;
  select count(*) into n from public.profiles where full_name = 'Clara Vento';
  if n <> 0 then raise exception 'Bruno não deveria ver a líder irmã'; end if;
  select count(*) into n from public.profiles where full_name = 'Ana Raiz';
  if n <> 1 then raise exception 'Bruno deveria ver a discipuladora'; end if;

  update public.profiles set role = 'pastor' where id = '22222222-2222-4222-8222-222222222222';
  select role into papel from public.profiles where id = '22222222-2222-4222-8222-222222222222';
  if papel <> 'lider' then raise exception 'Bruno conseguiu mudar o próprio papel'; end if;
end $$;
rollback;

-- Uma pastora entra depois. As células continuam com pastor_id nulo
-- e passam a aparecer para ela.
begin;
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change
) values (
  '00000000-0000-0000-0000-000000000000',
  '66666666-6666-4666-8666-666666666666',
  'authenticated',
  'authenticated',
  'olga.topo@videfreqkids.test',
  extensions.crypt('Senha-Raiz-123', extensions.gen_salt('bf')),
  now(),
  '{"provider":"email","providers":["email"],"role":"pastor","is_admin":true,"must_change_password":false}'::jsonb,
  '{"full_name":"Olga Topo"}'::jsonb,
  now(), now(), '', '', '', ''
);

select set_config('request.jwt.claim.sub', '66666666-6666-4666-8666-666666666666', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"66666666-6666-4666-8666-666666666666","role":"authenticated"}',
  true
);
set local role authenticated;
do $$
declare
  n int;
begin
  select count(*) into n from public.cells;
  if n <> 0 then raise exception 'pastora ainda não ligada viu % células', n; end if;
end $$;

reset role;
select set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}',
  true
);
set local role authenticated;
select public.vincular_pastor(
  '66666666-6666-4666-8666-666666666666',
  '11111111-1111-4111-8111-111111111111'
);
select public.vincular_pastor(
  '66666666-6666-4666-8666-666666666666',
  '44444444-4444-4444-8444-444444444444'
);

reset role;
do $$
declare
  n int;
begin
  select count(*) into n from public.cells where pastor_id is not null;
  if n <> 0 then raise exception 'vincular pastora reescreveu pastor_id das células'; end if;
end $$;

select set_config('request.jwt.claim.sub', '66666666-6666-4666-8666-666666666666', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"66666666-6666-4666-8666-666666666666","role":"authenticated"}',
  true
);
set local role authenticated;
do $$
declare
  n int;
begin
  select count(*) into n from public.cells;
  if n <> 3 then raise exception 'pastora ligada deveria ver 3 células, viu %', n; end if;
  select count(*) into n from public.children;
  if n <> 5 then raise exception 'pastora ligada deveria ver 5 crianças, viu %', n; end if;
end $$;
rollback;

-- needs_initial_setup é falso quando já existe gente.
do $$
begin
  if public.needs_initial_setup() then
    raise exception 'needs_initial_setup deveria ser falso com o seed';
  end if;
end $$;
