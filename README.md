# EA Pro Training — Gym Club App

Hebrew (RTL) personal-training / gym-club app: client list, profiles, training plans, and body measurements.

## Repo map

| Path | What it is |
|---|---|
| [PROJECT.md](PROJECT.md) | Planning doc — scope, decisions, data model, UX/behavior notes |
| [OPEN_QUESTIONS.md](OPEN_QUESTIONS.md) | Unresolved decisions |
| [db/schema.sql](db/schema.sql) | Real Postgres schema — source of truth for the data model, meant to be run against Supabase |
| [deploy/index.html](deploy/index.html) | The real front-end app — single-file HTML/CSS/JS, deployed to Netlify. Currently uses hardcoded in-memory mock data, not yet wired to Supabase |
| [design_handoff_gym_club_redesign/](design_handoff_gym_club_redesign/README.md) | Visual reference only for a styling redesign — not production code, do not deploy directly, recreate in `deploy/index.html` |
| [mockups/design_options.html](mockups/design_options.html) | Earlier visual exploration, same "reference only" status |

## Current status

Per [PROJECT.md](PROJECT.md): user cases → data model → mockups are done. Phase 4 (real development) started 2026-07-23 with the DB schema confirmed. Infra decision: **Supabase** (managed Postgres + auto-generated REST API + storage + future auth), chosen because there's no local Node/npm dev environment and deploys are manual to Netlify.

**Next step**: create the Supabase project, apply `db/schema.sql`, then wire `deploy/index.html`'s mock `state` object to real Supabase calls via the `supabase-js` CDN script (no npm needed).

## Working locally

There's no build step — `deploy/index.html` is opened/edited directly and deployed by dragging it to Netlify.
