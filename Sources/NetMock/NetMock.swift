// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import OSLog

private let netMockSetupLogger = Logger(subsystem: "NetMock", category: "load")
internal let netMockRequestLogger = Logger(subsystem: "NetMock", category: "request")

public actor NetMock {
    private var definitions: [NetMockDefinition.Request: NetMockDefinition] = [:]
    
    public static let shared = NetMock()
    // Ideally the client could initialise NetMock itself and create URLProtocol with a reference, but URLProtocol can't be initialised directly so we have to use singleton pattern to provide access to NetMock within URLProtocol.
    private init() {}
    public func initialise(bundle: Bundle = .main) {
        definitions.removeAll()
        guard let urls = bundle.urls(forResourcesWithExtension: "nm", subdirectory: nil) else {
            return
        }
        definitions.reserveCapacity(urls.count)
        for url in urls {
            do {
                let definition = try NetMockDefinition(fileURL: url)
                self.definitions[definition.request] = definition
            } catch {
                netMockSetupLogger.debug(
                    """
                    NetMock: Error reading \(url.lastPathComponent):
                    > \(error)
                    """
                )
            }
        }
    }
    
    public func override(_ method: String = "GET", _ url: URL, responses: String...) {
        override(method, url, responses: responses)
    }
    public func override(_ method: String = "GET", _ url: URL, responses: [String]) {
        let request = NetMockDefinition.Request(method: method, url: url)
        if responses.isEmpty {
            definitions[request] = nil
        } else {
            definitions[request]?.override(responses)
        }
    }
    
    func hasResponse(for request: URLRequest) -> Bool {
        guard
            let method = request.httpMethod?.uppercased(),
            let url = request.url
        else { return false }
        let netMockRequest = NetMockDefinition.Request(method: method, url: url)
        if let definition = definitions[netMockRequest] {
            return definition.responseSequence.first != "#Live" // If we see #Live in a sequence, don't intercept
        } else {
            return false
        }
    }
    func mockResponse(for request: URLRequest) -> (response: HTTPURLResponse, body: String)? {
        guard
            let method = request.httpMethod?.uppercased(),
            let url = request.url
        else { return nil }
        
        let netMockRequest = NetMockDefinition.Request(method: method, url: url)
        
        guard let response = definitions[netMockRequest]?.nextResponse() else {
            netMockRequestLogger.debug(
                """
                NetMock: No response found for request:
                > \(url.absoluteString)

                NetMock should be correctly determining if a response is present, so seeing this indicates a bug in NetMock!
                """
            )
            return nil
        }
        
        guard let statusCode = Int(response.statusCode) else {
            netMockRequestLogger.debug(
                """
                NetMock: Failed to parse status code for:
                > \(url.absoluteString)

                Ensure the status code defined in the .nm file is a valid number!
                """
            )
            return nil
        }
        
        guard let httpResponse = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        ) else {
            netMockRequestLogger.debug(
                """
                NetMock: Unexpectedly failed to initialise HTTPURLResponse instance from mock response for:
                > \(url.absoluteString) \(statusCode)
                """
            )
            return nil
        }
        
        return (
            response: httpResponse,
            body: response.body
        )
    }
}
