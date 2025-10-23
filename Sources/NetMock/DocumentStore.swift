//
//  DocumentStore.swift
//  NetMock
//
//  Created by Christopher Wainwright on 26/09/2025.
//

import Foundation

private extension NetMock.Document {
    init(request: NetMock.Request, body: [NetMock.DocumentStoreEntry.CapturedResponse]) {
        self.init(version: nil, header: request, body: body.map(\.response))
    }
}

extension NetMock {
    /// A struct containing the information associated to a given network request and response
    public struct DocumentStoreEntry {
        /// A struct containing information associated with a single captured response
        ///
        /// This struct is used internally inside DocumentStore to store captured responses.
        struct CapturedResponse : Hashable {
            let statusCode: Int
            let datetime: Date
            let body: Data
            
            public init(statusCode: Int, body: Data) {
                self.statusCode = statusCode
                self.datetime = Date()
                self.body = body
            }
            
            var response: NetMock.Response {
                .init(header: .init(code: statusCode, labels: [datetime.ISO8601Format()]), body: body)
            }
        }

        let request: Request
        let response: CapturedResponse
        
        public init(method: Method, url: URL, statusCode: Int, body: Data) {
            self.request = .init(method: method, url: url)
            self.response = .init(statusCode: statusCode, body: body)
        }
    }
    
    /// A singleton to capture network responses, structure them into NetMock documents, and persist them to the filesystem.
    public actor DocumentStore {
        public static let shared: DocumentStore = .init()
        
        private init() {}
        
        private var documents: [Request: [DocumentStoreEntry.CapturedResponse]] = [:]
        
        /// Store the DocumentStoreEntry to the DocumentStore singleton
        /// - Parameter entry: DocumentStoreEntry containing the details of a provided network request and response.
        public func add(_ entry: DocumentStoreEntry) {
            let request = entry.request
            let response = entry.response
            documents[request, default: []].append(response)
        }
        
        /// Persist captured responses in DocumentStore to filesystem as .nm files
        /// - Parameters:
        ///   - file: The base directory where files will be written. Defaults to the app’s document directory.
        ///   - modifyContents: A closure for transforming the saved file contents (e.g. redacting or generalising domains). Defaults to a closure with no effect.
        ///   - customFilename: A closure for customising the file’s name. Defaults to the last component of the urlString (if a valid url) otherwise the full urlString.
        ///   - customDirectory: A closure for customising the directory structure for each response. Defaults to all but the last component of the urlString plus the method.
        public func save(
            toFile file: URL? = nil,
            modifyContents: (String) -> String = { $0 },
            customFilename: (Request) -> String = { $0.url.pathComponents.last ?? $0.url.absoluteString },
            customDirectory: (Request) -> [String] = { $0.url.pathComponents.dropLast() + [$0.method.rawValue] }
        ) {
            let documentCount = self.documents.count
            var writeCount: Int = 0
            
            let documentsDirectory = if let file {
                file
            } else {
                FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            }
            
            for document in self.documents {
                let fileContents = Document(request: document.key, body: document.value).description
                let modifiedFileContents = modifyContents(fileContents)

                guard let data = modifiedFileContents.data(using: .utf8)
                else { continue }

                let directory: URL = customDirectory(document.key)
                    .reduce(documentsDirectory) { $0.appendingPathComponent($1) }
                
                let filename: String = customFilename(document.key)
                
                do {
                    try FileManager().createDirectory(at: directory, withIntermediateDirectories: true)
                } catch {
                    NetMock.captureLogger.debug("Failed to create folder \(directory)")
                    break
                }
                
                let url = directory.appendingPathComponent(filename).appendingPathExtension("nm")
                NetMock.captureLogger.debug("Writing to \(url)")
                
                do {
                    try data.write(to: url, options: [.atomic, .completeFileProtection])
                    writeCount += 1
                } catch {
                    NetMock.captureLogger.debug("Failed to write document \(document.key): \(error)")
                }
            }
            
            guard documentCount != 0 else { return }
            
            if writeCount == documentCount {
                NetMock.captureLogger.debug("All files successfully written")
            } else {
                NetMock.captureLogger.debug("\(writeCount)/\(documentCount) Documents successfully written")
            }
        }
        
        public func reset() {
            self.documents.removeAll()
        }
    }
}
