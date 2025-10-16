//
//  NetMockDefinition.swift
//  NetMock
//
//  Created by James Froggatt on 2025.07.29.
//

import Foundation
import OSLog

extension NetMock {
    struct Definition {
        
        enum LoadError: Error {
            case invalidFileFormat
            case invalidStructure
            case invalidHeaderStructure
            case invalidResponseStructure
            case invalidHTTPMethod
            case invalidURL
        }
    
        struct Response {
            var code: Int, body: String
        }
        
        /// The request which will use this local override.
        private(set) var request: Request
        
        /// Each response will be returned once and then removed. The last item in the sequence will be repeated indefinitely. If a response cannot be found in the available responses, it will be ignored.
        private(set) var responseSequence: [Identifier]
        
        /// The available responses from the NetMock configuration file. These will be identified by status code, and by the name(s) if provided. A provided name can be used to disambiguate when multiple responses are provided for a status code, otherwise the first defined response for the status code will be used.
        private(set) var availableResponses: [Identifier.Mock: Response]
        
        
        init(fileURL: URL, urlParser: (String) -> URL?) throws {
            let data = try Data(contentsOf: fileURL)
            guard let contents = String(data: data, encoding: .utf8) else {
                throw LoadError.invalidFileFormat
            }
            try self.init(contents, urlParser: urlParser)
        }
        init(_ string: String, urlParser: (String) -> URL?) throws {
            var lines = string.components(separatedBy: "\n")
            
            // Parse VERSION STRING
            
            let netMockVersion: String
            if let version = lines.first, version.hasPrefix("NetMock") {
                lines.removeFirst()
                netMockVersion = version.components(separatedBy: " ").last!
            } else {
                netMockVersion = "1.0.0"
            }
            _ = netMockVersion // Use when making breaking changes to ensure backwards-compatibility
            
            // Parse METHOD and URL
            
            guard let header = lines.first else {
                throw LoadError.invalidStructure
            }
            lines.removeFirst()
            let headerComponents = header.components(separatedBy: " ")
            guard headerComponents.count >= 2 else {
                throw LoadError.invalidHeaderStructure
            }
            guard let url = urlParser(headerComponents[1]) else {
                throw LoadError.invalidURL
            }
            
            guard let method = Method(rawValue: headerComponents[0].uppercased()) else {
                throw LoadError.invalidHTTPMethod
            }
            
            self.request = Request(
                method: method,
                url: url
            )
            
            // Parse BLANK LINE if responses are defined
            
            if let nextLine = lines.first {
                guard nextLine.isEmpty else {
                    throw LoadError.invalidStructure
                }
                lines.removeFirst()
            }
            
            // Parse RESPONSES
            
            var firstResponse: Identifier.Mock? = nil
            if !lines.isEmpty {
                let responseDefinition = lines.joined(separator: "\n")
                
                let responses = responseDefinition
                    .components(separatedBy: "\n---\n")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                self.availableResponses = Dictionary(minimumCapacity: responses.count)
                for response in responses.reversed() {
                    // Allow whitespace before & after each response
                    let response = response.trimmingCharacters(in: .whitespacesAndNewlines)
                    let responseLines = response.components(separatedBy: "\n")
                    // Parse first line as `NAME? STATUSCODE` where NAME? is optionally provided. We also handle providing multiple names, for cases like migrating to new names
                    guard
                        let responseHeaderComponents = responseLines.first?.components(separatedBy: " "),
                        let responseCode = responseHeaderComponents.first.flatMap(Int.init)
                    else {
                        throw LoadError.invalidResponseStructure
                    }
                    let responseBody = responseLines.dropFirst().joined(separator: "\n")
                    for name in responseHeaderComponents.dropFirst() {
                        self.availableResponses[.label(name)] = Response(code: responseCode, body: responseBody)
                    }
                    self.availableResponses[.code(responseCode)] = Response(code: responseCode, body: responseBody)
                    firstResponse = .code(responseCode)
                }
            } else {
                self.availableResponses = [:]
            }
            lines.removeAll()
            
            // Parse RESPONSE SEQUENCING from header, or default to first response
            
            let responseOverride: [Identifier] = headerComponents.dropFirst(2).map(Identifier.init)
            if responseOverride.isEmpty, let firstResponse {
                self.responseSequence = [.mock(firstResponse)]
            } else {
                self.responseSequence = Array(responseOverride)
            }
            assert(!responseSequence.dropLast().contains(.live), "#Live is only supported as the final entry in a sequence")
        }
        
        /// Configured a new responseSequence different to that defined in the original source.
        /// - Parameter responseSequence: Values must match a defined response or they will be ignored.
        mutating func override(_ responseSequence: [Identifier]) {
            assert(!responseSequence.dropLast().contains(.live), "#Live is only supported as the final entry in a sequence")
            self.responseSequence = responseSequence
        }
        
        func response(for identifier: Identifier.Mock) -> Response? {
            if case let .code(code) = identifier, code < 0 {
                Response(code: code, body: "")
            } else {
                availableResponses[identifier]
            }
        }
        /// Returns the next response if a sequence has been set, or the default response. Only returns `nil` if no response definitions are found, or use of a live API call has been specifically requested.
        mutating func nextResponse() -> Response? {
            // If multiple responses remain, then consume the responses
            while responseSequence.count > 1 {
                let identifier = responseSequence.removeFirst()
                switch identifier {
                case .live:
                    return nil
                case .mock(let id):
                    if let response = response(for: id) {
                        return response
                    }
                    fallthrough
                case _:
                    let request = self.request
                    netMockRequestLogger.debug(
                    """
                    NetMock: Response definition not found for \(identifier.description) on request:
                    > \(request.method.rawValue) \(request.url)
                    
                    Update the .nm file to only use existing response names!
                    """
                    )
                }
            }
            // When one response remains, do not consume
            if let id = responseSequence.first, case let .mock(id) = id, let response = response(for: id) {
                return response
            }
            return nil
        }
    }
}
