//
//  Document+Parsing.swift
//  NetMock
//
//  Created by Christopher Wainwright on 25/09/2025.
//

import Foundation

extension NetMock.Document.VersionNumber : Parsable {
    static var parser: Parser<NetMock.Document.VersionNumber> {
        .init { input in
            let preambleParser: Parser<Void> = (.string("NetMock") >> .whitespace()).discard()
            
            let majorParser: Parser<Int> = .number()
            let auxiliaryNumber: Parser<Int> = .character(".") >> .number()
            
            _ = try preambleParser.run(&input)
            let major: Int = try majorParser.run(&input)
            let minor: Int = try auxiliaryNumber.run(&input)
            let patch: Int? = try? auxiliaryNumber.run(&input)
            
            return .init(major: major, minor: minor, patch: patch)
        }
    }
}

extension NetMock.Document.Header.Identifier : Parsable {
    static var parser: Parser<NetMock.Document.Header.Identifier> {
        .init{ input in
            let liveParser: Parser<String> = .string("#Live")
            let codeParser: Parser<Int> = .number()
            let labelParser: Parser<String> = .prefix { !$0.isWhitespace }
            
            if (try? liveParser.run(&input)) != nil { return .live}
            else if let code = try? codeParser.run(&input) { return .code(code)}
            else if let label = try? labelParser.run(&input) { return .label(label)}
            
            throw ParseError.expectedToken(.oneOf(["#Live", "number", "label"]))
        }
    }
}

extension NetMock.Document.Header : Parsable {
    static var parser: Parser<NetMock.Document.Header> {
        .init { input in
            let methodParser: Parser<NetMock.Document.Header.Method> = .enumeration() << .whitespace()
            let urlStringParser: Parser<String> = .prefix { !$0.isWhitespace }
            let sequenceParser = NetMock.Document.Header.Identifier.parser.sequence(separator: .whitespace())
            
            let method = try methodParser.run(&input)
            let urlString = try urlStringParser.run(&input)
            let sequence = try sequenceParser.run(&input)
            
            return .init(method: method, urlString: urlString, sequence: sequence)
        }
    }
}

extension NetMock.Document.Response : Parsable {
    static var parser: Parser<NetMock.Document.Response> {
        .init { input in
            let headerParser: Parser<NetMock.Document.Response.Header> = .init { input in
                let codeParser: Parser<Int> = .number()
                let labelParser: Parser<[String]> = .prefix(allowEmpty: true) { $0 != "\n" }.map { $0.components(separatedBy: " ").filter { $0 != ""} }
                let code = try codeParser.run(&input)
                let labels = try labelParser.run(&input)
                return .init(code: code, labels: labels)
            }.context(label: "Header")
            
            let bodyParser: Parser<Data?> = (Parser<String>.until(terminator: .whitespace() >> .string("---"))).map { $0.trimmingCharacters(in: .newlines) }.map { if $0.isEmpty { return nil } else { return $0.data(using: .utf8) }}.context(label: "Body")
            
            let header: NetMock.Document.Response.Header = try headerParser.run(&input)
            let body: Data? = try bodyParser.run(&input)
            
            return .init(header: header, body: body)
        }
    }
    
}

extension NetMock.Document : Parsable {
    static var parser: Parser<NetMock.Document> {
        .init { input in
            let versionParser = NetMock.Document.VersionNumber.parser.optional()
            let headerParser = NetMock.Document.Header.parser
            let bodyParser = NetMock.Document.Response.parser.sequence(separator: .whitespace())
            
            let version = try versionParser.run(&input)
            let header = try headerParser.run(&input)
            let body = try bodyParser.run(&input)
            
            return .init(version: version, header: header, body: body)
        }
    }
}
