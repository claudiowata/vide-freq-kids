-- As migrations 20261118120000 e 20261118143000 foram aplicadas com UTF-8
-- duplicado. Esta migration regrava o corpo de vincular_pastor e os
-- comentários de tabela, view e coluna com o texto mais recente do repositório.
-- Colunas removidas em regras_planilha não entram. RLS permanece ligado.

create or replace function public.vincular_pastor(p_pastor uuid, p_discipulador uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  actor uuid := auth.uid();
begin
  if actor is null then
    raise exception 'é preciso estar autenticado';
  end if;
  if not exists (
    select 1 from public.profiles
    where id = p_pastor and role = 'pastor' and active
  ) then
    raise exception 'pastor inválido';
  end if;
  if not exists (
    select 1 from public.profiles
    where id = p_discipulador and role = 'discipulador' and active
  ) then
    raise exception 'discipulador inválido';
  end if;
  if not exists (
    select 1 from public.profiles
    where id = actor
      and active
      and (is_admin or id = p_pastor or id = p_discipulador)
  ) then
    raise exception 'sem permissão para vincular';
  end if;

  update public.profiles
  set supervisor_id = p_pastor
  where id = p_discipulador
    and role = 'discipulador'
    and (supervisor_id is null or supervisor_id = p_pastor);

  if not found then
    raise exception 'discipulador já está vinculado a outra pessoa';
  end if;
end;
$$;

revoke all on function public.vincular_pastor(uuid, uuid) from public, anon;
grant execute on function public.vincular_pastor(uuid, uuid) to authenticated;

comment on function public.vincular_pastor(uuid, uuid) is
  'Coloca uma pastora acima de uma discipuladora. Exige auth.uid() ativo: admin, a pastora ou a própria discipuladora. O papel anon não executa.';

comment on table public.profiles is
  'Contas da liderança. A pastora pode não existir: discipulador com supervisor_id nulo é raiz.';
comment on column public.profiles.pastor_id is
  'Atalho anulável. A visibilidade usa a cadeia supervisor_id e continua valendo quando isto é nulo.';
comment on column public.profiles.is_admin is
  'A primeira discipuladora da rede nasce como admin raiz. Não amplia a árvore que ela enxerga.';

comment on table public.cells is
  'Ficha da Célula Kids e Juvenis. pastor_id é anulável de propósito.';
comment on column public.cells.weekday is '0 = domingo … 6 = sábado.';
comment on column public.cells.cell_type is
  'kids (Kids), juvenis (Juvenis) ou mista_juvenis (Mista com Juvenis, a "C Mista J" da planilha).';
comment on column public.cells.color_classification is
  'VERDE, AZUL, VERMELHA ou BEGE. Ainda não há regra nem faixas: o valor é só um campo configurável.';
comment on column public.cells.leader_has_ctl is 'CTL do líder, como na ficha (sim/não).';
comment on column public.cells.trainee_name is 'Líder em treinamento (LT).';
comment on column public.cells.host_name is 'Anfitrião.';
comment on column public.cells.host_is_believer is 'Anfitrião é crente?';
comment on column public.cells.is_parallel is 'Paralela ou não paralela.';

comment on table public.children is
  'Crianças e jovens. Toda pessoa começa visitante. Status e sequências são calculados.';
comment on column public.children.parents_are_believers is 'Pais crentes, como na ficha.';
comment on column public.children.guardians is 'Responsáveis.';
comment on column public.children.authorized_pickup is 'Quem pode buscar.';
comment on column public.children.allergies_medication is 'Alergias e medicação.';
comment on column public.children.image_authorization is 'Autorização de imagem.';
comment on column public.children.culto is 'Frequenta o culto (flag da ficha, não é a chamada).';
comment on column public.children.mae_convertida is
  'A mãe desta criança é convertida? Sim/não. Não é um total do mês.';
comment on column public.children.pai_convertido is
  'O pai desta criança é convertido? Sim/não. Não é um total do mês.';

comment on table public.child_status_history is
  'Mudanças datadas de visitante/membro. A chamada da célula reescreve as transições calculadas.';

comment on table public.meetings is
  'Encontros da célula ou culto. O culto não altera o status da criança.';

comment on table public.attendance is
  'Chamada. present = false é ausência explícita e entra na sequência.';
comment on column public.attendance.present is
  'Presença na célula. Falso com outro_responsavel ainda não é falta.';

comment on table public.monthly_reports is
  'Fechamento mensal no formato da planilha Acompanhamento de Células.';
comment on column public.monthly_reports.sent_to_encontro is 'Enviados para o Encontro.';
comment on column public.monthly_reports.youth_baptized is 'Jovens batizados no mês.';
comment on column public.monthly_reports.is_project_cell is 'É projeto célula?';
comment on column public.monthly_reports.bridge_event_visitors is 'Visitantes no Evento Ponte.';
comment on column public.monthly_reports.members_average is
  'M: média do mês dos membros presentes. Semanas em branco ficam de fora.';
comment on column public.monthly_reports.attendance_percent is
  '%: M dividido pelo total de membros da célula, em percentual.';
comment on column public.monthly_reports.visitors_average is
  'V: média do mês dos visitantes. Semanas em branco ficam de fora.';

comment on view public.children_with_age is
  'Crianças com age_years calculado. security_invoker para não furar o RLS.';

alter table public.profiles enable row level security;
alter table public.profiles force row level security;
alter table public.cells enable row level security;
alter table public.cells force row level security;
alter table public.children enable row level security;
alter table public.children force row level security;
alter table public.child_status_history enable row level security;
alter table public.child_status_history force row level security;
alter table public.meetings enable row level security;
alter table public.meetings force row level security;
alter table public.attendance enable row level security;
alter table public.attendance force row level security;
alter table public.monthly_reports enable row level security;
alter table public.monthly_reports force row level security;
