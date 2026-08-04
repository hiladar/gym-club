# Handoff: Gym Club App — Visual Hierarchy & Spacing Redesign

## Overview
Redesign of 4 core screens of a Hebrew (RTL) personal-training / gym-club mobile web app ("EA Pro Training"): client list, client overview, training plan, and measurements. The goal was to fix a confusing visual hierarchy caused by mixed fonts and inconsistent spacing, while keeping the app's existing structure, flows, and content.

## About the Design Files
The bundled file (`gym-club-app-redesign.dc.html`) is a **design reference built in HTML** — a static prototype showing the intended look, layout, and content, not production code to copy directly. It renders all 4 screens side by side as mobile frames for review purposes only (that side-by-side gallery wrapper is NOT part of the app).

**Task**: recreate these designs pixel-faithfully inside the app's actual codebase/framework (React, Vue, native, etc.), using its existing component patterns, state management, and routing — do not embed this HTML directly.

## Fidelity
**High-fidelity.** Colors, typography, spacing, and component structure are final. Recreate pixel-perfectly. Copy text is real Hebrew app content, not placeholder.

**Color update (03.08.26)**: palette changed from warm gold/cream to white + dark navy per owner request. All tokens below reflect the new palette. Structure/layout/copy unchanged — visual only. Semantic status colors (danger red `#B14A3E`, medical-alert amber `#D98324`) were kept as-is since they're functional signals, not brand color.

## Global Notes
- **Language/direction**: Entire app is Hebrew, RTL (`dir="rtl"`). All layout mirrors accordingly — icons/chevrons, button order, and flex direction all follow RTL logic (in RTL, the first flex child renders on the right).
- **Font**: Single family throughout — **Rubik** (Google Fonts), weights 400/500/600/700/800. This replaces the previous multi-font setup that caused hierarchy confusion. Do not mix in additional fonts.
- **Base background**: white `#FFFFFF`. Cards/surfaces: white `#FFFFFF` (separated from background purely by 1px border + shadow, since both are white — see Fidelity update below).

## Screens / Views

### 1. Client List
- **Purpose**: browse/search all trainees, jump into a client's profile.
- **Layout**: header bar, search field, vertical list of client rows, floating "+" add button at the end of the flow.
- **Components**:
  - Header: circular monogram avatar (dark navy `#1E3A5F` bg, 2px `#1E3A5F` border, "EA" 13px/800 **white** text for contrast on the dark fill) + wordmark "EA Pro Training" (16px/800, `#16233D`) + subtitle (11px/400, `#6C7A90`) on one side; a small square "+" button (36×36, 10px radius, `#1E3A5F` bg, white, add new client) on the other.
  - Search input: static-looking field, `#EEF3F9` bg, 14px radius, 14px/400 placeholder in `#6C7A90`.
  - Client row (repeats): name (16px/700 `#16233D`) + optional medical-attention alert badge (17px circle, `#D98324` bg, white "!" — sits directly beside the name, NOT tied to the date field) on one side, "‹" chevron (`#A9B7C8`) on the other; below, "מדידה אחרונה: <date>" (13px/400 `#6C7A90`).
  - Currently-open/selected client row is visually elevated: `#E4EDF8` bg, 1.5px `#1E3A5F` border, 16px radius, 16px padding. Other rows are plain list items separated by 1px `#E3E9F0` hairlines.
  - FAB: 52px dark navy circle, white "+", drop shadow.

### 2. Client Overview (tab: סקירה / Overview)
- **Purpose**: client identity, goal, quick actions, and contact/profile summary.
- **Layout**: back link → name (H1) → tab strip → goal description → action buttons → contact-details card → FAB.
- **Components**:
  - Back link: "→ חזרה לרשימה", 13px `#6C7A90`.
  - Name: 26px/800 `#16233D`.
  - Tab strip (shared across screens 2–4, fixed order regardless of which is active): סקירה — מדדים — תוכנית אימון. Active tab: 15px/700 `#16233D` with 2.5px `#1E3A5F` bottom border; inactive: 15px/500 `#6C7A90`. Full-width 1px `#E3E9F0` hairline under the row.
  - Goal description text: 14px/400 `#57687F`, line-height 1.55.
  - Action buttons (equal width, 13px radius, 13px padding): "עריכת פרטים" (outline `#DCE4EE`, text `#16233D`) and "מחיקת לקוח" (outline `#E3B9AF`, text `#B14A3E`, destructive).
  - Contact card: white, 1px `#DCE4EE` border, 20px radius, 24px padding. Section label "פרטי קשר" (13px/700 `#6C7A90`). Fields in a 2-column grid, 22px/16px gap: טלפון, מייל, תאריך לידה, מין, גובה, BMI (מחושב). Each field: 12px/400 muted label above a 16px/600 dark value. Phone and email values must stay single-line (`white-space:nowrap`); email additionally uses `text-overflow:ellipsis` for long addresses. Below a 1px divider, "מאמנים" section lists trainer pill(s): `#EEF3F9` bg, 10px radius, 13px/600 text.
  - FAB same as screen 1.

### 3. Training Plan (tab: תוכנית אימון)
- **Purpose**: view/manage the active training plan and log coach notes.
- **Layout** (order changed 03.08.26 — was plan meta card → exercise card list → coach notes section): shared header shell (back link, name, tabs) → **coach notes section (now first)** → plan meta card → exercise card list. Reasoning: the exercise list can run long, so putting the most-recently-needed content (last note) above it means it's visible without scrolling; the plan itself follows below. The bundled `.dc.html` was **not** restructured to match this reorder (its screen 03 still shows the pre-03.08.26 order: plan → exercises → notes) — treat its section *content/styling* as authoritative but its top-to-bottom order for this screen as superseded by this note; follow this README for the real build.
- **Components**:
  - Plan meta card: white, 20px radius, 24px padding. Title "תוכנית בתוקף מ-<date>" (18px/700), subtitle change-log text (14px/400 `#57687F`). Controls row: **current-version pill + its edit button grouped together on one side** ("<date> (נוכחית) ▾" pill, then "עריכת גרסה" outline button right next to it), with **"+ גרסה חדשה" (primary dark-navy button) pushed to the opposite side** via `justify-content:space-between` — this groups the edit action with the version it edits, separate from "add a new version".
  - Exercise card (repeats): name (17px/700). Below it, a **4-column stat grid** (`#EEF3F9` cells, 12px radius) for סטים / חזרות / משקל / מנוחה — each cell: 11px muted label over 15px/700 value. This replaces a long stacked list of individual rows for better scannability — it's the direct fix for exercise lists otherwise pushing the coach-notes section too far down to reach on mobile. Optional notes footer (only if present), separated by a 1px `#E7ECF3` divider: 12px muted "הערות" label + 14px/400 text.
  - Coach notes section (now the **first** section on the screen, see Layout above): header "הערות אימון" + primary "+ הערה חדשה" button. Note card (repeats): date + time (11px muted label / 14px/700 value, side by side), note text (14px/400, line-height 1.55), and text-link style "עריכה"/"מחיקה" (מחיקה in `#B14A3E`) actions below a divider. **Default-collapsed to 1** (updated 03.08.26 — was 2): only the single most recent note card renders by default — a "הצג עוד (N)" text/ghost button below the list expands to the full history for this plan version, and toggles to "הצג פחות" to collapse again. **Scoped to the plan version being viewed**: a note belongs to whichever plan version was in effect on its date (see the data-model note under Training Plan → State Management); switching the version dropdown (or viewing a historical version) re-filters this list, and an empty result shows "אין הערות אימון לתוכנית זו עדיין" instead of a blank list. The bundled `.dc.html` still shows its static 2-note, unfiltered, unreordered sample as-is; implement the reorder/scoping/toggle in the real build.

### 4. Measurements (tab: מדדים)
- **Purpose**: track body-composition trend over time and log new measurements.
- **Layout**: shared header shell → 3-up summary chip row → trend chart card → measurement history list → FAB.
- **Components**:
  - Summary chips (**4-column** grid, updated 03.08.26 — was 3-column): אחוז נוזלים, מסת שריר, אחוז שומן, משקל. Plain chips: `#EEF3F9` bg, 1px `#DCE4EE` border. The משקל chip (primary metric) is visually highlighted: `#E4EDF8` bg, 1.5px `#1E3A5F` border. Each: 12px muted label, 19px/700 value.
  - Trend chart card: title "משקל לאורך זמן" + delta text (e.g. "▼ 0.7 ק"ג מהמדידה הקודמת", 12px/600 `#1E3A5F`). Below, an SVG line chart (300×84 viewBox, `#1E3A5F` 2.5px stroke, rounded joins, a filled dot at the latest point) plotting weight across all historical entries (oldest→newest, left to right). Large current value below the chart (26px/800).
  - History list: header "כל המדידות" + primary "+ מדידה חדשה" button. Measurement card (repeats): date (15px/700) + weight (18px/800 `#1E3A5F`) on the header row; below, a **9-cell 4-column stat grid** (BMI, % שומן, % נוזלים, מסת שריר, מסת שומן, מותניים, ירכיים, ירך, זרוע — each 10px label / 13px/700 value; % נוזלים added 03.08.26, was an 8-cell grid) replacing the original long stacked field list. Optional note footer (same pattern as exercise cards). "עריכה"/"מחיקה" text actions below a divider.

## Interactions & Behavior
- Tapping a client row in the list opens that client's Overview tab.
- Tab strip switches between סקירה / מדדים / תוכנית אימון for the open client; order stays fixed, only the active-state styling changes (this was a bug in the prior version where tab order shifted — must be fixed as fixed-order tabs in the rebuild).
- "+" additions (client, version, note, measurement) open their respective create forms — forms are not designed in this pass.
- "עריכה"/"מחיקה" open edit forms / confirm-delete for that row.
- Version dropdown pill lets the user pick a past plan version to view (read-only view of history) vs. the current one.
- No animations/transitions were specified; use standard tap/press feedback consistent with the rest of the app.

## State Management
- Selected client (drives Overview/Training Plan/Measurements screens).
- Active tab per client detail view.
- List data: clients (name, last-measurement date, medical-alert flag).
- Per-client: profile fields, contact info, assigned trainer(s).
- Per-client training plan: version list + active version, exercises (sets/reps/weight/rest/notes), coach notes (date/time/text). A note's plan version is **derived from its date** (not stored) — it belongs to the version whose `effectiveDate` is in effect on the note's date, up to (not including) the next version's `effectiveDate`; on the exact boundary date, the new version wins. Added 03.08.26.
- Per-client measurements: chronological list of entries (date, weight, BMI, body-fat %, body-water % [added 03.08.26], muscle mass, fat mass, waist/hips/thigh/arm circumference, optional note) — used both for the list and the trend chart.

## Design Tokens

### Colors
| Token | Hex | Use |
|---|---|---|
| bg | `#FFFFFF` | app background |
| surface | `#FFFFFF` | cards |
| surface-tint | `#EEF3F9` | stat cells, chips, trainer pill |
| surface-tint-strong | `#E4EDF8` | selected/highlighted card or chip |
| border | `#DCE4EE` / `#E3E9F0` | card & hairline borders |
| border-strong | `#C9D6E3` / `#DCE4EE` | button outlines |
| text primary | `#16233D` | headings, values |
| text muted | `#6C7A90` / `#57687F` | labels, secondary text |
| text faint | `#A9B7C8` | chevrons |
| dark navy (primary accent) | `#1E3A5F` | buttons, active tab, highlights, chart line |
| dark navy deep (on-tint text) | `#14263F` | text on navy-tinted surface |
| logo navy | `#1E3A5F` | avatar background (avatar text flips to white on this dark fill) |
| danger | `#B14A3E` | delete actions, error text |
| alert amber | `#D98324` | medical-attention badge |

### Typography (Rubik)
| Style | Size / Weight |
|---|---|
| Page title (client name) | 26px / 800 |
| Section/card title | 17–19px / 700 |
| Wordmark | 16px / 800 |
| Body / field value | 14–16px / 500–700 |
| Field label / meta | 11–13px / 400–600 |
| Stat-cell label | 10–12px / 400 |
| Stat-cell value | 13–15px / 700 |

### Spacing
Base scale: 4 / 6 / 8 / 10 / 12 / 14 / 16 / 20 / 24 / 28 / 32px. Cards use 16–24px internal padding; card-to-card gap 12–14px; section gap 24–32px.

### Radius
- Cards/large surfaces: 16–20px
- Buttons/pills/stat-cells: 10–12px
- Client row (selected): 16px
- FAB / avatar: 50% (circle)

### Shadows
- FAB: `0 10px 24px -6px rgba(30,58,95,.6)`

## Assets
No external images/icons — the avatar is a text monogram ("EA"), and the chart is an inline SVG polyline (no icon library used). If the production app uses an icon set already, swap the text-based "‹" chevron and "+"/edit/delete affordances for that set's equivalents.

## Files
- `gym-club-app-redesign.dc.html` — full design reference (all 4 screens). Note: this file uses a proprietary component-template syntax (`sc-for`/`sc-if`/`{{ }}`) for internal authoring — read it for content, structure, and exact inline styles/values, but implement the actual screens using the target codebase's own templating/component system, not this syntax.
