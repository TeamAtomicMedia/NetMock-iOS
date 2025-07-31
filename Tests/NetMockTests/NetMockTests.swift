import Testing
@testable import NetMock
import Foundation

@Suite(.serialized)
struct Tests {
    let netMock = NetMock.shared
    let network = NetworkAPI()
    
    init() async {
        await NetMock.shared.initialise(bundle: .module)
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
    
    @Test func liveURLCallsProceedToLiveCall() async throws {
        let statusCode = try await network.exampleLiveAPI()
        #expect(statusCode == 200)
        
        try await assertUnsupportedURLError(await network.exampleLiveAPI())
        try await assertUnsupportedURLError(await network.exampleLiveAPI())
    }
    
    @Test func unmockedURLCallsProceedToLiveCall() async throws {
        try await assertUnsupportedURLError(await network.exampleUnmockedAPI())
        try await assertUnsupportedURLError(await network.exampleUnmockedAPI())
    }
    
    @Test func overridesApplyToUnsequencedAPI() async throws {
        await NetMock.shared.override("GET", NetworkAPI.exampleAPI, response: "500")
        
        try await assertParseFailure(await network.exampleGET())
        try await assertParseFailure(await network.exampleGET())
    }
    
    @Test func overridesApplyToSequencedAPI() async throws {
        await NetMock.shared.override("GET", NetworkAPI.sequencedAPI, response: "500")
        
        try await assertParseFailure(await network.exampleSequencedGET())
        try await assertParseFailure(await network.exampleSequencedGET())
    }
    
    @Test func overridesCanMakeAPISucceed() async throws {
        await NetMock.shared.override("GET", NetworkAPI.exampleFailureAPI, response: "200")
        
        assertGetResponse(try await network.exampleGETFailure())
        assertGetResponse(try await network.exampleGETFailure())
    }
    
    @Test func overridesCanMakeNoInternet() async throws {
        await NetMock.shared.override("GET", NetworkAPI.exampleFailureAPI, response: "-1009")
        
        try await assertNoInternet(await network.exampleNoInternetAPI())
        try await assertNoInternet(await network.exampleNoInternetAPI())
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
    
    func assertGetResponse(_ response: ExampleGETResponse, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(response.name == "John Doe", sourceLocation: sourceLocation)
        #expect(response.id == 1, sourceLocation: sourceLocation)
    }
}
