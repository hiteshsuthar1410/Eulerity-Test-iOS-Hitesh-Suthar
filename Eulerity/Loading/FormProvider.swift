//
//  FormProvider.swift
//  Eulerity
//
//  Source of the raw form JSON.
//

import Foundation

/// Supplies the raw form JSON bytes.
///
/// `async throws` today even though the bundle read is synchronous, so swapping in
/// a `URLSession`-backed provider later needs no change to call sites or the
/// parse → map → validate pipeline (DECISIONS.md → D5). Decoding operates on bytes
/// regardless of where they came from.
protocol FormProvider {
    func loadForm() async throws -> Data
}
