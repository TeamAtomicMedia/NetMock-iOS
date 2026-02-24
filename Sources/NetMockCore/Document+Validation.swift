//
//  Document+Validation.swift
//  NetMock
//
//  Created by Christopher Wainwright on 17/10/2025.
//

import Foundation

extension Document {
    /// Errors thrown when a NetMock document fails validation
    public enum ValidationError: Error {
        case invalidHeaderSequence
        case invalidLabels([String])
    }

    /// Validates the NetMock document format
    ///
    /// Validation checks:
    /// - `#Live` identifier only appears as the final item in the sequence
    /// - No labels use the reserved `#` prefix
    ///
    /// - Throws: `ValidationError` if validation fails
    public func validate() throws {
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
