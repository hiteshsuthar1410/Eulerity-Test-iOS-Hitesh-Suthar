# Progress

Milestone tracker for the Server-Driven UI form engine. Logic milestones
(M1–M3) are built and unit-tested before any UI (M4–M7).

| Milestone | Status | Date | Notes |
|-----------|--------|------|-------|
| M0 — Foundation & hygiene | ✅ Done | 2026-06-18 | `.gitignore`, untracked `xcuserdata`, aligned all targets to iOS 16.0, stripped template, scaffolded docs |
| M1 — Resilient decoding boundary | ✅ Done | 2026-06-18 | DTOs, `FieldType`/`FieldSubtype` w/ `.unknown`, `FailableDecodable` + lenient helper, `FormParser`, `FormProvider` + bundle loader, `form.json` bundled. 15 parsing tests pass (incl. nil/duplicate-id decode preservation per D6) |
| M2 — Domain mapping | ✅ Done | 2026-06-19 | `FieldFactory` (DTO→`RenderableField`, D6 dedup, D10 drop/degrade, D4 sort), `FieldDiagnostic` + DEBUG `debugPrint` (D7), headless `RGBAColor`/`ResolvedTheme` per-channel fallback. 22 new tests; 35 pass / 2 skip |
| M3 — ViewModel + validation + Save | ✅ Done | 2026-06-19 | `FieldValue` + seeding (D12), `FieldValidator` required/numeric/regex (D13/D15), `FormViewModel` `@MainActor` w/ sync `apply`/`save` seam (D14), Save emits scalars/arrays + raw-string NUMBER (D15). 25 new tests; 58 pass / 2 skip |
| M4 — Theme + Typography engines | ✅ Done | 2026-06-21 | `Typography` semantic-role font engine (D16), `FormPalette` verbatim/adaptive resolver + Environment (D17), `ResolvedTheme` → optional channels (D11 amended), `FieldContainer` chrome (D18). Dark/Light verified in simulator. 64 tests pass |
| M5 — Reusable field components | ✅ Done | 2026-06-21 | `FormTextField` (5 subtypes, keyboards, live counter), `FormDropdownField` (Menu single / sheet multi, label-shown/id-tracked), `FormToggleField`, `FormCheckboxField` (swappable label for M6) — all via `FieldContainer`, bound to VM (D19/D20/D21). Light/Dark verified in simulator; 65 tests pass |
| M6 — Rich-text checkbox labels | ⬜ Not started | — | metadata → tappable → Safari, `clickable_text_color` |
| M7 — Wire-up & polish | ⬜ Not started | — | `FormScreen`, Dark/Light + HIG pass, resilience hardening tests |

Status legend: ⬜ Not started · 🔄 In progress · ✅ Done

## Known issues

| ID | Issue | Status | Notes |
|----|-------|--------|-------|
| `isolation-deadlock` | The two `BundleFormProvider` **async** tests hung when awaiting the nonisolated async `loadForm()`, under `SWIFT_DEFAULT_ACTOR_ISOLATION = nonisolated` + `NonisolatedNonsendingByDefault`. | ✅ **Resolved (2026-06-21)** | De-risked first by confirming the runtime `load()` path in the simulator (no hang), then **fixed** by making `loadForm()` synchronous — the `async` was a premature abstraction (D5/D14 amendments, D8). Both tests now run green, unskipped; FIXME markers removed. Suite: 60 pass / 0 skip. |
