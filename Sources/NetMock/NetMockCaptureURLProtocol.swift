//
//  NetMockCaptureURLProtocol.swift
//  NetMock
//
//  Created by Christopher Wainwright on 04/12/2025.
//

import Foundation

/// Apply this to the URLSessionConfiguration to send URL responses to NetMock Capture
public class NetMockCaptureURLProtocol: URLProtocol, @unchecked Sendable {
    @MainActor
    static var session = URLSession(configuration: .default)
    
    public override class func canInit(with request: URLRequest) -> Bool {
        guard let scheme = request.url?.scheme else { return false }
        return scheme == "https" || scheme == "http"
    }
    
    override public class func canonicalRequest(for request: URLRequest) -> URLRequest { request
    }
    
    override public func startLoading() {
        let rawMethod = request.httpMethod ?? "GET"
        let method: NetMock.Method = NetMock.Method(rawValue: rawMethod) ?? .GET
        let url = request.url
        
        Task {
            do {
                let (data, urlResponse) = try await NetMockCaptureURLProtocol.session.data(for: request)
                
                client?.urlProtocol(self, didReceive: urlResponse, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
                
                if let url, let httpResponse = urlResponse as? HTTPURLResponse {
                    await NetMock.DocumentStore.shared.add(.init(method: method, url: url, statusCode: httpResponse.statusCode, body: data))
                }
            } catch {
                client?.urlProtocol(self, didFailWithError: error)
            }
        }
    }
    
    public static func applyGlobally() {
        // WebViews and system
        URLProtocol.registerClass(Self.self)
        
        // Apply to all URLSessions created in project
        let configDefaultOriginal = class_getClassMethod(URLSessionConfiguration.self, #selector(getter: URLSessionConfiguration.defaultBypassingNetMockCapture))!
        let configDefaultReplacement = class_getClassMethod(URLSessionConfiguration.self, #selector(getter: URLSessionConfiguration.`default`))!
        method_exchangeImplementations(configDefaultOriginal, configDefaultReplacement)
        
        let configEphemeralOriginal = class_getClassMethod(URLSessionConfiguration.self, #selector(getter: URLSessionConfiguration.ephemeralBypassingNetMockCapture))!
        let configEphemeralReplacement = class_getClassMethod(URLSessionConfiguration.self, #selector(getter: URLSessionConfiguration.ephemeral))!
        method_exchangeImplementations(configEphemeralOriginal, configEphemeralReplacement)
        
        let sessionSharedOriginal = class_getClassMethod(URLSession.self, #selector(getter: URLSession.sharedBypassingNetMockCapture))!
        let sessionSharedReplacement = class_getClassMethod(URLSession.self, #selector(getter: URLSession.shared))!
        method_exchangeImplementations(sessionSharedOriginal, sessionSharedReplacement)
    }
}

extension URLSessionConfiguration {
    /// Use this method to get `URLSessionConfiguration.default` without NetMock applied.
    /// This method must be called after `NetMockCaptureURLProtocol.applyGlobally()`.
    @objc public class var defaultBypassingNetMockCapture: URLSessionConfiguration {
        // The implementation to be used post-swizzle.
        let config = URLSessionConfiguration.defaultBypassingNetMockCapture // Now has .default's implementation. Pre-swizzle, this will infinitely recurse and stack overflow.
        config.protocolClasses = [NetMockCaptureURLProtocol.self] + (config.protocolClasses ?? [])
        return config
    }
    /// Use this method to get `URLSessionConfiguration.ephemeral` without NetMock applied.
    /// This method must be called after `NetMockCaptureURLProtocol.applyGlobally()`.
    @objc public class var ephemeralBypassingNetMockCapture: URLSessionConfiguration {
        // The implementation to be used post-swizzle.
        let config = URLSessionConfiguration.ephemeralBypassingNetMockCapture // Now has .ephemeral's implementation. Pre-swizzle, this will infinitely recurse and stack overflow.
        config.protocolClasses = [NetMockCaptureURLProtocol.self] + (config.protocolClasses ?? [])
        return config
    }
}

extension URLSession {
    /// Use this method to get `URLSession.shared` without NetMock applied.
    /// This method must be called after `NetMockCaptureURLProtocol.applyGlobally()`.
    @objc public class var sharedBypassingNetMockCapture: URLSession {
        // The implementation to be used post-swizzle.
        let session = URLSession.sharedBypassingNetMockCapture // Now has .shared's implementation. Pre-swizzle, this will infinitely recurse and stack overflow.
        if session.configuration.protocolClasses?.contains(where: { $0 == NetMockCaptureURLProtocol.self }) == false {
            session.configuration.protocolClasses = [NetMockCaptureURLProtocol.self] + (session.configuration.protocolClasses ?? [])
        }
        return session
    }
}
