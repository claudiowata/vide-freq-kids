-- RLS: discipuladora lê a subárvore inteira; líder e outro ramo não.
-- Roda depois do seed, com `npm run test:db`, e desfaz o que cria.
\set ON_ERROR_STOP on

begin;

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change
) values
  (
    '00000000-0000-0000-0000-000000000000',
    '77777777-7777-4777-8777-777777777777',
    'authenticated', 'authenticated',
    'bia.rede@videfreqkids.test',
    extensions.crypt('Senha-Raiz-123', extensions.gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"],"role":"discipulador","supervisor_id":"11111111-1111-4111-8111-111111111111","is_admin":false,"must_change_password":false}'::jsonb,
    '{"full_name":"Bia Rede"}'::jsonb,
    now(), now(), '', '', '', ''
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '88888888-8888-4888-8888-888888888888',
    'authenticated', 'authenticated',
    'hugo.vale@videfreqkids.test',
    extensions.crypt('Senha-Lider-123', extensions.gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"],"role":"lider","supervisor_id":"77777777-7777-4777-8777-777777777777","is_admin":false,"must_change_password":false}'::jsonb,
    '{"full_name":"Hugo Vale"}'::jsonb,
    now(), now(), '', '', '', ''
  );

update public.profiles
set phone = '11900000088'
where id = '88888888-8888-4888-8888-888888888888';

insert into public.cells (
  id, name, pastor_id, discipulador_id, leader_id,
  host_name, address, cell_type
) values (
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4',
  'Célula da subárvore',
  null,
  '77777777-7777-4777-8777-777777777777',
  '88888888-8888-4888-8888-888888888888',
  'Anfitrião da Subárvore',
  'Rua da Subárvore, 7',
  'kids'
);

insert into public.children (
  id, cell_id, full_name, phone, guardians, mae_convertida, pai_convertido
) values (
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb6',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4',
  'Nina Subárvore',
  '11910000077',
  'Mãe da Subárvore',
  true,
  false
);

insert into public.meetings (id, cell_id, held_on, kind)
values (
  'cccccccc-cccc-4ccc-8ccc-cccccccccc10',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4',
  '2026-07-06',
  'celula'
);

insert into public.attendance (meeting_id, child_id, present)
values (
  'cccccccc-cccc-4ccc-8ccc-cccccccccc10',
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb6',
  true
);

insert into public.monthly_reports (
  cell_id, year, month, members_count,
  w1_members, w1_visitors
) values (
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4', 2026, 7, 4,
  3, 1
);

-- Ana, raiz, lê a célula, o líder, a criança, a frequência e o fechamento
-- da discipuladora subordinada. Não passa a ver a Diana.
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
  v_cell text;
  v_leader text;
  v_phone text;
  v_child text;
  v_guardians text;
  v_child_phone text;
  v_mae boolean;
  v_pai boolean;
  v_status text;
  v_present boolean;
  v_members integer;
  v_visitors numeric;
begin
  select count(*) into n from public.cells;
  if n <> 3 then
    raise exception 'Ana deveria ver as 2 células dela e a da subárvore, viu %', n;
  end if;
  select count(*) into n from public.cells where name = 'Célula Exemplo da Diana';
  if n <> 0 then raise exception 'Ana passou a ver o outro ramo'; end if;

  select c.name, p.full_name, p.phone
    into v_cell, v_leader, v_phone
  from public.cells c
  join public.profiles p on p.id = c.leader_id
  where c.id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4';
  if v_cell <> 'Célula da subárvore' or v_leader <> 'Hugo Vale' or v_phone <> '11900000088' then
    raise exception 'Ana não leu a ficha da célula e o líder da subárvore';
  end if;
  select count(*) into n
  from public.child_status_history
  where child_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb6'
    and reason = 'cadastro_inicial';
  if n <> 1 then
    raise exception 'Ana não leu o histórico de status da subárvore';
  end if;

  select full_name, guardians, phone, mae_convertida, pai_convertido, status
    into v_child, v_guardians, v_child_phone, v_mae, v_pai, v_status
  from public.children
  where id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb6';
  if v_child <> 'Nina Subárvore'
     or v_guardians <> 'Mãe da Subárvore'
     or v_child_phone <> '11910000077'
     or v_mae is not true
     or v_pai is not false
     or v_status <> 'visitante' then
    raise exception 'Ana não leu a ficha completa da criança da subárvore';
  end if;

  select present into v_present
  from public.attendance
  where meeting_id = 'cccccccc-cccc-4ccc-8ccc-cccccccccc10';
  if v_present is not true then
    raise exception 'Ana não leu a frequência da subárvore';
  end if;

  select members_count, visitors_average into v_members, v_visitors
  from public.monthly_reports
  where cell_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4';
  if v_members <> 4 or v_visitors <> 1 then
    raise exception 'Ana não leu o fechamento da subárvore: % %', v_members, v_visitors;
  end if;
end $$;

-- Bruno, líder, continua vendo só a própria célula.
reset role;
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
begin
  select count(*) into n from public.cells;
  if n <> 1 then raise exception 'Bruno deveria ver 1 célula, viu %', n; end if;
  select count(*) into n from public.cells where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4';
  if n <> 0 then raise exception 'Bruno viu a célula da subárvore'; end if;
  select count(*) into n from public.children where id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb6';
  if n <> 0 then raise exception 'Bruno viu a criança da subárvore'; end if;
  select count(*) into n from public.child_status_history
  where child_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb6';
  if n <> 0 then raise exception 'Bruno viu o status da subárvore'; end if;
  select count(*) into n from public.attendance
  where meeting_id = 'cccccccc-cccc-4ccc-8ccc-cccccccccc10';
  if n <> 0 then raise exception 'Bruno viu a frequência da subárvore'; end if;
  select count(*) into n from public.monthly_reports
  where cell_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4';
  if n <> 0 then raise exception 'Bruno viu o fechamento da subárvore'; end if;
  select count(*) into n from public.profiles where full_name = 'Hugo Vale';
  if n <> 0 then raise exception 'Bruno viu o líder de outra célula'; end if;
end $$;

-- Diana, discipuladora de outro ramo, não vê a subárvore da Ana.
reset role;
select set_config('request.jwt.claim.sub', '44444444-4444-4444-8444-444444444444', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"44444444-4444-4444-8444-444444444444","role":"authenticated"}',
  true
);
set local role authenticated;

do $$
declare
  n int;
begin
  select count(*) into n from public.cells where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4';
  if n <> 0 then raise exception 'Diana viu a célula de outro ramo'; end if;
  select count(*) into n from public.children where id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb6';
  if n <> 0 then raise exception 'Diana viu a criança de outro ramo'; end if;
  select count(*) into n from public.profiles where full_name in ('Ana Raiz', 'Bia Rede', 'Hugo Vale');
  if n <> 0 then raise exception 'Diana viu gente de outro ramo'; end if;
  select count(*) into n from public.cells;
  if n <> 1 then raise exception 'Diana deveria continuar vendo só a própria célula, viu %', n; end if;
end $$;

-- A discipuladora subordinada lê a própria célula e não a célula irmã da Ana.
reset role;
select set_config('request.jwt.claim.sub', '77777777-7777-4777-8777-777777777777', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"77777777-7777-4777-8777-777777777777","role":"authenticated"}',
  true
);
set local role authenticated;

do $$
declare
  n int;
begin
  select count(*) into n from public.cells where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4';
  if n <> 1 then raise exception 'Bia deveria ver a própria célula'; end if;
  select count(*) into n from public.cells where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1';
  if n <> 0 then raise exception 'Bia viu a célula do líder da Ana'; end if;
  select count(*) into n from public.cells;
  if n <> 1 then raise exception 'Bia deveria ver só a própria subárvore, viu % células', n; end if;
end $$;

rollback;
