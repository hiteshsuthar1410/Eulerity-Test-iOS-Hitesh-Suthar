//
//  ContentView.swift
//  Eulerity
//
//  Created by Hitesh Suthar on 17/06/26.
//

import SwiftUI

/// Temporary root placeholder.
///
/// The Server-Driven UI form engine is built in milestones M1–M6 (decode →
/// map → validate → save), all of which are headless and unit-tested before
/// any view exists. This placeholder keeps the app target compiling until
/// `FormScreen` replaces it in M7.
struct ContentView: View {
    var body: some View {
        Text("Form engine — wiring up in M7")
            .padding()
    }
}

#Preview {
    ContentView()
}
