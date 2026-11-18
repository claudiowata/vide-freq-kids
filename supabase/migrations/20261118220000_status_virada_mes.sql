-- O status gravado só muda na virada do mês. Durante o mês ele fica fixo.
-- A sequência de presenças e faltas atravessa meses e é avaliada até o fim
-- do mês fechado: 4 presenças -> membro, 8 faltas -> visitante.
-- Semana neutra e culto continuam fora. status_avaliado_ate torna o fechamento
-- idempotente. RLS permanece ligado.

alter table public.children
  add column status_avaliado_ate date;

comment on column public.children.status_avaliado_ate is
  'Fim do último mês já aplicado ao status. Fechar de novo o mesmo período não muda o resultado se a chamada não mudou.';

create or replace function internal.fim_do_mes(p_dia date)
returns date
language sql
immutable
set search_path = public
as $$
  select (date_trunc('month', p_dia) + interval '1 month' - interval '1 day')::date;
$$;

-- Recalcula o status oficial até p_ate e regrava o histórico das viradas.
-- Não mexe nas sequências do mês aberto.
create or replace function internal.aplicar_status_ate(p_child uuid, p_ate date)
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
  v_closed text := 'visitante';
  v_month date;
  v_last_month date := null;
  v_ja date;
  v_marco date;
begin
  select status_avaliado_ate into v_ja
  from public.children
  where id = p_child;
  if v_ja is not null and v_ja > p_ate then
    p_ate := v_ja;
  end if;

  perform set_config('internal.recomputing', 'on', true);

  delete from public.child_status_history
  where child_id = p_child
    and reason <> 'cadastro_inicial';

  for mark in
    select a.present, a.outro_responsavel, m.held_on
    from public.attendance a
    join public.meetings m on m.id = a.meeting_id
    where a.child_id = p_child
      and m.kind = 'celula'
      and m.held_on <= p_ate
    order by m.held_on, m.created_at, a.created_at
  loop
    v_month := internal.fim_do_mes(mark.held_on);
    if v_last_month is not null and v_month is distinct from v_last_month then
      if v_status is distinct from v_closed then
        v_marco := least(v_last_month, p_ate);
        insert into public.child_status_history (
          child_id, from_status, to_status, changed_on, reason
        ) values (
          p_child,
          v_closed,
          v_status,
          v_marco,
          case
            when v_status = 'membro' then 'quatro_presencas_consecutivas'
            else 'oito_ausencias_consecutivas'
          end
        );
        v_closed := v_status;
      end if;
    end if;
    v_last_month := v_month;

    if mark.outro_responsavel then
      continue;
    end if;

    if mark.present then
      v_presence := v_presence + 1;
      v_absence := 0;
      if v_status = 'visitante' and v_presence >= 4 then
        v_status := 'membro';
      end if;
    else
      v_presence := 0;
      v_absence := v_absence + 1;
      if v_status = 'membro' and v_absence >= 8 then
        v_status := 'visitante';
      end if;
    end if;
  end loop;

  if v_last_month is not null and v_status is distinct from v_closed then
    v_marco := least(v_last_month, p_ate);
    insert into public.child_status_history (
      child_id, from_status, to_status, changed_on, reason
    ) values (
      p_child,
      v_closed,
      v_status,
      v_marco,
      case
        when v_status = 'membro' then 'quatro_presencas_consecutivas'
        else 'oito_ausencias_consecutivas'
      end
    );
    v_closed := v_status;
  end if;

  update public.children
  set status = v_closed,
      status_avaliado_ate = p_ate
  where id = p_child;
end;
$$;

create or replace function internal.atualizar_sequencias(p_child uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  mark record;
  v_presence integer := 0;
  v_absence integer := 0;
  v_first date := null;
begin
  for mark in
    select a.present, a.outro_responsavel, m.held_on
    from public.attendance a
    join public.meetings m on m.id = a.meeting_id
    where a.child_id = p_child
      and m.kind = 'celula'
    order by m.held_on, m.created_at, a.created_at
  loop
    if mark.outro_responsavel then
      continue;
    end if;
    if mark.present then
      if v_first is null then
        v_first := mark.held_on;
      end if;
      v_presence := v_presence + 1;
      v_absence := 0;
    else
      v_presence := 0;
      v_absence := v_absence + 1;
    end if;
  end loop;

  perform set_config('internal.recomputing', 'on', true);
  update public.children
  set presence_streak = v_presence,
      absence_streak = v_absence,
      first_visit_on = v_first
  where id = p_child;
end;
$$;

-- Chamada no mês aberto atualiza sequências, não o status.
-- Se o mês anterior ainda não foi avaliado, avalia até o fim dele.
create or replace function internal.recompute_child_status(p_child uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_corte date := (date_trunc('month', current_date)::date - 1);
  v_ate date;
begin
  select status_avaliado_ate into v_ate
  from public.children
  where id = p_child;

  if v_ate is null or v_ate < v_corte then
    perform internal.aplicar_status_ate(p_child, v_corte);
  end if;
  perform internal.atualizar_sequencias(p_child);
end;
$$;

create or replace function public.fechar_status_do_mes(p_ano integer, p_mes integer)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  actor uuid := auth.uid();
  fim date;
  cid uuid;
begin
  if actor is null then
    raise exception 'é preciso estar autenticado';
  end if;
  if not exists (
    select 1 from public.profiles
    where id = actor and active and role in ('pastor', 'discipulador')
  ) then
    raise exception 'só a discipuladora ou quem está acima fecha o status do mês';
  end if;
  if p_mes < 1 or p_mes > 12 then
    raise exception 'mês inválido';
  end if;

  fim := internal.fim_do_mes(make_date(p_ano, p_mes, 1));
  for cid in
    select ch.id
    from public.children ch
    where internal.can_edit_cell_id(actor, ch.cell_id)
  loop
    perform internal.aplicar_status_ate(cid, fim);
    perform internal.atualizar_sequencias(cid);
  end loop;
end;
$$;

revoke all on function internal.fim_do_mes(date) from public, anon, authenticated;
revoke all on function internal.aplicar_status_ate(uuid, date) from public, anon, authenticated;
revoke all on function internal.atualizar_sequencias(uuid) from public, anon, authenticated;
revoke all on function internal.recompute_child_status(uuid) from public, anon, authenticated;
revoke all on function public.fechar_status_do_mes(integer, integer) from public, anon;
grant execute on function public.fechar_status_do_mes(integer, integer) to authenticated;

comment on function public.fechar_status_do_mes(integer, integer) is
  'Aplica o status até o fim do mês, na subárvore de quem chama. Repetir o mesmo mês é idempotente.';

do $$
declare
  cid uuid;
  corte date := (date_trunc('month', current_date)::date - 1);
begin
  for cid in select id from public.children loop
    perform internal.aplicar_status_ate(cid, corte);
    perform internal.atualizar_sequencias(cid);
  end loop;
end $$;

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
    new.status_avaliado_ate := null;
    return new;
  end if;
  if new.status is distinct from old.status
     or new.presence_streak is distinct from old.presence_streak
     or new.absence_streak is distinct from old.absence_streak
     or new.first_visit_on is distinct from old.first_visit_on
     or new.status_avaliado_ate is distinct from old.status_avaliado_ate then
    raise exception 'status, sequências e primeira visita são calculados pela frequência';
  end if;
  return new;
end;
$$;

alter table public.children enable row level security;
alter table public.children force row level security;
alter table public.child_status_history enable row level security;
alter table public.child_status_history force row level security;
