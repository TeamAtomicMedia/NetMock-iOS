//
//  ParseError.swift
//  NetMock
//
//  Created by Christopher Wainwright on 24/09/2025.
//

fileprivate extension String {
    func indent(_ size: Int) -> String {
        self.split { $0 == "\n" }.map { String(repeating: " ", count: size) + $0 }.joined(separator: "\n")
    }
}

enum ParseError: Error, CustomStringConvertible {
    var description: String {
        switch (self) {
        case .expectedCharacter(let char): return "Expected Character '\(char)'"
        case .expectedToken(let token): return "Expected Token \(token)"
        case .expectedType(let typeName): return "Expected Type '\(typeName)'"
        case .expectedWhitespace: return "Expected Whitespace"
        case .expectedTerminationSequence: return "Expected Termination Sequence"
        case .expectedNumber: return "Expected Number"
        case .expectedAlphaNumericString: return "Expected AlphaNumericString"
        case .expectedCharactersSatisfyingPredicate: return "Expected Characters Satisfying Predicate"
        case .incompleteParse(let remaining): return "Incomplete Parse - Remaining: \n\(remaining)"
        case .contextualError(let context, let error): return "- Parsing Error in \(context):\n\(error.description.indent(2))"
        }
    }
    
    enum ExpectedToken : Sendable, CustomStringConvertible {
        case one(String)
        case oneOf([String])
        case sequence([String])
        
        var description: String {
            switch (self) {
            case .one(let str): return "'\(str)'"
            case .oneOf(let strs): return "[\(strs.map{"'\($0)'"}.joined(separator: ", "))]"
            case .sequence(let strs): return "[\(strs.joined(separator: ", "))]"
            }
        }
    }
    
    case expectedCharacter(Character)
    case expectedWhitespace
    case expectedTerminationSequence
    case expectedToken(ExpectedToken)
    case expectedType(String)
    case expectedNumber
    case expectedAlphaNumericString
    case expectedCharactersSatisfyingPredicate
    case incompleteParse(Substring)
    indirect case contextualError(String, ParseError)
}

typealias Parse<T> = @Sendable (inout Substring) throws -> T

struct Parser<T: Sendable> : Sendable {
    /// Perform the actions defined inside the parser
    let _run: Parse<T>
    
    func run(_ substring: inout Substring) throws -> T { try _run(&substring) }
    
    func run(_ string: inout String) throws -> T {
        var substring = string[...]
        defer  { string = String(substring) }
        return try self.run(&substring)
    }
    
    func run(_ string: String) throws -> T {
        var string = string
        return try self.run(&string)
    }
    
    /// Define a parser
    init(_ run: @escaping Parse<T>) { self._run = run }
}

extension Parser {
    /// Functor
    ///
    /// Functor Operator (transform value inside Monadic context of Parser)
    func map<U>(transform: @Sendable @escaping (T) -> U) -> Parser<U> {
        Parser<U> { input in
            transform(try self.run(&input))
        }
    }
    
    func map<U>(transform: @Sendable @escaping (T) throws -> U) -> Parser<U> {
        Parser<U> { input in
            try transform(try self.run(&input))
        }
    }
}

/// Alternative
///
/// Alternative Operator (parse this, but if that fails, parse this instead)
infix operator <|> : LogicalDisjunctionPrecedence

func <|><A>(
    lhs: Parser<A>,
    rhs: Parser<A>
) -> Parser<A> {
    Parser { input in
        if let a = try? lhs.run(&input) { return a }
        return try rhs.run(&input)
    }.atomic()
}

/// Monad
///
/// Bind Operator (parse this, then pipe the result into this parser)
infix operator >>= : AdditionPrecedence

func >>=<A, B>(
    lhs: Parser<A>,
    rhs: @Sendable @escaping (A) -> Parser<B>
) -> Parser<B> {
    Parser<B> { input in
        let a = try lhs.run(&input)
        let bParser = rhs(a)
        return try bParser.run(&input)
    }.atomic()
}

infix operator >> : AdditionPrecedence

func >><A, B>(
    lhs: Parser<A>,
    rhs: Parser<B>
) -> Parser<B> {
    .init { input in
        let _ = try lhs.run(&input)
        let b = try rhs.run(&input)
        return b
    }.atomic()
}

infix operator << : AdditionPrecedence

func <<<A, B>(
    lhs: Parser<A>,
    rhs: Parser<B>
) -> Parser<A> {
    .init { input in
        let a = try lhs.run(&input)
        let _ = try rhs.run(&input)
        return a
    }.atomic()
}

/// Parser Modifiers
extension Parser {
    /// Make Compound Parser Atomic
    ///
    /// Make parser groupings atomic, either they complete completely,
    /// or fail and restore the partially consumed string to its original state
    func atomic() -> Parser<T> {
        .init { input in
            let original = input
            do {
                return try self.run(&input)
            } catch {
                input = original
                throw error
            }
        }
    }
    
    /// Make Parser Optional
    ///
    /// This modifier transforms the output of the parser to an optional
    /// - If the parser completes sucessfully, it will return the value as normal
    /// - If the parser does not complete, it will return nil and restore the input to its original
    func optional() -> Parser<T?> {
        .init { input in
            let original = input
            if let result = try? self.run(&input) {
                return result
            }
            input = original
            return nil
        }
    }
    
    /// Make Parser Optional
    ///
    /// This modifier adds a default to the parser output
    /// - If the parser completes sucessfully, it will return its result as normal
    /// - If the parser does not complete, it will return a default value and restore the input to its original
    func optional(defaultValue: T) -> Parser<T> {
        .init { input in
            let original = input
            if let result = try? self.run(&input) {
                return result
            }
            input = original
            return defaultValue
        }
    }
    
    /// Discard Parser's Output
    ///
    /// Useful when you want to consume a token without using the result
    func discard() -> Parser<Void> {
        .init { input in
            let _ = try? self.run(&input)
        }
    }
    
    /// Consume Multiple Tokens Sequentially
    ///
    /// # Parameters:
    /// - separator: customise the separator between each element in your sequence, defaults to ', ' (with optional trailing whitespace)
    /// - allowEmpty: accept no instances of elements and separators, returning an empty array
    /// - allowTrailingSeparator: accept trailing separator in list
    func sequence<U>(separator: Parser<U> = (.character(",") >> .whitespace().optional()), allowEmpty: Bool = true, allowTrailingSeparator: Bool = true) -> Parser<[T]> {
        .init { input in
            var results: [T] = []
            
            do {
                let first = try self.run(&input)
                results.append(first)
            } catch {
                if allowEmpty {
                    return results
                } else {
                    throw error
                }
            }
            
            while !input.isEmpty {
                let original = input
                do {
                    let _ = try separator.run(&input)
                    do {
                        let element = try self.run(&input)
                        results.append(element)
                    } catch {
                        if allowTrailingSeparator {
                            return results
                        } else {
                            throw error
                        }
                    }
                } catch {
                    input = original
                    return results
                }
            }
            
            return results
        }
    }
    
    /// Provide Context for Thrown Errors
    ///
    /// When an error is thrown by a parser, this modifier will catch the error,
    /// wrapping it with a `String` to provide additional context as to where the error was thrown
    func context(_ label: String) -> Parser<T> {
        .init { input in
            do {
                return try self.run(&input)
            } catch {
                if let parseError = error as? ParseError {
                    throw ParseError.contextualError(label, parseError)
                } else {
                    throw error
                }
            }
        }
    }
    
    /// Ensure a complete parse
    /// Trailing input which remains unconsumed will trigger an .incompleteParser error
    func complete() -> Parser<T> {
        .init { input in
            do {
                let result = try self.run(&input)
                
                if !input.isEmpty {
                    throw ParseError.incompleteParse(input)
                }
                
                return result
            }
        }
    }
}

/// Common Parsers
extension Parser {
    /// A convenience Parser to return a value (regardless of input)
    static func result(_ res: T) -> Parser<T> {
        Parser<T>{ _ in return res }
    }
    
    /// A convenience Parser to return an error (regardless of input)
    static func error(_ err: ParseError) -> Parser<T> {
        Parser<T>{ _ in throw err }
    }
    
    static func character(_ char: Character) -> Parser<Character> {
        .init { input in
            let original = input
            guard
                let nextChar = input.popFirst(),
                nextChar == char
            else {
                input = original
                throw ParseError.expectedCharacter(char)
            }
            return char
        }
    }
    
    static func token(_ str: String) -> Parser<String> {
        .init { input in
            guard input.hasPrefix(str)
            else { throw ParseError.expectedToken(.one(str)) }
            input.removeFirst(str.count)
            return str
        }
    }
    
    static func predicate(allowEmpty: Bool = false, where predicate: @Sendable @escaping (Character) -> Bool) -> Parser<String> {
        .init { input in
            let prefix = input.prefix(while: predicate)
            if prefix.isEmpty && !allowEmpty { throw ParseError.expectedCharactersSatisfyingPredicate}
            input.removeFirst(prefix.count)
            return String(prefix)
        }
    }
    
    static func until<U>(terminator: Parser<U>, allowEmpty: Bool = false, allowEOF: Bool = false, consumeTerminator: Bool = false) -> Parser<String> {
        .init { input in
            var collected = Substring()
            var remainder = input

            while !remainder.isEmpty {
                let original = remainder
                if let _ = try? terminator.run(&remainder) {
                    // Success: stop and return what we collected so far
                    input = consumeTerminator ? remainder : original // put terminator back into input
                    return String(collected)
                } else {
                    // Consume one character and continue
                    collected.append(remainder.removeFirst())
                }
            }

            if allowEOF {
                input = remainder
                return String(collected)
            }
            
            // Ran out of input without finding terminator
            throw ParseError.expectedTerminationSequence
        }
    }
    
    static func number() -> Parser<Int> {
        .init { input in
            let numberPrefix = input.prefix { ( $0 >= "0" && $0 <= "9" ) }
            guard !numberPrefix.isEmpty
            else { throw ParseError.expectedNumber }
            let intValue = Int(String(numberPrefix))!
            input.removeFirst(numberPrefix.count)
            return intValue
        }
    }
    
    static func rawRepr(_ value: T) -> Parser<T> where T: RawRepresentable, T.RawValue == String {
        .init { input in
            let rawValue = value.rawValue
            
            guard input.hasPrefix(rawValue)
            else { throw ParseError.expectedToken(.one(rawValue)) }
            input.removeFirst(rawValue.count)
            return value
        }
    }
    
    static func enumeration() -> Parser<T> where T: RawRepresentable & CaseIterable, T.RawValue == String {
        let baseCase: Parser<T> = .error(.expectedToken(.oneOf(T.allCases.map(\.rawValue))))
        return T.allCases
            .map { rawRepr($0) }
            .reduce(baseCase) { $0 <|> $1 }
    }
    
    static func whitespace() -> Parser<Void> {
        .init { input in
            let whitespace = input.prefix(while: \.isWhitespace)
            if whitespace.isEmpty { throw ParseError.expectedWhitespace }
            input.removeFirst(whitespace.count)
        }
    }
    
    static func optionalWhitespace() -> Parser<Void> {
        .whitespace().optional().discard()
    }
}

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


protocol Parsable : Sendable {
    static var parser: Parser<Self> { get }
}

extension Parsable {
    static func parse(_ substring: inout Substring) throws -> Self {
        try self.parser.run(&substring)
    }
    
    static func parse(_ string: inout String) throws -> Self {
        try self.parser.run(&string)
    }
}
