//
//  Document+Initialisers.swift
//  NetMock
//
//  Created by Christopher Wainwright on 23/02/2026.
//

import Foundation

extension Document {
    /// Loads and parses a NetMock document from a file
    ///
    /// This initialiser reads a `.nm` file, parses its contents, and validates the format.
    ///
    /// - Parameters:
    ///   - fileURL: The URL of the `.nm` file to load
    ///   - urlParser: A custom URL parser for converting string URLs to URL objects
    /// - Throws:
    ///   - `LoadError.invalidFileFormat` if the file is not valid UTF-8
    ///   - `LoadError.incompleteParse` if parsing doesn't consume the entire file
    ///   - `Document.ValidationError` if validation fails
    public init(fileURL: URL, urlParser: @Sendable @escaping (String) -> URL?) throws {
        let data = try Data(contentsOf: fileURL)
        
        guard let contents = String(data: data, encoding: .utf8)
        else { throw LoadError.invalidFileFormat }
        
        try self.init(contents, urlParser: urlParser)
    }

    
    /// Loads and parses a NetMock document from a string
    ///
    /// - Parameters:
    ///   - fileContents: The String contents of a `.nm` file
    ///   - urlParser: A custom URL parser for converting string URLs to URL objects
    /// - Throws:
    ///   - `LoadError.incompleteParse` if parsing doesn't consume the entire file
    ///   - `Document.ValidationError` if validation fails
    public init(_ fileContents: String, urlParser: @Sendable @escaping (String) -> URL?) throws {
        var contentsSubstring = fileContents[...]
        
        let document: Document = try .parser(with: urlParser).run(&contentsSubstring)
        
        if !contentsSubstring.isEmpty { throw LoadError.incompleteParse }
        
        try document.validate()
        
        self = document
    }
}
