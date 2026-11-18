-- Rede fictícia, sem pastora e sem nomes reais.
-- Duas discipuladoras raiz não se enxergam. As células ficam com pastor_id nulo.

insert into auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at,
  confirmation_token,
  recovery_token,
  email_change_token_new,
  email_change
)
values
  (
    '00000000-0000-0000-0000-000000000000',
    '11111111-1111-4111-8111-111111111111',
    'authenticated',
    'authenticated',
    'ana.raiz@videfreqkids.test',
    extensions.crypt('Senha-Raiz-123', extensions.gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"],"role":"discipulador","is_admin":true,"must_change_password":false}'::jsonb,
    '{"full_name":"Ana Raiz"}'::jsonb,
    now(),
    now(),
    '',
    '',
    '',
    ''
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '44444444-4444-4444-8444-444444444444',
    'authenticated',
    'authenticated',
    'diana.serra@videfreqkids.test',
    extensions.crypt('Senha-Raiz-123', extensions.gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"],"role":"discipulador","is_admin":false,"must_change_password":false}'::jsonb,
    '{"full_name":"Diana Serra"}'::jsonb,
    now(),
    now(),
    '',
    '',
    '',
    ''
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '22222222-2222-4222-8222-222222222222',
    'authenticated',
    'authenticated',
    'bruno.leme@videfreqkids.test',
    extensions.crypt('Senha-Lider-123', extensions.gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"],"role":"lider","supervisor_id":"11111111-1111-4111-8111-111111111111","is_admin":false,"must_change_password":true}'::jsonb,
    '{"full_name":"Bruno Leme"}'::jsonb,
    now(),
    now(),
    '',
    '',
    '',
    ''
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '33333333-3333-4333-8333-333333333333',
    'authenticated',
    'authenticated',
    'clara.vento@videfreqkids.test',
    extensions.crypt('Senha-Lider-123', extensions.gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"],"role":"lider","supervisor_id":"11111111-1111-4111-8111-111111111111","is_admin":false,"must_change_password":false}'::jsonb,
    '{"full_name":"Clara Vento"}'::jsonb,
    now(),
    now(),
    '',
    '',
    '',
    ''
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '55555555-5555-4555-8555-555555555555',
    'authenticated',
    'authenticated',
    'edu.mar@videfreqkids.test',
    extensions.crypt('Senha-Lider-123', extensions.gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"],"role":"lider","supervisor_id":"44444444-4444-4444-8444-444444444444","is_admin":false,"must_change_password":false}'::jsonb,
    '{"full_name":"Edu Mar"}'::jsonb,
    now(),
    now(),
    '',
    '',
    '',
    ''
  );

insert into auth.identities (provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
select
  id::text,
  id,
  jsonb_build_object('sub', id::text, 'email', email, 'email_verified', true),
  'email',
  now(),
  now(),
  now()
from auth.users
where email like '%@videfreqkids.test';

update public.profiles
set birth_date = '1988-04-02', phone = '11900000010', has_ctl = true
where id = '11111111-1111-4111-8111-111111111111';

update public.profiles
set birth_date = '1996-11-20', phone = '11900000020', has_ctl = true
where id = '22222222-2222-4222-8222-222222222222';

update public.profiles
set birth_date = '1994-01-15', phone = '11900000030', has_ctl = false
where id = '33333333-3333-4333-8333-333333333333';

update public.profiles
set birth_date = '1990-08-08', phone = '11900000040', has_ctl = true
where id = '44444444-4444-4444-8444-444444444444';

update public.profiles
set birth_date = '2001-05-05', phone = '11900000050', has_ctl = false
where id = '55555555-5555-4555-8555-555555555555';

insert into public.cells (
  id, name, pastor_id, discipulador_id, leader_id,
  leader_birth_date, leader_has_ctl,
  trainee_name, trainee_birth_date, trainee_encontro, trainee_batismo, trainee_maturidade, trainee_ctl,
  host_name, host_is_believer, address, weekday, meeting_time, is_parallel,
  started_on, cell_type, color_classification
)
values
  (
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
    'Célula Exemplo da Ana — Bruno',
    null,
    '11111111-1111-4111-8111-111111111111',
    '22222222-2222-4222-8222-222222222222',
    '1996-11-20', true,
    'Lia Treino', '2004-07-01', true, false, false, false,
    'Anfitrião Exemplo', true,
    'Rua das Acácias, 100 — Bairro Exemplo',
    1, '19:00', false,
    '2024-08-01', 'mista', 'vermelha'
  ),
  (
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',
    'Célula Exemplo da Ana — Clara',
    null,
    '11111111-1111-4111-8111-111111111111',
    '33333333-3333-4333-8333-333333333333',
    '1994-01-15', false,
    null, null, null, null, null, null,
    'Casa Exemplo', false,
    'Rua do Ipê, 20 — Bairro Exemplo',
    5, '19:30', false,
    '2025-03-07', 'criancas', 'azul'
  ),
  (
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3',
    'Célula Exemplo da Diana',
    null,
    '44444444-4444-4444-8444-444444444444',
    '55555555-5555-4555-8555-555555555555',
    '2001-05-05', false,
    null, null, null, null, null, null,
    'Anfitriã Exemplo', true,
    'Rua das Palmeiras, 7 — Bairro Exemplo',
    3, '18:30', true,
    '2025-09-03', 'juvenis', 'bege'
  );

insert into public.children (
  id, cell_id, full_name, birth_date, parents_are_believers, phone,
  guardians, authorized_pickup, allergies_medication, image_authorization,
  encontro, batismo, culto, registered_on
)
values
  (
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1',
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
    'Lia Presença', '2016-02-02', true, '11910000001',
    'Mãe Exemplo', 'Mãe Exemplo', 'nenhuma', true,
    false, false, true, '2026-05-01'
  ),
  (
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2',
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
    'Nico Intervalo', '2015-06-18', false, '11910000002',
    'Pai Exemplo', 'Pai Exemplo ou tia', 'alergia a amendoim', false,
    false, false, false, '2026-05-01'
  ),
  (
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb3',
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
    'Bia Queda', '2014-09-09', true, '11910000003',
    'Avó Exemplo', 'Avó Exemplo', 'usa bombinha', true,
    true, false, true, '2026-05-01'
  ),
  (
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb4',
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
    'Caio Quase', '2017-01-30', null, '11910000004',
    'Mãe Exemplo', 'Mãe Exemplo', null, null,
    false, false, false, '2026-05-01'
  ),
  (
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb5',
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3',
    'Duda Visita', '2013-12-12', false, '11910000005',
    'Pai Exemplo', 'Pai Exemplo', null, false,
    false, false, false, '2026-06-01'
  );

insert into public.meetings (id, cell_id, held_on, kind)
values
  ('cccccccc-cccc-4ccc-8ccc-ccccccccccc1', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', '2026-05-04', 'celula'),
  ('cccccccc-cccc-4ccc-8ccc-ccccccccccc2', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', '2026-05-11', 'celula'),
  ('cccccccc-cccc-4ccc-8ccc-ccccccccccc3', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', '2026-05-18', 'celula'),
  ('cccccccc-cccc-4ccc-8ccc-ccccccccccc4', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', '2026-05-25', 'celula'),
  ('cccccccc-cccc-4ccc-8ccc-ccccccccccc5', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', '2026-06-01', 'celula'),
  ('cccccccc-cccc-4ccc-8ccc-ccccccccccc6', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', '2026-06-08', 'celula'),
  ('cccccccc-cccc-4ccc-8ccc-ccccccccccc7', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', '2026-06-15', 'celula'),
  ('cccccccc-cccc-4ccc-8ccc-ccccccccccc8', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', '2026-06-22', 'celula'),
  ('cccccccc-cccc-4ccc-8ccc-ccccccccccc9', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', '2026-05-10', 'culto');

-- Lia: 4 presenças de célula e um culto, que não conta.
insert into public.attendance (meeting_id, child_id, present)
values
  ('cccccccc-cccc-4ccc-8ccc-ccccccccccc1', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1', true),
  ('cccccccc-cccc-4ccc-8ccc-ccccccccccc2', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1', true),
  ('cccccccc-cccc-4ccc-8ccc-ccccccccccc3', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1', true),
  ('cccccccc-cccc-4ccc-8ccc-ccccccccccc4', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1', true),
  ('cccccccc-cccc-4ccc-8ccc-ccccccccccc9', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1', true);

-- Nico: presença, presença, falta, presença. Continua visitante.
insert into public.attendance (meeting_id, child_id, present)
values
  ('cccccccc-cccc-4ccc-8ccc-ccccccccccc1', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2', true),
  ('cccccccc-cccc-4ccc-8ccc-ccccccccccc2', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2', true),
  ('cccccccc-cccc-4ccc-8ccc-ccccccccccc3', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2', false),
  ('cccccccc-cccc-4ccc-8ccc-ccccccccccc4', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2', true);

-- Bia: 4 presenças e depois 4 faltas. Volta a visitante.
insert into public.attendance (meeting_id, child_id, present)
values
  ('cccccccc-cccc-4ccc-8ccc-ccccccccccc1', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb3', true),
  ('cccccccc-cccc-4ccc-8ccc-ccccccccccc2', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb3', true),
  ('cccccccc-cccc-4ccc-8ccc-ccccccccccc3', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb3', true),
  ('cccccccc-cccc-4ccc-8ccc-ccccccccccc4', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb3', true),
  ('cccccccc-cccc-4ccc-8ccc-ccccccccccc5', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb3', false),
  ('cccccccc-cccc-4ccc-8ccc-ccccccccccc6', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb3', false),
  ('cccccccc-cccc-4ccc-8ccc-ccccccccccc7', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb3', false),
  ('cccccccc-cccc-4ccc-8ccc-ccccccccccc8', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb3', false);

-- Caio: 3 presenças. Ainda visitante.
insert into public.attendance (meeting_id, child_id, present)
values
  ('cccccccc-cccc-4ccc-8ccc-ccccccccccc1', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb4', true),
  ('cccccccc-cccc-4ccc-8ccc-ccccccccccc2', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb4', true),
  ('cccccccc-cccc-4ccc-8ccc-ccccccccccc3', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb4', true);

insert into public.monthly_reports (
  cell_id, year, month, members_count,
  sent_to_encontro, youth_baptized, is_project_cell, bridge_event_visitors,
  mothers_converted, fathers_converted, color_classification, is_parallel,
  w1_members, w1_visitors, w2_members, w2_visitors, w3_members, w3_visitors,
  w4_members, w4_visitors, w5_members, w5_visitors, indicador_final
)
values (
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 2026, 6, 12,
  1, 0, false, 0,
  0, 0, 'vermelha', false,
  10, 2, 8, 1, 11, 0, 9, 2, 10, 1, 2
);
