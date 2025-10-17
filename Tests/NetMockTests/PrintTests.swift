//
//  PrintTests.swift
//  NetMock
//
//  Created by Christopher Wainwright on 14/10/2025.
//

import Foundation
import Testing

@testable import NetMock

@Suite
struct PrintingTests {
    @Suite
    struct TestVersionNumber {
        var versionNumberLong: NetMock.Document.VersionNumber { .init(major: 10, minor: 10, patch: 10) }
        var versionNumberAbbreviated: NetMock.Document.VersionNumber { .init(major: 10, minor: 10, patch: nil) }
        
        @Test
        func testVersionPrintLong() {
            #expect("NetMock 10.10.10" == versionNumberLong.description)
        }
        
        @Test
        func testVersionPrintAbbreviated() {
            #expect("NetMock 10.10" == versionNumberAbbreviated.description)
        }
    }
    
    @Suite
    struct TestHeader {
        var header: NetMock.Request { .init(method: .GET, url: URL(string: "https://example.com")!) }
        
        @Test
        func testHeaderPrint() {
            #expect("GET https://example.com" == header.description)
        }
    }
    
    @Suite
    struct TestSequence {
        var sequence: [NetMock.Identifier] = ["Test", 200, .live]
        
        @Test
        func testSequencePrint() {
            #expect("Test 200 #Live" == sequence.map(\.description).joined(separator: " "))
        }
    }
    
    @Suite
    struct TestResponse {
        var header: NetMock.Document.Response.Header { .init(code: 200, labels: ["Test", "Success"]) }
        var response1: NetMock.Document.Response { .init(header: header, body: "TEST BODY".data(using: .utf8)) }
        var response2Body = try! JSONSerialization.data(withJSONObject: ["key": "value"], options: [.prettyPrinted])
        var response2: NetMock.Document.Response { .init(header: header, body: response2Body) }
        var response3: NetMock.Document.Response { .init(header: header, body: nil) }
        
        @Test
        func testHeaderPrint() {
            #expect(header.description == "200 Test Success")
        }
        
        @Test
        func testResponse1Print() {
            #expect(response1.description == "200 Test Success\nTEST BODY\n---")
        }
        
        @Test
        func testResponse2Print() {
            #expect(response2.description == """
        200 Test Success
        {
          "key" : "value"
        }
        ---
        """)
        }
        
        @Test
        func testResponse3Print() {
            #expect(response3.description == "200 Test Success\n---")
        }
    }
    
    @Suite struct TestDocument {
        var version: NetMock.Document.VersionNumber { .init(major: 1, minor: 0, patch: 0) }
        var header: NetMock.Request { .init(method: .GET, url: URL(string: "https://example.com")!) }
        let sequence: [NetMock.Identifier] = ["Test", 200, .live]
        var responses: [NetMock.Document.Response] {
            [
                .init(
                    header: .init(code: 200, labels: ["Test", "Success"]),
                    body: "{\"key\": \"value\"}".data(using: .utf8)
                ),
                .init(
                    header: .init(code: 500, labels: ["Error"]),
                    body: "The Server Crashed!".data(using: .utf8)
                ),
                .init(
                    header: .init(code: 404, labels: ["NotFound"]),
                    body: nil
                )
            ]
        }
        var document: NetMock.Document {
            .init(version: version, header: header, sequence: sequence, body: responses)
        }
        
        @Test
        func testDocumentPrint() {
            #expect(document.description == """
        NetMock 1.0.0
        GET https://example.com Test 200 #Live
        
        200 Test Success
        {
          "key" : "value"
        }
        ---
        500 Error
        The Server Crashed!
        ---
        404 NotFound
        ---
        """)
        }
    }
}
