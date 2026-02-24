//
//  Document.swift
//  NetMock
//
//  Created by Christopher Wainwright on 24/09/2025.
//

import Foundation

/// HTTP Method for NetMock file / captured response
public enum Method : String, CaseIterable, Sendable, Codable {
    case GET, PUT, POST, DELETE, PATCH
}

/// An identifier present in the header of a NetMock file, **includes** `#Live`
public enum Identifier : Equatable, Sendable, Codable, ExpressibleByStringLiteral, ExpressibleByIntegerLiteral {
    case mock(Mock), live
    
    public static func code(_ code: Int) -> Self { .mock(.code(code)) }
    public static func label(_ label: String) -> Self { .mock(.label(label)) }
    
    /// An identifier present in the header of a NetMock file response, **excludes** `#Live`
    public enum Mock : Hashable, Sendable, Codable {
        case code(Int)
        case label(String)
    }
    
    public init(_ string: String) {
        self.init(stringLiteral: string)
    }
    
    public init(stringLiteral value: String) {
        if value == "#Live" {
            self = .live
        } else if let intValue = Int(value) {
            self = .code(intValue)
        } else {
            self = .label(value)
        }
    }
    
    public init(integerLiteral value: Int) {
        self = .code(value)
    }
}

public struct Request : Sendable, Hashable {
    public let method: Method
    public let url: URL
    
    public init(method: Method, url: URL) {
        self.method = method
        self.url = url
    }
}

public struct VersionNumber : Comparable, Sendable {
    public let major: Int
    public let minor: Int
    public let patch: Int?
    
    public init(major: Int, minor: Int, patch: Int?) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }
    
    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.major == rhs.major
        ? lhs.minor == rhs.minor
            ? lhs.patch ?? 0 < rhs.patch ?? 0
            : lhs.minor < rhs.minor
        : lhs.major < rhs.major
    }
}


public struct Response : Sendable {
    public struct Header : Sendable {
        public let code: Int
        public let labels: [String]
        
        public init(code: Int, labels: [String]) {
            self.code = code
            self.labels = labels
        }
    }
    
    public let header: Header
    public let body: Data
    
    public init(header: Header, body: Data) {
        self.header = header
        self.body = body
    }
}

public struct Document : Sendable {
    public let version: VersionNumber?
    public let header: Request
    public let sequence: [Identifier]
    public var body: [Response]
    
    public init(version: VersionNumber? = nil, header: Request, sequence: [Identifier] = [], body: [Response] = []) {
        self.version = version
        self.header = header
        self.sequence = sequence
        self.body = body
    }
}
