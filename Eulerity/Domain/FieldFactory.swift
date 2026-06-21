//
//  FieldFactory.swift
//  Eulerity
//
//  The semantic half of the anti-corruption boundary: maps permissive [FieldDTO]
//  into trusted [RenderableField], dropping or degrading anything unusable and
//  recording why. Pure, non-throwing, UI-framework-free, fully unit-testable.
//

import Foundation

enum FieldFactory {

    struct Output: Equatable {
        let fields: [RenderableField]
        let diagnostics: [FieldDiagnostic]
    }

    /// Maps decoded field DTOs (in source order) into renderable fields, sorted by
    /// the D4 total order, plus the diagnostics for everything dropped/adjusted.
    static func make(from dtos: [FieldDTO]) -> Output {
        var fields: [RenderableField] = []
        var diagnostics: [FieldDiagnostic] = []
        var keptIDs: Set<String> = []

        for (index, dto) in dtos.enumerated() {
            if let field = mapField(dto, sourceIndex: index, keptIDs: &keptIDs, diagnostics: &diagnostics) {
                keptIDs.insert(field.id)
                fields.append(field)
            }
        }

        // D4: (order ?? .max, sourceIndex) is a total order — no ties, deterministic.
        fields.sort { ($0.order ?? .max, $0.sourceIndex) < ($1.order ?? .max, $1.sourceIndex) }

        #if DEBUG
        for diagnostic in diagnostics {
            debugPrint("⚠️ [FieldFactory] \(diagnostic)")
        }
        #endif

        return Output(fields: fields, diagnostics: diagnostics)
    }

    // MARK: - Per-field mapping

    private static func mapField(_ dto: FieldDTO,
                                 sourceIndex: Int,
                                 keptIDs: inout Set<String>,
                                 diagnostics: inout [FieldDiagnostic]) -> RenderableField? {
        // D6: id must be present, non-empty, and unique among kept fields.
        guard let id = dto.id?.trimmedNonEmpty else {
            diagnostics.append(.init(sourceIndex: sourceIndex, fieldID: nil, wasDropped: true, reason: .missingID))
            return nil
        }
        guard !keptIDs.contains(id) else {
            diagnostics.append(.init(sourceIndex: sourceIndex, fieldID: id, wasDropped: true, reason: .duplicateID(id)))
            return nil
        }

        // Kind must be known. Unknown/missing type drops the field (Net 2's deferred decision).
        let kind: RenderableField.Kind
        switch dto.type {
        case .text:
            kind = .text(makeText(dto, id: id, sourceIndex: sourceIndex, diagnostics: &diagnostics))
        case .dropdown:
            guard let dropdown = makeDropdown(dto, id: id, sourceIndex: sourceIndex, diagnostics: &diagnostics) else {
                return nil
            }
            kind = .dropdown(dropdown)
        case .toggle:
            kind = .toggle(.init(defaultOn: false))
        case .checkbox:
            kind = .checkbox(makeCheckbox(dto))
        case .unknown(let raw):
            diagnostics.append(.init(sourceIndex: sourceIndex, fieldID: id, wasDropped: true, reason: .unknownType(raw: raw)))
            return nil
        case .none:
            diagnostics.append(.init(sourceIndex: sourceIndex, fieldID: id, wasDropped: true, reason: .unknownType(raw: nil)))
            return nil
        }

        return RenderableField(
            id: id,
            order: dto.order,
            sourceIndex: sourceIndex,
            label: dto.label,
            isRequired: dto.required ?? false,
            supportingText: dto.supportingText,
            errorMessage: dto.errorMessage,
            kind: kind
        )
    }

    // MARK: - Kind builders

    private static func makeText(_ dto: FieldDTO,
                                 id: String,
                                 sourceIndex: Int,
                                 diagnostics: inout [FieldDiagnostic]) -> RenderableField.Text {
        // Unknown subtype degrades to PLAIN (the field is still usable).
        var subtype = dto.subtype ?? .plain
        if case .unknown(let raw) = subtype {
            diagnostics.append(.init(sourceIndex: sourceIndex, fieldID: id, wasDropped: false,
                                     reason: .unknownSubtypeDegradedToPlain(raw: raw)))
            subtype = .plain
        }

        // A non-positive max length is a meaningless constraint → ignore it.
        var maxLength = dto.maxLength
        if let value = maxLength, value <= 0 {
            diagnostics.append(.init(sourceIndex: sourceIndex, fieldID: id, wasDropped: false,
                                     reason: .ignoredNonPositiveMaxLength(value)))
            maxLength = nil
        }

        return .init(subtype: subtype, placeholder: dto.placeholder, maxLength: maxLength, regex: dto.regex)
    }

    private static func makeDropdown(_ dto: FieldDTO,
                                     id: String,
                                     sourceIndex: Int,
                                     diagnostics: inout [FieldDiagnostic]) -> RenderableField.Dropdown? {
        var options: [RenderableField.Dropdown.Option] = []
        var seenOptionIDs: Set<String> = []
        var droppedOptionCount = 0

        for option in dto.options ?? [] {
            // An option needs an id to track state; a missing label degrades to the id.
            guard let optionID = option.id?.trimmedNonEmpty, !seenOptionIDs.contains(optionID) else {
                droppedOptionCount += 1
                continue
            }
            seenOptionIDs.insert(optionID)
            let label = option.label?.trimmedNonEmpty ?? optionID
            options.append(.init(id: optionID, label: label))
        }

        if droppedOptionCount > 0 {
            diagnostics.append(.init(sourceIndex: sourceIndex, fieldID: id, wasDropped: false,
                                     reason: .droppedInvalidOptions(count: droppedOptionCount)))
        }

        // A dropdown with nothing to pick is unusable → drop the field.
        guard !options.isEmpty else {
            diagnostics.append(.init(sourceIndex: sourceIndex, fieldID: id, wasDropped: true,
                                     reason: .dropdownHasNoValidOptions))
            return nil
        }

        // Defaults must reference real options.
        let validIDs = Set(options.map(\.id))
        let requested = dto.defaultValues ?? []
        let unknownDefaults = requested.filter { !validIDs.contains($0) }
        if !unknownDefaults.isEmpty {
            diagnostics.append(.init(sourceIndex: sourceIndex, fieldID: id, wasDropped: false,
                                     reason: .filteredUnknownDefaultValues(unknownDefaults)))
        }
        var defaultSelection = Set(requested.filter { validIDs.contains($0) })

        // Single-select can't carry multiple defaults → keep the first by option order.
        let allowMultiple = dto.allowMultiple ?? false
        if !allowMultiple && defaultSelection.count > 1 {
            diagnostics.append(.init(sourceIndex: sourceIndex, fieldID: id, wasDropped: false,
                                     reason: .reducedMultipleDefaultsForSingleSelect))
            if let first = options.first(where: { defaultSelection.contains($0.id) }) {
                defaultSelection = [first.id]
            }
        }

        return .init(options: options, allowMultiple: allowMultiple, defaultSelection: defaultSelection)
    }

    private static func makeCheckbox(_ dto: FieldDTO) -> RenderableField.Checkbox {
        // Sort by the substring text for deterministic ordering (dictionaries are unordered).
        let links = (dto.metadata ?? [:])
            .sorted { $0.key < $1.key }
            .compactMap { key, value -> RenderableField.Checkbox.MetadataLink? in
                guard let text = key.trimmedNonEmpty, let url = value.trimmedNonEmpty else { return nil }
                return .init(text: text, urlString: url)
            }
        let clickableColor = dto.clickableTextColor.flatMap(RGBAColor.init(hex:))
        return .init(defaultOn: false, metadata: links, clickableColor: clickableColor)
    }
}

private extension String {
    /// The trimmed string, or `nil` if empty after trimming.
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
