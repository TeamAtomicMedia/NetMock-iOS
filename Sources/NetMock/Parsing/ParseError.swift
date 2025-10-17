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

enum ParseError: Error, CustomStringConvertible, Equatable {
    var description: String {
        switch self {
        case .expectedCharacter(let char): "Expected Character '\(char)'"
        case .expectedToken(let token): "Expected Token \(token)"
        case .expectedType(let typeName): "Expected Type '\(typeName)'"
        case .expectedWhitespace: "Expected Whitespace"
        case .expectedTerminationSequence: "Expected Termination Sequence"
        case .expectedNumber: "Expected Number"
        case .expectedAlphaNumericString: "Expected AlphaNumericString"
        case .expectedCharactersSatisfyingPredicate: "Expected Characters Satisfying Predicate"
        case .incompleteParse(let remaining): "Incomplete Parse - Remaining: \n\(remaining)"
        case .contextualError(let context, let error): "- Parsing Error in \(context):\n\(error.description.indent(2))"
        case .eitherError(let firstError, let secondError): "Parsing Failed in Either:\n\("1. \(firstError.description)\n2. \(secondError.description)".indent(2))"
        case .custom(let error): error
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
    indirect case eitherError(ParseError, ParseError)
    case custom(String)
}
