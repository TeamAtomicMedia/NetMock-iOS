//  DocumentParserTests.swift
//  NetMock
//
//  Created by Christopher Wainwright on 26/09/2025.
//

import Testing
@testable import NetMock

@Suite
struct ParserTests {
    @Suite("Version Parsing")
    struct VersionParsing {
        @Test func testValidVersion1() throws {
            var input: Substring = "NetMock 1.2"
            let parser = NetMock.Document.VersionNumber.parser
            let result = try parser.complete().run(&input)
            #expect(result == NetMock.Document.VersionNumber(major: 1, minor: 2, patch: nil))
        }
        
        @Test func testValidVersion2() throws {
            var input: Substring = "NetMock 1.2.3"
            let parser = NetMock.Document.VersionNumber.parser
            let result = try parser.complete().run(&input)
            #expect(result == NetMock.Document.VersionNumber(major: 1, minor: 2, patch: 3))
        }
        
        @Test func testInvalidVersion1() {
            var input = "NetMock 1.x" // Invalid minor version 'x'
            let parser = NetMock.Document.VersionNumber.parser
            #expect(throws: ParseError.expectedNumber) {
                try parser.complete().run(&input)
            }
        }
        
        @Test func testInvalidVersion2() {
            var input: Substring = "NetMoc 1.2.3" // Typo in 'NetMock'
            let parser = NetMock.Document.VersionNumber.parser
            #expect(throws: ParseError.expectedToken(.one("NetMock"))) {
                try parser.complete().run(&input)
            }
        }
    }

    @Suite("Header Parsing")
    struct HeaderParsing {
        @Test func testValidHeader1() throws {
            let parser = NetMock.Request.parser
            var input: Substring = "GET https://example.com/test"[...]
            let result = try parser.complete().run(&input)
            #expect(result.method == .GET)
            #expect(result.url.absoluteString == "https://example.com/test")
        }
        
        @Test func testValidHeader2() throws {
            let parser = NetMock.Request.parser
            var input: Substring = "GET https://example.com/test"[...]
            let result = try parser.complete().run(&input)
            #expect(result.method == .GET)
            #expect(result.url.absoluteString == "https://example.com/test")
        }
        
        @Test func testValidHeader3() throws {
            let parser = NetMock.Request.parser
            var input: Substring = "GET https://example.com/test"[...]
            let result = try parser.complete().run(&input)
            #expect(result.method == .GET)
            #expect(result.url.absoluteString == "https://example.com/test")
        }
        
        @Test func testValidHeader4() throws {
            let parser = NetMock.Request.parser
            var input: Substring = "GET https://example.com/test"[...]
            let result = try parser.complete().run(&input)
            #expect(result.method == .GET)
            #expect(result.url.absoluteString == "https://example.com/test")
        }
        
        @Test func testValidHeader5() throws {
            let parser = NetMock.Request.parser
            var input: Substring = "GET https://example.com/test"[...]
            let result = try parser.complete().run(&input)
            #expect(result.method == .GET)
            #expect(result.url.absoluteString == "https://example.com/test")
        }
        
        @Test func testInvalidHeader1() throws {
            let parser = NetMock.Request.parser
            var input: Substring = "GET"[...]
            #expect(throws: ParseError.contextualError("Method", .expectedWhitespace)) {
                try parser.complete().run(&input)
            }
            #expect(input == "GET")
        }
        
        @Test func testInvalidHeader2() {
            let parser = NetMock.Request.parser
            var input: Substring = "NEW https://shouldBreakOnMethodParse"[...]
            
            #expect(throws: ParseError.contextualError("Method", .expectedToken(.oneOf(NetMock.Method.allCases.map(\.rawValue))))) {
                try parser.complete().run(&input)
            }
        }
    }
    
    @Suite("Sequence Parser")
    struct SequenceParsing {
        @Test func testEmpty() throws {
            var input: Substring = ""
            
            let result = try NetMock.Identifier.parser
                .sequence(separator: .whitespace(), allowEmpty: true)
                .run(&input)
            
            #expect(result == [])
            #expect(input == "")
        }
        
        @Test func testEmptyBlocked() throws {
            var input: Substring = ""
            
            #expect(throws: ParseError.expectedToken(.oneOf(["#Live", "number", "label"]))) {
                try NetMock.Identifier.parser
                    .sequence(separator: .whitespace(), allowEmpty: false)
                    .run(&input)
            }
            #expect(input == "")
        }
        
        @Test func testHelloWorldSequence() throws {
            var input: Substring = "Hello world"
            
            let result = try NetMock.Identifier.parser
                .sequence(separator: .whitespace())
                .run(&input)
            
            #expect(result == ["Hello", "world"])
            #expect(input == "")
        }
        
        @Test func testHelloWorldSequenceTrailingWhitespace() throws {
            var input: Substring = "Hello world  "
            
            let result = try NetMock.Identifier.parser
                .sequence(separator: .whitespace(), allowTrailingSeparator: true)
                .run(&input)
            
            #expect(result == ["Hello", "world"])
            #expect(input == "")
        }
        
        @Test func testHelloWorldSequenceTrailingWhitespaceDisallowed() throws {
            var input: Substring = "Hello world  "
            
            let result = try NetMock.Identifier.parser
                    .sequence(separator: .whitespace(), allowTrailingSeparator: false)
                    .run(&input)
            
            #expect(result == ["Hello", "world"])
            #expect(input == "  ")
        }
    }
    
    @Suite("Identifier Parsing")
    struct IdentifierParsing {
        @Suite("Singular")
        struct Singular {
            @Test func testLive() throws {
                var input: Substring = "#Live"
                
                let result = try NetMock.Identifier.parser.run(&input)
                
                #expect(result == .live)
            }
            
            @Test func testCode() throws {
                var input: Substring = "200"
                
                let result = try NetMock.Identifier.parser.run(&input)
                
                #expect(result == 200)
            }
            
            @Test func testLabel() throws {
                var input: Substring = "success"
                
                let result = try NetMock.Identifier.parser.run(&input)
                
                #expect(result == "success")
            }
        }
        
        @Suite("Multiple")
        struct Multiple {
            @Test func testCodeAndLabel() throws {
                var input: Substring = "200 success"
                
                let result = try NetMock.Identifier.parser.sequence(separator: .whitespace()).run(&input)
                
                #expect(result[0] == 200)
                #expect(result[1] == "success")
            }
            
            @Test func testCodeAndLive() async throws {
                var input: Substring = "200 #Live"
                
                let result = try NetMock.Identifier.parser.sequence(separator: .whitespace()).run(&input)
                
                #expect(result[0] == 200)
                #expect(result[1] == .live)
            }
            
            @Test func testLiveAndLabel() throws {
                var input: Substring = "#Live success"
                
                let result = try NetMock.Identifier.parser.sequence(separator: .whitespace()).run(&input)
                
                #expect(result[0] == .live)
                #expect(result[1] == "success")
            }
        }
    }
    
    @Suite("Body Parsing")
    struct BodyParsing {
        @Test func testStatusCodeOnly() throws {
            let input = """
            200
            ---
            """
            var substring: Substring = input[...]
            
            let result = try NetMock.Document.Response.parser.complete().run(&substring)

            #expect(result.header.code == 200)
            #expect(result.header.labels.isEmpty == true)
            #expect(result.body == nil, "Expected body to be nil (\(result.body.map{String(data: $0, encoding: .utf8)} ?? "<nil>"))")
        }
        
        @Test func testEmptyResponse() throws {
            let input = """
            204 noContent
            ---
            """
            var substring: Substring = input[...]
            
            let result = try NetMock.Document.Response.parser.complete().run(&substring)
            
            #expect(result.header.code == 204)
            #expect(result.header.labels == ["noContent"])
            #expect(result.body == nil)
        }
        
        @Test func testStatusCodeAndIdentifiers() throws {
            let input = """
            404 notFound specialCase
            ---
            """
            var substring: Substring = input[...]
            
            let result = try NetMock.Document.Response.parser.complete().run(&substring)
            
            #expect(result.header.code == 404)
            #expect(result.header.labels == ["notFound", "specialCase"])
            #expect(result.body == nil, "Expected body to be nil (\(result.body.map{String(data: $0, encoding: .utf8)} ?? "<nil>"))")
        }
        
        @Test func testJsonResponse() throws {
            let input = """
            200 jsonResponse
            { "message": "Hello, world!" }
            ---
            """
            var substring: Substring = input[...]
            
            let result = try NetMock.Document.Response.parser.complete().run(&substring)
            
            #expect(result.header.code == 200)
            #expect(result.header.labels == ["jsonResponse"])
            #expect(result.body == "{ \"message\": \"Hello, world!\" }".data(using: .utf8),
                    "Body contained: '\(result.body.flatMap { String(data: $0, encoding: .utf8) } ?? "<nil>")'")
        }
        
        @Test func testBinaryResponse() throws {
            let input = """
            200 bin
            \u{00}\u{01}\u{02}\u{FF}
            ---
            """
            var substring: Substring = input[...]
            
            let result = try NetMock.Document.Response.parser.complete().run(&substring)
            
            #expect(result.header.code == 200)
            #expect(result.header.labels == ["bin"])
            #expect(result.body == "\u{00}\u{01}\u{02}\u{FF}".data(using: .utf8),
                    "Body contained: '\(result.body.flatMap { String(data: $0, encoding: .utf8) } ?? "<nil>")'")
        }
        
        @Test func testBodyWithMultipleLines() throws {
            let input = """
                200 multiline
                {
                  "id": 123,
                  "name": "Test"
                }
                ---
                """
            var substring: Substring = input[...]
            let result = try NetMock.Document.Response.parser.complete().run(&substring)
            
            #expect(result.header.code == 200)
            #expect(result.header.labels == ["multiline"])
            let expected = """
                {
                  "id": 123,
                  "name": "Test"
                }
                """.data(using: .utf8)
            #expect(result.body == expected, "Got: \(result.body.flatMap { String(data: $0, encoding: .utf8) } ?? "<nil>")")
        }
        
        @Test func testResponseWithoutBodyOrLabels() throws {
            let input = """
                500
                ---
                """
            var substring: Substring = input[...]
            let result = try? NetMock.Document.Response.parser.complete().run(&substring)
            
            #expect(result?.header.code == 500)
            #expect(result?.header.labels.isEmpty == true)
            #expect(result?.body == nil)
        }
        
        @Test func testResponseWithLabelButNoBody() throws {
            let input = """
                301 redirect
                ---
                """
            var substring: Substring = input[...]
            let result = try? NetMock.Document.Response.parser.complete().run(&substring)
            
            #expect(result?.header.code == 301)
            #expect(result?.header.labels == ["redirect"])
            #expect(result?.body == nil)
        }
        
        @Test func testResponseWithTerminatorButNoNewline() throws {
            let input = """
                200 simple
                ---
                """
            var substring: Substring = input[...]
            let result = try? NetMock.Document.Response.parser.complete().run(&substring)
            
            #expect(result?.header.code == 200)
            #expect(result?.header.labels == ["simple"])
            #expect(result?.body == nil)
        }
        
        @Test func testResponseBodyContainingTerminator() throws {
            let input = """
                200 success
                {
                    "id": "test",
                    "separators": "---"
                }
                ---
                """
            var substring: Substring = input[...]
            let result = try? NetMock.Document.Response.parser.complete().run(&substring)
            
            #expect(result?.header.code == 200)
            #expect(result?.header.labels == ["success"])
            #expect(result?.body != nil)
        }
    }
    
    @Suite("NetMock Files")
    struct NetMockFiles {
        @Test func testValidFile() async throws {
            let input = """
                NetMock 2.5.0
                GET https://this.is.a.test.com/hello/world TEST1 TEST2 #Live 200 300
                
                200 simple
                ---
                500
                ---
                200 multiline
                {
                  "id": 123,
                  "name": "Test"
                }
                ---
                404 notFound specialCase
                ---
                """
            var substring: Substring = input[...]
            let result = try NetMock.Document.parser.complete().run(&substring)
            
            #expect(result.version?.major == 2)
            #expect(result.version?.minor == 5)
            #expect(result.version?.patch == 0)
            
            #expect(result.header.method == .GET)
            #expect(result.header.url.absoluteString == "https://this.is.a.test.com/hello/world")
            
            guard result.body.count == 4
            else {#expect(Bool(false), "Result body count is not 4, got \(result.body.count)"); return}
            
            #expect(result.body[0].header.code == 200)
            #expect(result.body[0].header.labels == ["simple"])
            #expect(result.body[0].body == nil)
            
            #expect(result.body[1].header.code == 500)
            #expect(result.body[1].header.labels == [])
            #expect(result.body[1].body == nil)
            
            #expect(result.body[2].header.code == 200)
            #expect(result.body[2].header.labels == ["multiline"])
            #expect(result.body[2].body == """
                {
                  "id": 123,
                  "name": "Test"
                }
                """.data(using: .utf8)
                )
            #expect(result.body[3].header.code == 404)
            #expect(result.body[3].header.labels == ["notFound", "specialCase"])
            #expect(result.body[3].body == nil)
        }
        
        @Test func testRealWorldFile() async throws {
            let input = """
                GET graphql://Notifications 200

                200 2025-10-01T12:51:05Z
                {
                  "data" : {
                    "notificationsForUser" : [

                    ]
                  }
                }
                ---
                """
            var substring: Substring = input[...]
            let result = try NetMock.Document.parser.complete().run(&substring)
            
            #expect(result.version == nil)
            
            #expect(result.header.method == .GET)
            #expect(result.header.url.absoluteString == "graphql://Notifications")
            
            guard result.body.count == 1
            else {#expect(Bool(false), "Result body count is not 1, got \(result.body.count)"); return}
            
            #expect(result.body[0].header.code == 200)
            #expect(result.body[0].header.labels == ["2025-10-01T12:51:05Z"])
            #expect(result.body[0].body == """
                    {
                      "data" : {
                        "notificationsForUser" : [

                        ]
                      }
                    }
                    """.data(using: .utf8)
            )
        }
        
        @Test func testMissingTrailingTerminator() async throws {
            let input = """
                GET graphql://Notifications 200

                200 2025-10-01T12:51:05Z
                {
                  "data": "test"
                }
                """
            var substring: Substring = input[...]
            var result = try NetMock.Document.parser.complete().run(&substring)
            
            #expect(result.version == nil)
            
            #expect(result.header.method == .GET)
            #expect(result.header.url.absoluteString == "graphql://Notifications")
            
            guard result.body.count == 1
            else {#expect(Bool(false), "Result body count is not 1, got \(result.body.count)"); return}
            
            #expect(result.body[0].header.code == 200)
            #expect(result.body[0].header.labels == ["2025-10-01T12:51:05Z"])
            #expect(result.body[0].body == """
                    {
                      "data": "test"
                    }
                    """.data(using: .utf8)
            )
        }
        
        @Test func testTrailingWhitespaceFile() async throws {
            let input = """
                NetMock 2.5.0       
                GET https://this.is.a.test.com/hello/world TEST1 TEST2 #Live 200 300        
                
                200 simple
                ---
                500   
                ---
                200 multiline
                {
                  "id": 123,
                  "name": "Test"
                }
                ---
                404 notFound specialCase   
                ---   
                """
            var substring: Substring = input[...]
            let result = try NetMock.Document.parser.complete().run(&substring)
            
            #expect(result.version?.major == 2)
            #expect(result.version?.minor == 5)
            #expect(result.version?.patch == 0)
            
            #expect(result.header.method == .GET)
            #expect(result.header.url.absoluteString == "https://this.is.a.test.com/hello/world")
            
            guard result.body.count == 4
            else {#expect(Bool(false), "Result body count is not 4, got \(result.body.count)"); return}
            
            #expect(result.body[0].header.code == 200)
            #expect(result.body[0].header.labels == ["simple"])
            #expect(result.body[0].body == nil)
            
            #expect(result.body[1].header.code == 500)
            #expect(result.body[1].header.labels == [])
            #expect(result.body[1].body == nil)
            
            #expect(result.body[2].header.code == 200)
            #expect(result.body[2].header.labels == ["multiline"])
            #expect(result.body[2].body == """
                {
                  "id": 123,
                  "name": "Test"
                }
                """.data(using: .utf8)
                )
            #expect(result.body[3].header.code == 404)
            #expect(result.body[3].header.labels == ["notFound", "specialCase"])
            #expect(result.body[3].body == nil)
        }
    }
}
