//
//  FormProvider.swift
//  Eulerity
//
//  Source of the raw form JSON.
//

import Foundation

/// Supplies the raw form JSON bytes.
///
/// Synchronous today — the bundle read is synchronous, so `async` was a premature
/// abstraction (it bought nothing and interacted badly with the concurrency model).
/// The **protocol** is the real swap point: a future `URLSession`-backed provider can
/// reintroduce `async` then, changing only the provider and its call site; the
/// parse → map → validate pipeline is untouched (DECISIONS.md → D5).
protocol FormProvider {
    func loadForm() throws -> Data
}
