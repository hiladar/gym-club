-- Migration: user types + login (owner / trainer / client), 2026-08-08.
-- Paste this into the Supabase SQL editor (Project → SQL Editor → New query) and run it
-- against the real project. Safe to re-run — uses IF NOT EXISTS / DROP POLICY IF EXISTS
-- throughout. See PROJECT.md ("סוגי משתמשים והתחברות") and OPEN_QUESTIONS.md for the
-- product decisions behind this; see db/schema.sql for the annotated "fresh DB" version
-- of the same schema + policies.
--
-- After running this, do ONE manual step per real login you want to create:
--   1. Supabase Dashboard → Authentication → Users → Add user (email + password).
--   2. Copy that user's UUID.
--   3. Run:  update trainers set auth_user_id = '<uuid>', role = 'owner' where id = '<trainer row id>';
--            (or role = 'trainer', or  update clients set auth_user_id = '<uuid>' where id = '<client row id>';)

-- ---------- 1. new columns ----------

alter table trainers add column if not exists auth_user_id uuid unique references auth.users(id) on delete set null;
alter table trainers add column if not exists role text not null default 'trainer' check (role in ('owner','trainer'));

-- the single existing trainer row (the club owner) becomes role='owner'; harmless no-op on re-run.
update trainers set role = 'owner' where role = 'trainer' and id = (select id from trainers order by created_at asc limit 1);

alter table clients add column if not exists auth_user_id uuid unique references auth.users(id) on delete set null;

-- ---------- 2. row level security ----------

alter table trainers                 enable row level security;
alter table clients                  enable row level security;
alter table client_trainers          enable row level security;
alter table measurements             enable row level security;
alter table training_plans           enable row level security;
alter table training_plan_exercises  enable row level security;
alter table training_notes           enable row level security;

create or replace function is_owner() returns boolean
language sql stable security definer as $$
  select exists (
    select 1 from trainers
    where auth_user_id = auth.uid() and role = 'owner'
  );
$$;

create or replace function is_assigned_trainer(p_client_id uuid) returns boolean
language sql stable security definer as $$
  select exists (
    select 1 from client_trainers ct
    join trainers t on t.id = ct.trainer_id
    where ct.client_id = p_client_id and t.auth_user_id = auth.uid()
  );
$$;

create or replace function is_self_client(p_client_id uuid) returns boolean
language sql stable security definer as $$
  select exists (
    select 1 from clients where id = p_client_id and auth_user_id = auth.uid()
  );
$$;

create or replace function is_any_trainer() returns boolean
language sql stable security definer as $$
  select exists (select 1 from trainers where auth_user_id = auth.uid());
$$;

create or replace function current_trainer_id() returns uuid
language sql stable security definer as $$
  select id from trainers where auth_user_id = auth.uid();
$$;

-- trainers
drop policy if exists trainers_select on trainers;
create policy trainers_select on trainers for select
  using (is_owner() or auth_user_id = auth.uid());
drop policy if exists trainers_modify on trainers;
create policy trainers_modify on trainers for all
  using (is_owner()) with check (is_owner());

-- client_trainers
drop policy if exists client_trainers_select on client_trainers;
create policy client_trainers_select on client_trainers for select
  using (is_owner() or trainer_id = current_trainer_id());
drop policy if exists client_trainers_insert on client_trainers;
create policy client_trainers_insert on client_trainers for insert
  with check (is_owner() or trainer_id = current_trainer_id());
drop policy if exists client_trainers_update on client_trainers;
create policy client_trainers_update on client_trainers for update
  using (is_owner()) with check (is_owner());
drop policy if exists client_trainers_delete on client_trainers;
create policy client_trainers_delete on client_trainers for delete
  using (is_owner());
-- older draft name, in case it was ever applied — safe no-op if it wasn't.
drop policy if exists client_trainers_modify on client_trainers;

-- clients
drop policy if exists clients_select on clients;
create policy clients_select on clients for select
  using (is_owner() or is_assigned_trainer(id) or is_self_client(id));
drop policy if exists clients_insert on clients;
create policy clients_insert on clients for insert
  with check (is_owner() or is_any_trainer());
drop policy if exists clients_update on clients;
create policy clients_update on clients for update
  using (is_owner() or is_assigned_trainer(id))
  with check (is_owner() or is_assigned_trainer(id));
drop policy if exists clients_delete on clients;
create policy clients_delete on clients for delete
  using (is_owner() or is_assigned_trainer(id));
drop policy if exists clients_modify on clients;

-- measurements
drop policy if exists measurements_select on measurements;
create policy measurements_select on measurements for select
  using (is_owner() or is_assigned_trainer(client_id) or is_self_client(client_id));
drop policy if exists measurements_modify on measurements;
create policy measurements_modify on measurements for all
  using (is_owner() or is_assigned_trainer(client_id))
  with check (is_owner() or is_assigned_trainer(client_id));

-- training_plans
drop policy if exists training_plans_select on training_plans;
create policy training_plans_select on training_plans for select
  using (is_owner() or is_assigned_trainer(client_id) or is_self_client(client_id));
drop policy if exists training_plans_modify on training_plans;
create policy training_plans_modify on training_plans for all
  using (is_owner() or is_assigned_trainer(client_id))
  with check (is_owner() or is_assigned_trainer(client_id));

-- training_notes
drop policy if exists training_notes_select on training_notes;
create policy training_notes_select on training_notes for select
  using (is_owner() or is_assigned_trainer(client_id) or is_self_client(client_id));
drop policy if exists training_notes_modify on training_notes;
create policy training_notes_modify on training_notes for all
  using (is_owner() or is_assigned_trainer(client_id))
  with check (is_owner() or is_assigned_trainer(client_id));

-- training_plan_exercises (scoped through the parent plan's client)
drop policy if exists training_plan_exercises_select on training_plan_exercises;
create policy training_plan_exercises_select on training_plan_exercises for select
  using (exists (
    select 1 from training_plans p
    where p.id = training_plan_id
      and (is_owner() or is_assigned_trainer(p.client_id) or is_self_client(p.client_id))
  ));
drop policy if exists training_plan_exercises_modify on training_plan_exercises;
create policy training_plan_exercises_modify on training_plan_exercises for all
  using (exists (
    select 1 from training_plans p
    where p.id = training_plan_id and (is_owner() or is_assigned_trainer(p.client_id))
  ))
  with check (exists (
    select 1 from training_plans p
    where p.id = training_plan_id and (is_owner() or is_assigned_trainer(p.client_id))
  ));
