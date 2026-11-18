-- 8 faltas para voltar a visitante, e semana neutra da guarda compartilhada.
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

-- Ivo: 4 presenças, 7 faltas ainda membro, a 8ª devolve a visitante.
do $$
declare
  i integer;
  reuniao uuid;
  dia date;
  ivo public.children%rowtype;
begin
  for i in 0..3 loop
    dia := date '2026-09-07' + (i * 7);
    insert into public.meetings (cell_id, held_on, kind)
    values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', dia, 'celula')
    returning id into reuniao;
    insert into public.attendance (meeting_id, child_id, present)
    values (reuniao, 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb8', true);
  end loop;

  select * into ivo from public.children where id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb8';
  if ivo.status <> 'membro' or ivo.presence_streak <> 4 then
    raise exception 'Ivo deveria virar membro na 4ª presença';
  end if;

  for i in 4..10 loop
    dia := date '2026-09-07' + (i * 7);
    insert into public.meetings (cell_id, held_on, kind)
    values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', dia, 'celula')
    returning id into reuniao;
    insert into public.attendance (meeting_id, child_id, present)
    values (reuniao, 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb8', false);
  end loop;

  select * into ivo from public.children where id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb8';
  if ivo.status <> 'membro' or ivo.absence_streak <> 7 or ivo.presence_streak <> 0 then
    raise exception 'Ivo deveria continuar membro com 7 faltas, veio % % %',
      ivo.status, ivo.absence_streak, ivo.presence_streak;
  end if;

  dia := date '2026-09-07' + (11 * 7);
  insert into public.meetings (cell_id, held_on, kind)
  values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', dia, 'celula')
  returning id into reuniao;
  insert into public.attendance (meeting_id, child_id, present)
  values (reuniao, 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb8', false);

  select * into ivo from public.children where id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb8';
  if ivo.status <> 'visitante' or ivo.absence_streak <> 8 then
    raise exception 'Ivo deveria voltar a visitante na 8ª falta';
  end if;
  if (select count(*) from public.child_status_history
      where child_id = ivo.id and reason = 'oito_ausencias_consecutivas') <> 1 then
    raise exception 'histórico do Ivo sem a volta por 8 faltas';
  end if;
end $$;

-- Sem guarda, a semana neutra é recusada.
do $$
declare
  reuniao uuid;
begin
  insert into public.meetings (cell_id, held_on, kind)
  values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', date '2026-12-07', 'celula')
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

-- Eva: presença, outro responsável, presença... a 4ª presença vira membro.
-- A semana neutra não zera a sequência.
do $$
declare
  passo integer;
  reuniao uuid;
  dia date;
  eva public.children%rowtype;
  marcas text[] := array['P', 'N', 'P', 'N', 'P', 'N', 'P', 'N'];
begin
  for passo in 1..array_length(marcas, 1) loop
    dia := date '2026-07-06' + ((passo - 1) * 7);
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
  if eva.status <> 'membro' or eva.presence_streak <> 4 or eva.absence_streak <> 0 then
    raise exception 'Eva deveria ser membro com 4 presenças intercaladas, veio % % %',
      eva.status, eva.presence_streak, eva.absence_streak;
  end if;

  -- Culto no meio não mexe.
  insert into public.meetings (cell_id, held_on, kind)
  values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', date '2026-07-08', 'culto')
  returning id into reuniao;
  insert into public.attendance (meeting_id, child_id, present)
  values (reuniao, 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb7', false);

  select * into eva from public.children where id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb7';
  if eva.presence_streak <> 4 or eva.status <> 'membro' then
    raise exception 'culto alterou a Eva';
  end if;
end $$;

rollback;
