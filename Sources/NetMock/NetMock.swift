// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import OSLog

private let netMockSetupLogger = Logger(subsystem: "NetMock", category: "load")
internal let netMockRequestLogger = Logger(subsystem: "NetMock", category: "request")

/// The NetMock API. Call `initialise` to load NetMock files, and then call `override` to change how mock responses are selected.
public actor NetMock {
    private var definitions: [NetMockDefinition.Request: NetMockDefinition] = [:]
    
    /// The NetMock instance used by NetMockURLProtocol to keep tracks of mock responses to substitute. Must be initialised before use.
    public static let shared = NetMock()
    
    // Ideally the client could initialise NetMock itself and create URLProtocol with a reference, but URLProtocol can't be initialised directly so we have to use singleton pattern to provide access to NetMock within URLProtocol.
    private init() {}
    
    private var urlParser: (String) -> URL? = URL.init(string:)
    /// By default, NetMock will attempt to parse URLs in nm files directly to a URL.
    ///
    /// Use this method to intercept the URL parsing to perform a custom mapping.
    /// The latest added parser will be attempted first, falling back to previous parsers and finally the NetMock default.
    ///
    /// For example, you can use this to convert API paths to a full URL, where the domain varies by app configuration.
    /// - Parameter parser: The URL parser that will become the new initially attempted parser.
    public func applyCustomURLParsing(_ parser: @escaping (String) -> URL?) {
        self.urlParser = { [oldValue = self.urlParser] string in
            parser(string) ?? oldValue(string)
        }
    }
    
    /// Loads the nm files in the given bundle.
    ///
    /// - Parameter bundle: Typically `.main` is fine, but `.module` may be preferred if nm files are included within a package.
    public func initialise(bundle: Bundle = .main) {
        definitions.removeAll()
        guard let urls = bundle.urls(forResourcesWithExtension: "nm", subdirectory: nil) else {
            return
        }
        definitions.reserveCapacity(urls.count)
        for url in urls {
            do {
                let definition = try NetMockDefinition(fileURL: url, urlParser: urlParser)
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
    
    /// Represents a NetMock override which can change the responses returned to an alternative defined in the nm file.
    public struct Override: Codable {
        /// The HTTP request method to observe. Defaults to "GET".
        public var method: String
        /// The URL whose response will be overridden.
        public var url: URL
        /// A list of response names or codes from the nm file to use as the response.
        public var responses: [String]
        
        public init(method: String = "GET", url: URL, responses: [String]) {
            self.method = method
            self.url = url
            self.responses = responses
        }
    }
    
    /// Applies an override to the response for a given URL and optionally HTTP request method. The override takes the form of a list of identifiers or status codes defined in the nm file for the URL.
    ///
    /// - Parameters:
    ///   - method: The HTTP request method to observe. Defaults to "GET".
    ///   - url: The URL whose response will be overridden.
    ///   - responses: A list of response names or codes from the nm file to use as the response.
    public func override(_ method: String = "GET", _ url: URL, response: String) {
        override(method, url, responses: [response])
    }
    
    /// Applies an override to the response for a given URL and optionally HTTP request method. The override takes the form of a list of identifiers or status codes defined in the nm file for the URL.
    ///
    /// - Parameters:
    ///   - method: The HTTP request method to observe. Defaults to "GET".
    ///   - url: The URL whose response will be overridden.
    ///   - responses: A list of response names or codes from the nm file to use as the response.
    public func override(_ method: String = "GET", _ url: URL, responses: [String]) {
        applyOverride(Override(method: method, url: url, responses: responses))
    }
    
    /// Applies an override to the response for a given URL and optionally HTTP request method. The override takes the form of a list of identifiers or status codes defined in the nm file for the URL.
    ///
    /// - Parameter overrides: The list of overrides to apply.
    public func applyOverrides(_ overrides: [Override]) {
        for override in overrides {
            applyOverride(override)
        }
    }
    
    /// Applies an override to the response for a given URL and optionally HTTP request method. The override takes the form of a list of identifiers or status codes defined in the nm file for the URL.
    ///
    /// - Parameter override: The override to apply.
    public func applyOverride(_ override: Override) {
        let request = NetMockDefinition.Request(method: override.method, url: override.url)
        if override.responses.isEmpty {
            definitions[request] = nil
        } else {
            definitions[request]?.override(override.responses)
        }
    }
    
    // Used by URLProtocol to decide whether to handle the request.
    // If a nm file hasn't been provided or couldn't be read, this should return false.
    func hasResponse(for request: URLRequest) -> Bool {
        guard
            let method = request.httpMethod?.uppercased(),
            let url = request.url
        else { return false }
        let netMockRequest = NetMockDefinition.Request(method: method, url: url)
        if let definition = definitions[netMockRequest], !definition.responseSequence.isEmpty {
            return definition.responseSequence.first != "#Live" // If we see #Live in a sequence, don't intercept
        } else {
            return false
        }
    }
    
    enum Response {
        case success(response: HTTPURLResponse, body: String)
        case urlError(_ code: Int)
    }
    // Used by URLProtocol to generate a response.
    // Logs in DEBUG if an unexpected failure occurs.
    func mockResponse(for request: URLRequest) -> Response? {
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
        
        if statusCode < 0 {
            return .urlError(statusCode)
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
        
        return .success(
            response: httpResponse,
            body: response.body
        )
    }
}
