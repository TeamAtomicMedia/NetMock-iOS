//
//  Document+Printing.swift
//  NetMock
//
//  Created by Christopher Wainwright on 26/09/2025.
//

import Playgrounds

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
        switch(self) {
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

#Playground {
    let testDocument = NetMock.Document(
        version: .init(major: 2, minor: 0, patch: 20),
        header: .init(
            method: .GET,
            urlString: "https://api.example.com/data",
            sequence: [.code(200), .code(404), .label("TEST"), .label("FAILURE"), .live]),
        body: [
            .init(
                header: .init(code: 200, labels: ["TEST"]),
                body: "{\"id\": \"Hello\"}".data(using: .utf8)
            ),
            .init(
                header: .init(code: 404, labels: []),
                body: nil
            )
        ]
    )
    
    print(testDocument)
}
