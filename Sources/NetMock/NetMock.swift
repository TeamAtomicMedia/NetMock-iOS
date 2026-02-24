// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import OSLog

@_exported import NetMockCore

/// The NetMock API. Call `initialise` to load NetMock files, and then call `override` to change how mock responses are selected.
public actor NetMock {
    private var definitions: [NetMockCore.Request: Definition] = [:]
    
    /// The NetMock instance used by NetMockURLProtocol to keep tracks of mock responses to substitute. Must be initialised before use.
    public static let shared = NetMock()
    
    // Ideally the client could initialise NetMock itself and create URLProtocol with a reference, but URLProtocol can't be initialised directly so we have to use singleton pattern to provide access to NetMock within URLProtocol.
    private init() {}
    
    private(set) var handleAllRequests = true
    
    private var urlParser: @Sendable (String) -> URL? = URL.init(string:)
    /// By default, NetMock will attempt to parse URLs in nm files directly to a URL.
    ///
    /// Use this method to intercept the URL parsing to perform a custom mapping.
    /// The latest added parser will be attempted first, falling back to previous parsers and finally the NetMock default.
    /// The new parser will be applied when NetMock.initialise() is next called.
    ///
    /// For example, you can use this to convert API paths to a full URL, where the domain varies by app configuration.
    /// - Parameter parser: The URL parser that will become the new initially attempted parser.
    public func applyCustomURLParsing(_ parser: @Sendable @escaping (String) -> URL?) {
        self.urlParser = { [oldValue = self.urlParser] string in
            parser(string) ?? oldValue(string)
        }
    }
    
    /// Blocks requests which do not have a nm file included, producing a resource unavailable error.
    public func allowUnmockedRequests(_ newValue: Bool = true) {
        handleAllRequests = !newValue
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
                let document = try NetMockCore.Document(fileURL: url, urlParser: urlParser)
                let definition = Definition(document: document)
                self.definitions[definition.request] = definition
            } catch {
                setupLogger.debug(
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
        public var method: NetMockCore.Method
        /// The URL whose response will be overridden.
        public var url: URL
        /// A list of response names or codes from the nm file to use as the response.
        public var responses: [NetMockCore.Identifier]
        
        public init(method: NetMockCore.Method = .GET, url: URL, responses: [NetMockCore.Identifier]) {
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
    ///   - response: A list of response names or codes from the nm file to use as the response.
    public func override(_ method: NetMockCore.Method = .GET, _ url: URL, response: NetMockCore.Identifier) {
        override(method, url, responses: [response])
    }
    
    /// Applies an override to the response for a given URL and optionally HTTP request method. The override takes the form of a list of identifiers or status codes defined in the nm file for the URL.
    ///
    /// - Parameters:
    ///   - method: The HTTP request method to observe. Defaults to "GET".
    ///   - url: The URL whose response will be overridden.
    ///   - responses: A list of response names or codes from the nm file to use as the response.
    public func override(_ method: NetMockCore.Method = .GET, _ url: URL, responses: [NetMockCore.Identifier]) {
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
        let request = NetMockCore.Request(method: override.method, url: override.url)
        if override.responses.isEmpty {
            definitions[request] = nil
        } else {
            guard definitions[request] != nil else {
                setupLogger.warning(
                    """
                    NetMock: Response was not found for override:
                    > \(request.method.rawValue):\(request.url)
                    
                    Verify that a corresponding .nm file exists.
                    """
                )
                return
            }
            definitions[request]?.override(override.responses)
        }
    }
    
    // Used by URLProtocol to decide whether to handle the request.
    // If a nm file hasn't been provided or couldn't be read, this should return false.
    func shouldHandle(_ request: URLRequest) -> Bool {
        guard
            let method = (request.httpMethod?.uppercased()).flatMap(NetMockCore.Method.init),
            let url = request.url
        else { return false }
        let netMockRequest = NetMockCore.Request(method: method, url: url)
        if let definition = definitions[netMockRequest], !definition.responseSequence.isEmpty {
            let isLive = definition.responseSequence.first == .live // If we see #Live in a sequence, don't intercept
            return !isLive
        } else {
            return handleAllRequests
        }
    }
    
    enum URLProtocolResponse {
        case success(response: HTTPURLResponse, body: Data)
        case urlError(_ code: Int)
    }
    
    // Used by URLProtocol to generate a response.
    // Logs in DEBUG if an unexpected failure occurs.
    func mockResponse(for request: URLRequest) -> URLProtocolResponse? {
        guard
            let method = (request.httpMethod?.uppercased()).flatMap(NetMockCore.Method.init),
            let url = request.url
        else { return nil }
        
        let netMockRequest = NetMockCore.Request(method: method, url: url)
        
        guard let response = definitions[netMockRequest]?.nextResponse()
        else { return nil }
        
        
        if response.header.code < 0 {
            return .urlError(response.header.code)
        }
        
        guard let httpResponse = HTTPURLResponse(
            url: url,
            statusCode: response.header.code,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        ) else {
            requestLogger.debug(
                """
                NetMock: Unexpectedly failed to initialise HTTPURLResponse instance from mock response for:
                > \(url.absoluteString) \(response.header.code)
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
