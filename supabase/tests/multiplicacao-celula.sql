-- Multiplicação e remanejamento. Roda depois do seed e desfaz o que cria.
\set ON_ERROR_STOP on

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
  nova uuid;
  lia public.children%rowtype;
  n int;
begin
  nova := public.multiplicar_celula(
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
    'Célula Nova da Clara',
    'mista_juvenis',
    '33333333-3333-4333-8333-333333333333',
    3,
    time '19:30',
    'Rua Nova, 10',
    date '2026-07-01',
    array['bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1']::uuid[]
  );

  select * into lia from public.children where id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1';
  if lia.cell_id <> nova or lia.status <> 'membro' or lia.presence_streak <> 4 then
    raise exception 'Lia deveria ir para a célula nova como membro, com as 4 presenças';
  end if;
  if lia.guardians is null or lia.mae_convertida is not true then
    raise exception 'Lia deveria levar os dados dos pais';
  end if;

  select count(*) into n from public.child_transfers
  where child_id = lia.id
    and from_cell_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1'
    and to_cell_id = nova
    and transferred_on = date '2026-07-01'
    and transferred_by = '11111111-1111-4111-8111-111111111111';
  if n <> 1 then raise exception 'movimentação da Lia não foi gravada'; end if;

  if (select celula_origem_id from public.cells where id = nova)
       <> 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1'
     or (select multiplied_on from public.cells where id = nova) <> date '2026-07-01'
     or (select cell_type from public.cells where id = nova) <> 'mista_juvenis'
     or (select leader_id from public.cells where id = nova)
       <> '33333333-3333-4333-8333-333333333333'
     or (select address from public.cells where id = nova) <> 'Rua Nova, 10' then
    raise exception 'a célula filha não guardou mãe, data, tipo, líder ou endereço';
  end if;
end $$;

-- Frequência antiga e o fechamento de junho continuam na célula do Bruno.
reset role;
do $$
declare
  n int;
  m numeric;
  v numeric;
begin
  select count(*) into n
  from public.attendance a
  join public.meetings m on m.id = a.meeting_id
  where a.child_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1'
    and m.cell_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1';
  if n <> 5 then
    raise exception 'a frequência da Lia deveria continuar na célula de origem, achou %', n;
  end if;

  select members_average, visitors_average into m, v
  from public.monthly_reports
  where cell_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1' and year = 2026 and month = 6;
  if m <> 10 or v <> 1 then
    raise exception 'o fechamento passado mudou: M=% V=%', m, v;
  end if;
end $$;

-- Remanejar o Caio para a célula que a Clara já tinha.
select set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}',
  true
);
set local role authenticated;

select public.remanejar_criancas(
  array['bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb4']::uuid[],
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2'
);

do $$
declare
  caio public.children%rowtype;
  n int;
begin
  select * into caio from public.children where id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb4';
  if caio.cell_id <> 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2'
     or caio.status <> 'visitante'
     or caio.presence_streak <> 3 then
    raise exception 'Caio deveria mudar de célula sem perder status nem sequência';
  end if;
  select count(*) into n from public.child_transfers
  where child_id = caio.id
    and from_cell_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1'
    and to_cell_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2';
  if n <> 1 then raise exception 'movimentação do Caio não foi gravada'; end if;
end $$;

-- Update direto não fura o histórico.
do $$
begin
  update public.children
  set cell_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1'
  where id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb4';
  raise exception 'update direto de célula deveria falhar';
exception
  when others then
    if sqlerrm ilike '%update direto%' then
      raise;
    end if;
    if sqlerrm not ilike '%multiplicação ou pelo remanejamento%' then
      raise exception 'erro inesperado no update direto: %', sqlerrm;
    end if;
end $$;

-- Bruno, líder, não multiplica nem remaneja.
reset role;
select set_config('request.jwt.claim.sub', '22222222-2222-4222-8222-222222222222', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"22222222-2222-4222-8222-222222222222","role":"authenticated"}',
  true
);
set local role authenticated;

do $$
begin
  perform public.multiplicar_celula(
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
    'Célula do Bruno',
    'kids',
    '33333333-3333-4333-8333-333333333333',
    1,
    time '19:00',
    'Rua do Líder, 1',
    date '2026-07-02',
    '{}'::uuid[]
  );
  raise exception 'Bruno conseguiu multiplicar';
exception
  when others then
    if sqlerrm ilike '%Bruno conseguiu%' then
      raise;
    end if;
    if sqlerrm not ilike '%discipuladora ou quem está acima%' then
      raise exception 'erro inesperado do Bruno: %', sqlerrm;
    end if;
end $$;

do $$
begin
  perform public.remanejar_criancas(
    array['bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2']::uuid[],
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2'
  );
  raise exception 'Bruno conseguiu remanejar';
exception
  when others then
    if sqlerrm ilike '%Bruno conseguiu%' then
      raise;
    end if;
    if sqlerrm not ilike '%discipuladora ou quem está acima%' then
      raise exception 'erro inesperado do remanejamento do Bruno: %', sqlerrm;
    end if;
end $$;

-- Diana, outro ramo, não mexe na célula da Ana.
reset role;
select set_config('request.jwt.claim.sub', '44444444-4444-4444-8444-444444444444', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"44444444-4444-4444-8444-444444444444","role":"authenticated"}',
  true
);
set local role authenticated;

do $$
begin
  perform public.multiplicar_celula(
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
    'Célula da Diana',
    'juvenis',
    '55555555-5555-4555-8555-555555555555',
    2,
    time '18:30',
    'Rua de Fora, 2',
    date '2026-07-03',
    '{}'::uuid[]
  );
  raise exception 'Diana conseguiu multiplicar outro ramo';
exception
  when others then
    if sqlerrm ilike '%Diana conseguiu%' then
      raise;
    end if;
    if sqlerrm not ilike '%fora da sua árvore%' then
      raise exception 'erro inesperado da Diana: %', sqlerrm;
    end if;
end $$;

do $$
declare
  n int;
begin
  select count(*) into n from public.child_transfers;
  if n <> 0 then raise exception 'Diana viu movimentação de outro ramo'; end if;
  select count(*) into n from public.cells where name = 'Célula Nova da Clara';
  if n <> 0 then raise exception 'Diana viu a célula filha de outro ramo'; end if;
end $$;

rollback;
