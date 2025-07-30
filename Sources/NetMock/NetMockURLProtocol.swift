//
//  MockURLProtocol.swift
//  NetMock
//
//  Created by James Froggatt on 2025.07.29.
//

import Foundation

public enum NetMockError: String, Error {
    case failedToGenerateResponse = "NetMock has loaded a nm response definition successfully, but failed to turn it into a response."
}

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
            withNetMock { netMock in
                netMock.hasResponse(for: request)
            }
        } else {
            false
        }
    }
    
    override init(request: URLRequest, cachedResponse: CachedURLResponse?, client: (any URLProtocolClient)?) {
        super.init(request: request, cachedResponse: cachedResponse, client: client)
    }
    
    override public class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }
    
    override public func startLoading() {
        guard let (response, body) = Self.withNetMock({ [request] in $0.mockResponse(for: request) }) else {
            client?.urlProtocol(self, didFailWithError: NetMockError.failedToGenerateResponse)
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body.data(using: .utf8)!)
        client?.urlProtocolDidFinishLoading(self)
    }
    
    override public func stopLoading() {}
}
