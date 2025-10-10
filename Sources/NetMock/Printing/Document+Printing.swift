//
//  Document+Printing.swift
//  NetMock
//
//  Created by Christopher Wainwright on 26/09/2025.
//

extension NetMock.Document: CustomStringConvertible {
    var description: String {
        """
        \(self.version.map { "\($0.description)\n" } ?? "")\(self.header.description)

        \(self.body.map(\.description).joined(separator: "\n"))
        """
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

extension NetMock.Document.Header : CustomStringConvertible {
    var description: String {
        "\(self.method) \(self.urlString) \(self.sequence.map(\.description).joined(separator: " "))"
    }
}

extension NetMock.Document.Header.Identifier : CustomStringConvertible {
    var description: String {
        switch self {
        case .code(let code): "\(code)"
        case .label(let label): label
        case .live: "#Live"
        }
    }
}

extension NetMock.Document.Response : CustomStringConvertible {
    var description: String {
        """
        \(self.header.description)\(self.body.flatMap{String(data: $0, encoding: .utf8)}.map {"\n" + $0} ?? "")
        ---
        """
    }
}

extension NetMock.Document.Response.Header : CustomStringConvertible {
    var description: String {
        "\(self.code) \(self.labels.joined(separator: " "))"
    }
}
