-- Migration: no time slots in the past, 2026-08-25 (revised 2026-08-26 — see "revision" below).
-- Paste this into the Supabase SQL editor (Project → SQL Editor → New query) and run it.
-- Safe to re-run — uses CREATE OR REPLACE / DROP POLICY IF EXISTS.
-- STATUS: RUN SUCCESSFULLY against the real project on 2026-08-26 (owner ran it in the
-- Supabase SQL editor, reported "Success"). Safe to re-run if ever needed.
--
-- Product rule (see PROJECT.md, "מודול תיאום אימונים" → "משבצות בעבר"):
--   1. a trainer cannot open a slot whose date/time has already passed;
--   2. a client is never shown — and cannot book — an open slot in the past.
-- The app enforces both in the UI (deploy/index.html: todayStr/isPastSlot/dropPastTimes);
-- this migration is the server-side half, so the rule also holds for anything talking to
-- the API directly and for a stale browser tab left open past midnight.
--
-- Existing rows are intentionally left alone: past slots already in the table stay
-- readable by the trainer/owner (and by the client who booked them) as history — the
-- rules below only block CREATING a past slot and only hide past slots from the
-- "open slots to book" view. That's why this is done in RLS and not as a CHECK
-- constraint: a CHECK would also re-fire on every UPDATE of an old row.
--
-- Timezone: the club is in Israel and the app's clock is the user's device clock, so the
-- server compares against Jerusalem wall-clock time, not UTC. `date + start_time` builds
-- a timestamp from the two columns; `now() at time zone 'Asia/Jerusalem'` is "now" in the
-- same wall-clock frame.
--
-- Prerequisites: 2026-08-08_user_roles_and_login.sql, 2026-08-18_training_slots.sql and
-- 2026-08-19_simplify_trainer_client_access.sql must already be applied (this depends on
-- is_owner(), is_any_trainer(), is_any_client(), current_trainer_id(), current_client_id()).
--
-- Revision 2026-08-26, before this ever ran:
--   * every column reference is written as training_slots.date / training_slots.start_time.
--     `date` is also a type name in Postgres, and a bare `date` as a function argument is
--     the kind of thing that is either fine or a parse error depending on details nobody
--     should have to reason about in a production SQL editor. Qualifying costs nothing.
--   * training_slots_update_owner now carries the same guard (see section 4) — without it
--     the rule had a pre-installed hole for the cancel/reschedule feature in the backlog.

-- helper so the same expression isn't spelled out in three policies
create or replace function slot_is_future(d date, t time) returns boolean
language sql stable as $$
  select (d + t) > (now() at time zone 'Asia/Jerusalem');
$$;

-- ---------- 1. a trainer/owner can only INSERT a slot that is still ahead ----------
drop policy if exists training_slots_insert on training_slots;
create policy training_slots_insert on training_slots for insert
  with check (
    (is_owner() or trainer_id = current_trainer_id())
    and slot_is_future(training_slots.date, training_slots.start_time)
  );

-- ---------- 2. a client only SEES open slots that are still ahead ----------
-- unchanged for the other three branches: owner and every trainer still see every slot
-- (including past ones, as history), and a client still sees their own bookings forever.
drop policy if exists training_slots_select on training_slots;
create policy training_slots_select on training_slots for select
  using (
    is_owner()
    or is_any_trainer()
    or (status = 'open' and is_any_client() and slot_is_future(training_slots.date, training_slots.start_time))
    or client_id = current_client_id()
  );

-- ---------- 3. ...and cannot BOOK a past one either ----------
-- the SELECT policy above already hides it, but UPDATE is evaluated independently, so a
-- client holding a slot id from an earlier page load could otherwise still book it.
drop policy if exists training_slots_update_book on training_slots;
create policy training_slots_update_book on training_slots for update
  using (status = 'open' and is_any_client() and slot_is_future(training_slots.date, training_slots.start_time))
  with check (status = 'booked' and client_id = current_client_id());

-- ---------- 4. a trainer/owner cannot move an existing slot into the past either ----------
-- The guard is on WITH CHECK only (the row as it will be), not on USING (the row as it is),
-- so this is specifically "you may not end up with a past slot" rather than "you may not
-- touch old rows"... except that an untouched past row also fails WITH CHECK, which makes
-- past slots effectively read-only. That is the intended reading of "no slots in the past"
-- today, when no slot-editing UI exists at all. It has to be revisited the moment
-- cancel/reschedule is built (see OPEN_QUESTIONS.md) — cancelling a slot that has already
-- passed is a legitimate thing to want, and this policy would refuse it.
drop policy if exists training_slots_update_owner on training_slots;
create policy training_slots_update_owner on training_slots for update
  using (is_owner() or trainer_id = current_trainer_id())
  with check (
    (is_owner() or trainer_id = current_trainer_id())
    and slot_is_future(training_slots.date, training_slots.start_time)
  );
