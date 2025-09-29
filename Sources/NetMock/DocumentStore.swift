//
//  DocumentStore.swift
//  NetMock
//
//  Created by Christopher Wainwright on 26/09/2025.
//

import Foundation

extension NetMock {
    public struct DocumentStoreEntry {
        let method: Method
        let urlString: String
        let statusCode: Int
        let datetime: Date
        let body: Data?
        
        public init(method: Method, urlString: String, statusCode: Int, body: Data?) {
            self.method = method
            self.urlString = urlString
            self.statusCode = statusCode
            self.datetime = Date()
            self.body = body
        }
        
        func toDocument() -> Document {
            .init(version: nil,
                  header: .init(
                    method: self.method,
                    urlString: self.urlString,
                    sequence: []
                  ),
                  body: [self.toDocumentResponse()])
        }
        
        func toDocumentResponse() -> Document.Response {
            let timeFormatter = ISO8601DateFormatter()
            return .init(
                header: .init(
                    code: self.statusCode,
                    labels: [timeFormatter.string(from: self.datetime)]
                ),
                body: self.body
            )
        }
    }
    
    public struct DocumentStore {
        @MainActor
        public static var shared: DocumentStore = .init()
        
        var documents: [String: Document] = [:]
        
        public mutating func add(_ entry: DocumentStoreEntry) {
            if let existingDocument = documents[entry.urlString] {
                let response = entry.toDocumentResponse()
                documents[entry.urlString] = existingDocument.addResponse(response)
            } else {
                documents[entry.urlString] = entry.toDocument()
            }
            
            Task { @MainActor in
                print(DocumentStore.shared.documents.map(\.value.description))
            }
        }
    }
}

extension NetMock.Document {
    func addResponse(_ response: Response) -> Self {
        .init(version: self.version, header: self.header, body: self.body + [response])
    }
}
