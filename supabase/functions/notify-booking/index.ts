// Supabase Edge Function: sends a booking-confirmation email to both the trainer and the
// client after a training slot is booked (see PROJECT.md, "מודול תיאום אימונים").
// Deploy via the Supabase dashboard's Edge Functions "Editor" (no CLI needed) — paste this
// file's contents in as the function body, name the function "notify-booking".
//
// The app calls this with just { slotId } — everything else (trainer/client identity,
// email addresses, date/time) is looked up server-side with the service-role key so the
// client never has to be trusted with or pass around other people's contact details.
//
// Requires a secret named RESEND_API_KEY (Project Settings -> Edge Functions -> Secrets),
// using Resend (https://resend.com) as the email provider — swap the sendEmail() call below
// if a different provider is preferred. SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are
// auto-injected into every Edge Function by Supabase; no need to set them manually.
//
// If RESEND_API_KEY isn't configured yet, this returns 200 with sent:false rather than an
// error — the booking itself already succeeded in the database before this is called, so a
// missing/failed email should never look like a failed booking to the user.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY");
const RESEND_FROM = Deno.env.get("RESEND_FROM") || "EA Pro Training <onboarding@resend.dev>";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function fmtDate(d: string) {
  const [y, m, day] = d.split("-");
  return `${day}.${m}.${y}`;
}

async function sendEmail(to: string, subject: string, text: string) {
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${RESEND_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ from: RESEND_FROM, to, subject, text }),
  });
  if (!res.ok) {
    const errBody = await res.text();
    throw new Error(`Resend error (${res.status}): ${errBody}`);
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (!SUPABASE_URL || !SERVICE_ROLE_KEY) {
    return json({ error: "SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY not available" }, 500);
  }

  let slotId: string | undefined;
  try {
    const body = await req.json();
    slotId = body.slotId;
  } catch {
    return json({ error: "invalid JSON body, expected { slotId }" }, 400);
  }
  if (!slotId) return json({ error: "missing slotId" }, 400);

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

  const { data: slot, error: slotErr } = await admin
    .from("training_slots")
    .select("id, trainer_id, client_id, date, start_time, end_time, status")
    .eq("id", slotId)
    .maybeSingle();
  if (slotErr) return json({ error: slotErr.message }, 500);
  if (!slot) return json({ error: "slot not found" }, 404);
  if (slot.status !== "booked" || !slot.client_id) {
    return json({ error: "slot is not booked, nothing to notify" }, 400);
  }

  const [{ data: trainer, error: trainerErr }, { data: client, error: clientErr }] = await Promise.all([
    admin.from("trainers").select("id, full_name, auth_user_id").eq("id", slot.trainer_id).maybeSingle(),
    admin.from("clients").select("id, full_name, email").eq("id", slot.client_id).maybeSingle(),
  ]);
  if (trainerErr) return json({ error: trainerErr.message }, 500);
  if (clientErr) return json({ error: clientErr.message }, 500);

  let trainerEmail: string | null = null;
  if (trainer?.auth_user_id) {
    const { data: authUser } = await admin.auth.admin.getUserById(trainer.auth_user_id);
    trainerEmail = authUser?.user?.email || null;
  }
  const clientEmail = client?.email || null;

  const when = `${fmtDate(slot.date)} בשעה ${String(slot.start_time).slice(0, 5)}`;
  const sent = { trainer: false, client: false };
  const errors: string[] = [];

  if (!RESEND_API_KEY) {
    return json({ sent, reason: "RESEND_API_KEY not configured yet" });
  }

  if (trainerEmail) {
    try {
      await sendEmail(
        trainerEmail,
        "תור חדש נקבע",
        `${client?.full_name || "לקוח"} קבע/ה תור אצלך בתאריך ${when}.`
      );
      sent.trainer = true;
    } catch (e) {
      errors.push(String(e));
    }
  }
  if (clientEmail) {
    try {
      await sendEmail(
        clientEmail,
        "התור שלך נקבע",
        `קבעת תור עם ${trainer?.full_name || "המאמן/ת"} בתאריך ${when}.`
      );
      sent.client = true;
    } catch (e) {
      errors.push(String(e));
    }
  }

  return json({ sent, errors: errors.length ? errors : undefined });
});
