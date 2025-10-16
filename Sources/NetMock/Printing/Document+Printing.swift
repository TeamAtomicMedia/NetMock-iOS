//
//  Document+Printing.swift
//  NetMock
//
//  Created by Christopher Wainwright on 26/09/2025.
//

import Foundation

extension NetMock.Document: CustomStringConvertible {
    public var description: String {
        if let version = self.version {
            """
            \(version.description)
            \(self.header.description) \(self.sequence.map(\.description).joined(separator: " "))

            \(self.body.map(\.description).joined(separator: "\n"))
            """
        } else {
            """
            \(self.header.description) \(self.sequence.map(\.description).joined(separator: " "))
            
            \(self.body.map(\.description).joined(separator: "\n"))
            """
        }
    }
}

extension NetMock.Document.VersionNumber : CustomStringConvertible {
    var description: String {
        if let patch = self.patch {
            "NetMock \(self.major).\(self.minor).\(patch)"
        } else {
            "NetMock \(self.major).\(self.minor)"
        }
    }
}

extension NetMock.Request : CustomStringConvertible {
    public var description: String {
        "\(self.method) \(self.url.absoluteString)"
    }
}

extension NetMock.Identifier : CustomStringConvertible {
    public var description: String {
        switch self {
        case .code(let code): "\(code)"
        case .label(let label): label
        case .live: "#Live"
        }
    }
}

extension NetMock.Document.Response : CustomStringConvertible {
    var description: String {
        let formattedBody = body.flatMap { try? JSONSerialization.jsonObject(with: $0) }.flatMap { try? JSONSerialization.data(withJSONObject: $0, options: [.prettyPrinted]) }.flatMap{String(data: $0, encoding: .utf8)} ?? body.flatMap {String(data: $0, encoding: .utf8)}
        
        return if let body = formattedBody {
        """
        \(self.header.description)
        \(body)
        ---
        """
        } else {
        """
        \(self.header.description)
        ---
        """
        }
    }
}

extension NetMock.Document.Response.Header : CustomStringConvertible {
    var description: String {
        "\(self.code) \(self.labels.joined(separator: " "))"
    }
}
