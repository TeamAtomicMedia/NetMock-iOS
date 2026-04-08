//
//  ObjcPerformAsync.swift
//  NetMock
//
//  Created by Jamie Froggatt on 2026.04.08.
//

import Foundation

/// Helper for calling async code from URLProtocol, or other Obj-C method overrides in non-Sendable types.
internal func objcPerformAsync<T: Sendable, ErrorType: Error>(_ perform: @Sendable @escaping () async throws(ErrorType) -> T) throws(ErrorType) -> T {
    nonisolated(unsafe) var result: Result<T, Error>!
    let semaphore = DispatchSemaphore(value: 0)
    Task {
        do {
            result = .success(try await perform())
        } catch {
            result = .failure(error)
        }
        semaphore.signal()
    }
    semaphore.wait()
    switch result {
    case .success(let success): return success
    case .failure(let failure): throw failure as! ErrorType
    case .none: fatalError("Cannot reach")
    }
}
