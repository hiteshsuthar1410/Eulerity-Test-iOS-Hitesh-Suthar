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
