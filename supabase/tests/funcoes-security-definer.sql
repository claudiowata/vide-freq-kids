-- Anon não executa SECURITY DEFINER, exceto needs_initial_setup.
\set ON_ERROR_STOP on

do $$
declare
  fn record;
  signature text;
begin
  for fn in
    select p.oid,
           p.proname,
           n.nspname
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where p.prosecdef
      and n.nspname in ('public', 'internal')
  loop
    signature := format('%I.%I(%s)', fn.nspname, fn.proname, pg_get_function_identity_arguments(fn.oid));

    if not exists (
      select 1
      from unnest(coalesce((select p.proconfig from pg_proc p where p.oid = fn.oid), array[]::text[])) as config
      where config like 'search_path=%'
    ) then
      raise exception '% sem search_path fixo', signature;
    end if;

    if fn.proname = 'needs_initial_setup' then
      if not has_function_privilege('anon', fn.oid, 'execute') then
        raise exception 'anon precisa executar needs_initial_setup para /login e /setup';
      end if;
      if not has_function_privilege('authenticated', fn.oid, 'execute') then
        raise exception 'authenticated precisa executar needs_initial_setup';
      end if;
    elsif has_function_privilege('anon', fn.oid, 'execute') then
      raise exception 'anon ainda executa %', signature;
    end if;
  end loop;

  if not has_function_privilege('authenticated', (
    select p.oid from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'vincular_pastor'
  ), 'execute') then
    raise exception 'authenticated perdeu vincular_pastor';
  end if;
  if not has_function_privilege('authenticated', (
    select p.oid from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'multiplicar_celula'
  ), 'execute') then
    raise exception 'authenticated perdeu multiplicar_celula';
  end if;
  if not has_function_privilege('authenticated', (
    select p.oid from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'remanejar_criancas'
  ), 'execute') then
    raise exception 'authenticated perdeu remanejar_criancas';
  end if;
  if has_function_privilege('authenticated', (
    select p.oid from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'handle_new_user'
  ), 'execute') then
    raise exception 'authenticated ainda executa handle_new_user';
  end if;
  if has_function_privilege('anon', (
       select p.oid from pg_proc p
       join pg_namespace n on n.oid = p.pronamespace
       where n.nspname = 'internal' and p.proname = 'recompute_child_status'
     ), 'execute')
     or has_function_privilege('authenticated', (
       select p.oid from pg_proc p
       join pg_namespace n on n.oid = p.pronamespace
       where n.nspname = 'internal' and p.proname = 'recompute_child_status'
     ), 'execute') then
    raise exception 'recompute_child_status ficou chamável pelo cliente';
  end if;
end $$;

-- A chamada do anon nem entra na função.
begin;
set local role anon;
do $$
begin
  perform public.vincular_pastor(
    '66666666-6666-4666-8666-666666666666',
    '11111111-1111-4111-8111-111111111111'
  );
  raise exception 'anon executou vincular_pastor';
exception
  when insufficient_privilege then
    null;
  when others then
    if sqlerrm ilike '%anon executou%' then
      raise;
    end if;
    raise exception 'anon em vincular_pastor: %', sqlerrm;
end $$;
do $$
begin
  perform public.multiplicar_celula(
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
    'Célula do anon',
    'kids',
    '33333333-3333-4333-8333-333333333333',
    1,
    time '19:00',
    'Rua do Anon, 1',
    current_date,
    '{}'::uuid[]
  );
  raise exception 'anon executou multiplicar_celula';
exception
  when insufficient_privilege then
    null;
  when others then
    if sqlerrm ilike '%anon executou%' then
      raise;
    end if;
    raise exception 'anon em multiplicar_celula: %', sqlerrm;
end $$;
do $$
begin
  perform public.remanejar_criancas(
    array['bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1']::uuid[],
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2'
  );
  raise exception 'anon executou remanejar_criancas';
exception
  when insufficient_privilege then
    null;
  when others then
    if sqlerrm ilike '%anon executou%' then
      raise;
    end if;
    raise exception 'anon em remanejar_criancas: %', sqlerrm;
end $$;
do $$
begin
  if public.needs_initial_setup() then
    raise exception 'needs_initial_setup deveria ser falso com o seed';
  end if;
end $$;
rollback;

-- Bruno não é admin, nem a pastora, nem a discipuladora. auth.uid() barra.
begin;
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change
) values (
  '00000000-0000-0000-0000-000000000000',
  '66666666-6666-4666-8666-666666666666',
  'authenticated', 'authenticated',
  'olga.topo@videfreqkids.test',
  extensions.crypt('Senha-Raiz-123', extensions.gen_salt('bf')),
  now(),
  '{"provider":"email","providers":["email"],"role":"pastor","is_admin":false,"must_change_password":false}'::jsonb,
  '{"full_name":"Olga Topo"}'::jsonb,
  now(), now(), '', '', '', ''
);

select set_config('request.jwt.claim.sub', '22222222-2222-4222-8222-222222222222', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"22222222-2222-4222-8222-222222222222","role":"authenticated"}',
  true
);
set local role authenticated;

do $$
begin
  perform public.vincular_pastor(
    '66666666-6666-4666-8666-666666666666',
    '11111111-1111-4111-8111-111111111111'
  );
  raise exception 'Bruno vinculou pastora';
exception
  when others then
    if sqlerrm ilike '%Bruno vinculou%' then
      raise;
    end if;
    if sqlerrm not ilike '%sem permissão para vincular%' then
      raise exception 'vincular_pastor não checou auth.uid(): %', sqlerrm;
    end if;
end $$;
rollback;
