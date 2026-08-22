-- Migration: allow trainers/owner to upload training-note recordings, 2026-08-22.
-- Paste this into the Supabase SQL editor (Project → SQL Editor → New query) and run it
-- against the real project. Safe to re-run — uses DROP POLICY IF EXISTS.
--
-- Why: the `training-note-audio` Storage bucket was created manually via the dashboard
-- (public read access, so playback via getPublicUrl works with no policy needed). But
-- Storage's `storage.objects` table has row-level security ON by default regardless of
-- the bucket's public/private setting — "public" only affects reads through the public
-- URL endpoint, not uploads. With no INSERT policy for this bucket, every upload from the
-- app fails with "new row violates row-level security policy". This adds that policy,
-- matching the same is_owner()/is_any_trainer() pattern already used for training_notes
-- itself (see db/schema.sql) — recording a note is a trainer/owner action, not a client one.
--
-- Prerequisite: 2026-08-08_user_roles_and_login.sql must already be applied (this depends
-- on is_owner() and is_any_trainer() already existing).

drop policy if exists training_note_audio_insert on storage.objects;

create policy training_note_audio_insert on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'training-note-audio'
    and (is_owner() or is_any_trainer())
  );
