//
//  NetMockResponse.swift
//  NetMock
//
//  Created by James Froggatt on 2025.07.29.
//

import Foundation
import OSLog

struct NetMockDefinition {
    
    enum LoadError: Error {
        case invalidFileFormat
        case invalidStructure
        case invalidHeaderStructure
        case invalidResponseStructure
        case invalidURL
    }
    
    struct Request: Hashable {
        var method: String, url: URL
    }
    struct Response {
        var name: String, statusCode: String, body: String
    }
    
    /// The request which will use this local override.
    private(set) var request: Request
    
    /// Each response will be returned once and then removed. The last item in the sequence will be repeated indefinitely. If a response cannot be found in the available responses, it will be ignored.
    private(set) var responseSequence: [String]
    
    /// The available responses from the NetMock configuration file. These will be identified by status code, and by the name(s) if provided. A provided name can be used to disambiguate when multiple responses are provided for a status code, otherwise the first defined response for the status code will be used.
    private(set) var availableResponses: [String: Response]
    
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
        self.request = Request(
            method: headerComponents[0].uppercased(),
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
        
        var firstResponse: Response? = nil
        if !lines.isEmpty {
            let responseDefinition = lines.joined(separator: "\n")
            
            let responses = responseDefinition.components(separatedBy: "\n---\n")
            self.availableResponses = Dictionary(minimumCapacity: responses.count)
            for response in responses {
                // Allow whitespace before & after each response
                let response = response.trimmingCharacters(in: .whitespacesAndNewlines)
                let responseLines = response.components(separatedBy: "\n")
                // Parse first line as `NAME? STATUSCODE` where NAME? is optionally provided. We also handle providing multiple names, for cases like migrating to new names
                guard
                    let responseHeaderComponents = responseLines.first?.components(separatedBy: " "),
                    let responseCode = responseHeaderComponents.first,
                    !responseCode.isEmpty
                else {
                    throw LoadError.invalidResponseStructure
                }
                let responseBody = responseLines.dropFirst().joined(separator: "\n")
                for name in responseHeaderComponents.dropFirst() {
                    self.availableResponses[name.lowercased()] = Response(name: name, statusCode: responseCode, body: responseBody)
                    firstResponse = firstResponse ?? self.availableResponses[name]
                }
                self.availableResponses[responseCode] = Response(name: responseCode, statusCode: responseCode, body: responseBody)
                firstResponse = firstResponse ?? self.availableResponses[responseCode]
            }
        } else {
            self.availableResponses = [:]
        }
        lines.removeAll()
        
        // Parse RESPONSE SEQUENCING from header, or default to first response
        
        let responseOverride = headerComponents.dropFirst(2)
        if responseOverride.isEmpty, let firstResponse {
            self.responseSequence = [firstResponse.name]
        } else {
            self.responseSequence = Array(responseOverride)
        }
        assert(!responseSequence.dropLast().contains("#Live"), "#Live is only supported as the final entry in a sequence")
    }
    
    /// Configured a new responseSequence different to that defined in the original source.
    /// - Parameter responseSequence: Values must match a defined response or they will be ignored.
    mutating func override(_ responseSequence: [String]) {
        assert(!responseSequence.dropLast().contains("#Live"), "#Live is only supported as the final entry in a sequence")
        self.responseSequence = responseSequence
    }
    
    func response(forName name: String) -> Response? {
        if name.hasPrefix("-") {
            Response(name: name, statusCode: name, body: "")
        } else {
            availableResponses[name.lowercased()]
        }
    }
    /// Returns the next response if a sequence has been set, or the default response. Only returns `nil` if no response definitions are found, or use of a live API call has been specifically requested.
    mutating func nextResponse() -> Response? {
        while responseSequence.count > 1 {
            let name = responseSequence.removeFirst()
            if let response = response(forName: name) {
                return response
            } else {
                let request = self.request
                netMockRequestLogger.debug(
                    """
                    NetMock: Response definition not found for \(name) on request:
                    > \(request.method) \(request.url)
                    
                    Update the .nm file to only use existing response names!
                    """
                )
            }
        }
        if let responseName = responseSequence.first, let response = response(forName: responseName) {
            return response
        }
        return nil
    }
    
}
