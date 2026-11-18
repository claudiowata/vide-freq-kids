-- A migration 20261118200000 varre as funções que já existem na hora em que
-- ela roda. 20261118210000 cria internal.attendance_require_shared_custody
-- depois disso e substitui internal.recompute_child_status. Esta varredura
-- roda de novo para cobrir as duas, com search_path fixo e sem EXECUTE para anon.
-- needs_initial_setup continua no anon.

do $$
declare
  fn record;
begin
  for fn in
    select p.oid::regprocedure as signature,
           p.proname as name
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where p.prosecdef
      and n.nspname in ('public', 'internal')
  loop
    execute format('alter function %s set search_path = public', fn.signature);
    if fn.name <> 'needs_initial_setup' then
      execute format('revoke all on function %s from public, anon', fn.signature);
    end if;
  end loop;
end $$;

grant execute on function internal.attendance_require_shared_custody() to authenticated;

revoke all on function public.handle_new_user() from public, anon, authenticated;
revoke all on function internal.recompute_child_status(uuid) from public, anon, authenticated;
revoke all on function internal.assert_can_manage_cell(uuid, uuid) from public, anon, authenticated;

grant execute on function public.vincular_pastor(uuid, uuid) to authenticated;
grant execute on function public.multiplicar_celula(uuid, text, text, uuid, smallint, time, text, date, uuid[]) to authenticated;
grant execute on function public.remanejar_criancas(uuid[], uuid) to authenticated;
grant execute on function public.needs_initial_setup() to anon, authenticated;
