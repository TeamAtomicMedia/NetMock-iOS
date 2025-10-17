//
//  Document+Validation.swift
//  NetMock
//
//  Created by Christopher Wainwright on 17/10/2025.
//

import Foundation

extension NetMock.Document {
    enum ValidationError: Error {
        case invalidSequence
        case invalidLabels([String])
    }

    /// Validate document format
    func validate() throws {
        if self.sequence.dropLast().contains(.live) {
            throw ValidationError.invalidSequence
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
