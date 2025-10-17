//
//  Document+Parsing.swift
//  NetMock
//
//  Created by Christopher Wainwright on 25/09/2025.
//

import Foundation

extension NetMock.VersionNumber : Parsable {
    static var parser: Parser<NetMock.VersionNumber> {
        .init { input in
            let preambleParser: Parser<Void> = .token("NetMock") *> .whitespace().discard()
            
            let majorParser: Parser<Int> = .number()
            let auxiliaryNumber: Parser<Int> = .character(".") *> .number()
            
            _ = try preambleParser.run(&input)
            let major: Int = try majorParser.run(&input)
            let minor: Int = try auxiliaryNumber.run(&input)
            let patch: Int? = try? auxiliaryNumber.run(&input)
            
            return .init(major: major, minor: minor, patch: patch)
        }
    }
}

extension NetMock.Identifier : Parsable {
    static var parser: Parser<NetMock.Identifier> {
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

extension NetMock.Request : Parsable {
    static var parser: Parser<NetMock.Request> {
        self.parser(with: URL.init(string:))
    }
    
    /// Parse Document with custom URLHandler
    /// - Parameter urlHandler: A closure to convert from the parsed document urlString to an optional URL. Returning a nil value from this closure will cause the Request parser to fail.
    /// - Returns: A Request parser with the custom urlHandler behaviour.
    static func parser(with urlHandler: @Sendable @escaping (String) -> URL?) -> Parser<NetMock.Request> {
        .init { input in
            let methodParser: Parser<NetMock.Method> = .enumeration() <* .whitespace()
            let urlStringParser: Parser<String> = .predicate { !$0.isWhitespace }
            
            let method = try methodParser.context("Method").run(&input)
            let urlString = try urlStringParser.context("URLString").run(&input)
            
            guard let url = urlHandler(urlString)
            else { throw NetMock.Definition.LoadError.invalidURL }
            
            return .init(method: method, url: url)
        }
    }
}

extension NetMock.Response : Parsable {
    static var parser: Parser<NetMock.Response> {
        .init { input in
            let headerParser: Parser<NetMock.Response.Header> = .init { input in
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
            
            let header: NetMock.Response.Header = try headerParser.run(&input)
            let body: Data = try bodyParser.run(&input)
            
            return .init(header: header, body: body)
        }
    }
}

extension NetMock.Document : Parsable {
    static var parser: Parser<NetMock.Document> {
        self.parser(with: URL.init(string:))
    }
    
    /// Parse Document with custom URLHandler
    /// - Parameter urlHandler: A closure to convert from the parsed document urlString to an optional URL. Returning a nil value from this closure will cause the Request parser to fail.
    /// - Returns: A Document parser with the custom urlHandler behaviour.
    static func parser(with urlHandler: @Sendable @escaping (String) -> URL?) -> Parser<NetMock.Document> {
        .init { input in
            let versionParser = (NetMock.VersionNumber.parser <* .newline()).optional()
            let headerParser = NetMock.Request.parser(with: urlHandler) <* .space().optional()
            let sequenceParser = NetMock.Identifier.parser.sequence(separator: .space())
            let doubleNewlineParser = Parser<Void>.newline() *> Parser<Void>.newline().discard()
            let bodyParser = NetMock.Response.parser.sequence(separator: .whitespace())
            
            let version = try versionParser.run(&input)
            let header = try headerParser.run(&input)
            let sequence = try sequenceParser.run(&input)
            try doubleNewlineParser.run(&input)
            let body = try bodyParser.run(&input)
            
            return .init(version: version, header: header, sequence: sequence, body: body)
        }
    }
}
