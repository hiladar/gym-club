# EA Pro Training — Gym Club App

Hebrew (RTL) personal-training / gym-club app: client list, profiles, training plans, and body measurements.

## Repo map

| Path | What it is |
|---|---|
| [PROJECT.md](PROJECT.md) | Planning doc — scope, decisions, data model, UX/behavior notes |
| [OPEN_QUESTIONS.md](OPEN_QUESTIONS.md) | Unresolved decisions |
| [db/schema.sql](db/schema.sql) | Real Postgres schema — source of truth for the data model, meant to be run against Supabase |
| [deploy/index.html](deploy/index.html) | The real front-end app — single-file HTML/CSS/JS, deployed to Netlify, live-wired to Supabase (Postgres/Auth/Storage) |
| [design_handoff_gym_club_redesign/](design_handoff_gym_club_redesign/README.md) | Visual reference only for a styling redesign — not production code, do not deploy directly, recreate in `deploy/index.html` |
| [mockups/design_options.html](mockups/design_options.html) | Earlier visual exploration, same "reference only" status |

## Current status

Per [PROJECT.md](PROJECT.md): user cases → data model → mockups → real development are all done and live, not just planned. `deploy/index.html` is a real single-file app doing live CRUD against a real Supabase project (Postgres + Auth + Storage + Edge Functions) — not mock data. Live features: full client/measurement/training-plan CRUD, voice-recorded + transcribed training notes, three real user roles (owner/trainer/client) via Supabase Auth with RLS, and a training-slot scheduling module (trainer opens slots, client books one). See PROJECT.md for the full, currently-accurate feature/decision history — this file only tracks the big picture.

**Known gaps as of the last update (see PROJECT.md/OPEN_QUESTIONS.md for specifics)**: a couple of DB migrations under `supabase/migrations/` may exist locally without confirmation they've been run against the live Supabase project yet — check each migration file's own header comment for its run status before assuming it's applied.

## Working locally

There's no build step — `deploy/index.html` is opened/edited directly, plain HTML/CSS/JS with the `supabase-js` CDN script (no npm needed).

**Deploy**: git-based, not drag-and-drop. The Netlify project (`ea-gym`) is connected to the GitHub repo and auto-deploys from `main` — merging/pushing to `main` is what puts a change live, no manual Netlify step. Current working agreement (see PROJECT.md "תהליך העבודה" for the full history of this changing): commits go straight to `main` (no feature branches/PRs), but the `push` to `main` itself only happens when the owner explicitly asks for it — a local commit sitting unpushed is normal and does not mean the work is unfinished, just not live yet. DB schema/RLS changes are separate from this: they're applied by hand in the Supabase SQL editor (see `supabase/migrations/`), independent of any git push.
