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
    
    public actor DocumentStore {
        public static let shared: DocumentStore = .init()
        
        private init() {}
        
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
        
        public func save(
            toFile file: URL? = nil,
            modifyContents: @escaping (String) -> String = {$0},
            customFilename: @escaping (Method, String) -> String = {$1.split(separator: "/").last.map(String.init) ?? $1},
            customDirectory: @escaping (Method, String) -> [String] = {method, urlString in urlString.split(separator: "/").dropLast().map(String.init) + [method.rawValue] }
        ) {
            let documentCount = self.documents.count
            var writeCount: Int = 0
            
            let documentsDirectory = if let file {
                file
            } else {
                FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            }
            
            for document in self.documents {
                let fileContents = modifyContents(document.value.description)
                let data = fileContents.data(using: .utf8)
                
                let directory: URL = customDirectory(document.key.method, document.key.urlString)
                    .reduce(documentsDirectory) { $0.appendingPathComponent($1) }
                
                let filename: String = customFilename(document.key.method, document.key.urlString)
                
                do {
                    try FileManager().createDirectory(at: directory, withIntermediateDirectories: true)
                } catch {
                    print("Failed to create folder \(directory)")
                }
                
                let url = directory.appendingPathComponent(filename).appendingPathExtension("nm")
                print("Writing to \(url)")
                
                do {
                    try data?.write(to: url, options: [.atomic, .completeFileProtection])
                    writeCount += 1
                } catch {
                    print("Failed to write document \(document.key): \(error)")
                }
            }
            
            guard documentCount != 0 else { return }
            
            if writeCount == documentCount {
                print("All files successfully written")
            } else {
                print("\(writeCount)/\(documentCount) Documents successfully written")
            }
        }
    }
}
