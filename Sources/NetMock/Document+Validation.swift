//
//  Document+Validation.swift
//  NetMock
//
//  Created by Christopher Wainwright on 17/10/2025.
//

import Foundation

extension NetMock.Document {
    /// Validation Errors to throw in case of invalid document
    enum ValidationError: Error {
        case invalidHeaderSequence
        case invalidLabels([String])
    }

    /// Validate document format
    /// - Prevent #Live in leading sequence items (must be final item in sequence)
    /// - Flag Labels with '#'-prefix
    func validate() throws {
        if self.sequence.dropLast().contains(.live) {
            throw ValidationError.invalidHeaderSequence
        }
        
        let invalidLabels = self.sequence.compactMap {
            if case .mock(.label(let label)) = $0 { return label }
            return nil
        }.filter { $0.hasPrefix("#") }
        
        if !invalidLabels.isEmpty {
            throw ValidationError.invalidLabels(invalidLabels)
        }
    }
}
