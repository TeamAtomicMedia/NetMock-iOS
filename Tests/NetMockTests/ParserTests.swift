//
//  File.swift
//  NetMock
//
//  Created by Christopher Wainwright on 14/10/2025.
//

import Foundation
import Testing

@testable
import NetMock

extension Parser {
    func test(tests: [String]) {
        for test in tests {
            var testSubStr = test[...]
            do {
                let result = try self.run(&testSubStr)
                print("\(test) -> \(result)")
            } catch {
                print("\(test) -> \(error)")
            }
            print("Remaining: '\(testSubStr)'")
        }
    }
}

@Suite
struct CommonParsers {
    @Suite
    struct ResultParser {
        @Test
        func testString() {
            var input: Substring = "abc"
            let parser: Parser<String> = .result("hello")
            let result = try? parser.run(&input)
            #expect(result == "hello")
            #expect(input == "abc")
        }
        
        @Test
        func testInteger() {
            var input: Substring = "abc"
            let parser: Parser<Int> = .result(420)
            let result = try? parser.run(&input)
            #expect(result == 420)
            #expect(input == "abc")
        }
        
        @Test
        func emptyInputResultParser() {
            var input: Substring = ""
            let parser: Parser<String> = .result("hello")
            let result = try? parser.run(&input)
            #expect(result == "hello")
            #expect(input.isEmpty)
        }
    }
    
    @Suite
    struct ErrorParser {
        @Test
        func testThrows () {
            var input: Substring = "abc"
            let parser: Parser<String> = .error(.expectedNumber)
            #expect(throws: ParseError.expectedNumber) {
                try parser.run(&input)
            }
            #expect(input == "abc")
        }
        
        @Test
        func testEmptyInputThrows() {
            var input: Substring = ""
            let parser: Parser<String> = .error(.expectedNumber)
            #expect(throws: ParseError.expectedNumber) {
                try parser.run(&input)
            }
            #expect(input.isEmpty)
        }
    }
    
    @Suite
    struct CharacterParser {
        @Test
        func testSuccess() {
            var input: Substring = "abc"
            let parser: Parser<Character> = .character("a")
            let result = try? parser.run(&input)
            #expect(result == "a")
            #expect(input == "bc")
        }
        
        @Test
        func testFailure() {
            var input: Substring = "abc"
            let parser: Parser<Character> = .character("x")
            #expect(throws: ParseError.expectedCharacter("x")) {
                try parser.run(&input)
            }
            #expect(input == "abc")
        }
    }
    
    @Suite
    struct TokenParser {
        @Test
        func testSuccess() {
            var input: Substring = "hello world"
            let parser: Parser<String> = .token("hello")
            let result = try? parser.run(&input)
            #expect(result == "hello")
            #expect(input == " world")
        }
        
        @Test
        func testFailure() {
            var input: Substring = "hey"
            let parser: Parser<String> = .token("hello")
            #expect(throws: ParseError.expectedToken(.one("hello"))) {
                try parser.run(&input)
            }
            #expect(input == "hey")
        }
    }
    
    @Suite
    struct PredicateParser {
        @Test
        func testConsumesWhileTrue() {
            var input: Substring = "abc123"
            let parser: Parser<String> = .predicate(where: \.isLetter)
            let result = try? parser.run(&input)
            #expect(result == "abc")
            #expect(input == "123")
        }
        
        @Test
        func testFailsWhenNoMatch() {
            var input: Substring = "123"
            let parser: Parser<String> = .predicate(where: \.isLetter)
            #expect(throws: ParseError.expectedCharactersSatisfyingPredicate) {
                try parser.run(&input)
            }
            #expect(input == "123")
        }
        
        @Test
        func testAllowEmptySucceeds() {
            var input: Substring = "123"
            let parser: Parser<String> = .predicate(allowEmpty: true, where: \.isLetter)
            let result = try? parser.run(&input)
            #expect(result?.isEmpty ?? false)
            #expect(input == "123")
        }
    }
    
    @Suite
    struct UntilParser {
        
        
        @Test
        func testStopsBeforeTerminator() {
            var input: Substring = "abc;def"
            let parser: Parser<String> = .until(terminator: .character(";"))
            let result = try? parser.run(&input)
            #expect(result == "abc")
            #expect(input == ";def")
        }
        
        @Test
        func testConsumesTerminatorWhenConfigured() {
            var input: Substring = "abc;def"
            let parser: Parser<String> = .until(
                terminator: .character(";"),
                consumeTerminator: true
            )
            let result = try? parser.run(&input)
            #expect(result == "abc")
            #expect(input == "def")
        }
        
        @Test
        func testFailsWithoutTerminator() {
            var input: Substring = "abc"
            let parser: Parser<String> = .until(terminator: .character(";"))
            #expect(throws: ParseError.expectedTerminationSequence) {
                try parser.run(&input)
            }
        }
        
        @Test
        func testAllowsEOFWhenConfigured() {
            var input: Substring = "abc"
            let parser: Parser<String> = .until(
                terminator: .character(";"),
                allowEOF: true
            )
            let result = try? parser.run(&input)
            #expect(result == "abc")
            #expect(input.isEmpty)
        }
    }
    
    @Suite
    struct NumberParser {
        var parser: Parser<Int> { .number() }
        
        @Test
        func testSuccess() {
            var input: Substring = "123abc"
            let result = try? parser.run(&input)
            #expect(result == 123)
            #expect(input == "abc")
        }
        
        @Test
        func testFailsOnNonDigit() {
            var input: Substring = "abc"
            #expect(throws: ParseError.expectedNumber) {
                try parser.run(&input)
            }
            #expect(input == "abc")
        }
        
        @Test
        func testAllowsEmptyInput() {
            var input: Substring = ""
            #expect(throws: ParseError.expectedNumber) {
                try parser.run(&input)
            }
            #expect(input.isEmpty)
        }
    }
    
    @Suite
    struct EnumParser {
        enum Kind: String, CaseIterable { case foo, bar }
        
        @Test
        func testRawValueSuccess() {
            var input: Substring = "foo123"
            let parser: Parser<Kind> = .rawRepr(.foo)
            let result = try? parser.run(&input)
            #expect(result == .foo)
            #expect(input == "123")
        }
        
        @Test
        func testEnumerationMatchesAnyCase() {
            var input: Substring = "bar!"
            let parser: Parser<Kind> = .enumeration()
            let result = try? parser.run(&input)
            #expect(result == .bar)
            #expect(input == "!")
        }
        
        @Test
        func testEnumerationParserThrowsForUnknown() {
            var input: Substring = "baz"
            #expect(throws: ParseError.expectedToken(.oneOf(["foo", "bar"]))) {
                try Parser<Kind>.enumeration().run(&input)
            }
            #expect(input == "baz")
        }
    }
    
    
    @Suite
    struct WhitespaceParser {
        var parser: Parser<String> { .whitespace() }
        
        @Test
        func testConsumesSpaces() {
            var input: Substring = "   abc"
            _ = try? parser.run(&input)
            #expect(input == "abc")
        }
        
        @Test
        func testThrowsWhenNoSpaces() {
            var input: Substring = "abc"
            #expect(throws: ParseError.expectedWhitespace) {
                try parser.run(&input)
            }
            #expect(input == "abc")
        }
    }
     
    @Suite
    struct OptionalWhitespaceParser {
        var parser: Parser<String?> { .optionalWhitespace() }
        
        @Test
        func testConsumesSpaces() {
            var input: Substring = "   abc"
            _ = try? parser.run(&input)
            #expect(input == "abc")
        }
        
        @Test
        func testDoesNotThrowWhenNoSpaces() {
            var input: Substring = "abc"
            _ = try? parser.run(&input)
            #expect(input == "abc")
        }
    }
    
    @Suite
    struct SpaceParser {
        var parser: Parser<String> { .space() }

        @Test
        func testConsumesSingleSpace() throws {
            var input: Substring = " abc"
            let result = try parser.run(&input)
            #expect(result == " ")
            #expect(input == "abc")
        }

        @Test
        func testConsumesMultipleSpaces() throws {
            var input: Substring = "    abc"
            let result = try parser.run(&input)
            #expect(result == "    ")
            #expect(input == "abc")
        }

        @Test
        func testStopsBeforeNewline() throws {
            var input: Substring = " \nabc"
            let result = try parser.run(&input)
            #expect(result == " ")
            #expect(input == "\nabc")
        }

        @Test
        func testTabsAreConsideredSpaces() throws {
            var input: Substring = "\t\tabc"
            let result = try parser.run(&input)
            #expect(result == "\t\t")
            #expect(input == "abc")
        }

        @Test
        func testNoSpacesDoesNotConsumeAnything() {
            var input: Substring = "abc"
            let result = try? parser.run(&input)
            #expect(result == nil)
            #expect(input == "abc")
        }

        @Test
        func testEmptyInputThrows() {
            var input: Substring = ""
            #expect(throws: Error.self) {
                _ = try parser.run(&input)
            }
        }
    }
    
    @Suite
    struct NewlineParser {
        var parser: Parser<String> { .newline() }

        @Test
        func testConsumesSingleNewline() throws {
            var input: Substring = "\nabc"
            let result = try parser.run(&input)
            #expect(result == "\n")
            #expect(input == "abc")
        }

        @Test
        func testConsumesSpacesThenNewline() throws {
            var input: Substring = "   \nabc"
            let result = try parser.run(&input)
            #expect(result == "   \n")
            #expect(input == "abc")
        }

        @Test
        func testNoNewlineThrows() {
            var input: Substring = "   abc"
            #expect(throws: Error.self) {
                _ = try parser.run(&input)
            }
            #expect(input == "   abc")
        }

        @Test
        func testEmptyInputThrows() {
            var input: Substring = ""
            #expect(throws: Error.self) {
                _ = try parser.run(&input)
            }
        }
    }
}

@Suite
struct ParserModifiers {
    @Suite
    struct Atomic {
        var parser: Parser<(Character, Int)> { .init { input in
            let parser1: Parser = .character("a")
            let parser2: Parser = .number()
            
            let result1 = try parser1.run(&input)
            let result2 = try parser2.run(&input)
            
            return (result1, result2)
        } }
        
        @Test
        func testDestructiveParser() {
            var input: Substring = "abc"
            let result = try? parser.run(&input)
            #expect(result == nil)
            // Note that without usage of .atomic(), input is partially consumed
            #expect(input == "bc")
        }
        
        @Test
        func testSuccessConsumesInput() {
            var input: Substring = "a1c"
            guard let result = try? parser.atomic().run(&input)
            else { #expect(Bool(false)); return }
            #expect(result == ("a", 1))
            #expect(input == "c")
        }
        
        @Test
        func testFailureRestoresInput() {
            var input: Substring = "abc"
            let result = try? parser.atomic().run(&input)
            #expect(result == nil)
            #expect(input == "abc")
        }
        
        @Test
        func testSuccessDoesNotRollback() {
            var input: Substring = "abc"
            let parser: Parser = .character("a").atomic()
            let result = try! parser.run(&input)
            #expect(result == "a")
            #expect(input == "bc")
        }
        
        @Test
        func testFailureRollsBack() {
            var input: Substring = "abc"
            let parser: Parser = .character("z").atomic()
            let result = try? parser.run(&input)
            #expect(result == nil)
            #expect(input == "abc")
        }
        
        @Test
        func testNonConsumingAtomic() {
            var input: Substring = "abc"
            let parser: Parser = .result("res").atomic()
            let result = try? parser.run(&input)
            #expect(result == "res")
            #expect(input == "abc")
        }
        
        @Test
        func testNestedAtomicRestoresInput() {
            var input: Substring = "abc"
            let inner: Parser = .character("a").atomic()
            let outer: Parser = (inner *> .character("z")).atomic()
            let result = try? outer.run(&input)
            #expect(result == nil)
            #expect(input == "abc")
        }
        
        @Test
        func testEOFRestoresInput() {
            var input: Substring = "a"
            let result = try? parser.atomic().run(&input)
            #expect(result == nil)
            #expect(input == "a")
        }
        
        @Test
        func testEmptyInput() {
            var input: Substring = ""
            let result = try? parser.atomic().run(&input)
            #expect(result == nil)
            #expect(input.isEmpty)
        }
    }
    
    @Suite
    struct Optional {
        @Test
        func testSuccessReturnsValue() {
            var input: Substring = "a"
            let parser: Parser = .character("a").optional()
            let result = try! parser.run(&input)
            #expect(result == "a")
            #expect(input.isEmpty)
        }
        
        @Test
        func testFailureReturnsNilAndRestoresInput() {
            var input: Substring = "b"
            let parser: Parser = .character("a").optional()
            let result = try! parser.run(&input)
            #expect(result == nil)
            #expect(input == "b")
        }
        
        @Test
        func testSuccessConsumesInput() {
            var input: Substring = "420"
            let parser: Parser = .number().optional()
            let result = try! parser.run(&input)
            #expect(result == 420)
            #expect(input.isEmpty)
        }
        
        @Test
        func testFailureRestoresInput() {
            var input: Substring = "abc"
            let parser: Parser = .number().optional()
            let result = try! parser.run(&input)
            #expect(result == nil)
            #expect(input == "abc")
        }
        
        @Test
        func testDefaultSuccessReturnsParsedValue() {
            var input: Substring = "42"
            let parser: Parser = .number().optional(defaultValue: 99)
            let result = try! parser.run(&input)
            #expect(result == 42)
            #expect(input.isEmpty)
        }
        
        @Test
        func testDefaultFailureReturnsDefault() {
            var input: Substring = "abc"
            let parser: Parser = .number().optional(defaultValue: 99)
            let result = try! parser.run(&input)
            #expect(result == 99)
            #expect(input == "abc")
        }
        
        @Test
        func testDefaultFailureDoesNotConsumeInput() {
            var input: Substring = "abc"
            let parser: Parser = .character("z").optional(defaultValue: "x")
            let result = try! parser.run(&input)
            #expect(result == "x")
            #expect(input == "abc")
        }
        
        @Test
        func testDefaultEmptyInput() {
            var input: Substring = ""
            let parser: Parser = .number().optional(defaultValue: 420)
            let result = try! parser.run(&input)
            #expect(result == 420)
            #expect(input.isEmpty)
        }
    }
    
    @Suite
    struct Discard {
        @Test
        func testDiscardConsumesInputOnSuccess() {
            var input: Substring = "abc"
            let parser: Parser = .character("a").discard()
            try! parser.run(&input)
            #expect(input == "bc")
        }
        
        @Test
        func testDiscardLeavesInputOnFailure() {
            var input: Substring = "abc"
            let parser: Parser = .character("z").discard()
            try? parser.run(&input)
            #expect(input == "abc")
        }
        
        @Test
        func testDiscardReturnsVoid() {
            var input: Substring = "123"
            let parser: Parser = .number().discard()
            let result: Void? = try? parser.run(&input)
            #expect(result != nil)
            #expect(input.isEmpty)
        }
        
        @Test
        func testDiscardFailureDoesNotConsumeInput() {
            var input: Substring = "abc"
            let parser: Parser = .number().discard()
            try? parser.run(&input)
            #expect(input == "abc")
        }
        
        @Test
        func testDiscardOnEmptyInputFails() {
            var input: Substring = ""
            let parser: Parser = .character("a").discard()
            let result: Void? = try? parser.run(&input)
            #expect(result != nil)
            #expect(input.isEmpty)
        }
    }
    
    @Suite
    struct Sequence {
        @Test
        func testSingleElement() {
            var input: Substring = "a"
            let parser: Parser = .character("a").sequence()
            let result = try? parser.run(&input)
            #expect(result == ["a"])
            #expect(input.isEmpty)
        }
        
        @Test
        func testMultipleElements() {
            var input: Substring = "a, a, a"
            let parser: Parser = .character("a").sequence()
            let result = try? parser.run(&input)
            #expect(result == ["a", "a", "a"])
            #expect(input.isEmpty)
        }
        
        @Test
        func testEmptyAllowed() {
            var input: Substring = ""
            let parser: Parser = .character("a").sequence(allowEmpty: true)
            let result = try! parser.run(&input)
            #expect(result.isEmpty)
            #expect(input.isEmpty)
        }
        
        @Test
        func testEmptyDisallowed() {
            var input: Substring = ""
            let parser: Parser = .character("a").sequence(allowEmpty: false)
            let result = try? parser.run(&input)
            #expect(result == nil)
            #expect(input.isEmpty)
        }
        
        @Test
        func testTrailingSeparatorAllowed() {
            var input: Substring = "a, a, "
            let parser: Parser = .character("a").sequence(allowTrailingSeparator: true)
            let result = try! parser.run(&input)
            #expect(result == ["a", "a"])
            #expect(input.isEmpty)
        }
        
        @Test
        func testTrailingSeparatorDisallowed() {
            var input: Substring = "a, a, "
            let parser: Parser = .character("a").sequence(allowTrailingSeparator: false)
            let result = try? parser.run(&input)
            #expect(result == ["a", "a"])
            #expect(input == ", ")
        }
        
        @Test
        func testCustomSeparator() {
            var input: Substring = "a|a|a"
            let separator: Parser = .character("|").discard()
            let parser: Parser = .character("a").sequence(separator: separator)
            let result = try! parser.run(&input)
            #expect(result == ["a", "a", "a"])
            #expect(input.isEmpty)
        }
        
        @Test
        func testStopsOnUnexpectedInput() {
            var input: Substring = "a, a, b"
            let parser: Parser = .character("a").sequence()
            let result = try! parser.run(&input)
            #expect(result == ["a", "a"])
            #expect(input == "b")
        }
    }
    
    @Suite
    struct Context {
        @Test
        func testSuccessPassthrough() {
            let parser: Parser = .result(42).context("should never appear")
            let result = try? parser.run("")
            #expect(result == 42)
        }
        
        @Test
        func testFailureWrapsError() {
            let parser: Parser<Void> = .error(.expectedNumber).context("Context Label")
            #expect(throws: ParseError.contextualError("Context Label", .expectedNumber)) {
                try parser.run("")
            }
        }
        
        @Test
        func testNestedContextError() {
            let parser: Parser<Void> = .error(.expectedNumber).context("Inner Context").context("Outer Context")
            #expect(throws: ParseError.contextualError("Outer Context", .contextualError("Inner Context", .expectedNumber))) {
                try parser.run("")
            }
        }
    }
    
    @Suite
    struct Complete {
        var parser: Parser<Int> { .number().complete() }
        
        @Test
        func testSuccess() {
            var input: Substring = "42"
            let result = try? parser.run(&input)
            #expect(result == 42)
            #expect(input.isEmpty)
        }
        
        @Test
        func testFailure() {
            var input: Substring = "42a"
            let result = try? parser.run(&input)
            #expect(result == nil)
            #expect(input == "a")
        }
        
        @Test
        func testFailureWithWhitespace() {
            var input: Substring = "42 "
            let result = try? parser.run(&input)
            #expect(result == nil)
            #expect(input == " ")
        }
    }
}

@Suite
struct MonadicOperators {
    @Suite("Functor (map)")
    struct Functor {
        @Test
        func testMapSuccess() {
            let parser: Parser<Int> = .number()
            let transformedParser: Parser<Int> = parser.map {$0 + 1}
            
            let result = try? transformedParser.run("42")
            #expect(result == 43)
        }
        
        @Test
        func testMapFailure() {
            let parser: Parser<Int> = .number()
            let transformedParser: Parser<Int> = parser.map {$0 + 1}
            
            let result = try? transformedParser.run("A24")
            #expect(result == nil)
        }
        
        @Test
        func testMapFailurePropagation() {
            let parser: Parser<Int> = .number()
            let transformedParser: Parser<Int> = parser.map {$0 + 1}
            
            #expect(throws: ParseError.expectedNumber) {
                try transformedParser.run("A24")
            }
        }
    }
    
    @Suite("Alternative (<|>)")
    struct Alternative {
        enum Cases: Equatable { case i(Int), c(Character) }
        
        var parser1: Parser<Cases> { .number().map {.i($0)} }
        var parser2: Parser<Cases> { .character("X").map {.c($0)} }
        var transformedParser: Parser<Cases> { parser1 <|> parser2 }
        
        @Test
        func testLeftSuccess() {
            let result = try? transformedParser.run("42")
            #expect(result == .i(42))
        }
        
        @Test
        func testRightSuccess() {
            let result = try? transformedParser.run("X")
            #expect(result == .c("X"))
        }
        
        @Test
        func testFailure() {
            let result = try? transformedParser.run("Z")
            #expect(result == nil)
        }
        
        @Test
        func testFailuresPropagate() {
            #expect(throws: ParseError.eitherError(.expectedNumber, .expectedCharacter("X"))) {
                try transformedParser.run("Z")
            }
        }
    }
    
    @Suite("Monad (>>=)")
    struct Monad {
        var parser1: Parser<Int> { .number() }
        func parser2(count: Int) -> Parser<String> { .token(.init(repeating: "a", count: count)) }
        var transformedParser: Parser<String> { parser1.bind(to: parser2) }
        
        @Test
        func testBind() {
            var input: Substring = "3aaa"
            let result = try? transformedParser.run(&input)
            #expect(result == "aaa")
            #expect(input.isEmpty)
        }
        
        @Test
        func testBindWithTrailing() {
            var input: Substring = "3aaaaa"
            let result = try? transformedParser.run(&input)
            #expect(result == "aaa")
            #expect(input == "aa")
        }
        
        @Test
        func testBindFailure() {
            #expect(throws: ParseError.expectedNumber) {
                try transformedParser.run("aaa")
            }
        }
        
        @Test
        func testBoundParserFailure() {
            #expect(throws: ParseError.expectedToken(.one("aaaa"))) {
                try transformedParser.run("4")
            }
        }
    }
    
    @Suite("BindLeft (*>)")
    struct BindLeft {
        var parser1: Parser<String> { .whitespace() }
        var parser2: Parser<Int> { .number() }
        var transformedParser: Parser<Int> { parser1 *> parser2 }
        
        @Test
        func testBindLeft() {
            var input: Substring = " 42"
            let result = try? transformedParser.run(&input)
            #expect(result == 42)
            #expect(input.isEmpty)
        }
        
        @Test
        func testBindLeftFailure1() {
            #expect(throws: ParseError.expectedWhitespace) {
                try transformedParser.run("42")
            }
        }
        
        @Test
        func testBindLeftFailure2() {
            #expect(throws: ParseError.expectedNumber) {
                try transformedParser.run("  ")
            }
        }
    }
    
    @Suite("BindRight (<*)")
    struct BindRight {
        var parser1: Parser<Int> { .number() }
        var parser2: Parser<String> { .whitespace() }
        var transformedParser: Parser<Int> { parser1 <* parser2 }
        
        @Test
        func testBindRight() {
            var input: Substring = "42 "
            let result = try? transformedParser.run(&input)
            #expect(result == 42)
            #expect(input.isEmpty)
        }
        
        @Test
        func testBindRightFailure1() {
            #expect(throws: ParseError.expectedNumber) {
                try transformedParser.run(" ")
            }
        }
        
        @Test
        func testBindRightFailure2() {
            #expect(throws: ParseError.expectedWhitespace) {
                try transformedParser.run("42")
            }
//  ParserTests.swift
//  NetMock
//
//  Created by Christopher Wainwright on 26/09/2025.
//

import Testing
@testable import NetMock

@Suite(.serialized)
struct ParserTests {
    @Suite("Version Parsing")
    struct VersionParsing {
        let validVersion1 = "NetMock 1.2"
        let validVersion2 = "NetMock 1.2.3"
        let invalidVersion1 = "NetMock 1.x"  // Invalid minor version 'x'
        let invalidVersion2 = "NetMoc 1.2.3" // Typo in 'NetMock'
        
        @Test func testValidVersion1() {
            let parser = NetMock.Document.VersionNumber.parser
            let result = try? parser.run(validVersion1)
            #expect(result == NetMock.Document.VersionNumber(major: 1, minor: 2, patch: nil))
        }
        
        @Test func testValidVersion2() {
            let parser = NetMock.Document.VersionNumber.parser
            let result = try? parser.run(validVersion2)
            #expect(result == NetMock.Document.VersionNumber(major: 1, minor: 2, patch: 3))
        }
        
        @Test func testInvalidVersion1() {
            let parser = NetMock.Document.VersionNumber.parser
            let result = try? parser.run(invalidVersion1)
            #expect(result == nil)
        }
        
        @Test func testInvalidVersion2() {
            let parser = NetMock.Document.VersionNumber.parser
            let result = try? parser.run(invalidVersion2)
            #expect(result == nil)
        }
    }
    
    @Suite("Header Parsing")
    struct HeaderParsing {
        let validHeaders = [
            "GET https://example.com/test",
            "GET https://example.com/test #Live",
            "GET https://example.com/test 200",
            "GET https://example.com/test TEST",
            "GET https://example.com/test #Live 200 OK"
        ]
        let invalidHeaders = [
            "GET",
            "NEW https://shouldBreakOnMethodParse"
        ]

        @Test func testValidHeader1() {
            let parser = NetMock.Document.Header.parser
            var input: Substring = validHeaders[0][...]
            let result = try? parser.run(&input)
            #expect(result != nil, "Failed to parse: \(input)")
        }
        
        @Test func testValidHeader2() {
            let parser = NetMock.Document.Header.parser
            var input: Substring = validHeaders[1][...]
            let result = try? parser.run(&input)
            #expect(result != nil, "Failed to parse: \(input)")
        }
        
        @Test func testValidHeader3() {
            let parser = NetMock.Document.Header.parser
            var input: Substring = validHeaders[2][...]
            let result = try? parser.run(&input)
            #expect(result != nil, "Failed to parse: \(input)")
        }
        
        @Test func testValidHeader4() {
            let parser = NetMock.Document.Header.parser
            var input: Substring = validHeaders[3][...]
            let result = try? parser.run(&input)
            #expect(result != nil, "Failed to parse: \(input)")
        }
        
        @Test func testValidHeader5() {
            let parser = NetMock.Document.Header.parser
            var input: Substring = validHeaders[4][...]
            let result = try? parser.run(&input)
            #expect(result != nil, "Failed to parse: \(input)")
        }
        
        @Test func testInvalidHeader1() {
            let parser = NetMock.Document.Header.parser
            var input: Substring = invalidHeaders[0][...]
            let result = try? parser.run(&input)
            #expect(result == nil, "Unexpectedly succeeded parsing: \(input)")
        }
        
        @Test func testInvalidHeader2() {
            let parser = NetMock.Document.Header.parser
            var input: Substring = invalidHeaders[1][...]
            let result = try? parser.run(&input)
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
                result = try NetMock.Document.Response.parser.run(&substring)
            } catch {
                #expect(Bool(false), "Parser failed with error: \(error)")
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
                result = try NetMock.Document.Response.parser.run(&substring)
            } catch {
                #expect(Bool(false), "Parser failed with error: \(error)")
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
                result = try NetMock.Document.Response.parser.run(&substring)
            } catch {
                #expect(Bool(false), "Parser failed with error: \(error)")
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
                result = try NetMock.Document.Response.parser.run(&substring)
            } catch {
                #expect(Bool(false), "Parser failed with error: \(error)")
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
                result = try NetMock.Document.Response.parser.run(&substring)
            } catch {
                #expect(Bool(false), "Parser failed with error: \(error)")
                return
            }
            
            #expect(result.header.code == 200)
            #expect(result.header.labels == ["bin"])
            #expect(result.body == "\u{00}\u{01}\u{02}\u{FF}".data(using: .utf8),
                    "Body contained: '\(result.body.flatMap { String(data: $0, encoding: .utf8) } ?? "<nil>")'")
        }
        
        @Test func testBodyWithTrailingWhitespace() throws {
            let input = """
                200 ok
                { "key": "value" }   
                ---
                """
            var substring: Substring = input[...]
            let result = try? NetMock.Document.Response.parser.run(&substring)
            
            #expect(result?.header.code == 200)
            #expect(result?.header.labels == ["ok"])
            #expect(result?.body == "{ \"key\": \"value\" }   ".trimmingCharacters(in: .whitespaces).data(using: .utf8))
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
            let result = try? NetMock.Document.Response.parser.run(&substring)
            
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
        
        @Test func testBodyWithOnlyWhitespace() throws {
            let input = """
                200 emptyBody
                   
                ---
                """
            var substring: Substring = input[...]
            let result = try? NetMock.Document.Response.parser.run(&substring)
            
            #expect(result?.header.code == 200)
            #expect(result?.header.labels == ["emptyBody"])
            #expect(result?.body == nil, "Whitespace-only body should be nil")
        }
        
        @Test func testResponseWithoutBodyOrLabels() throws {
            let input = """
                500
                ---
                """
            var substring: Substring = input[...]
            let result = try? NetMock.Document.Response.parser.run(&substring)
            
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
            let result = try? NetMock.Document.Response.parser.run(&substring)
            
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
            let result = try? NetMock.Document.Response.parser.run(&substring)
            
            #expect(result?.header.code == 200)
            #expect(result?.header.labels == ["simple"])
            #expect(result?.body == nil)
        }
    }
}
