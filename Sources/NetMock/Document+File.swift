//
//  Document+File.swift
//  NetMock
//
//  Created by Christopher Wainwright on 23/02/2026.
//

import Foundation

import NetMockCore

extension Document {
    public init(fileURL: URL, urlParser: @Sendable @escaping (String) -> URL?) throws {
        let data = try Data(contentsOf: fileURL)
        
        guard let contents = String(data: data, encoding: .utf8)
        else { throw LoadError.invalidFileFormat }
        
        var contentsSubstring = contents[...]
        
        let document: Document = try .parser(with: urlParser).run(&contentsSubstring)
        
        if !contentsSubstring.isEmpty { throw LoadError.incompleteParse }
        
        try document.validate()
        
        self = document
    }
}
