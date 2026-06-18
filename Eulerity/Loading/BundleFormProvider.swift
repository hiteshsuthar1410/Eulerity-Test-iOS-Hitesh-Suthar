//
//  BundleFormProvider.swift
//  Eulerity
//
//  Loads the bundled form.json. Used at runtime today; a URLSession-backed
//  provider replaces it when the form moves to a server (D5).
//

import Foundation

/// Loads form JSON from a bundle. The bundle and resource name are injectable so
/// tests can point at a fixture without touching `Bundle.main`.
struct BundleFormProvider: FormProvider {
    enum LoadError: Error, Equatable {
        case resourceNotFound(name: String)
    }

    let resourceName: String
    let bundle: Bundle

    init(resourceName: String = "form", bundle: Bundle = .main) {
        self.resourceName = resourceName
        self.bundle = bundle
    }

    // FIXME: [isolation-deadlock] Awaiting this nonisolated async function from an
    // XCTest async method hangs under SWIFT_DEFAULT_ACTOR_ISOLATION = nonisolated +
    // the NonisolatedNonsendingByDefault upcoming feature. The two BundleFormProvider
    // async tests are XCTSkip'd until resolved (PROGRESS.md Known issues, DECISIONS D8).
    // Production code path (ViewModel on @MainActor, M3) is unaffected; this is a
    // test-harness/concurrency-feature interaction to revisit.
    func loadForm() async throws -> Data {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            throw LoadError.resourceNotFound(name: resourceName)
        }
        return try Data(contentsOf: url)
    }
}
