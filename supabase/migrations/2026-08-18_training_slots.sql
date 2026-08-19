-- Migration: scheduling module ("תיאום אימונים" — training_slots table + RLS), 2026-08-18.
-- Paste this into the Supabase SQL editor (Project → SQL Editor → New query) and run it
-- against the real project. Safe to re-run — uses IF NOT EXISTS / DROP POLICY IF EXISTS
-- throughout. See PROJECT.md ("מודול תיאום אימונים") and OPEN_QUESTIONS.md for the product
-- decisions behind this; see db/schema.sql for the annotated "fresh DB" version.
--
-- Prerequisite: the 2026-08-08_user_roles_and_login.sql migration must already be applied
-- (this depends on is_owner(), is_assigned_trainer(), current_trainer_id(), etc.) — those
-- functions are re-created here defensively via CREATE OR REPLACE so this file is safe to
-- run standalone too, but the underlying trainers/clients.auth_user_id columns and login
-- flow must already exist for any of this to actually be reachable by a real user.
--
-- Nothing here sends email by itself — the app calls a separate Edge Function
-- (see supabase/functions/notify-booking/index.ts) after a successful booking, best-effort.

-- ---------- 1. table ----------

create table if not exists training_slots (
  id          uuid primary key default gen_random_uuid(),
  trainer_id  uuid not null references trainers(id) on delete cascade,
  date        date not null,
  start_time  time not null,
  end_time    time not null,
  status      text not null default 'open' check (status in ('open','booked')),
  client_id   uuid references clients(id) on delete set null,
  created_at  timestamptz not null default now(),
  constraint training_slots_booked_has_client check (status <> 'booked' or client_id is not null)
);
create index if not exists training_slots_trainer_date_idx on training_slots (trainer_id, date, start_time);
create unique index if not exists training_slots_trainer_datetime_uniq on training_slots (trainer_id, date, start_time);

-- ---------- 2. row level security ----------

alter table training_slots enable row level security;

create or replace function is_owner() returns boolean
language sql stable security definer as $$
  select exists (
    select 1 from trainers
    where auth_user_id = auth.uid() and role = 'owner'
  );
$$;

create or replace function current_trainer_id() returns uuid
language sql stable security definer as $$
  select id from trainers where auth_user_id = auth.uid();
$$;

create or replace function current_client_id() returns uuid
language sql stable security definer as $$
  select id from clients where auth_user_id = auth.uid();
$$;

create or replace function is_any_client() returns boolean
language sql stable security definer as $$
  select exists (select 1 from clients where auth_user_id = auth.uid());
$$;

drop policy if exists training_slots_select on training_slots;
create policy training_slots_select on training_slots for select
  using (
    is_owner()
    or trainer_id = current_trainer_id()
    or (status = 'open' and is_any_client())
    or client_id = current_client_id()
  );

drop policy if exists training_slots_insert on training_slots;
create policy training_slots_insert on training_slots for insert
  with check (is_owner() or trainer_id = current_trainer_id());

drop policy if exists training_slots_update_owner on training_slots;
create policy training_slots_update_owner on training_slots for update
  using (is_owner() or trainer_id = current_trainer_id())
  with check (is_owner() or trainer_id = current_trainer_id());

drop policy if exists training_slots_update_book on training_slots;
create policy training_slots_update_book on training_slots for update
  using (status = 'open' and is_any_client())
  with check (status = 'booked' and client_id = current_client_id());

-- intentionally no delete policy — cancelling/removing a slot is backlog, not MVP.
