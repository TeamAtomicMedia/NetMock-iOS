//
//  ParseError.swift
//  NetMock
//
//  Created by Christopher Wainwright on 24/09/2025.
//


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

typealias Parse<T> = @Sendable (inout Substring) throws -> T

struct Parser<T: Sendable> : Sendable {
    /// Perform the actions defined inside the parser
    private let _run: Parse<T>
    
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
