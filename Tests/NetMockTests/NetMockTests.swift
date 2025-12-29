import Testing
@testable import NetMock
import Foundation

@Suite(.serialized)
struct Tests {
    let netMock = NetMock.shared
    let network = NetworkAPI()
    
    init() async {
        await NetMock.shared.initialise(bundle: .module)
        await NetMock.shared.allowUnmockedRequests(false)
    }
    
    @Test func exampleGetIsLoaded() async throws {
        assertGetResponse(try await network.exampleGET())
        assertGetResponse(try await network.exampleGET()) // Second call should return the same response
    }
    
    @Test func exampleGetFailureFailsAsExpected() async throws {
        try await assertParseFailure(await network.exampleGETFailure())
        try await assertParseFailure(await network.exampleGETFailure()) // Second call should return the same response
    }
    
    @Test func exampleGetNoInternetFailsAsExpected() async throws {
        try await assertNoInternet(await network.exampleNoInternetAPI())
        try await assertNoInternet(await network.exampleNoInternetAPI()) // Second call should return the same response
    }
    
    @Test func examplePostIsLoaded() async throws {
        #expect(try await network.examplePOST("123").success)
        #expect(try await network.examplePOST("123").success)
    }
    
    @Test func sequencingFunctionsAsExpected() async throws {
        assertGetResponse(try await network.exampleSequencedGET())
        
        try await assertParseFailure(await network.exampleSequencedGET())
        
        let response3 = try await network.exampleSequencedGET()
        #expect(response3.name == "Jugemu Jugemu Go-Kō-no-Surikire Kaijari-suigyo no Suigyō-matsu Unrai-matsu Fūrai-matsu Kū-Neru Tokoro ni Sumu Tokoro Yaburakōji no Burakōji Paipo Paipo Paipo no Shūringan Shūringan no Gūrindai Gūrindai no Ponpokopii no Ponpokonaa no Chōkyūmei no Chōsuke")
        #expect(response3.id == 1)
    }
    
    @Test func liveURLCallsProceedToLiveCallWhenFallbackEnabled() async throws {
        await netMock.allowUnmockedRequests(true)
        
        let statusCode = try await network.exampleLiveAPI()
        #expect(statusCode == 200)
        
        try await assertUnsupportedURLError(await network.exampleLiveAPI())
        try await assertUnsupportedURLError(await network.exampleLiveAPI())
    }
    
    @Test func liveURLCallsProceedToLiveCallWhenFallbackDisabled() async throws {
        await netMock.allowUnmockedRequests(false)
        
        let statusCode = try await network.exampleLiveAPI()
        #expect(statusCode == 200)
        
        try await assertUnsupportedURLError(await network.exampleLiveAPI())
        try await assertUnsupportedURLError(await network.exampleLiveAPI())
    }
    
    @Test func unmockedURLCallsProceedToLiveCallWhenFallbackEnabled() async throws {
        await netMock.allowUnmockedRequests(true)
        try await assertUnsupportedURLError(await network.exampleUnmockedAPI())
        try await assertUnsupportedURLError(await network.exampleUnmockedAPI())
    }
    
    @Test func unmockedURLCallsFailsWhenFallbackDisabled() async throws {
        await netMock.allowUnmockedRequests(false)
        try await assertUnmockedAndBlocked(await network.exampleUnmockedAPI())
        try await assertUnmockedAndBlocked(await network.exampleUnmockedAPI())
    }
    
    @Test func unmockedRealEndpointIsBlocked() async throws {
        do {
            let result = try await network.exampleLiveHTTPSAPI()
            Issue.record("Should not actually make the call, returned status code \(result)")
        } catch let error as NSError {
            #expect(error.domain == URLError.errorDomain)
            #expect(error.code == URLError.resourceUnavailable.rawValue)
        }
    }
    
    @Test func overridesApplyToUnsequencedAPI() async throws {
        await NetMock.shared.override(.GET, NetworkAPI.exampleAPI, response: 500)
        
        try await assertParseFailure(await network.exampleGET())
        try await assertParseFailure(await network.exampleGET())
    }
    
    @Test func overridesApplyToSequencedAPI() async throws {
        await NetMock.shared.override(.GET, NetworkAPI.sequencedAPI, response: 500)
        
        try await assertParseFailure(await network.exampleSequencedGET())
        try await assertParseFailure(await network.exampleSequencedGET())
    }
    
    @Test func overridesCanMakeAPISucceed() async throws {
        await NetMock.shared.override(.GET, NetworkAPI.exampleFailureAPI, response: 200)
        
        assertGetResponse(try await network.exampleGETFailure())
        assertGetResponse(try await network.exampleGETFailure())
    }
    
    @Test func overridesCanMakeNoInternet() async throws {
        await NetMock.shared.override(.GET, NetworkAPI.exampleFailureAPI, response: -1009)
        
        try await assertNoInternet(await network.exampleNoInternetAPI())
        try await assertNoInternet(await network.exampleNoInternetAPI())
    }
    
    @Test func exampleGetIsLoadedWithURLMapping() async throws {
        await NetMock.shared.applyCustomURLParsing { urlString in
            if !urlString.hasPrefix("https://") {
                return URL(string: "https://api.example.com/" + urlString)
            }
            return nil
        }
        await NetMock.shared.initialise(bundle: .module)
        assertGetResponse(try await network.exampleURLMappedGET())
        assertGetResponse(try await network.exampleURLMappedGET()) // Second call should return the same response
        assertGetResponse(try await network.exampleGET())
        assertGetResponse(try await network.exampleGET()) // Second call should return the same response
        try await assertParseFailure(try await network.exampleGETFailure())
        try await assertParseFailure(try await network.exampleGETFailure()) // Second call should return the same response
    }
    
    @Test func dataCaptureIsReversibleConversion() async throws {
        let documentStore = NetMock.DocumentStore.shared
        let fileManager = FileManager.default
        let data = try await network.exampleGETRawData()
        let response = try JSONDecoder().decode(ExampleGETResponse.self, from: data)
        
        await documentStore.add(.init(method: .GET, url: NetworkAPI.exampleAPI, statusCode: 200, body: data))
        let caches = try fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        await documentStore.save(toDirectory: caches, customFilename: { _ in "Test" }, customSubpath: { _ in [] })
        
        var fileContents = try String(contentsOf: caches.appendingPathComponent("Test.nm", isDirectory: false), encoding: .utf8)
        let result = try NetMock.Document.parser.complete().run(&fileContents)
        #expect(result.header.method == .GET)
        #expect(result.header.url == NetworkAPI.exampleAPI)
        let capturedResponse = try #require(result.body.first)
        #expect(capturedResponse.header.code == 200)
        
        let capturedResponseBody = try JSONDecoder().decode(ExampleGETResponse.self, from: capturedResponse.body)
        
        #expect(capturedResponseBody.id == response.id)
        #expect(capturedResponseBody.name == response.name)
    }
    
    func assertParseFailure(_ response: @autoclosure () async throws -> Any, sourceLocation: SourceLocation = #_sourceLocation) async rethrows {
        do {
            let _ = try await response()
            Issue.record("The second sequenced call should fail to parse as it returns a 500 status with no body", sourceLocation: sourceLocation)
        } catch is DecodingError {
            // Continue
        }
    }
    
    func assertUnsupportedURLError(_ response: @autoclosure () async throws -> Any, sourceLocation: SourceLocation = #_sourceLocation) async rethrows {
        do {
            let _ = try await response()
            Issue.record("Call succeeded so #Live was skipped or not respected")
        } catch URLError.unsupportedURL {
            // Continue
        }
    }
    
    func assertNoInternet(_ response: @autoclosure () async throws -> Any, sourceLocation: SourceLocation = #_sourceLocation) async rethrows {
        do {
            let _ = try await response()
            Issue.record("Call succeeded so -1009 (No Internet code) was skipped or not respected")
        } catch let error as URLError where error.code == .notConnectedToInternet {
            // Continue
        }
    }
    
    func assertUnmockedAndBlocked(_ response: @autoclosure () async throws -> Any, sourceLocation: SourceLocation = #_sourceLocation) async rethrows {
        do {
            let _ = try await response()
            Issue.record("Call succeeded so resourceUnavailable was skipped or not respected")
        } catch let error as URLError where error.code == .resourceUnavailable {
            // Continue
        }
    }
    
    func assertGetResponse(_ response: ExampleGETResponse, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(response.name == "John Doe", sourceLocation: sourceLocation)
        #expect(response.id == 1, sourceLocation: sourceLocation)
    }
}
