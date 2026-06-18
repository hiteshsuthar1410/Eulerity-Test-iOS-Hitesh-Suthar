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

    func loadForm() async throws -> Data {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            throw LoadError.resourceNotFound(name: resourceName)
        }
        return try Data(contentsOf: url)
    }
}
