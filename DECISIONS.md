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
  (`func loadForm() async throws -> Data`), with a `BundleFormProvider` today. The
  ViewModel depends on the protocol, not the bundle.
- **Why:** Swapping to a `URLSession`-backed provider later is a one-line change with
  the decode/map/validate path completely untouched, because decoding operates on
  bytes regardless of source.
- **Alternatives:** Read the bundle directly in the ViewModel (rejected — couples the
  core to the bundle and blocks the server migration the brief calls for).

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
- **Known side effect (see PROGRESS.md → Known issues):** Under `nonisolated` +
  the `NonisolatedNonsendingByDefault` upcoming feature, the two `BundleFormProvider`
  **async** tests hang when awaiting the nonisolated async `loadForm()` (the 13
  synchronous parsing tests are unaffected). They are `XCTSkip`'d with `// FIXME:
  [isolation-deadlock]` markers. **Update (2026-06-21, M4 de-risk):** the production
  runtime `load()` path was verified in the simulator and does **not** deadlock — so
  this is a test-harness gap, not a product risk; the M7 runtime concern is retired.
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
  SwiftUI`) with a failable `init?(hex:)`. `ResolvedTheme.resolve(_:)` applies
  per-channel fallback to defaults. M4 wraps `RGBAColor` into a SwiftUI `Color`.
- **Why:** Keeps all hex parsing/validation in the testable headless core (one bad
  channel can't break the palette, and we can assert exact channel values in XCTest).
  The SwiftUI dependency is pushed to the thin presentation edge.
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
- **Decision:** Split loading: `load() async` (thin runtime wrapper) calls the
  provider then delegates to **`apply(_ schema:)` — synchronous**. Tests are
  `@MainActor` classes that drive `apply` + `save` synchronously, so no `await`
  crosses an isolation boundary and the deadlock is sidestepped. `@MainActor` is
  applied *only* to `FormViewModel`, per D8.
- **Why:** Keeps the tested core independent of the unresolved async issue; isolates
  the risky async path to one thin, runtime-only method to verify in M7.
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
