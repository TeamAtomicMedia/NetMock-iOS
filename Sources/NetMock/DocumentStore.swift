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
                 
        func toDocumentResponse() -> Document.Response {
            let timeFormatter = ISO8601DateFormatter()
            
            // Attempt to decode body to JSON and pretty print result
            let decoded = self.body.flatMap { try? JSONSerialization.jsonObject(with: $0) }.flatMap { try? JSONSerialization.data(withJSONObject: $0, options: [.prettyPrinted]) }
            
            return .init(
                header: .init(
                    code: self.statusCode,
                    labels: [timeFormatter.string(from: self.datetime)]
                ),
                body: decoded
            )
        }
    }
    
    public class DocumentStore {
        public static let shared: DocumentStore = .init()
        
        private var documents: [Request: Document] = [:]
        
        public func add(_ entry: DocumentStoreEntry) {
            let request = Request(entry.method, entry.urlString)
            let response = entry.toDocumentResponse()
            documents[request, default: request.toDocument()].body.append(response)
        }
        
        struct Request : Hashable {
            let method: Method
            let urlString: String
            
            init(_ method: Method, _ urlString: String) {
                self.method = method
                self.urlString = urlString
            }

            func toDocument() -> NetMock.Document {
                .init(
                    version: nil,
                    header: .init(
                        method: method,
                        urlString: urlString,
                        sequence: []
                    ),
                    body: []
                )
            }
        }
    }
}
