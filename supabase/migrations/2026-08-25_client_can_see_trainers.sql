-- Migration: let a client see trainer names, 2026-08-25.
-- Paste this into the Supabase SQL editor (Project → SQL Editor → New query) and run it.
-- Safe to re-run — uses DROP POLICY IF EXISTS.
--
-- Bug this fixes: a logged-in client's "book a session" screen showed an empty trainer
-- dropdown, because the `trainers` table's SELECT policy never allowed the client role to
-- read it at all (only the owner, or a trainer reading their own row) — so the query for
-- trainer names silently came back with zero rows. See PROJECT.md / OPEN_QUESTIONS.md.
--
-- Prerequisite: 2026-08-08_user_roles_and_login.sql must already be applied (uses
-- is_owner() and is_any_client(), both defined there / in 2026-08-18_training_slots.sql).

drop policy if exists trainers_select on trainers;
create policy trainers_select on trainers for select
  using (is_owner() or auth_user_id = auth.uid() or is_any_client());
