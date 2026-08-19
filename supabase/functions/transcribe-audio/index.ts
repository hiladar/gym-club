// Supabase Edge Function: transcribes a recorded training-note audio clip via OpenAI's
// gpt-4o-mini-transcribe model (better multilingual/Hebrew accuracy than the older whisper-1,
// same /v1/audio/transcriptions endpoint).
// Deploy via the Supabase dashboard's Edge Functions "Editor" (no CLI needed) — paste this file's
// contents in as the function body, name the function "transcribe-audio".
// Requires a secret named OPENAI_API_KEY (Project Settings -> Edge Functions -> Secrets).

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY");

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (!OPENAI_API_KEY) {
    return new Response(JSON.stringify({ error: "OPENAI_API_KEY secret is not configured" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  try {
    const formData = await req.formData();
    const audio = formData.get("audio");
    if (!(audio instanceof File)) {
      return new Response(JSON.stringify({ error: "missing audio file" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const upstreamForm = new FormData();
    upstreamForm.append("file", audio, "note.webm");
    upstreamForm.append("model", "gpt-4o-mini-transcribe");
    upstreamForm.append("language", "he");

    const upstreamRes = await fetch("https://api.openai.com/v1/audio/transcriptions", {
      method: "POST",
      headers: { Authorization: `Bearer ${OPENAI_API_KEY}` },
      body: upstreamForm,
    });
    const upstreamData = await upstreamRes.json();

    if (!upstreamRes.ok) {
      return new Response(JSON.stringify({ error: upstreamData.error?.message || "transcription failed" }), {
        status: 502,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ text: upstreamData.text || "" }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
