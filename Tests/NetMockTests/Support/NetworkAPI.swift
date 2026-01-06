import Foundation
import NetMock

class NetworkAPI {
    let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [NetMockURLProtocol.self]
        let session = URLSession(configuration: configuration)
        return session
    }()
    
    static let exampleAPI = URL(string: "https://api.example.com/example")!
    
    func exampleGETRawData() async throws -> Data {
        let (data, _) = try await session.data(from: Self.exampleAPI)
        return data
    }
    func exampleGET() async throws -> ExampleGETResponse {
        let data = try await exampleGETRawData()
        return try JSONDecoder().decode(ExampleGETResponse.self, from: data)
    }
    
    func examplePOST(_ string: String) async throws -> ExamplePOSTResponse {
        var request = URLRequest(url: Self.exampleAPI)
        request.httpMethod = "POST"
        let (data, _) = try await session.data(for: request)
        return try JSONDecoder().decode(ExamplePOSTResponse.self, from: data)
    }
    
    static let sequencedAPI = URL(string: "https://api.example.com/sequenced")!
    
    func exampleSequencedGET() async throws -> ExampleGETResponse {
        let (data, _) = try await session.data(from: Self.sequencedAPI)
        return try JSONDecoder().decode(ExampleGETResponse.self, from: data)
    }
    
    static let liveHTTPSAPI = URL(string: "https://example.com")!
    func exampleLiveHTTPSAPI() async throws -> Int {
        let (_, response) = try await session.data(from: Self.liveHTTPSAPI) // This is expected to provide a failing status code
        return (response as! HTTPURLResponse).statusCode
    }
    
    static let liveAPI = URL(string: "local://api.example.com/live")!
    
    func exampleLiveAPI() async throws -> Int {
        let (_, response) = try await session.data(from: Self.liveAPI) // This is expected to provide a failing status code
        return (response as! HTTPURLResponse).statusCode
    }
    
    static let unmockedAPI = URL(string: "local://api.example.com/unmocked")!
    
    func exampleUnmockedAPI() async throws -> Int {
        let (_, response) = try await session.data(from: Self.unmockedAPI) // This is expected to provide a failing status code
        return (response as! HTTPURLResponse).statusCode
    }
    
    static let exampleFailureAPI = URL(string: "https://api.example.com/fail")!
    func exampleGETFailure() async throws -> ExampleGETResponse {
        let (data, _) = try await session.data(from: Self.exampleFailureAPI)
        return try JSONDecoder().decode(ExampleGETResponse.self, from: data)
    }
    
    static let noInternetAPI = URL(string: "https://api.example.com/nointernet")!
    func exampleNoInternetAPI() async throws {
        _ = try await session.data(from: Self.noInternetAPI) // This is expected to throw URLError(.notConnectedToInternet)
    }
    
    static let urlMappedAPI = URL(string: "https://api.example.com/urlmapped")!
    func exampleURLMappedGET() async throws -> ExampleGETResponse {
        let (data, _) = try await session.data(from: Self.urlMappedAPI)
        return try JSONDecoder().decode(ExampleGETResponse.self, from: data)
    }
}
