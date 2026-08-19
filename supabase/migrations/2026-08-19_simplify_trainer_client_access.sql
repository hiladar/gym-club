-- Migration: simplify trainer<->client access, 2026-08-19.
-- Paste this into the Supabase SQL editor (Project → SQL Editor → New query) and run it
-- against the real project. Safe to re-run — uses DROP POLICY/FUNCTION IF EXISTS and
-- DROP TABLE IF EXISTS throughout. See PROJECT.md ("סוגי משתמשים והתחברות" — "פישוט
-- 19.08.26") and "מודול תיאום אימונים" for the product decision behind this.
--
-- What changes:
--   1. The client_trainers link table (many-to-many client<->trainer assignment) is
--      dropped entirely. Every trainer (and the owner) now sees/edits every client —
--      no more "assigned clients only".
--   2. training_slots visibility opens up: every trainer can now SEE every trainer's
--      slots (not just their own), matching the owner's existing "כל המאמנים" tab.
--      Creating/editing a slot stays scoped to the owning trainer (unchanged).
--
-- Prerequisite: 2026-08-08_user_roles_and_login.sql and 2026-08-18_training_slots.sql
-- must already be applied (this depends on is_owner(), is_any_trainer(),
-- current_client_id(), is_any_client(), etc. already existing).
--
-- IMPORTANT: step 1 drops client_trainers and any rows in it. If you want to keep a
-- record of the assignments that existed before running this, export the table first
-- (Table Editor → client_trainers → Export CSV) — the app no longer reads or writes
-- this table after this migration, so nothing will break once it's gone, but the data
-- itself is not recoverable through the app afterward.

-- ---------- 1. drop the client_trainers table (its own policies go with it) ----------
-- NOTE: is_assigned_trainer(uuid) is NOT dropped here — clients/measurements/plans/notes/
-- exercises policies still reference it until steps 2-4 replace them below. Dropping it
-- early fails with "cannot drop function ... because other objects depend on it". It's
-- dropped last, in step 5, once nothing references it anymore.

drop policy if exists client_trainers_select on client_trainers;
drop policy if exists client_trainers_insert on client_trainers;
drop policy if exists client_trainers_update on client_trainers;
drop policy if exists client_trainers_delete on client_trainers;

drop table if exists client_trainers;

-- ---------- 2. clients: any trainer (not just an "assigned" one) has full access ----------

drop policy if exists clients_select on clients;
create policy clients_select on clients for select
  using (is_owner() or is_any_trainer() or is_self_client(id));

drop policy if exists clients_insert on clients;
create policy clients_insert on clients for insert
  with check (is_owner() or is_any_trainer());

drop policy if exists clients_update on clients;
create policy clients_update on clients for update
  using (is_owner() or is_any_trainer())
  with check (is_owner() or is_any_trainer());

drop policy if exists clients_delete on clients;
create policy clients_delete on clients for delete
  using (is_owner() or is_any_trainer());

-- ---------- 3. measurements / training_plans / training_notes: same change ----------

drop policy if exists measurements_select on measurements;
create policy measurements_select on measurements for select
  using (is_owner() or is_any_trainer() or is_self_client(client_id));
drop policy if exists measurements_modify on measurements;
create policy measurements_modify on measurements for all
  using (is_owner() or is_any_trainer())
  with check (is_owner() or is_any_trainer());

drop policy if exists training_plans_select on training_plans;
create policy training_plans_select on training_plans for select
  using (is_owner() or is_any_trainer() or is_self_client(client_id));
drop policy if exists training_plans_modify on training_plans;
create policy training_plans_modify on training_plans for all
  using (is_owner() or is_any_trainer())
  with check (is_owner() or is_any_trainer());

drop policy if exists training_notes_select on training_notes;
create policy training_notes_select on training_notes for select
  using (is_owner() or is_any_trainer() or is_self_client(client_id));
drop policy if exists training_notes_modify on training_notes;
create policy training_notes_modify on training_notes for all
  using (is_owner() or is_any_trainer())
  with check (is_owner() or is_any_trainer());

-- ---------- 4. training_plan_exercises: scoped through the parent plan's client ----------

drop policy if exists training_plan_exercises_select on training_plan_exercises;
create policy training_plan_exercises_select on training_plan_exercises for select
  using (exists (
    select 1 from training_plans p
    where p.id = training_plan_id
      and (is_owner() or is_any_trainer() or is_self_client(p.client_id))
  ));
drop policy if exists training_plan_exercises_modify on training_plan_exercises;
create policy training_plan_exercises_modify on training_plan_exercises for all
  using (exists (
    select 1 from training_plans p
    where p.id = training_plan_id and (is_owner() or is_any_trainer())
  ))
  with check (exists (
    select 1 from training_plans p
    where p.id = training_plan_id and (is_owner() or is_any_trainer())
  ));

-- ---------- 5. training_slots: any trainer can now SEE every trainer's slots ----------
-- (create/edit stays scoped to the owning trainer — training_slots_insert and
-- training_slots_update_owner/update_book are unchanged, not touched here.)

drop policy if exists training_slots_select on training_slots;
create policy training_slots_select on training_slots for select
  using (
    is_owner()
    or is_any_trainer()
    or (status = 'open' and is_any_client())
    or client_id = current_client_id()
  );

-- ---------- 6. now safe to drop is_assigned_trainer() — no policy references it anymore ----------

drop function if exists is_assigned_trainer(uuid);
