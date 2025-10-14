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
        let validVersion1 = "NetMock 1.2"
        let validVersion2 = "NetMock 1.2.3"
        let invalidVersion1 = "NetMock 1.x"  // Invalid minor version 'x'
        let invalidVersion2 = "NetMoc 1.2.3" // Typo in 'NetMock'
        
        @Test func testValidVersion1() {
            let parser = NetMock.Document.VersionNumber.parser
            do {
                let result = try parser.complete().run(validVersion1)
                #expect(result == NetMock.Document.VersionNumber(major: 1, minor: 2, patch: nil))
            } catch {
                #expect(Bool(false), """
                    Parser failed with error: 
                    \(error)
                    """
                )
            }
        }
        
        @Test func testValidVersion2() {
            let parser = NetMock.Document.VersionNumber.parser
            do {
                let result = try parser.complete().run(validVersion2)
                #expect(result == NetMock.Document.VersionNumber(major: 1, minor: 2, patch: 3))
            } catch {
                #expect(Bool(false), """
                    Parser failed with error: 
                    \(error)
                    """
                )
            }
        }
        
        @Test func testInvalidVersion1() {
            let parser = NetMock.Document.VersionNumber.parser
            let result = try? parser.complete().run(invalidVersion1)
            #expect(result == nil, "Unexpectedly parsed invalid input: \(invalidVersion1)")
            
        }
        
        @Test func testInvalidVersion2() {
            let parser = NetMock.Document.VersionNumber.parser
            let result = try? parser.complete().run(invalidVersion2)
            #expect(result == nil, "Unexpectedly parsed invalid input: \(invalidVersion2)")
        }
    }

    @Suite("Header Parsing")
    struct HeaderParsing {
        @Test func testValidHeader1() {
            let parser = NetMock.Document.Header.parser
            var input: Substring = "GET https://example.com/test"[...]
            do {
                let result = try parser.complete().run(&input)
                #expect(result.method == .GET)
                #expect(result.urlString == "https://example.com/test")
                #expect(result.sequence.isEmpty == true)
            } catch {
                #expect(Bool(false), """
                    Parser failed with error: 
                    \(error)
                    """
                )
            }
        }
        
        @Test func testValidHeader2() {
            let parser = NetMock.Document.Header.parser
            var input: Substring = "GET https://example.com/test #Live"[...]
            do {
                let result = try parser.complete().run(&input)
                #expect(result.method == .GET)
                #expect(result.urlString == "https://example.com/test")
                #expect(result.sequence == [.live])
            } catch {
                #expect(Bool(false), """
                    Parser failed with error: 
                    \(error)
                    """
                )
            }
        }
        
        @Test func testValidHeader3() {
            let parser = NetMock.Document.Header.parser
            var input: Substring = "GET https://example.com/test 200"[...]
            do {
                let result = try parser.complete().run(&input)
                #expect(result.method == .GET)
                #expect(result.urlString == "https://example.com/test")
                #expect(result.sequence == [.code(200)])
            } catch {
                #expect(Bool(false), """
                    Parser failed with error: 
                    \(error)
                    """
                )
            }
        }
        
        @Test func testValidHeader4() {
            let parser = NetMock.Document.Header.parser
            var input: Substring = "GET https://example.com/test TEST"[...]
            do {
                let result = try parser.complete().run(&input)
                #expect(result.method == .GET)
                #expect(result.urlString == "https://example.com/test")
                #expect(result.sequence == [.label("TEST")])
            } catch {
                #expect(Bool(false), """
                    Parser failed with error: 
                    \(error)
                    """
                )
            }
        }
        
        @Test func testValidHeader5() {
            let parser = NetMock.Document.Header.parser
            var input: Substring = "GET https://example.com/test #Live 200 OK"[...]
            do {
                let result = try parser.complete().run(&input)
                #expect(result.method == .GET)
                #expect(result.urlString == "https://example.com/test")
                #expect(result.sequence == [.live, .code(200), .label("OK")])
            } catch {
                #expect(Bool(false), """
                    Parser failed with error: 
                    \(error)
                    """
                )
            }
        }
        
        @Test func testInvalidHeader1() {
            let parser = NetMock.Document.Header.parser
            var input: Substring = "GET"[...]
            let result = try? parser.complete().run(&input)
            #expect(result == nil, "Unexpectedly succeeded parsing: \(input)")
        }
        
        @Test func testInvalidHeader2() {
            let parser = NetMock.Document.Header.parser
            var input: Substring = "NEW https://shouldBreakOnMethodParse"[...]
            let result = try? parser.complete().run(&input)
            #expect(result == nil, "Unexpectedly succeeded parsing: \(input)")
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
            
            let result: NetMock.Document.Response
            do {
                result = try NetMock.Document.Response.parser.complete().run(&substring)
            } catch {
                #expect(Bool(false), """
                    Parser failed with error: 
                    \(error)
                    """
                )
                return
            }
            
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
            
            let result: NetMock.Document.Response
            do {
                result = try NetMock.Document.Response.parser.complete().run(&substring)
            } catch {
                #expect(Bool(false), """
                    Parser failed with error: 
                    \(error)
                    """
                )
                return
            }
            
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
            
            let result: NetMock.Document.Response
            do {
                result = try NetMock.Document.Response.parser.complete().run(&substring)
            } catch {
                #expect(Bool(false), """
                    Parser failed with error: 
                    \(error)
                    """
                )
                return
            }
            
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
            
            let result: NetMock.Document.Response
            do {
                result = try NetMock.Document.Response.parser.complete().run(&substring)
            } catch {
                #expect(Bool(false), """
                    Parser failed with error: 
                    \(error)
                    """
                )
                return
            }
            
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
            
            let result: NetMock.Document.Response
            do {
                result = try NetMock.Document.Response.parser.complete().run(&substring)
            } catch {
                #expect(Bool(false), """
                    Parser failed with error: 
                    \(error)
                    """
                )
                return
            }
            
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
            let result = try? NetMock.Document.Response.parser.complete().run(&substring)
            
            #expect(result?.header.code == 200)
            #expect(result?.header.labels == ["multiline"])
            let expected = """
                {
                  "id": 123,
                  "name": "Test"
                }
                """.data(using: .utf8)
            #expect(result?.body == expected, "Got: \(result?.body.flatMap { String(data: $0, encoding: .utf8) } ?? "<nil>")")
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
            var result: NetMock.Document
            do {
                result = try NetMock.Document.parser.complete().run(&substring)
            } catch {
                #expect(Bool(false),
                    """
                    Parser failed with error: 
                    \(error)
                    """
                )
                return
            }
            
            #expect(result.version?.major == 2)
            #expect(result.version?.minor == 5)
            #expect(result.version?.patch == 0)
            
            #expect(result.header.method == .GET)
            #expect(result.header.urlString == "https://this.is.a.test.com/hello/world")
            #expect(result.header.sequence == [.label("TEST1"), .label("TEST2"), .live, .code(200), .code(300)])
            
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
            var result: NetMock.Document
            do {
                result = try NetMock.Document.parser.complete().run(&substring)
            } catch {
                #expect(Bool(false),
                    """
                    Parser failed with error: 
                    \(error)
                    """
                )
                return
            }
            
            #expect(result.version == nil)
            
            #expect(result.header.method == .GET)
            #expect(result.header.urlString == "graphql://Notifications")
            #expect(result.header.sequence == [.code(200)])
            
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
            var result: NetMock.Document
            do {
                result = try NetMock.Document.parser.complete().run(&substring)
            } catch {
                #expect(Bool(false),
                    """
                    Parser failed with error:
                    \(error)
                    """
                )
                return
            }
            
            #expect(result.version == nil)
            
            #expect(result.header.method == .GET)
            #expect(result.header.urlString == "graphql://Notifications")
            #expect(result.header.sequence == [.code(200)])
            
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
    }
}
