# Decisions

Every non-obvious choice, recorded as **Context / Decision / Why / Alternatives**.
Newest decisions are appended at the bottom.

---

## D1 — iOS 16 minimum, so no Observation framework

- **Context:** Strict requirement is iOS 16+. Apple's `@Observable` macro and the
  `Observation` framework are iOS 17+.
- **Decision:** The view model uses `ObservableObject` + `@Published`, observed in
  views via `@StateObject`. We use the iOS-16 two-parameter `onChange(of:perform:)`
  signature (the zero/one-parameter form is iOS 17+).
- **Why:** Honors the deployment target and guarantees the engine compiles and runs
  on iOS 16 devices, not just newer simulators.
- **Alternatives:** `@Observable` (rejected — iOS 17+). Plain `@State` scattered
  across views (rejected — violates MVVM single-source-of-truth).

## D2 — Align ALL targets to iOS 16.0

- **Context:** The template shipped with `IPHONEOS_DEPLOYMENT_TARGET = 26.5`. The app
  target was lowered to 16.0, but the project-level default and the `EulerityTests`
  target were still 26.5. The UITests target inherits the project default.
- **Decision:** Set every `IPHONEOS_DEPLOYMENT_TARGET` (project default + test
  targets) to 16.0.
- **Why:** A test bundle deploying to 26.5 could compile against post-iOS-16 APIs and
  pass, masking a real iOS-16 break in app code. Uniform targets keep the test suite
  an honest guard of the deployment contract.
- **Alternatives:** Leave tests at 26.5 (rejected — false confidence).

## D3 — Two-net polymorphic decoding boundary

- **Context:** The form JSON comes from a server and "can send anything" — unknown
  field types, missing arrays, conflicting constraints, bad hex. A naive
  `[Field].self` decode throws for the *whole array* if any one element is malformed,
  losing the entire form.
- **Decision:** Quarantine all "garbage in" handling upstream of the ViewModel with
  two independent nets:
  1. **Per-element failable decode** — decode `fields` as
     `[FailableDecodable<FieldDTO>]` (each element is its own single-value container;
     a `try?` inside swallows that element's error and the array decode still
     advances). Bad-shape elements become `nil` and are dropped; neighbors survive.
  2. **`FieldType` decodes unknowns** — `type`/`subtype` decode into enums with a
     `case unknown(String)`, so `"DATE_PICKER"` decodes *successfully* rather than
     throwing. The drop decision is made deliberately later, with a diagnostic.
  Semantic validation lives entirely in a non-throwing `FieldFactory`
  (`FieldDTO → RenderableField?`). The ViewModel only ever sees trusted
  `[RenderableField]` + a list of `DroppedFieldDiagnostic`.
- **Why:** Codable does mechanics; the factory does meaning. "The server can send
  anything" is then handled in exactly two files, by design — the View has zero
  defensive code, and one bad field can never collapse the form.
- **Alternatives:** Manual unkeyed-container iteration with `try?` (rejected — a throw
  mid-container can leave the decode cursor unadvanced and infinite-loop). Throwing
  enums for unknown types (rejected — couples decoding to a closed type set, so any
  future server type crashes old clients).

## D4 — Field render order: total-order comparator, never array index

- **Context:** Fields render sorted by their `order` integer. But `order` is
  server-supplied and optional: values can be duplicated or missing/nil. Swift's
  `sort`/`sorted` is **not guaranteed stable**, so sorting on `order` alone is
  non-deterministic the moment two fields tie.
- **Decision:** Capture each field's original array position as `sourceIndex` during
  decode, then sort by the tuple **`(order ?? Int.max, sourceIndex)`**.
  - Equal `order` → tie-broken by source order (first-in-payload wins).
  - Missing/nil `order` → sinks to the bottom (`Int.max`), still tie-broken by source.
  - A missing `order` never drops the field — order is presentation metadata, not a
    validity condition.
- **Why:** `sourceIndex` is unique per element, so the tuple is a *total order* — no
  remaining ties, no nondeterminism, identical output on every run and across devices.
- **Alternatives:** Sort on `order` only (rejected — unstable on ties). Tie-break on
  `id` (rejected — ids can also collide and carry no ordering meaning).

## D5 — Network-ready loader behind a protocol

- **Context:** Form JSON loads from the app bundle today but must come from a server
  eventually.
- **Decision:** Define a `FormProvider` protocol returning raw bytes
  (`func loadForm() throws -> Data`), with a `BundleFormProvider` today. The
  ViewModel depends on the protocol, not the bundle.
- **Why:** Swapping to a `URLSession`-backed provider later is a localized change with
  the decode/map/validate path completely untouched, because decoding operates on
  bytes regardless of source.
- **Amended (2026-06-21):** `loadForm()` was originally `async throws`, anticipating a
  network swap. That was a **premature abstraction** — the bundle read is synchronous,
  so the `async` bought nothing today and interacted badly with
  `NonisolatedNonsendingByDefault` (it deadlocked two XCTest async tests, the
  `isolation-deadlock` issue). Made it synchronous; the **protocol** is the real swap
  point — a network provider can reintroduce `async` then (changing only the provider
  and its call site). The two tests now run green, unskipped.
- **Alternatives:** Read the bundle directly in the ViewModel (rejected — couples the
  core to the bundle and blocks the server migration the brief calls for). Keep
  `async` now (rejected — see amendment: abstraction with no present benefit and a real
  cost).

## D6 — Duplicate / missing `id`: first-wins, drop the rest

- **Context:** `id` is the primary key of the whole engine — ViewModel state is
  `[String: FieldValue]` keyed by it, the Save output is `[id: value]`, errors are
  keyed by it, and SwiftUI uses it for row identity. It is server-supplied, so it can
  be missing, empty, or duplicated. Unlike `order`/`max_length`, there is no graceful
  partial degrade: two fields under one id collapse to one state slot (typing in one
  mutates the other), the Save output silently loses a value (last-write-wins), and
  `ForEach(id: \.id)` gets undefined row identity.
- **Decision:** `id` stays an optional `String` at the DTO layer (decode never
  enforces it). The `FieldFactory` (M2) enforces uniqueness over the field set in
  source order:
  1. Missing/empty `id` → drop the field + emit a diagnostic.
  2. `id` duplicating an already-kept field → drop the *later* one (by source order)
     + diagnostic; the **first occurrence wins**.
  Because uniqueness is guaranteed before the ViewModel sees anything, `id` is then
  provably safe as the `ForEach` identifier.
- **Why:** `id` is the one property that cannot be lenient — a collision corrupts
  state, output, and view identity, not just one field. First-wins keeps the mental
  model identical to the D4 tie-break ("first in payload wins" everywhere). Uniqueness
  is a *collection-level* rule, so it belongs in the factory pass, not in per-element
  decode — reinforcing the boundary (decode = mechanical/per-element, factory =
  semantic/cross-field).
- **Alternatives:** De-dupe by suffixing ids (rejected — breaks the server key
  contract; the Save payload keys must match what the server expects). Keep an
  internal synthetic identity separate from the server id (rejected — the Save output
  must still be keyed by server id, so two fields sharing one id are ambiguous at the
  source regardless). Last-wins (rejected — inconsistent with D4).

## D7 — Dropped-field diagnostics are surfaced via debugPrint

- **Context:** When the factory (M2) drops a malformed/unknown field, that field
  simply vanishes from the rendered form. Silent dropping makes a server-side payload
  bug nearly impossible to notice during development.
- **Decision:** The factory returns `[FieldDiagnostic]` alongside the
  `[RenderableField]`, and the engine `debugPrint`s each diagnostic (id/index + reason)
  in `DEBUG` builds. Diagnostics are part of the return value (not just a side effect),
  so tests assert on them directly.
- **Why:** A dropped field should be *loud* in development and *silent* in production:
  `debugPrint` (gated to `#if DEBUG`) gives a visible breadcrumb while building/QA
  without polluting release logs or the UI. Returning the diagnostics keeps the
  factory pure and unit-testable.
- **Alternatives:** Throw on a bad field (rejected — defeats graceful degradation).
  Drop silently (rejected — the reason this decision exists). A full logging framework
  (rejected — overkill for an offline single-screen engine; revisit if needed).

## D8 — Default actor isolation: nonisolated project-wide; only the ViewModel @MainActor

- **Context:** The project shipped with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`
  (Xcode's "approachable concurrency" default). That makes every type — including the
  headless decode/DTO value types — `MainActor`-isolated, which clashes with
  `Codable`'s `nonisolated init(from:)` and wrongly forces the parsing layer onto the
  main thread.
- **Decision:** Set `SWIFT_DEFAULT_ACTOR_ISOLATION = nonisolated` at the project level
  (inherited by all targets; the app target also sets it explicitly). UI-thread
  isolation is applied *narrowly and deliberately*: only `FormViewModel` will be
  annotated `@MainActor` (M3). The decode/map/validate layers stay nonisolated.
- **Why:** The parsing/mapping core is pure, synchronous, thread-agnostic logic; it
  should not be main-actor-bound. Opting in to `@MainActor` only where UI state lives
  is the correct, conventional MVVM boundary and removes the `Codable` conflict.
- **Known side effect — RESOLVED (2026-06-21):** Under `nonisolated` +
  `NonisolatedNonsendingByDefault`, the two `BundleFormProvider` **async** tests hung
  when awaiting the nonisolated async `loadForm()`. First de-risked by verifying the
  runtime `load()` path in the simulator (no hang), then **fully resolved** by making
  `loadForm()` synchronous (D5 amendment) — the `async` was premature. Both tests now
  run green, unskipped; the FIXME markers are removed.
- **Alternatives:** Keep `MainActor` default and mark value types `nonisolated`
  piecemeal (rejected — inverts the sensible default; every new DTO would need an
  annotation). Disable approachable concurrency entirely (rejected — heavier hammer
  than needed).

## D9 — `RenderableField`: common header + `Kind` enum

- **Context:** The View must switch on a field's kind to pick a component, and the
  ViewModel must key state / sort regardless of kind. A single struct with every
  property optional would let the View read `options` off a toggle or `allowMultiple`
  off a checkbox — illegal states that compile.
- **Decision:** `RenderableField` is a struct with a uniform header (`id`, `order`,
  `sourceIndex`, `label`, `isRequired`, `supportingText`, `errorMessage`) plus a
  `kind: Kind` enum whose cases each carry a kind-specific payload type
  (`Text`/`Dropdown`/`Toggle`/`Checkbox`) holding only that kind's data.
- **Why:** Uniform header → the ViewModel sorts and keys state without switching.
  Per-kind payloads → illegal states are unrepresentable; the View destructures one
  case and gets exactly the fields it needs. Each payload also documents its
  post-mapping invariants (e.g. `Dropdown.options` is non-empty).
- **Alternatives:** One struct of all-optionals + a `kind` tag (rejected — illegal
  states compile, View needs defensive nil-checks). A class hierarchy / protocol per
  kind (rejected — heavier, fights value semantics and `Equatable` synthesis).

## D10 — Degrade-vs-drop policy

- **Context:** The factory must decide, per anomaly, whether to drop the whole field
  or keep it with an adjustment. Too aggressive loses usable fields; too lenient
  renders broken ones.
- **Decision:** Drop only when the field is *unusable or ambiguous*; otherwise degrade
  and keep rendering. Every drop/degrade emits a `FieldDiagnostic`.

  | Condition | Action |
  |-----------|--------|
  | missing/empty `id`, or duplicate `id` | **drop** (D6, first-wins) |
  | `type` missing or `.unknown` | **drop** |
  | DROPDOWN with no valid options left | **drop** (nothing to pick) |
  | TEXT `subtype` `.unknown` | **degrade → PLAIN** |
  | DROPDOWN with some bad/duplicate options | keep good, **drop bad** |
  | `default_values` referencing unknown option ids | **filter to valid** |
  | single-select with multiple defaults | **keep first** by option order |
  | `max_length <= 0` | **ignore constraint** |
  | option missing `label` (but has `id`) | **label ← id** |
  | bad theme hex | **per-channel fallback** (D11) |

- **Why:** Maximizes how much of a partially-broken payload still renders, which is
  the brief's core requirement ("drop the bad field, keep rendering the rest"), while
  diagnostics keep every decision auditable (D7).
- **Alternatives:** Drop on any anomaly (rejected — loses usable fields over cosmetic
  issues). Never drop, always coerce (rejected — would render a dropdown with no
  options or a field with no id, corrupting state).

## D11 — Theme/hex resolution is headless (no SwiftUI)

- **Context:** Theme parsing produces colors, which tempts an early dependency on
  SwiftUI `Color`. But `Color` needs a UI context and isn't cleanly unit-testable for
  channel values, and the brief wants bad hex to degrade gracefully.
- **Decision:** Parse hex into `RGBAColor` (channels in `0...1`, **no** `import
  SwiftUI`) with a failable `init?(hex:)`. `ResolvedTheme.resolve(_:)` validates each
  channel. M4 wraps `RGBAColor` into a SwiftUI `Color`.
- **Why:** Keeps all hex parsing/validation in the testable headless core (one bad
  channel can't break the palette, and we can assert exact channel values in XCTest).
  The SwiftUI dependency is pushed to the thin presentation edge.
- **Amended (2026-06-21, M4):** `ResolvedTheme` originally filled missing channels
  with **fixed light defaults**. M4's appearance requirement (D17) needs *adaptive*
  fallback, which requires knowing *which* channels the server actually sent — fixed
  fill erased that. So `ResolvedTheme` now holds **optional** channels (`nil` =
  absent/invalid) and the fallback choice is deferred to `FormPalette` (D17). This
  supersedes the fixed-fallback part of D11; the headless/testable parsing stays.
- **Alternatives:** Parse straight into `Color` (rejected — drags SwiftUI into the
  logic layer and is hard to unit-test). Store raw hex strings and parse in the View
  (rejected — scatters validation across the UI, exactly what the boundary avoids).

## D12 — `FieldValue` state model + seeding from defaults

- **Context:** The ViewModel needs one uniform state container keyed by field id for
  all kinds, and sensible initial values.
- **Decision:** `FieldValue` is `.text(String)` / `.selection(Set<String>)` /
  `.bool(Bool)`, held in `[String: FieldValue]`. On `apply`, each field is seeded:
  text → `""`, dropdown → its validated `defaultSelection`, toggle/checkbox →
  `defaultOn`. Dropdown state stores option **ids**; labels are render-only.
- **Why:** A small closed enum keeps the engine uniform and `Equatable` (easy
  testing); seeding from the already-validated `RenderableField` means initial state
  is correct by construction (e.g. defaults that referenced unknown options were
  already filtered in M2).
- **Alternatives:** `Any`/type-erased values (rejected — loses type safety and
  Equatable). Per-kind separate dictionaries (rejected — fragments the source of truth).

## D13 — Validation: on Save, required → numeric → regex, clear-on-edit

- **Context:** The brief: errors surface on Save, counters are live. Need a rule order
  and an error lifecycle.
- **Decision:** `FieldValidator` is pure/headless. Rules run **on `save()`**:
  required → numeric (NUMBER only, D15) → regex; first failure's message wins
  (`field.errorMessage ?? default`). `max_length` is **not** a validation rule — it is
  enforced as a hard typing limit (truncation) in `setText`, so it can't be violated.
  Editing a field **clears its error**; a full re-validation only re-runs on the next
  Save. An uncompilable regex is skipped (never blocks the user).
- **Why:** Matches the brief's "errors on Save / live counters"; clear-on-edit is
  standard, forgiving UX; making `max_length` a Save error would be unreachable since
  the value is truncated at input.
- **Alternatives:** Validate on every keystroke (rejected — noisy, not the brief).
  Keep errors until next Save (rejected — feels broken while the user is fixing them).

## D14 — Sync `apply`/`save` seam; `@MainActor` only on the ViewModel

- **Context:** `FormViewModel` is `@MainActor` (UI state). Its async `load()` awaits
  the nonisolated async `loadForm()` — the exact shape that deadlocks XCTest async
  tests (`isolation-deadlock`, D8). We still need the core fully unit-tested.
- **Decision:** Split loading: `load()` (thin runtime wrapper) calls the
  provider then delegates to **`apply(_ schema:)` — synchronous**. Tests are
  `@MainActor` classes that drive `apply` + `save` synchronously. `@MainActor` is
  applied *only* to `FormViewModel`, per D8.
- **Why:** Keeps the tested core decoupled from loading (tests feed a parsed schema
  straight to `apply`, no bundle/network). `@MainActor` only on the VM keeps UI-thread
  isolation narrow.
- **Amended (2026-06-21):** the original motivation was also to keep tests off the
  `async` deadlock path. With the loader now synchronous (D5 amendment), `load()` is no
  longer `async` and the deadlock is gone — but the `apply`/`load` split stays because
  it's the clean testability seam regardless.
- **Alternatives:** Make the whole VM async-tested (rejected — would hit the deadlock).
  Load synchronously from the bundle (rejected — breaks the network-ready D5 seam).

## D15 — NUMBER serializes as a raw string; Save payload is scalars + arrays

- **Context (your call):** How should NUMBER fields appear in the Save payload, and
  what is the payload's exact shape?
- **Decision:** Keep NUMBER as `.text(String)` in state (uniform engine) and add a
  light numeric validation rule — *if non-empty, it must parse as a finite number*
  (cheap defense against pasted junk like `"50abc"` that the numeric keypad can't
  stop). In the Save payload, emit the **raw string** (`"50"`, not `50`). Overall
  payload shape: **scalars for single values** (text/number → string, toggle/checkbox
  → bool, single-select dropdown → the id string) and **arrays for multi-select
  dropdowns** (ids in option-declaration order). Serialized via `JSONSerialization`.
- **Why:** Partial/empty numeric input has no clean numeric form, and conceptually the
  engine treats all text input as strings for the **server** to coerce. The numeric
  rule still blocks obvious garbage without forcing a lossy type conversion.
- **Alternatives:** Force NUMBER to a `Double` in the output (**rejected** — partial or
  empty input (`""`, `"-"`, `"3."`) has no clean numeric representation, and it would
  break the engine's "all input is string, server coerces" model). Always emit
  single-select as a 1-element array (rejected — doesn't match the spec's scalar shape).

## D16 — Single typography engine of semantic roles

- **Context:** The brief wants a font styling engine in one file so font changes are
  atomic, and HIG wants Dynamic Type support.
- **Decision:** `Typography` is one enum of *semantic roles* (`.formTitle`,
  `.fieldLabel`, `.input`, `.supporting`, `.error`, `.counter`, `.button`), each a
  `Font` built from a Dynamic Type text style (`.system(.body)` etc.) so it scales
  with the user's accessibility text size. Views reference roles, never raw sizes.
- **Why:** One file = atomic, defensible font changes (swap a family / bump weights in
  one place). Semantic roles (not a generic `font(size:weight:)` passthrough) keep call
  sites intent-revealing and consistent. Text-style basis gives Dynamic Type for free.
- **Alternatives:** Per-view inline `.font(.system(size:))` (rejected — scatters font
  decisions, the opposite of the requirement). Fixed point sizes (rejected — breaks
  Dynamic Type / accessibility).

## D17 — Server colors verbatim; adaptive fallback only when a channel is absent

- **Context:** SDUI theming and Dark/Light support pull against each other: the server
  sends fixed hex (`background #FFFFFF`), which doesn't adapt to dark mode on its own.
  The brief requires *both* a theme-driven palette *and* appearance compliance.
- **Decision:** `FormPalette` resolves this in one place:
  - **Channel present →** use the server hex **verbatim**. A coherent server palette is
    internally legible in either system appearance; the backend owns the branded surface.
  - **Channel absent/invalid →** fall back to the **adaptive** system color
    (`Color(uiColor: .systemBackground)`, `.label`, `.separator`, `.systemRed`).
  Additionally, the **app chrome around the form surface is adaptive** (page background
  / safe areas follow system appearance), so the themed form reads as an intentional
  branded card while the app still demonstrates real Dark/Light compliance. Distributed
  via `@Environment(\.formPalette)`.
- **Why (the SDUI-vs-appearance tension, explicitly):** In server-driven UI the backend
  is the source of truth for look; silently re-tinting its colors for dark mode would
  override deliberate brand choices. But a form with *no* theme must still respect the
  OS. Honoring present colors verbatim while making *absent* channels (and the
  surrounding chrome) adaptive satisfies both: branded where the server speaks, native
  where it doesn't. Verified in the simulator — Light shows a light page + white card;
  Dark shows a black page + the same white branded card.
- **Alternatives:** Always force adaptivity (rejected — overrides explicit server brand
  colors). Honor server colors but make the whole screen non-adaptive (rejected — a
  theme-less form would ignore dark mode, failing the brief). Ship dark variants in the
  schema (rejected — not in the contract; can be added later without changing this seam).

## D18 — `FieldContainer` owns shared field chrome

- **Context:** Every field kind needs the same surrounding chrome: label (+ required
  marker), supporting text, error message, and a live character counter. Duplicating
  that per component would drift.
- **Decision:** `FieldContainer` is a generic wrapper taking the `RenderableField`
  header, an optional `error`, an optional `characterCount`, and a `@ViewBuilder`
  content slot. It renders the label with a required `*` (in `palette.error`), then a
  footer showing **error (precedence) or supporting text**, with the counter
  right-aligned when the field has `max_length` (turning `palette.error` at the limit).
- **Why:** One source of truth for field chrome → every component (M5) gets consistent,
  HIG-aligned layout and theming for free; only the interactive control differs.
- **Alternatives:** Chrome per component (rejected — duplication, drift). A bag of
  view modifiers (rejected — less discoverable, harder to keep layout consistent).

## D19 — Components take the view model + field (bind through the VM)

- **Context:** Each component needs its value binding, its error, and (for text) its
  character count. It could take raw `Binding`s, or the whole view model.
- **Decision:** Components take `@ObservedObject viewModel: FormViewModel` + their
  `RenderableField`, and pull the binding from `viewModel.textBinding(for:)` /
  `boolBinding(for:)` and selection mutators. Previews build a real VM from a small
  JSON fixture.
- **Why:** The `max_length` truncation and error-clear-on-edit live in the VM's
  mutators — routing through them keeps that behavior centralized; a raw `Binding`
  would bypass it. The VM stays the single source of truth.
- **Alternatives:** Pass raw `Binding<String>`/`Binding<Bool>` (rejected — loses
  truncation/error-clear unless re-implemented per component). Abstract the VM behind a
  protocol (rejected — over-abstraction for a single app; the `async` episode is the
  cautionary tale).

## D20 — Dropdown: Menu for single-select, sheet for multi-select

- **Context:** Single- and multi-select need different idioms; both must show option
  **labels** while tracking option **ids**.
- **Decision:** Single-select → an HIG pull-down `Menu`. Multi-select → a checkmark
  `List` in a `.sheet` (with `presentationDetents`), Done to dismiss. The collapsed row
  shows the selected labels joined (or a placeholder). NUMBER's `.decimalPad` pairs with
  the D15 `Double` numeric check so `"50.00"` is valid.
- **Why:** The HIG-idiomatic split, and cheaper than the alternative: the multi-select
  sheet must exist regardless, so making single-select a `Menu` is *less* work than a
  unified sheet (a heavier single-select). A `Menu` can't cleanly hold multi-select on
  iOS 16.
- **Alternatives:** One unified sheet for both (rejected — heavier single-select for no
  gain). A `Menu` of toggles for multi (rejected — dismisses on each tap, clunky).

## D21 — Toggle/checkbox inline labels; control tint = text color; swappable checkbox label

- **Context:** Toggles/checkboxes put their label beside the control, not on top. The
  schema also has no dedicated accent channel, yet controls need an on/selected tint.
  And the checkbox label must become rich text in M6.
- **Decision:** `FieldContainer` gained `showsLabel` (D18); toggle/checkbox pass `false`
  and render an inline label (with the required `*`), keeping the error/supporting
  footer. Control tint uses `palette.text` (the strongest theme color) since there's no
  accent channel. The checkbox's label is a separate subview, and only the box toggles
  state — so M6 can swap in a rich-text label whose links receive taps without a
  row-level tap stealing them.
- **Why:** Matches platform conventions for switches/checkboxes; `palette.text` keeps the
  tint theme-driven; the label/box separation is the seam M6 needs.
- **Alternatives:** Keep the top label for toggle/checkbox too (rejected — lone control
  under a label looks wrong). Hardcode a system accent for tint (rejected — ignores the
  theme). Whole-row toggle (rejected — would conflict with M6's tappable label links).

## D22 — Rich-text labels via one AttributedString Text; longest-first overlap guard

- **Context:** Checkbox labels embed `metadata` substrings that must become tappable
  links (→ Safari) styled in `clickable_text_color`. Multiple keys can overlap (e.g.
  "Terms" inside "Terms of Service"), and URLs are server-supplied.
- **Decision:** A pure builder `RichText.make(...)` produces a single `AttributedString`
  (rendered by one `Text`): the label in `textColor`, each metadata substring as an
  `http(s)` link in `linkColor` + underline, plus a trailing required `*`.
  - **First occurrence** per key.
  - **Longest-key-first, skip overlapping ranges** — keys are sorted by length
    descending and any occurrence overlapping an already-linked range is skipped, so a
    short key ("Terms") can't corrupt a longer link ("Terms of Service").
  - **https-only:** a value links only if `URL(string:)` succeeds *and* its scheme is
    `http`/`https`; otherwise it stays plain text (blocks `javascript:` / junk).
  - **Color fallback:** `clickable_text_color` verbatim, else `Color(uiColor: .link)`
    (adaptive), consistent with D17.
  - **Open in Safari:** a `.link` tap uses SwiftUI's default `OpenURLAction` (external
    Safari) — no `SFSafariViewController` (that would be in-app).
  The builder is extracted from the View so all of this is unit-tested.
- **Why:** One `Text`/`AttributedString` lets links flow inline with the label with no
  overlay hacks; the box still owns the toggle (D21), only link runs are tappable. The
  overlap guard prevents a subtle data-driven corruption; https-only is a sane posture
  for server URLs.
- **Alternatives:** Concatenate `Link`/`Button` segments (rejected — clumsy for inline
  substrings, brittle wrapping). Link all occurrences (rejected — first-occurrence is
  the agreed scope). Open in an in-app `SFSafariViewController` (rejected — brief says
  Safari; can be added later behind the same tap).
