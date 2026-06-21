# Architecture

A Server-Driven UI form engine: the backend ships a JSON payload that fully
describes a form (fields, order, theme, validation); the app renders it
dynamically. Strict MVVM, with an **anti-corruption boundary** between the wire
format and everything the UI touches.

Guiding principle: **the View and ViewModel may only ever see fields that are
already proven renderable.** All "the server sent garbage" handling is
quarantined upstream of them.

## Data flow

```mermaid
flowchart TD
    A["Bundle JSON bytes"] -->|FormProvider protocol\n(BundleFormProvider today,\nURLSession later)| B["Decode layer"]

    subgraph Boundary["Anti-corruption boundary (resilience lives here)"]
        B --> C["FormSchemaDTO / FieldDTO\n(Codable — mechanical only)"]
        C -->|"Net 1: FailableDecodable\nper-element try?"| C
        C -->|"Net 2: FieldType.unknown\n(no throw on unknown type)"| C
        C --> D["FieldFactory\n(semantic validation,\nnon-throwing)"]
        D --> E["[RenderableField]\n+ [FieldDiagnostic]"]
    end

    E --> F["FormViewModel\n(ObservableObject)\nstate: [fieldID: FieldValue]\nerrors, theme, save()"]
    F --> G["FormScreen"]
    G --> H["Reusable components\nText / Dropdown / Toggle / Checkbox"]
    F -.theme.-> I["Theme + Typography engines"]
    I -.-> H
    F -->|"valid Save"| J["Print final key-value pairs + confirm"]
```

## The decoding boundary (the deliberate firewall)

Two independent safety nets ensure a malformed or future field can never collapse
the form. See **DECISIONS.md → D3** for the full rationale.

1. **Per-element failable decode** — `fields` decodes as
   `[FailableDecodable<FieldDTO>]`; a bad element becomes `nil` and is dropped,
   neighbors survive.
2. **`FieldType.unknown(String)`** — unknown `type`/`subtype` decode *successfully*;
   they are dropped deliberately in the factory, with a diagnostic, not at decode time.

`Codable` does mechanics only. **`FieldFactory`** (plain Swift, non-throwing) does all
semantics: unknown type → drop; `DROPDOWN` with missing/empty `options` → drop;
conflicting constraints (`max_length <= 0`, `default_values` referencing a
non-existent option id) → resolve or drop; bad hex → per-channel fallback. Output is
`[RenderableField]` the ViewModel can fully trust, plus `[FieldDiagnostic]`.

## Module notes (planned layout)

Built incrementally; folders are created in Xcode's file-system-synchronized groups
as the first file in each lands.

| Area | Files | Milestone |
|------|-------|-----------|
| Loader | `FormProvider.swift`, `BundleFormProvider.swift` | M1 ✅ |
| DTO / decode | `FormSchemaDTO.swift`, `FieldDTO.swift`, `OptionDTO.swift`, `ThemeDTO.swift`, `FieldType.swift`, `FailableDecodable.swift`, `FormParser.swift` | M1 ✅ |
| Domain / mapping | `RenderableField.swift`, `FieldFactory.swift`, `FieldDiagnostic.swift` | M2 ✅ |
| Theme resolution | `RGBAColor.swift`, `ResolvedTheme.swift` (headless) → SwiftUI `Color` wrapper | M2 ✅ (logic) / M4 (styling) |
| Validation | `FieldValidator.swift` (required, numeric, regex) | M3 ✅ |
| ViewModel | `FormViewModel.swift`, `FieldValue.swift` (+ `FormOutputValue`/`SaveResult`) | M3 ✅ |
| Typography | `Typography.swift` (single font engine) | M4 |
| Components | `FieldContainer.swift`, `FormTextField.swift`, `FormDropdownField.swift`, `FormToggleField.swift`, `FormCheckboxField.swift`, `RichTextLabel.swift` | M4–M6 |
| Screen | `FormScreen.swift` (replaces `ContentView`) | M7 |

## State model

The ViewModel holds `[String: FieldValue]` keyed by field id:

- `.text(String)` — TEXT (all subtypes)
- `.selection(Set<String>)` — DROPDOWN; stores option **ids**, renders option **labels**
- `.bool(Bool)` — TOGGLE / CHECKBOX

Render order is driven by the D4 total-order comparator, never array index. Validation
surfaces on Save; character counters update live. A valid Save prints the final
key-value pairs and confirms.
