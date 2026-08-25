-- EA Pro Training — Phase 1 (MVP) database schema
-- PostgreSQL. Source of truth for the data model described in PROJECT.md.
-- Confirmed 2026-07-23. Units: kg / cm throughout. IDs: UUID.

create extension if not exists pgcrypto;

create table trainers (
  id            uuid primary key default gen_random_uuid(),
  auth_user_id  uuid unique references auth.users(id) on delete set null,
  full_name     text not null,
  role          text not null default 'trainer' check (role in ('owner','trainer')),
  email         text, -- added 25.08.26: contact address for booking-notification emails (notify-booking),
                       -- separate from auth_user_id's login email — a trainer may want notifications at a
                       -- different address than they log in with, or may not have a login account at all yet.
  created_at    timestamptz not null default now()
);

create table clients (
  id                       uuid primary key default gen_random_uuid(),
  auth_user_id             uuid unique references auth.users(id) on delete set null,
  full_name                text not null,
  phone                    text,
  email                    text,
  date_of_birth            date,
  gender                   text check (gender in ('male','female','other')),
  height_cm                numeric(5,1),
  profile_photo_url        text,
  training_goal            text,
  medical_condition        text,
  injuries_limitations     text,
  medications              text,
  doctor_approval          boolean,
  emergency_contact_name   text,
  emergency_contact_phone  text,
  created_at               timestamptz not null default now(),
  updated_at               timestamptz not null default now()
);

-- NOTE: the client_trainers link table (many-to-many client<->trainer
-- assignment) was removed 2026-08-19 to simplify the access model — every
-- trainer now sees/edits every client, no assignment step. See PROJECT.md
-- ("סוגי משתמשים והתחברות" — "פישוט 19.08.26") and
-- supabase/migrations/2026-08-19_simplify_trainer_client_access.sql, which
-- drops the table on the live project.

create table measurements (
  id                 uuid primary key default gen_random_uuid(),
  client_id          uuid not null references clients(id) on delete cascade,
  date               date not null,
  weight_kg          numeric(5,1),
  body_fat_percent   numeric(4,1),
  water_percent      numeric(4,1),
  muscle_mass_kg     numeric(5,1),
  fat_mass_kg        numeric(5,1),
  waist_cm           numeric(5,1),
  chest_cm           numeric(5,1),
  arm_cm             numeric(5,1),
  thigh_cm           numeric(5,1),
  notes              text,
  created_at         timestamptz not null default now()
);
create index on measurements (client_id, date desc);

-- "Current" plan for a client = the row with the latest effective_date.
create table training_plans (
  id              uuid primary key default gen_random_uuid(),
  client_id       uuid not null references clients(id) on delete cascade,
  effective_date  date not null,
  coach_notes     text,
  created_at      timestamptz not null default now()
);
create index on training_plans (client_id, effective_date desc);

create table training_plan_exercises (
  id                  uuid primary key default gen_random_uuid(),
  training_plan_id    uuid not null references training_plans(id) on delete cascade,
  order_index         int not null,
  exercise_name       text not null,
  sets                text,
  reps                text,
  working_weight_kg   text, -- free text: exercises can use bodyweight notation ("גוף+5"), not always a plain number
  rest_time           text,
  notes               text
);
create index on training_plan_exercises (training_plan_id, order_index);

create table training_notes (
  id          uuid primary key default gen_random_uuid(),
  client_id   uuid not null references clients(id) on delete cascade,
  date        date not null,
  time        time,
  note        text not null,
  audio_url   text,
  created_at  timestamptz not null default now()
);
create index on training_notes (client_id, date desc);

-- Scheduling module ("תיאום אימונים"), added 2026-08-18 — see PROJECT.md
-- ("מודול תיאום אימונים") and OPEN_QUESTIONS.md for the product decision.
-- A trainer manually creates open slots (no recurring pattern in this phase);
-- a client books one, which flips it to 'booked' and stamps client_id.
-- Cancelling a booking, or a trainer removing an already-created open slot,
-- is explicitly backlog (not supported by these policies) — that's why there
-- is no delete policy below: with RLS enabled and no delete policy, deletes
-- are blocked for everyone via the API, matching the intended app behavior.
create table training_slots (
  id          uuid primary key default gen_random_uuid(),
  trainer_id  uuid not null references trainers(id) on delete cascade,
  date        date not null,
  start_time  time not null,
  end_time    time not null, -- = start_time + 50 minutes, computed app-side on insert
  status      text not null default 'open' check (status in ('open','booked')),
  client_id   uuid references clients(id) on delete set null,
  created_at  timestamptz not null default now(),
  constraint training_slots_booked_has_client check (status <> 'booked' or client_id is not null)
);
create index on training_slots (trainer_id, date, start_time);
-- guards against a trainer accidentally double-entering the same slot; not a
-- substitute for a real anti-double-booking transaction (see RLS notes below).
create unique index training_slots_trainer_datetime_uniq on training_slots (trainer_id, date, start_time);

-- ============================================================================
-- User types & Row Level Security — added 2026-08-04, refined 2026-08-08,
-- simplified 2026-08-19 alongside the login UI in deploy/index.html.
-- Applied to the real Supabase project via
-- supabase/migrations/2026-08-08_user_roles_and_login.sql (18.08.26) and
-- supabase/migrations/2026-08-19_simplify_trainer_client_access.sql (not yet
-- run against the live project — see OPEN_QUESTIONS.md).
-- Reflects three user types described in PROJECT.md ("סוגי משתמשים והתחברות"):
--   owner   — trainers.role = 'owner': full read/write on everything except
--             other trainers stay owner-managed either way (see below).
--   trainer — trainers.role = 'trainer': read/write on EVERY client (no more
--             per-trainer assignment — client_trainers was removed 19.08.26,
--             see PROJECT.md "פישוט 19.08.26"). May create a new client.
--             Cannot manage other trainer rows (owner-only).
--   client  — clients.auth_user_id = auth.uid(): read-only on their own data.
-- Accounts are invite-only: an admin links a trainers/clients row to a
-- Supabase Auth user by setting auth_user_id (manual in the Supabase
-- dashboard for now — see OPEN_QUESTIONS.md for what's still undecided).
-- ============================================================================

alter table trainers                 enable row level security;
alter table clients                  enable row level security;
alter table measurements             enable row level security;
alter table training_plans           enable row level security;
alter table training_plan_exercises  enable row level security;
alter table training_notes           enable row level security;
alter table training_slots           enable row level security;

create or replace function is_owner() returns boolean
language sql stable security definer as $$
  select exists (
    select 1 from trainers
    where auth_user_id = auth.uid() and role = 'owner'
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

create or replace function current_client_id() returns uuid
language sql stable security definer as $$
  select id from clients where auth_user_id = auth.uid();
$$;

create or replace function is_any_client() returns boolean
language sql stable security definer as $$
  select exists (select 1 from clients where auth_user_id = auth.uid());
$$;

-- "is this slot still ahead of us?" — used by the training_slots policies below to keep
-- past slots out of both slot creation and the client's booking view (added 25.08.26).
-- Jerusalem wall-clock, not UTC: the club and every user are in Israel.
create or replace function slot_is_future(d date, t time) returns boolean
language sql stable as $$
  select (d + t) > (now() at time zone 'Asia/Jerusalem');
$$;

-- trainers: owner manages all rows; a trainer can see (not edit) their own row; a client
-- can see trainer names too — needed so the client's "book a session" screen can list
-- trainers to pick from (trainer full_name isn't sensitive, this is a small private club).
create policy trainers_select on trainers for select
  using (is_owner() or auth_user_id = auth.uid() or is_any_client());
create policy trainers_modify on trainers for all
  using (is_owner()) with check (is_owner());

-- clients: every trainer (and the owner) has full access to every client —
-- no more per-trainer assignment (client_trainers removed 19.08.26, see
-- PROJECT.md "פישוט 19.08.26"); client role is read-only on their own row.
create policy clients_select on clients for select
  using (is_owner() or is_any_trainer() or is_self_client(id));
create policy clients_insert on clients for insert
  with check (is_owner() or is_any_trainer());
create policy clients_update on clients for update
  using (is_owner() or is_any_trainer())
  with check (is_owner() or is_any_trainer());
create policy clients_delete on clients for delete
  using (is_owner() or is_any_trainer());

-- measurements / training_plans / training_notes: same shape, scoped by client_id.
create policy measurements_select on measurements for select
  using (is_owner() or is_any_trainer() or is_self_client(client_id));
create policy measurements_modify on measurements for all
  using (is_owner() or is_any_trainer())
  with check (is_owner() or is_any_trainer());

create policy training_plans_select on training_plans for select
  using (is_owner() or is_any_trainer() or is_self_client(client_id));
create policy training_plans_modify on training_plans for all
  using (is_owner() or is_any_trainer())
  with check (is_owner() or is_any_trainer());

create policy training_notes_select on training_notes for select
  using (is_owner() or is_any_trainer() or is_self_client(client_id));
create policy training_notes_modify on training_notes for all
  using (is_owner() or is_any_trainer())
  with check (is_owner() or is_any_trainer());

-- training_plan_exercises: scoped through the parent plan's client.
create policy training_plan_exercises_select on training_plan_exercises for select
  using (exists (
    select 1 from training_plans p
    where p.id = training_plan_id
      and (is_owner() or is_any_trainer() or is_self_client(p.client_id))
  ));
create policy training_plan_exercises_modify on training_plan_exercises for all
  using (exists (
    select 1 from training_plans p
    where p.id = training_plan_id and (is_owner() or is_any_trainer())
  ))
  with check (exists (
    select 1 from training_plans p
    where p.id = training_plan_id and (is_owner() or is_any_trainer())
  ));

-- training_slots: every trainer (and the owner) can SEE every slot, across all
-- trainers — added 19.08.26 (see PROJECT.md "פישוט 19.08.26"); a client sees
-- open slots for ANY trainer (to browse and pick one) plus their own booked
-- slots, but not other clients' bookings. Creating/editing a slot stays scoped
-- to the owning trainer (or owner) — see the insert/update policies below.
-- Past slots (added 25.08.26): a client is only offered open slots that are still ahead;
-- the owner/trainers keep seeing past slots as history, and a client keeps seeing their
-- own past bookings. Enforced in RLS rather than a CHECK constraint so that old rows stay
-- readable and updatable — see supabase/migrations/2026-08-25_slots_no_past.sql.
create policy training_slots_select on training_slots for select
  using (
    is_owner()
    or is_any_trainer()
    or (status = 'open' and is_any_client() and slot_is_future(date, start_time))
    or client_id = current_client_id()
  );

-- only the owning trainer (or owner) can create a slot for that trainer, and only for a
-- date/time that hasn't passed yet (25.08.26) — the app blocks it in the form too
-- (deploy/index.html: todayStr/dropPastTimes), this is the server-side half.
create policy training_slots_insert on training_slots for insert
  with check (
    (is_owner() or trainer_id = current_trainer_id())
    and slot_is_future(date, start_time)
  );

-- two permissive UPDATE policies, combined with OR by Postgres:
--  (a) the owning trainer/owner editing their own slot (e.g. future edit support).
--  (b) a client booking: only allowed FROM an open slot, and the new row must land
--      on status='booked' with client_id = themselves. This is enforced only at the
--      row level, not per-column — the app must only ever send {status,client_id} in
--      the update payload, otherwise a client could in principle also smuggle in a
--      trainer_id/date/time change in the same request. Acceptable for a small
--      private-club MVP; a stricter version would need a database trigger/RPC.
create policy training_slots_update_owner on training_slots for update
  using (is_owner() or trainer_id = current_trainer_id())
  with check (is_owner() or trainer_id = current_trainer_id());
-- the slot_is_future() guard is repeated here on purpose: UPDATE is evaluated
-- independently of the SELECT policy, so without it a client holding a slot id from an
-- earlier page load could still book a slot whose time has already passed.
create policy training_slots_update_book on training_slots for update
  using (status = 'open' and is_any_client() and slot_is_future(date, start_time))
  with check (status = 'booked' and client_id = current_client_id());

-- no delete policy: cancelling/removing a slot is backlog (see table comment above),
-- so deletes are blocked entirely for every role via the API while RLS is enabled.
