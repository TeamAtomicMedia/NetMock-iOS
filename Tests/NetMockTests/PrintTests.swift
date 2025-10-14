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
    var header: NetMock.Document.Header { .init(method: .GET, urlString: "https://example.com", sequence: [.label("Test"), .code(200), .live]) }
    
    @Test
    func testHeaderPrint() {
        #expect("GET https://example.com Test 200 #Live" == header.description)
    }
}

@Suite
struct TestResponse {
    var header: NetMock.Document.Response.Header { .init(code: 200, labels: ["Test", "Success"]) }
    var response: NetMock.Document.Response { .init(header: header, body: "{\"key\": \"value\"}".data(using: .utf8)) }
    
    @Test
    func testHeaderPrint() {
        #expect("200 Test Success" == header.description)
    }
    
    @Test
    func testResponsePrint() {
        #expect("200 Test Success\n{\"key\": \"value\"}\n---" == response.description)
    }
}

@Suite struct TestDocument {
    var version: NetMock.Document.VersionNumber { .init(major: 1, minor: 0, patch: 0) }
    var header: NetMock.Document.Header { .init(method: .GET, urlString: "https://example.com", sequence: [.label("Test"), .code(200), .live]) }
    var response: NetMock.Document.Response {
        .init(
            header: .init(code: 200, labels: ["Test", "Success"]),
            body: "{\"key\": \"value\"}".data(using: .utf8)
        )
    }
    var document: NetMock.Document {
        .init(version: version, header: header, body: [response])
    }
    
    @Test
    func testDocumentPrint() {
        #expect("NetMock 1.0.0\nGET https://example.com Test 200 #Live\n\n200 Test Success\n{\"key\": \"value\"}\n---" == document.description)
    }
}
