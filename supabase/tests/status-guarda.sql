-- Status só muda na virada do mês. 4 presenças, 8 faltas, semana neutra.
\set ON_ERROR_STOP on

begin;

insert into public.children (id, cell_id, full_name, guarda_compartilhada)
values
  (
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb7',
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
    'Eva Guarda',
    true
  ),
  (
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb8',
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
    'Ivo Falta',
    false
  );

-- Quatro presenças no mês corrente não mudam o status.
do $$
declare
  i integer;
  reuniao uuid;
  dia date;
  ivo public.children%rowtype;
begin
  for i in 0..3 loop
    dia := date_trunc('month', current_date)::date + 9 + i;
    insert into public.meetings (cell_id, held_on, kind)
    values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', dia, 'celula')
    returning id into reuniao;
    insert into public.attendance (meeting_id, child_id, present)
    values (reuniao, 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb8', true);
  end loop;

  select * into ivo from public.children where id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb8';
  if ivo.status <> 'visitante' or ivo.presence_streak <> 4 then
    raise exception 'chamada no mês aberto mudou o status do Ivo: % sequência %',
      ivo.status, ivo.presence_streak;
  end if;
end $$;

-- Fechar o mês corrente promove. Fechar de novo não duplica o histórico.
select set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}',
  true
);
set local role authenticated;

select public.fechar_status_do_mes(
  extract(year from current_date)::integer,
  extract(month from current_date)::integer
);
select public.fechar_status_do_mes(
  extract(year from current_date)::integer,
  extract(month from current_date)::integer
);
select public.fechar_status_do_mes(
  extract(year from (current_date - interval '1 month'))::integer,
  extract(month from (current_date - interval '1 month'))::integer
);

do $$
declare
  ivo public.children%rowtype;
  n integer;
begin
  select * into ivo from public.children where id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb8';
  if ivo.status <> 'membro' or ivo.presence_streak <> 4 then
    raise exception 'fechar o mês deveria tornar o Ivo membro';
  end if;
  if ivo.status_avaliado_ate <> (date_trunc('month', current_date) + interval '1 month' - interval '1 day')::date then
    raise exception 'fechar um mês anterior voltou o horizonte: %', ivo.status_avaliado_ate;
  end if;
  select count(*) into n from public.child_status_history
  where child_id = ivo.id and reason = 'quatro_presencas_consecutivas';
  if n <> 1 then
    raise exception 'fechamento repetido duplicou o histórico: %', n;
  end if;
end $$;

reset role;

-- 7 faltas no mês fechado continuam membro; a 8ª devolve a visitante.
do $$
declare
  i integer;
  reuniao uuid;
  dia date;
  ivo public.children%rowtype;
begin
  for i in 0..3 loop
    dia := date '2027-02-02' + (i * 7);
    insert into public.meetings (cell_id, held_on, kind)
    values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', dia, 'celula')
    returning id into reuniao;
    insert into public.attendance (meeting_id, child_id, present)
    values (reuniao, 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb7', true);
  end loop;
  for i in 0..6 loop
    dia := date '2027-03-02' + (i * 7);
    insert into public.meetings (cell_id, held_on, kind)
    values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', dia, 'celula')
    returning id into reuniao;
    insert into public.attendance (meeting_id, child_id, present, outro_responsavel)
    values (reuniao, 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb7', false, false);
  end loop;

  perform internal.aplicar_status_ate('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb7', date '2027-04-30');
  perform internal.atualizar_sequencias('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb7');
  select * into ivo from public.children where id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb7';
  if ivo.status <> 'membro' or ivo.absence_streak <> 7 then
    raise exception 'Eva deveria continuar membro com 7 faltas, veio % %',
      ivo.status, ivo.absence_streak;
  end if;

  dia := date '2027-04-20';
  insert into public.meetings (cell_id, held_on, kind)
  values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', dia, 'celula')
  returning id into reuniao;
  insert into public.attendance (meeting_id, child_id, present)
  values (reuniao, 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb7', false);
  perform internal.aplicar_status_ate('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb7', date '2027-05-31');
  perform internal.atualizar_sequencias('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb7');
  select * into ivo from public.children where id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb7';
  if ivo.status <> 'visitante' or ivo.absence_streak <> 8 then
    raise exception 'Eva deveria voltar a visitante na 8ª falta, veio % %',
      ivo.status, ivo.absence_streak;
  end if;
end $$;

-- Sem guarda, a semana neutra é recusada.
do $$
declare
  reuniao uuid;
begin
  insert into public.meetings (cell_id, held_on, kind)
  values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', date '2027-12-07', 'celula')
  returning id into reuniao;
  insert into public.attendance (meeting_id, child_id, present, outro_responsavel)
  values (reuniao, 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb8', false, true);
  raise exception 'aceitou outro responsável sem guarda compartilhada';
exception
  when others then
    if sqlerrm ilike '%aceitou outro responsável%' then
      raise;
    end if;
    if sqlerrm not ilike '%guarda compartilhada%' then
      raise exception 'erro inesperado na guarda: %', sqlerrm;
    end if;
end $$;

-- Presenças intercaladas com semana neutra, atravessando o fechamento.
do $$
declare
  passo integer;
  reuniao uuid;
  dia date;
  eva public.children%rowtype;
  marcas text[] := array['P', 'N', 'P', 'N', 'P', 'N', 'P'];
begin
  for passo in 1..array_length(marcas, 1) loop
    dia := date '2027-06-07' + ((passo - 1) * 7);
    insert into public.meetings (cell_id, held_on, kind)
    values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', dia, 'celula')
    returning id into reuniao;
    insert into public.attendance (meeting_id, child_id, present, outro_responsavel)
    values (
      reuniao,
      'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb7',
      marcas[passo] = 'P',
      marcas[passo] = 'N'
    );
  end loop;

  select * into eva from public.children where id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb7';
  if eva.status_avaliado_ate < date '2027-07-31' and eva.status <> 'visitante' then
    raise exception 'a sequência neutra não deveria mudar o status antes do fechamento';
  end if;

  perform internal.aplicar_status_ate('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb7', date '2027-07-31');
  perform internal.atualizar_sequencias('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb7');
  select * into eva from public.children where id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb7';
  if eva.status <> 'membro' or eva.presence_streak <> 4 or eva.absence_streak <> 0 then
    raise exception 'Eva deveria ser membro com 4 presenças intercaladas, veio % % %',
      eva.status, eva.presence_streak, eva.absence_streak;
  end if;
end $$;

-- Líder não fecha o mês.
select set_config('request.jwt.claim.sub', '22222222-2222-4222-8222-222222222222', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"22222222-2222-4222-8222-222222222222","role":"authenticated"}',
  true
);
set local role authenticated;
do $$
begin
  perform public.fechar_status_do_mes(2027, 6);
  raise exception 'Bruno fechou o status';
exception
  when others then
    if sqlerrm ilike '%Bruno fechou%' then
      raise;
    end if;
    if sqlerrm not ilike '%discipuladora ou quem está acima%' then
      raise exception 'erro inesperado do Bruno: %', sqlerrm;
    end if;
end $$;

rollback;
