-- Status: 4 presenças continuam virando membro. A volta a visitante passa
-- de 4 para 8 faltas consecutivas de célula.
--
-- Guarda compartilhada: a chamada ganha "Semana com o outro responsável".
-- Essa semana é neutra (não é presença nem falta e não quebra a sequência).
-- Culto continua fora da conta.
--
-- O status já gravado é recalculado no fim. RLS permanece ligado.

alter table public.children
  add column guarda_compartilhada boolean not null default false;

comment on column public.children.guarda_compartilhada is
  'Guarda compartilhada (uma semana com cada responsável).';

alter table public.attendance
  add column outro_responsavel boolean not null default false;

comment on column public.attendance.outro_responsavel is
  'Semana com o outro responsável. Neutra: não entra na sequência nem no fechamento como falta.';

comment on column public.attendance.present is
  'Presença na célula. Falso com outro_responsavel ainda não é falta.';

alter table public.attendance
  drop constraint if exists attendance_outro_responsavel_neutro;

alter table public.attendance
  add constraint attendance_outro_responsavel_neutro
  check (outro_responsavel = false or present = false);

do $$
declare
  constraint_name text;
begin
  select con.conname
    into constraint_name
  from pg_constraint con
  where con.conrelid = 'public.child_status_history'::regclass
    and con.contype = 'c'
    and pg_get_constraintdef(con.oid) ilike '%quatro_ausencias%';

  if constraint_name is not null then
    execute format(
      'alter table public.child_status_history drop constraint %I',
      constraint_name
    );
  end if;
end $$;

alter table public.child_status_history
  add constraint child_status_history_reason_check
  check (
    reason in (
      'cadastro_inicial',
      'quatro_presencas_consecutivas',
      'quatro_ausencias_consecutivas',
      'oito_ausencias_consecutivas'
    )
  );

create or replace function internal.attendance_require_shared_custody()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.outro_responsavel and not exists (
    select 1
    from public.children
    where id = new.child_id
      and guarda_compartilhada
  ) then
    raise exception 'semana com o outro responsável só vale com guarda compartilhada';
  end if;
  return new;
end;
$$;

drop trigger if exists attendance_require_shared_custody on public.attendance;
create trigger attendance_require_shared_custody
  before insert or update on public.attendance
  for each row execute function internal.attendance_require_shared_custody();

revoke all on function internal.attendance_require_shared_custody() from public, anon;
grant execute on function internal.attendance_require_shared_custody() to authenticated;

-- 4 presenças consecutivas de célula: visitante vira membro.
-- 8 ausências consecutivas de célula: membro volta a visitante.
-- Semana com o outro responsável não altera as sequências.
-- Culto não entra. Espelha src/domain/child-status.ts.
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
      if v_status = 'membro' and v_absence >= 8 then
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
          else 'oito_ausencias_consecutivas'
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

do $$
declare
  cid uuid;
begin
  for cid in select id from public.children loop
    perform internal.recompute_child_status(cid);
  end loop;
end $$;

alter table public.children enable row level security;
alter table public.children force row level security;
alter table public.attendance enable row level security;
alter table public.attendance force row level security;
alter table public.child_status_history enable row level security;
alter table public.child_status_history force row level security;
