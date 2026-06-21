//
//  FormScreen.swift
//  Eulerity
//
//  The real form screen (replaces the disposable ContentView). Renders the loaded
//  fields in a branded card on adaptive chrome (D17), pins Save to the bottom, and
//  offers an in-app switch to load a hostile edge-cases payload for the resilience demo.
//

import SwiftUI

@MainActor
struct FormScreen: View {
    @StateObject private var viewModel = FormViewModel()
    @State private var hasLoaded = false
    @State private var source: FormSource
    @State private var showSuccess = false
    @State private var submittedCount = 0

    /// Which bundled payload to load. The edge-cases file is the live resilience demo.
    private enum FormSource: String, CaseIterable, Identifiable {
        case standard = "form"
        case edgeCases = "form_edgecases"
        var id: String { rawValue }
        var title: String {
            switch self {
            case .standard: return "Standard form"
            case .edgeCases: return "Edge cases (hostile)"
            }
        }
    }

    init() {
        // A launch arg lets screenshots/UI tests start directly on the hostile payload.
        let startEdge = ProcessInfo.processInfo.arguments.contains("-edgecases")
        _source = State(initialValue: startEdge ? .edgeCases : .standard)
    }

    private var palette: FormPalette { FormPalette(viewModel.theme) }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.fields.isEmpty {
                    emptyState
                } else {
                    formBody
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: .systemGroupedBackground)) // adaptive chrome (D17)
            .navigationTitle(viewModel.title ?? "Form")
            .navigationBarTitleDisplayMode(.large)
            .toolbar { demoMenu }
            .safeAreaInset(edge: .bottom) { saveBar }
        }
        .environment(\.formPalette, palette)
        .onAppear {
            guard !hasLoaded else { return }
            hasLoaded = true
            reload()
        }
        .alert("Submitted", isPresented: $showSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("\(submittedCount) field(s) sent. The full key-value payload was printed to the console.")
        }
    }

    private var formBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(viewModel.fields) { field in
                    fieldView(for: field)
                }
            }
            .padding(20)
            .background(palette.background) // branded surface, server colors (D17)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(16)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No fields to display")
                .font(Typography.fieldLabel)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    @ViewBuilder
    private func fieldView(for field: RenderableField) -> some View {
        switch field.kind {
        case .text: FormTextField(viewModel: viewModel, field: field)
        case .dropdown: FormDropdownField(viewModel: viewModel, field: field)
        case .toggle: FormToggleField(viewModel: viewModel, field: field)
        case .checkbox: FormCheckboxField(viewModel: viewModel, field: field)
        }
    }

    private var saveBar: some View {
        Button { submit() } label: {
            Text("Save")
                .font(Typography.button)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .foregroundColor(palette.background)
        .background(palette.text)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
        .accessibilityIdentifier("save_button")
    }

    @ToolbarContentBuilder
    private var demoMenu: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Picker("Payload", selection: $source) {
                    ForEach(FormSource.allCases) { source in
                        Text(source.title).tag(source)
                    }
                }
            } label: {
                Image(systemName: "ladybug")
            }
            .onChange(of: source) { _ in reload() }
            .accessibilityIdentifier("demo_menu")
        }
    }

    private func reload() {
        viewModel.load(using: BundleFormProvider(resourceName: source.rawValue))
    }

    private func submit() {
        switch viewModel.save() {
        case .valid(let pairs):
            submittedCount = pairs.count
            showSuccess = true
        case .invalid:
            break // errors are published and surfaced inline by each field
        }
    }
}

#Preview { FormScreen() }
