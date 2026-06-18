# Progress

Milestone tracker for the Server-Driven UI form engine. Logic milestones
(M1–M3) are built and unit-tested before any UI (M4–M7).

| Milestone | Status | Date | Notes |
|-----------|--------|------|-------|
| M0 — Foundation & hygiene | ✅ Done | 2026-06-18 | `.gitignore`, untracked `xcuserdata`, aligned all targets to iOS 16.0, stripped template, scaffolded docs |
| M1 — Resilient decoding boundary | ⬜ Not started | — | DTOs, `FieldType` w/ `.unknown`, `FailableDecodable`, `sourceIndex`, `FormProvider` + bundle loader, parsing tests |
| M2 — Domain mapping | ⬜ Not started | — | `FieldFactory`, drop rules + diagnostics, `order` sort, theme/hex resolution, malformed-payload tests |
| M3 — ViewModel + validation + Save | ⬜ Not started | — | state dict, required/regex/max_length validation, Save prints k-v, headless tests |
| M4 — Theme + Typography engines | ⬜ Not started | — | `FormTheme` styling, `Typography` (single font file), `FieldContainer` |
| M5 — Reusable field components | ⬜ Not started | — | Text (+5 subtypes, counter), Dropdown (single+multi), Toggle, Checkbox + previews |
| M6 — Rich-text checkbox labels | ⬜ Not started | — | metadata → tappable → Safari, `clickable_text_color` |
| M7 — Wire-up & polish | ⬜ Not started | — | `FormScreen`, Dark/Light + HIG pass, resilience hardening tests |

Status legend: ⬜ Not started · 🔄 In progress · ✅ Done
