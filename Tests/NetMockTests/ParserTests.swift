//
//  ParserTests.swift
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
        func testSuccessConsumesInput() throws {
            var input: Substring = "a1c"
            let result = try parser.atomic().run(&input)
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
        }
    }
}
