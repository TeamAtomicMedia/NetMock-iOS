//
//  Document+Printing.swift
//  NetMock
//
//  Created by Christopher Wainwright on 26/09/2025.
//

import Foundation

extension Document: CustomStringConvertible {
    public var description: String {
        """
        \((version ?? .current).description)
        \(self.header.description) \(self.sequence.map(\.description).joined(separator: " "))

        \(self.body.map(\.description).joined(separator: "\n"))
        """
    }
}

extension VersionNumber : CustomStringConvertible {
    public var description: String {
        if let patch = self.patch {
            "NetMock \(self.major).\(self.minor).\(patch)"
        } else {
            "NetMock \(self.major).\(self.minor)"
        }
    }
    
    static var current: VersionNumber {
        .init(major: 3, minor: 0, patch: 0)
    }
}

extension Request : CustomStringConvertible {
    public var description: String {
        "\(self.method) \(self.url.absoluteString)"
    }
}

extension Identifier : CustomStringConvertible {
    public var description: String {
        switch self {
        case .mock(.code(let code)): "\(code)"
        case .mock(.label(let label)): label
        case .live: "#Live"
        }
    }
}

extension Response : CustomStringConvertible {
    public var description: String {
        let prettyPrintedJSONData = try? JSONSerialization.data(withJSONObject: JSONSerialization.jsonObject(with: body), options: [.prettyPrinted])
        let formattedBody = String(data: prettyPrintedJSONData ?? body, encoding: .utf8) ?? ""
        
        return if !formattedBody.isEmpty{
        """
        \(self.header.description)
        \(formattedBody)
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

extension Response.Header : CustomStringConvertible {
    public var description: String {
        "\(self.code) \(self.labels.joined(separator: " "))"
    }
}
