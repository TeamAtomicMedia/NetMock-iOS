//
//  NetMockDefinition.swift
//  NetMock
//
//  Created by James Froggatt on 2025.07.29.
//

import Foundation

import NetMockCore

extension NetMock {
    internal struct Definition {
        /// The request which will use this local override.
        private(set) var request: Request
        
        /// Each response will be returned once and then removed. The last item in the sequence will be repeated indefinitely. If a response cannot be found in the available responses, it will be ignored.
        private(set) var responseSequence: [Identifier]
        
        /// The available responses from the NetMock configuration file. These will be identified by status code, and by the name(s) if provided. A provided name can be used to disambiguate when multiple responses are provided for a status code, otherwise the first defined response for the status code will be used.
        private(set) var availableResponses: [Identifier.Mock: Response]
        
        
        init(document: Document) {
            self.request = document.header
   
            self.responseSequence = document.sequence
            
            if self.responseSequence.isEmpty, let code = document.body.first?.header.code {
                self.responseSequence = [.code(code)]
            }
            
            let identifierResponsePairs: [(Identifier.Mock, Response)] = document.body
                .flatMap { response in
                    ([Identifier.Mock.code(response.header.code)] + response.header.labels.map(Identifier.Mock.label))
                        .map { identifier in
                            (identifier, response)
                        }
                }
            
            self.availableResponses = Dictionary(identifierResponsePairs) { value1, value2 in
                // Always default to the existing value
                value1
            }
        }
        
        /// Configured a new responseSequence different to that defined in the original source.
        /// - Parameter responseSequence: Values must match a defined response or they will be ignored.
        mutating func override(_ responseSequence: [Identifier]) {
            assert(!responseSequence.dropLast().contains(.live), "#Live is only supported as the final entry in a sequence")
            let missingResponses = responseSequence
                .compactMap { if case .mock(let id) = $0 {return id} else {return nil} }
                .filter { self.availableResponses[$0] == nil }
            if !missingResponses.isEmpty {
                setupLogger.warning(
                    """
                    NetMock: Response definition(s) not found for the following override responses:
                    \(missingResponses.map { "> \(Identifier.mock($0).description)" }.joined(separator: "\n"))
                    
                    Please verify that your response identifiers appear in the .nm file. 
                    """
                )
            }
            self.responseSequence = responseSequence
        }
        
        func response(for identifier: Identifier.Mock) -> Response? {
            if case let .code(code) = identifier, code < 0 {
                .init(header: .init(code: code, labels: []), body: Data())
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
                    requestLogger.debug(
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
