-- Let a trainer take an open slot back off the board (26.08.26).
--
-- training_slots shipped with no DELETE policy at all — deletes were blocked for every role
-- while RLS is enabled — because cancelling an appointment is backlog. Removing a slot that
-- NOBODY booked is a different thing: it undoes the trainer's own typo (wrong day, block an
-- hour too long) and touches no client. So the policy is scoped to status = 'open'; a booked
-- slot still cannot be deleted by anyone, which keeps "cancel an appointment" out of reach
-- until it is built properly.
--
-- Past open slots are deletable too, on purpose: they are dead rows a trainer may want to
-- clear out, and nobody can book them any more. The UI only offers the ✕ on future ones.
--
-- Run against the real project in the Supabase SQL editor.

drop policy if exists training_slots_delete_open on training_slots;

create policy training_slots_delete_open on training_slots for delete
  using (
    (is_owner() or trainer_id = current_trainer_id())
    and status = 'open'
  );
