-- EA Pro Training — Phase 1 (MVP) database schema
-- PostgreSQL. Source of truth for the data model described in PROJECT.md.
-- Confirmed 2026-07-23. Units: kg / cm throughout. IDs: UUID.

create extension if not exists pgcrypto;

create table trainers (
  id          uuid primary key default gen_random_uuid(),
  full_name   text not null,
  created_at  timestamptz not null default now()
);

create table clients (
  id                       uuid primary key default gen_random_uuid(),
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

create table client_trainers (
  client_id   uuid not null references clients(id)  on delete cascade,
  trainer_id  uuid not null references trainers(id) on delete cascade,
  primary key (client_id, trainer_id)
);

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
  created_at  timestamptz not null default now()
);
create index on training_notes (client_id, date desc);
