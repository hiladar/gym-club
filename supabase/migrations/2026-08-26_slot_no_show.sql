-- סימון "לא הגיע/ה" על אימון שכבר עבר (26.08.26).
--
-- A trainer needs to record that a client did not turn up, and the client needs to see that
-- on their own past-sessions list. One boolean on the slot carries it; null-vs-false is not
-- a distinction anyone asked for, so the column is NOT NULL DEFAULT false — "not marked" and
-- "showed up" are the same state, and the mark is a toggle the trainer can take back.
--
-- Why an RPC and not an UPDATE policy:
-- training_slots_update_owner deliberately carries slot_is_future() in its WITH CHECK, which
-- makes a past row read-only for everyone (see db/schema.sql — it is what keeps "cancel an
-- appointment", still backlog, out of reach). Marking attendance happens only AFTER the
-- session, i.e. on exactly those read-only rows. A second permissive UPDATE policy would be
-- OR-ed with the existing ones and would reopen past rows to arbitrary edits — every column,
-- not just this one. This SECURITY DEFINER function is the narrow version: it touches
-- no_show and nothing else, and it re-checks the caller itself.

alter table training_slots
  add column if not exists no_show boolean not null default false;

-- only a session somebody actually booked can be a no-show
alter table training_slots drop constraint if exists training_slots_no_show_booked;
alter table training_slots
  add constraint training_slots_no_show_booked check (not no_show or status = 'booked');

-- End-of-month counting (26.08.26, owner's requirement): the mark is a column on the session
-- row, not a UI state, so "how many sessions did this client actually do in August, and how
-- many did they miss" is one query over date + client_id + no_show. The existing index is
-- (trainer_id, date, start_time) — a per-client month range had nothing to use.
create index if not exists training_slots_client_date_idx on training_slots (client_id, date);

-- The three checks are the whole permission model for this action: the slot's own trainer
-- (or the owner) may mark it, only once it is booked, and only once it has started — before
-- that there is nothing to report. Raises rather than silently updating nothing, so the app
-- can tell the user which of the three it was.
create or replace function set_slot_no_show(p_slot_id uuid, p_no_show boolean)
returns training_slots
language plpgsql security definer
set search_path = public
as $$
declare s training_slots;
begin
  select * into s from training_slots where id = p_slot_id;
  if not found then
    raise exception 'slot not found' using errcode = 'no_data_found';
  end if;
  if not (is_owner() or s.trainer_id = current_trainer_id()) then
    raise exception 'only the slot''s trainer may mark attendance' using errcode = 'insufficient_privilege';
  end if;
  if s.status <> 'booked' then
    raise exception 'slot is not booked' using errcode = 'check_violation';
  end if;
  if slot_is_future(s.date, s.start_time) then
    raise exception 'session has not started yet' using errcode = 'check_violation';
  end if;
  update training_slots set no_show = coalesce(p_no_show, false)
    where id = p_slot_id
    returning * into s;
  return s;
end;
$$;

-- security definer + a public execute grant would let anonymous callers in; only a logged-in
-- user may reach it, and the function's own checks decide the rest.
revoke all on function set_slot_no_show(uuid, boolean) from public;
grant execute on function set_slot_no_show(uuid, boolean) to authenticated;
