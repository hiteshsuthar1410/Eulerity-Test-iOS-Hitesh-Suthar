//
//  ContentView.swift
//  Eulerity
//
//  Created by Hitesh Suthar on 17/06/26.
//

import SwiftUI
import UIKit

/// DISPOSABLE smoke screen (M4). Demonstrates the theme layer end-to-end: the server
/// palette drives a branded form *surface* while the page chrome around it stays
/// adaptive (D17), so Dark/Light compliance is visible. Replaced by `FormScreen` (the
/// real interactive form) in M7.
@MainActor
struct ContentView: View {
    @StateObject private var viewModel = FormViewModel()

    private var palette: FormPalette { FormPalette(viewModel.theme) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(viewModel.title ?? "Loading…")
                    .font(Typography.formTitle)
                    .foregroundColor(palette.text)

                ForEach(viewModel.fields) { field in
                    fieldView(for: field)
                }

                Button("Save") { viewModel.save() }
                    .font(Typography.button)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundColor(palette.background)
                    .background(palette.text)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.top, 4)
            }
            .padding(20)
            .background(palette.background)           // branded surface (server colors)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemGroupedBackground)) // adaptive page chrome
        .environment(\.formPalette, palette)
        .onAppear {
            viewModel.load()
            print("✅ RUNTIME LOAD OK — \(viewModel.fields.count) fields; title=\(viewModel.title ?? "nil")")
        }
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
}

#Preview {
    ContentView()
}
