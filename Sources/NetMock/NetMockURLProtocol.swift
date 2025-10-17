//
//  MockURLProtocol.swift
//  NetMock
//
//  Created by James Froggatt on 2025.07.29.
//

import Foundation

/// Apply this to the URLSessionConfiguration to send URL requests with nm files present through NetMock.
public class NetMockURLProtocol: URLProtocol {
    static func withNetMock<T: Sendable>(_ perform: @Sendable @escaping (isolated NetMock) -> T) -> T {
        var result: T!
        let semaphore = DispatchSemaphore(value: 0)
        let netMock = NetMock.shared
        Task {
            result = await perform(netMock)
            semaphore.signal()
        }
        semaphore.wait()
        return result
    }
    
    override public class func canInit(with task: URLSessionTask) -> Bool {
        if let request = task.currentRequest ?? task.originalRequest {
            canInit(with: request)
        } else {
            false
        }
    }
    
    override public class func canInit(with request: URLRequest) -> Bool {
        withNetMock { netMock in
            netMock.shouldHandle(request)
        }
    }
    
    override init(request: URLRequest, cachedResponse: CachedURLResponse?, client: (any URLProtocolClient)?) {
        super.init(request: request, cachedResponse: cachedResponse, client: client)
    }
    
    override public class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }
    
    override public func startLoading() {
        guard let response = Self.withNetMock({ [request] in $0.mockResponse(for: request) }) else {
            client?.urlProtocol(self, didFailWithError: URLError(.resourceUnavailable))
            return
        }
        switch response {
        case .success(let response, let body):
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)
        case .urlError(let code):
            client?.urlProtocol(self, didFailWithError: URLError(.init(rawValue: code)))
        }
    }
    
    override public func stopLoading() {}
    
    public static func applyGlobally() {
        // WebViews and system
        URLProtocol.registerClass(NetMockURLProtocol.self)
        
        // Apply to all URLSessions created in project
        let configDefaultOriginal = class_getClassMethod(URLSessionConfiguration.self, #selector(getter: URLSessionConfiguration.defaultBypassingNetMock))!
        let configDefaultReplacement = class_getClassMethod(URLSessionConfiguration.self, #selector(getter: URLSessionConfiguration.`default`))!
        method_exchangeImplementations(configDefaultOriginal, configDefaultReplacement)
        
        let configEphemeralOriginal = class_getClassMethod(URLSessionConfiguration.self, #selector(getter: URLSessionConfiguration.ephemeralBypassingNetMock))!
        let configEphemeralReplacement = class_getClassMethod(URLSessionConfiguration.self, #selector(getter: URLSessionConfiguration.ephemeral))!
        method_exchangeImplementations(configEphemeralOriginal, configEphemeralReplacement)
        
        let sessionSharedOriginal = class_getClassMethod(URLSession.self, #selector(getter: URLSession.sharedBypassingNetMock))!
        let sessionSharedReplacement = class_getClassMethod(URLSession.self, #selector(getter: URLSession.shared))!
        method_exchangeImplementations(sessionSharedOriginal, sessionSharedReplacement)
    }
}

extension URLSessionConfiguration {
    /// Use this method to get `URLSessionConfiguration.default` without NetMock applied.
    /// This method must be called after `NetMockURLProtocol.applyGlobally()`.
    @objc public class var defaultBypassingNetMock: URLSessionConfiguration {
        // The implementation to be used post-swizzle.
        let config = URLSessionConfiguration.defaultBypassingNetMock // Now has .default's implementation. Pre-swizzle, this will infinitely recurse and stack overflow.
        config.protocolClasses = [NetMockURLProtocol.self] + (config.protocolClasses ?? [])
        return config
    }
    /// Use this method to get `URLSessionConfiguration.ephemeral` without NetMock applied.
    /// This method must be called after `NetMockURLProtocol.applyGlobally()`.
    @objc public class var ephemeralBypassingNetMock: URLSessionConfiguration {
        // The implementation to be used post-swizzle.
        let config = URLSessionConfiguration.ephemeralBypassingNetMock // Now has .ephemeral's implementation. Pre-swizzle, this will infinitely recurse and stack overflow.
        config.protocolClasses = [NetMockURLProtocol.self] + (config.protocolClasses ?? [])
        return config
    }
}

extension URLSession {
    /// Use this method to get `URLSession.shared` without NetMock applied.
    /// This method must be called after `NetMockURLProtocol.applyGlobally()`.
    @objc public class var sharedBypassingNetMock: URLSession {
        // The implementation to be used post-swizzle.
        let session = URLSession.sharedBypassingNetMock // Now has .shared's implementation. Pre-swizzle, this will infinitely recurse and stack overflow.
        if session.configuration.protocolClasses?.contains(where: { $0 == NetMockURLProtocol.self }) == false {
            session.configuration.protocolClasses = [NetMockURLProtocol.self] + (session.configuration.protocolClasses ?? [])
        }
        return session
    }
}
