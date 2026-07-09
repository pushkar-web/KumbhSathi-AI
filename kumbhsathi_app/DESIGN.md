# KumbhSathi AI — Design System v2 "Sanctum"

> Premium, modern, government-grade. Depth through tonal layering and soft
> shadows — never neon, never flat white. Calm authority with warm urgency
> accents. This document is the single source of truth for every screen.

---

## 1. Brand Direction

| Attribute | Expression |
|---|---|
| **Trustworthy** | Deep indigo-blue primary, official seals, structured layouts |
| **Urgent but calm** | Saffron amber reserved for CTAs & live states; crimson only for critical |
| **Premium** | Layered surfaces, hairline borders, soft diffuse shadows, generous whitespace, animated counters, staggered entrances |
| **Indian context** | Saffron accent, Devanagari-ready Inter, warm ivory-mist backgrounds |

**Anti-goals:** neon glows, glassmorphism overuse, pure-white cards on pure-white
backgrounds, hard material elevation, decorative gradients on content surfaces.

---

## 2. Color Tokens (`AppColors`)

### Light (default)
| Token | Value | Use |
|---|---|---|
| `primary` | `#0B4FA3` | Brand, links, active nav, primary buttons |
| `primaryDeep` | `#08356F` | Gradient end, pressed states, sidebar |
| `primaryDim` | `#0A458F` | Hover/pressed |
| `primaryContainer` | `#D6E5FA` | Tonal chips, selected states |
| `onPrimaryContainer` | `#082B57` | Text on primaryContainer |
| `accent` (`tertiaryContainer`) | `#F5820D` | Primary CTAs, live/active markers |
| `accentDeep` (`tertiaryDim`) | `#D96C05` | CTA pressed |
| `accentContainer` | `#FDEBD7` | Tonal accent chips |
| `success` | `#1B8A5A` | Reunited/verified/online |
| `successContainer` | `#DCF3E8` | Tonal success chips |
| `danger` (`error`) | `#C93B3B` | Critical, destructive |
| `dangerContainer` | `#FBE3E3` | Tonal danger chips |
| `warning` | `#B97D10` | Cautions, pending sync |
| `warningContainer` | `#FBF0D9` | Tonal warning chips |
| `info` | `#2C6FBF` | Informational |
| `hospital` | `#7D4CBB` | Hospital status |
| `background` | `#F2F5FA` | App background (blue-tinted mist) |
| `surface` | `#FFFFFF` | Cards |
| `surfaceRaised` | `#FBFCFE` | Elevated cards / sticky bars |
| `surfaceSunken` | `#EAEFF6` | Wells, input fills, table stripes |
| `ink` (`onSurface`) | `#101826` | Primary text |
| `inkMedium` (`onSurfaceVariant`) | `#4A5568` | Secondary text |
| `inkFaint` | `#8B96A5` | Tertiary text, placeholders |
| `hairline` (`outlineVariant`) | `#E3E9F2` | Card borders, dividers |
| `outline` | `#B9C2CF` | Input borders |

### Dark
`backgroundDark #0B1220`, `surfaceDark #121B2C`, `surfaceRaisedDark #182337`,
`surfaceSunkenDark #0E1626`, `inkDark #E8EDF5`, `inkMediumDark #A7B2C3`,
`hairlineDark #223049`. Primary lifts to `#5B96E8`; accent stays `#F5820D`.

### Gradients (hero/nav surfaces ONLY — never behind body text blocks)
- `heroGradient`: `#0B4FA3 → #08356F` (135°) — app bars, sidebar, hero cards
- `accentGradient`: `#F5820D → #E06D00` — primary CTA buttons
- `scrimGradient`: transparent → `#08356F @ 55%` — over imagery

### Legacy aliases
All v1 Stitch token names (`surfaceContainerLow`, `secondaryContainer`, …) are
kept as aliases so no file breaks; new code should prefer v2 names.

---

## 3. Typography — Inter only
| Style | Size/Weight | Use |
|---|---|---|
| `displayLarge` | 40/800, -1.0 tracking | Splash, hero numerals |
| `headlineLarge` | 28/800, -0.5 | Screen titles |
| `headlineMedium` | 24/700 | Section heroes |
| `headlineSmall` | 20/700 | Card titles, dialog titles |
| `titleMedium` | 16/600 | List titles, table headers |
| `bodyLarge` | 16/400, 1.5 height | Reading text |
| `bodyMedium` | 14/400 | Default body |
| `labelLarge` | 14/600 | Buttons |
| `labelMedium` | 12/500, +0.3 | Chips, badges |
| `labelSmall` | 11/500, +0.5, UPPERCASE optional | Overlines, table meta |

KPI numerals: `headlineLarge`/`displayLarge` with `FontFeature.tabularFigures()`.

## 4. Shape, Space, Elevation, Motion
- **Radius:** chip 8 · input/button 12 · card 16 · sheet/hero 20 · modal 24 · pill 999
- **Spacing (4pt):** xs 4 · sm 8 · md 12 · base 16 · lg 20 · xl 24 · 2xl 32 · 3xl 48
- **Page gutters:** mobile 16–20 · desktop 24–32; desktop content max-width 1280, 12-col grid, 24 gap
- **Shadows (`AppShadows`):**
  - `card`: y2 blur10 `#0F2A5A @ 5%` + y8 blur24 `@ 6%`
  - `raised`: y4 blur16 `@ 8%` + y12 blur32 `@ 10%`
  - `cta`: y6 blur18 accent `@ 28%` (CTA buttons only)
- **Motion:** enter 240ms easeOutCubic · exit 180ms easeIn · stagger 40–60ms/item
  (max 6) · counters 700ms easeOut · shimmer 1200ms loop · pressed scale 0.97.
  Use `flutter_animate` (`.animate().fadeIn(240.ms).slideY(begin:.06)`).

## 5. Component Library (`lib/shared/widgets/`)
| Widget | File | Spec |
|---|---|---|
| `AppCard` | `app_card.dart` | surface + hairline border + `AppShadows.card`, radius 16, padding 16/20, optional `accentColor` left bar (3px), optional onTap ripple |
| `KpiCard` | `kpi_card.dart` | icon in tonal rounded-12 chip, animated numeral, label, optional delta pill (+↑ success / −↓ danger), optional mini sparkline (fl_chart, no axes) |
| `StatusBadge` | `status_badge.dart` | tonal pill: dot 6px + labelMedium; maps `CaseStatus`→ colors (Pending=warning, Searching=accent, Reunited=success, Hospital=hospital, Unresolved=danger) |
| `PriorityBadge` | same file | Low=success · Medium=warning · High=accent · Critical=danger (filled) |
| `SectionHeader` | `section_header.dart` | titleMedium 700 + optional "View all" TextButton, 24 top / 12 bottom |
| `PrimaryCta` | `gradient_button.dart` | accentGradient, radius 12, h52, `AppShadows.cta`, white 700 label, optional icon; `.secondary()` = primary tonal |
| `EmptyState` | `empty_state.dart` | tonal icon disc 72, title, subtitle, optional action |
| `ShimmerBox/ShimmerList` | `loading_shimmer.dart` | shimmer on surfaceSunken |
| `PersonAvatar` | `person_avatar.dart` | initials on tonal bg (hash→hue from fixed palette), sizes 32/40/56/72, optional status dot |
| `AnimatedCount` | `animated_count.dart` | int/double tween, tabular figures |
| `OfflineBanner` | `offline_banner.dart` | animated slide-down: offline = warningContainer "Offline — on-device AI active"; syncing = infoContainer |
| `AiModeChip` | same file | pill showing ⚡ "Groq Cloud" / 📱 "Gemma on-device" / "AI unavailable" from `aiModeProvider` |

## 6. Screen Blueprints

### 6.1 Family portal (mobile-first)
- **Dashboard:** hero header on `heroGradient` (rounded-b-28): greeting, date,
  AiModeChip, notification bell w/ badge. Overlapping (-24) quick-action row:
  1 large `PrimaryCta` "Report Missing Person" + 3 tonal mini actions (Track,
  Upload Info, Help). "My Active Cases" carousel of AppCards (photo avatar,
  name, StatusBadge, PriorityBadge, elapsed time, progress rail). Notifications
  preview list. Staggered entrance.
- **Report Missing (wizard):** 4 steps (Person → Description → Last seen →
  Review), top step indicator (filled pill rail), photo upload card w/ face
  auto-detect chip ("Face captured ✓" success tonal), sticky bottom nav
  (Back / Continue `PrimaryCta`). On submit: enrolls face embedding offline +
  queues sync; success sheet with case ID.
- **AI Interview:** chat; AI bubbles surface + hairline left-accent primary,
  user bubbles primaryContainer right; typing indicator (3 dots); chips with
  AI-suggested quick replies; header shows AiModeChip; input bar raised w/ mic.
- **Tracker:** case header card, vertical timeline (dot+rail, done=success,
  active=accent pulse, pending=hairline), officer contact card, map snippet.
- **Notifications:** grouped Today/Earlier; cards w/ left accent by type;
  swipe-to-read; filter chips row.
- **Aadhaar Scanner:** see §7.2 flow — viewfinder w/ card-aspect mask, corner
  brackets, torch/gallery, then editable extracted-fields sheet w/ Verhoeff
  ✓/✗ badge, consent checkbox, verify CTA, result card.
- **Voice:** recorder w/ live waveform bars (custom painter), timer, on-stop
  transcription card (AI router), language chip.

### 6.2 Police portal (desktop-first, rail + mobile fallback)
- **Dashboard:** sidebar 260 on heroGradient (logo, nav, officer card at
  bottom); topbar: search field (w-360), date, AiModeChip, bell, avatar.
  Row 1: 4 KpiCards w/ sparklines (Missing today, Found & Reunited, Critical,
  Avg resolution). Row 2: cases table (2/3) — sortable, status/priority
  badges, hover row tint, row → case detail; live ops panel (1/3): AI alert
  cards (dup detection / face match / escalation) each w/ action buttons.
  Row 3: charts — status donut + 7-day area chart (fl_chart, soft gradient
  fill, no gridline clutter).
- **Cases list:** filter bar (status segmented, priority chips, search, date),
  DataTable paginated 10/pg, bulk select, export stub.
- **Case detail:** two-col: left = person card (photo, badges, description,
  identifiers), AI insight card (priority score radial + zone probabilities
  bars), duplicates panel (side-by-side mini cards w/ similarity %, Merge /
  Dismiss); right = timeline + assignment card + actions (status stepper).
- **Face match:** upload/capture zone (dashed), then results grid: query face
  left sticky; match cards (photo, name, case id, confidence radial ring
  colored by band ≥85 success / 60–85 warning / <60 danger), side-by-side
  compare sheet, Confirm → writes timeline + notifies.

### 6.3 Volunteer portal (mobile)
- **Dashboard:** compact hero (avatar, name, VOL-ID, verified chip, availability
  Switch w/ tonal state card), 3 KpiCards row, "Current Assignment" AppCard
  accent-left (person, distance, Navigate `PrimaryCta` + Update tonal),
  offline-ready badge, recent activity list.
- **Assigned case:** person hero card, description checklist, map preview,
  action bar (Navigate / Found — face scan / Can't continue).
- **Face scan (Found person):** full-bleed camera, face box overlay (animated
  corners success when locked), bottom sheet results: top-3 matches w/
  confidence rings, Confirm match CTA → success flow (notify + timeline).
- **Report observation:** photo grid capture, chips for condition, location
  autofill card, notes, submit queues offline sync w/ pending badge.
- **Task history:** month filter, impact summary card (3 stats), timeline list
  of AppCards w/ outcome badges.

### 6.4 Admin / Command Center (desktop)
- **Dashboard:** same chrome as police; KPI row (Active, Found today, Active
  volunteers, System health); center: live map card (flutter_map, zone
  circles + station/CCTV toggles) 2/3 + right rail live feed (auto-scroll
  event stream w/ severity dots); bottom: zone risk table + volunteer load
  bars.
- **Audit & Settings:** filterable table w/ severity chips; **AI Settings**
  screen (see §7.4): connectivity, Groq key, Gemma model download manager
  card w/ progress ring, face model card, storage usage, "Test AI" row.

### 6.5 Auth
- **Login:** full-bleed `heroGradient` bg + subtle mandala watermark (asset at
  6% opacity); centered floating card (max-w 440, radius 24, raised shadow):
  logo chip, role selector as 4 tonal segmented tiles (icon+label), phone,
  password, `PrimaryCta` Login, OTP alt, register link; gov footer minimal.
- **Register:** same chrome, stepper (Details → Security → Preferences).
- **OTP:** 6 boxes (radius 14, focus ring accent), auto-advance, resend timer
  ring around 48px icon.

## 7. Key Workflows

### 7.1 Report → Reunite (happy path)
Family reports (wizard/AI interview/voice) → face enrolled locally →
case created (queued offline if needed) → police triage (AI priority +
dup check) → volunteer assigned → volunteer face-scans found person →
offline match ≥ threshold → confirm → family + police notified → tracker
timeline updates → Reunited.

### 7.2 Aadhaar offline verify
Scan card (camera OCR) **or** secure QR (mobile_scanner) → extract fields →
**Verhoeff checksum** validates number offline → SHA-256(salted) hash →
match against locally cached case index → result (match / no-match / stored
for later) → if online, sync record; raw image discarded, only hash + fields
kept. Consent dialog precedes scan; audit event queued.

### 7.3 AI routing (online/offline)
`AiOrchestrator.generate()` → if connectivity + Groq key → **Groq**
(`llama-3.3-70b-versatile`) → on failure/offline → **Gemma 3n on-device**
(flutter_gemma, model downloaded once via AI Settings) → if neither →
graceful template fallback. Active mode surfaced via `AiModeChip` everywhere
AI appears. All AI calls resilient: try/catch, timeouts, typed results.

### 7.4 Model lifecycle
AI Settings → download Gemma 3n (HF token) & MobileFaceNet w/ progress →
stored in app documents → availability reflected in aiModeProvider /
faceServiceStatus. Delete/re-download supported. No model = features degrade
with clear EmptyStates, never crash.

## 8. Quality Bar (every screen)
1. Loading = shimmer skeleton matching final layout (never bare spinner).
2. Empty & error states designed (EmptyState widget) with retry.
3. All async via providers; no futures in build.
4. Entrance animations (staggered ≤6), pressed feedback, 48px touch targets.
5. Dark theme correct via theme tokens (no hardcoded whites/blacks).
6. No `Image.network` for avatars — `PersonAvatar`. No neon, no pure `#FFF` on `#FFF`.
7. Tabular figures for all metrics; `intl` date formats.
8. Offline: every write path works offline (queue) and shows sync state.
