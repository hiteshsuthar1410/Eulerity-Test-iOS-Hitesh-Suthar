//
//  ContentView.swift
//  Eulerity
//
//  Created by Hitesh Suthar on 17/06/26.
//

import SwiftUI

/// DISPOSABLE smoke screen (M4 de-risk). Exercises the *real* runtime async
/// `load()` path — `BundleFormProvider.loadForm()` (nonisolated async) awaited from
/// the `@MainActor` view model — to confirm it does not deadlock at runtime the way
/// the XCTest async tests do (`isolation-deadlock`, PROGRESS.md / D8). Prints a
/// marker on success. Replaced by `FormScreen` in M7.
@MainActor
struct ContentView: View {
    @StateObject private var viewModel = FormViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.title ?? "Loading…")
                .font(.title2).bold()
            Text("\(viewModel.fields.count) field(s) loaded")
                .foregroundStyle(.secondary)
            ForEach(viewModel.fields) { field in
                Text("• \(field.label ?? field.id)")
            }
        }
        .padding()
        .task {
            await viewModel.load()
            print("✅ RUNTIME LOAD OK — \(viewModel.fields.count) fields; title=\(viewModel.title ?? "nil")")
        }
    }
}

#Preview {
    ContentView()
}
