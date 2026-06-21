//
//  FormViewModel.swift
//  Eulerity
//
//  The single source of truth for form state, validation and Save.
//

import Combine
import Foundation
import SwiftUI

/// Drives the form. The only `@MainActor` type in the engine (D8): UI state lives
/// here, while the decode/map/validate layers stay nonisolated. Uses
/// `ObservableObject` + `@Published` (not Observation) for iOS 16 (D1).
@MainActor
final class FormViewModel: ObservableObject {
    @Published private(set) var title: String?
    @Published private(set) var fields: [RenderableField] = []
    @Published private(set) var theme: ResolvedTheme = ResolvedTheme()
    @Published private(set) var values: [String: FieldValue] = [:]
    @Published private(set) var errors: [String: String] = [:]
    private(set) var diagnostics: [FieldDiagnostic] = []

    private let provider: FormProvider

    init(provider: FormProvider = BundleFormProvider()) {
        self.provider = provider
    }

    // MARK: - Loading

    /// Runtime entry point: fetch bytes, parse, apply. Synchronous (the bundle read
    /// is synchronous); becomes `async` only when a network provider lands (D5). Any
    /// failure degrades to an empty form rather than crashing.
    func load() {
        do {
            let data = try provider.loadForm()
            switch FormParser.parse(data) {
            case .success(let schema):
                apply(schema)
            case .failure(let error):
                #if DEBUG
                debugPrint("⚠️ [FormViewModel] parse failed: \(error)")
                #endif
                reset()
            }
        } catch {
            #if DEBUG
            debugPrint("⚠️ [FormViewModel] load failed: \(error)")
            #endif
            reset()
        }
    }

    /// Synchronous apply — the tested entry point. Maps the schema, resolves the
    /// theme, and seeds initial state from each field's defaults.
    func apply(_ schema: FormSchemaDTO) {
        let output = FieldFactory.make(from: schema.fields)
        title = schema.formTitle
        theme = ResolvedTheme.resolve(schema.theme)
        fields = output.fields
        diagnostics = output.diagnostics
        errors = [:]
        values = Dictionary(uniqueKeysWithValues: output.fields.map { ($0.id, Self.seed($0)) })
    }

    private func reset() {
        title = nil
        theme = ResolvedTheme()
        fields = []
        diagnostics = []
        values = [:]
        errors = [:]
    }

    private static func seed(_ field: RenderableField) -> FieldValue {
        switch field.kind {
        case .text: return .text("")
        case .dropdown(let dropdown): return .selection(dropdown.defaultSelection)
        case .toggle(let toggle): return .bool(toggle.defaultOn)
        case .checkbox(let checkbox): return .bool(checkbox.defaultOn)
        }
    }

    // MARK: - Mutation (single source of truth)

    /// Sets text, enforcing `max_length` as a hard typing limit (truncation), and
    /// clears any existing error for the field (D13).
    func setText(_ text: String, for id: String) {
        guard case .text? = values[id] else { return }
        var newText = text
        if case .text(let model)? = field(id)?.kind, let max = model.maxLength, newText.count > max {
            newText = String(newText.prefix(max))
        }
        values[id] = .text(newText)
        errors[id] = nil
    }

    func setBool(_ isOn: Bool, for id: String) {
        guard case .bool? = values[id] else { return }
        values[id] = .bool(isOn)
        errors[id] = nil
    }

    /// Replaces the selection (single-select dropdown).
    func setSingleSelection(_ optionID: String, for id: String) {
        guard case .selection? = values[id] else { return }
        values[id] = .selection([optionID])
        errors[id] = nil
    }

    /// Adds/removes an option (multi-select dropdown).
    func toggleSelection(_ optionID: String, for id: String) {
        guard case .selection(var ids)? = values[id] else { return }
        if ids.contains(optionID) { ids.remove(optionID) } else { ids.insert(optionID) }
        values[id] = .selection(ids)
        errors[id] = nil
    }

    // MARK: - Bindings (thin wrappers for components; VM stays the source of truth)

    func textBinding(for id: String) -> Binding<String> {
        Binding(
            get: { if case .text(let value)? = self.values[id] { return value } else { return "" } },
            set: { self.setText($0, for: id) }
        )
    }

    func boolBinding(for id: String) -> Binding<Bool> {
        Binding(
            get: { if case .bool(let value)? = self.values[id] { return value } else { return false } },
            set: { self.setBool($0, for: id) }
        )
    }

    func isSelected(_ optionID: String, in id: String) -> Bool {
        if case .selection(let ids)? = values[id] { return ids.contains(optionID) }
        return false
    }

    // MARK: - Save

    /// Validates every field (populating `errors`); on success builds the ordered
    /// key-value payload, prints it, and returns it.
    @discardableResult
    func save() -> SaveResult {
        var newErrors: [String: String] = [:]
        for field in fields {
            let value = values[field.id] ?? Self.seed(field)
            if let message = FieldValidator.validate(field, value: value) {
                newErrors[field.id] = message
            }
        }
        errors = newErrors

        guard newErrors.isEmpty else { return .invalid(newErrors) }

        let pairs = fields.map { OutputPair(id: $0.id, value: outputValue(for: $0)) }
        printPayload(pairs)
        return .valid(pairs)
    }

    /// Maps a field's state to its Save shape: scalars for single values, arrays for
    /// multi-select dropdowns; NUMBER stays a raw string (D15).
    private func outputValue(for field: RenderableField) -> FormOutputValue {
        let value = values[field.id] ?? Self.seed(field)
        switch (field.kind, value) {
        case (.dropdown(let dropdown), .selection(let ids)):
            let ordered = dropdown.options.map(\.id).filter(ids.contains)
            return dropdown.allowMultiple ? .array(ordered) : .string(ordered.first ?? "")
        case (.text, .text(let string)):
            return .string(string)
        case (.toggle, .bool(let isOn)), (.checkbox, .bool(let isOn)):
            return .bool(isOn)
        default:
            return .string("") // unreachable given seeding invariants; defensive
        }
    }

    private func printPayload(_ pairs: [OutputPair]) {
        print("✅ Form valid — submitting \(pairs.count) field(s):")
        let dict = Dictionary(uniqueKeysWithValues: pairs.map { ($0.id, $0.value.jsonValue) })
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]),
           let json = String(data: data, encoding: .utf8) {
            print(json)
        }
        for pair in pairs { // ordered, human-readable
            print("  \(pair.id) = \(pair.value)")
        }
    }

    // MARK: - Helpers

    private func field(_ id: String) -> RenderableField? {
        fields.first { $0.id == id }
    }
}
