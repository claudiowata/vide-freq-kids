-- O advisor do Supabase marca SECURITY DEFINER executável por anon.
-- No projeto, criar função em public também concede EXECUTE a anon,
-- authenticated e service_role. Revogar só de public não tira o grant de anon.
--
-- public.vincular_pastor já exige auth.uid() e só segue se essa pessoa é
-- admin, a pastora informada ou a própria discipuladora. Esta migration não
-- muda essa regra: só impede o papel anon de chamá-la.
--
-- public.needs_initial_setup continua com anon. /login e /setup a chamam
-- antes de existir sessão, e ela só diz se a tabela de contas está vazia.
--
-- multiplicar_celula e remanejar_criancas já usam auth.uid() e search_path
-- fixo. O grant explícito de anon, vindo do privilégio padrão, é revogado aqui.

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

revoke all on function public.needs_initial_setup() from public;
grant execute on function public.needs_initial_setup() to anon, authenticated;

grant execute on function public.vincular_pastor(uuid, uuid) to authenticated;
grant execute on function public.multiplicar_celula(uuid, text, text, uuid, smallint, time, text, date, uuid[]) to authenticated;
grant execute on function public.remanejar_criancas(uuid[], uuid) to authenticated;

-- Funções que gravam ou nascem conta não ficam na API do usuário logado.
revoke all on function public.handle_new_user() from public, anon, authenticated;
revoke all on function internal.recompute_child_status(uuid) from public, anon, authenticated;
revoke all on function internal.assert_can_manage_cell(uuid, uuid) from public, anon, authenticated;

comment on function public.vincular_pastor(uuid, uuid) is
  'Coloca uma pastora acima de uma discipuladora. Exige auth.uid() ativo: admin, a pastora ou a própria discipuladora. O papel anon não executa.';

comment on function public.needs_initial_setup() is
  'Verdadeiro enquanto não existe nenhuma conta. Anon pode executar porque /login e /setup consultam isso antes do login.';
