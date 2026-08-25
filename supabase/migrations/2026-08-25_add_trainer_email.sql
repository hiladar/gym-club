-- Migration: add a dedicated email column to trainers, 2026-08-25.
-- Paste this into the Supabase SQL editor and run it. Safe to re-run (IF NOT EXISTS).
--
-- Why: notify-booking previously emailed a trainer only via their login email (looked up
-- through auth_user_id). The owner asked for a dedicated contact email on the trainer
-- record instead, so notifications don't depend on the trainer having a login account or
-- wanting notifications at their login address specifically.
--
-- After running this, fill in each real trainer's email manually: Table Editor -> trainers
-- -> click into the `email` cell for each row. The app has no "edit trainer" form (trainers
-- aren't a CRUD entity in deploy/index.html), so this stays a manual one-time edit per
-- trainer, same as linking auth_user_id already is.
--
-- notify-booking (the Edge Function) must also be redeployed with its updated code to
-- actually use this column - see supabase/functions/notify-booking/index.ts and PROJECT.md.

alter table trainers add column if not exists email text;
