# Screen Implementation Brief (read with DESIGN.md)

You are redesigning/implementing screens for KumbhSathi AI (Flutter) to the
premium Design System v2 in `DESIGN.md`. Read DESIGN.md FIRST, then this.

## Read these before writing any code
- `lib/core/theme/app_colors.dart` — v2 tokens (primary, accent, success, danger, warning, info, hospital, background, surface, surfaceRaised, surfaceSunken, ink, inkMedium, inkFaint, hairline + *Container variants + heroGradient/accentGradient/scrimGradient). v1 alias names also still exist.
- `lib/core/theme/app_spacing.dart` — AppSpacing (xs..xxxl, gutters), AppRadius (chip/input/button/card/sheet/modal/hero/pill), AppBreakpoints, AppMotion.
- `lib/core/theme/app_shadows.dart` — AppShadows.card / .raised / .cta.
- `lib/shared/widgets/` — USE THESE, do not reinvent:
  - `app_card.dart` → `AppCard(child:, padding:, accentColor:, onTap:, raised:)`
  - `kpi_card.dart` → `KpiCard(label:, value:, icon:, color:, containerColor:, deltaLabel:, deltaPositive:, sparkline: [..], suffix:, decimals:)`
  - `status_badge.dart` → `StatusBadge.fromLabel('Searching')`, `PriorityBadge.fromLabel('High')` (or enum constructors)
  - `section_header.dart` → `SectionHeader('Title', icon:, actionLabel:, onAction:)`
  - `gradient_button.dart` → `PrimaryCta(label:, icon:, onPressed:, loading:)` and `PrimaryCta.tonal(...)`
  - `empty_state.dart` → `EmptyState(icon:, title:, subtitle:, actionLabel:, onAction:)`
  - `loading_shimmer.dart` → `ShimmerBox(width:, height:, radius:)`, `ShimmerList(items:, itemHeight:)`
  - `person_avatar.dart` → `PersonAvatar(name, size:, statusDot:)` — NEVER remote images for people
  - `animated_count.dart` → `AnimatedCount(value, style:, suffix:, decimals:)`
  - `offline_banner.dart` → `OfflineBanner()` (place at top of mobile screens under app bar), `AiModeChip(dense:)`
  - `gov_footer.dart` → `GovFooter()` (auth screens only)

## Available providers (import path shown)
- `../../providers/auth_provider.dart` (adjust depth): `authStateProvider` → `.user` (AppUser: id, fullName, role), `.notifier.logout()/login()/register()/sendOtp()/verifyOtp()`
- `../../providers/dashboard_providers.dart`: `dashboardKpiProvider` (AsyncValue<Map>: total_cases, status_counts{...}, priority_counts{...}, avg_resolution_hours, children_pending, available_volunteers), `casesProvider` (AsyncValue<List<Map>>), `auditLogProvider`, `volunteerAvailabilityProvider`, `portalTabProvider`
- `../../providers/connectivity_provider.dart`: `isOnlineProvider` (bool)
- `../../providers/ai_providers.dart`: `aiOrchestratorProvider` (`.generate(prompt, system:, history:)` → `AiResult(text, source)`, `.interviewReply(List<AiMessage>)`), `aiModeProvider` (AiMode), `gemmaServiceProvider`, `faceServiceProvider`, `aadhaarServiceProvider`, `aiCredentialsProvider`, `aiBootstrapProvider`
- `../../providers/core_providers.dart`: `hiveServiceProvider` (`.queueRequest(path:, method:, body:)`, `.hasPendingRequests`), `apiClientProvider`

## Service contracts (read the files for full signatures)
- `lib/services/ai/ai_router.dart`: `AiMode {groqCloud, gemmaOnDevice, unavailable}`, `AiResult{text, source}`
- `lib/services/ai/groq_service.dart`: `AiMessage.user/.assistant/.system(content)`
- `lib/services/face/face_recognition_service.dart`: `FaceRecognitionService` (ChangeNotifier): `status` (FaceServiceStatus{modelMissing,downloading,ready,error}), `embedImageFile(path)→List<double>?`, `enroll(caseId:,name:,embedding:,photoPath:,meta:)`, `match(query, topK:, threshold:)→List<FaceMatchCandidate{caseId,name,score,photoPath,meta}>`, `enrolledCount`, `downloadModel()`
- `lib/services/aadhaar/aadhaar_service.dart`: `AadhaarService`: `extractFromImage(path)→AadhaarScanResult?`, `parseSecureQr(raw)→AadhaarScanResult?`, `matchAgainstLocalCases(scan, cases:)→List<AadhaarCaseMatch{caseId,personName,score,level,caseData}>`; `AadhaarScanResult{maskedNumber,numberHash,verhoeffValid,source,name,dob,yearOfBirth,gender,address,confidence,qrSigned}`

## Hard rules (violations = rejected work)
1. ONLY create/modify the files assigned to you. Never touch theme, shared widgets, providers, services, router, shell, main, app, pubspec.
2. Every screen: shimmer loading state, EmptyState for empty/error, entrance animations via `package:flutter_animate/flutter_animate.dart` (`.animate().fadeIn(duration: 240.ms).slideY(begin: 0.06)`; stagger with `delay: (i * 50).ms`, max 6 items).
3. Colors ONLY from AppColors / Theme.of(context).colorScheme. No raw hex except transparent/white where the design says so. No neon. Gradients only AppColors.heroGradient/accentGradient/scrimGradient.
4. Icons: `package:material_symbols_icons/symbols.dart` → `Symbols.*` only.
5. Typography via `Theme.of(context).textTheme`. Metrics through AnimatedCount.
6. NO `Image.network` for people/avatars → PersonAvatar. Asset images allowed: `assets/images/logo.png`, `gov_seal.png`, `auth_bg.png`.
7. Camera capture: use `image_picker` (`ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 1280)`) — NOT the raw camera package. QR: `mobile_scanner` `MobileScanner(onDetect:)`.
8. All async through providers/FutureBuilder-free patterns: `ref.watch(x).when(data:, loading:, error:)` or local state via StatefulWidget. Never block build.
9. Private helper widgets: prefix with screen-unique name (e.g. `_FamDash...`). All imports used; no unused imports; no `print`; const everywhere possible; `withValues(alpha: x)` not `withOpacity`.
10. Wrap deprecated/uncertain APIs defensively (try/catch around service calls; show SnackBar on failure).
11. Mobile screens: `Scaffold(body: SafeArea(child: Column(children: [OfflineBanner(), Expanded(child: <content>)])))` pattern where a scroll view is the content. Desktop screens (police/admin): no OfflineBanner in body top; put AiModeChip in the topbar.
12. Every interactive flow must WORK offline: wrap writes in try/catch → on failure `hiveServiceProvider.queueRequest(...)` + optimistic UI + "will sync" SnackBar.
13. File must be self-contained and compile. Match analyzer strictness: flutter_lints 4.
