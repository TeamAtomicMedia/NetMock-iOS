//
//  Document+Parsing.swift
//  NetMock
//
//  Created by Christopher Wainwright on 25/09/2025.
//

import Foundation

@_exported import Parser

// MARK: - Parser Conformances
// This file provides Parsable conformances for NetMock types, allowing them to be
// parsed from `.nm` file contents using the Parser library.

extension VersionNumber : Parsable {
    public static var parser: Parser<VersionNumber> {
        .init { input in
            let preambleParser: Parser<Void> = .token("NetMock") *> .whitespace().discard()
            
            let majorParser: Parser<Int> = .number()
            let auxiliaryNumber: Parser<Int> = .token(".") *> .number()
            
            _ = try preambleParser.run(&input)
            let major: Int = try majorParser.run(&input)
            let minor: Int = try auxiliaryNumber.run(&input)
            let patch: Int? = try? auxiliaryNumber.run(&input)
            
            return .init(major: major, minor: minor, patch: patch)
        }
    }
}

extension Identifier : Parsable {
    public static var parser: Parser<Identifier> {
        .init { input in
            let liveParser: Parser<String> = .token("#Live")
            let codeParser: Parser<Int> = .number()
            let labelParser: Parser<String> = .predicate { !$0.isWhitespace }
            
            if (try? liveParser.run(&input)) != nil { return .live}
            else if let code = try? codeParser.run(&input) { return .code(code)}
            else if let label = try? labelParser.run(&input) { return .label(label)}
            
            throw ParseError.expectedToken(.oneOf(["#Live", "number", "label"]))
        }
    }
}

extension Request : Parsable {
    public static var parser: Parser<Request> {
        self.parser(with: URL.init(string:))
    }
    
    /// Parse Document with custom URLHandler
    /// - Parameter urlHandler: A closure to convert from the parsed document urlString to an optional URL. Returning a nil value from this closure will cause the Request parser to fail.
    /// - Returns: A Request parser with the custom urlHandler behaviour.
    public static func parser(with urlHandler: @Sendable @escaping (String) -> URL?) -> Parser<Request> {
        .init { input in
            let methodParser: Parser<Method> = .enumeration() <* .whitespace()
            let urlStringParser: Parser<String> = .predicate { !$0.isWhitespace }
            
            let method = try methodParser.context("Method").run(&input)
            let urlString = try urlStringParser.context("URLString").run(&input)
            
            guard let url = urlHandler(urlString)
            else { throw LoadError.invalidURL }
            
            return .init(method: method, url: url)
        }
    }
}

extension Response : Parsable {
    public static var parser: Parser<Response> {
        .init { input in
            let headerParser: Parser<Response.Header> = .init { input in
                let codeParser: Parser<Int> = .number()
                let labelParser: Parser<[String]> = .predicate(allowEmpty: true) { $0 != "\n" }.map { $0.components(separatedBy: " ").filter { $0 != ""} }
                let code = try codeParser.run(&input)
                let labels = try labelParser.run(&input)
                return .init(code: code, labels: labels)
            }.context("Header")
            
            let bodyParser: Parser<Data> = Parser<String>
                .until(terminator: .token("\n---"), allowEOF: true, consumeTerminator: true)
                .map { $0.trimmingCharacters(in: .newlines) }
                .map { $0.data(using: .utf8) ?? Data() }
                .context("Body")
            
            let header: Response.Header = try headerParser.run(&input)
            let body: Data = try bodyParser.run(&input)
            
            return .init(header: header, body: body)
        }
    }
}

extension Document : Parsable {
    public static var parser: Parser<Document> {
        self.parser(with: URL.init(string:))
    }
    
    /// Parse Document with custom URLHandler
    /// - Parameter urlHandler: A closure to convert from the parsed document urlString to an optional URL. Returning a nil value from this closure will cause the Request parser to fail.
    /// - Returns: A Document parser with the custom urlHandler behaviour.
    public static func parser(with urlHandler: @Sendable @escaping (String) -> URL?) -> Parser<Document> {
        .init { input in
            let versionParser = (VersionNumber.parser <* .newline()).optional()
            let headerParser = Request.parser(with: urlHandler) <* .space().optional()
            let sequenceParser = Identifier.parser.separated(by: .space(), allowEmpty: true)
            let doubleNewlineParser = Parser<Void>.newline() *> Parser<Void>.newline().discard()
            let bodyParser = Response.parser.separated(by: .whitespace(), allowEmpty: true)
            
            let version = try versionParser.run(&input)
            let header = try headerParser.run(&input)
            let sequence = try sequenceParser.run(&input)
            try doubleNewlineParser.run(&input)
            let body = try bodyParser.run(&input)
            try Parser<String>.whitespace(allowEmpty: true).discard().run(&input) // consume any trailing whitespace
            
            return .init(version: version, header: header, sequence: sequence, body: body)
        }
    }
}
