-- Liga uma pastora acima de discipuladoras que já existem.
-- Não mexe em células, crianças, encontros nem relatórios.
-- Rode no SQL editor (postgres) depois de criar a conta com papel 'pastor'.
--
-- A célula pode continuar com pastor_id nulo: a árvore anda por supervisor_id.

-- update public.profiles
-- set supervisor_id = '<uuid-da-pastora>'
-- where role = 'discipulador'
--   and id = '<uuid-da-discipuladora>'
--   and supervisor_id is null;

-- Pelo app, a pessoa autenticada (admin, a própria discipuladora ou a pastora) chama:
-- select public.vincular_pastor('<uuid-da-pastora>', '<uuid-da-discipuladora>');
