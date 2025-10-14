//
//  ParseError.swift
//  NetMock
//
//  Created by Christopher Wainwright on 14/10/2025.
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
    
    enum ExpectedToken : Sendable, CustomStringConvertible, Equatable {
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

extension ParseError: Equatable {
    static func == (lhs: ParseError, rhs: ParseError) -> Bool {
        switch (lhs, rhs) {
        case (.expectedWhitespace, .expectedWhitespace) : true
        case (.expectedTerminationSequence, .expectedTerminationSequence) : true
        case (.expectedNumber, .expectedNumber) : true
        case (.expectedAlphaNumericString, .expectedAlphaNumericString) : true
        case (.expectedCharactersSatisfyingPredicate, .expectedCharactersSatisfyingPredicate) : true
        case (.expectedCharacter(let a), .expectedCharacter(let b)) : a == b
        case (.expectedToken(let a), .expectedToken(let b)) : a == b
        case (.expectedType(let a), .expectedType(let b)) : a == b
        case (.incompleteParse(let a), .incompleteParse(let b)) : a == b
        case (.contextualError(let contextA, let errorA), .contextualError(let contextB, let errorB)) : contextA == contextB && errorA == errorB
        default: false
        }
    }
}
