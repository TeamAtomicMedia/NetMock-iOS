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

/// An identifier for selecting specific responses in a NetMock file
///
/// Identifiers can be:
/// - `.code(Int)`: A numeric status code (e.g., 200, 404)
/// - `.label(String)`: A named label (e.g., "success", "error")
/// - `.live`: Special identifier indicating a live network call should be made
///
/// Example usage in a NetMock file header:
/// ```
/// GET https://api.example.com/users 200 500 200
/// ```
/// This sequence returns a 200 response, then 500, then 200 repeatedly.
///
/// The `#Live` identifier can be used to fall through to actual network calls:
/// ```
/// GET https://api.example.com/users #Live
/// ```
public enum Identifier : Equatable, Sendable, Codable, ExpressibleByStringLiteral, ExpressibleByIntegerLiteral {
    case mock(Mock), live
    
    /// Creates a code identifier
    public static func code(_ code: Int) -> Self { .mock(.code(code)) }
    /// Creates a label identifier
    public static func label(_ label: String) -> Self { .mock(.label(label)) }
    
    /// An identifier present in the header of a NetMock file response, **excludes** `#Live`
    public enum Mock : Hashable, Sendable, Codable {
        /// A numeric status code identifier
        case code(Int)
        /// A named label identifier
        case label(String)
    }
    
    /// Creates an identifier from a string
    ///
    /// - If the string is "#Live", creates a `.live` identifier
    /// - If the string is numeric, creates a `.code` identifier
    /// - Otherwise, creates a `.label` identifier
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

/// Represents an HTTP request with a method and URL
///
/// Used to identify which mock response should be returned for a given request.
public struct Request : Sendable, Hashable {
    /// The HTTP method (GET, POST, etc.)
    public let method: Method
    /// The request URL
    public let url: URL
    
    /// Creates a new request
    /// - Parameters:
    ///   - method: The HTTP method
    ///   - url: The request URL
    public init(method: Method, url: URL) {
        self.method = method
        self.url = url
    }
}

/// Represents the version number of a NetMock file format
///
/// NetMock files can optionally specify a format version in the form:
/// ```
/// NetMock 3.0.0
/// ```
/// The version follows semantic versioning with major, minor, and optional patch components.
public struct VersionNumber : Comparable, Sendable {
    /// Major version number
    public let major: Int
    /// Minor version number
    public let minor: Int
    /// Optional patch version number
    public let patch: Int?
    
    /// Creates a new version number
    /// - Parameters:
    ///   - major: Major version
    ///   - minor: Minor version
    ///   - patch: Optional patch version
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


/// Represents a mock HTTP response with headers and body
///
/// Each response in a NetMock file consists of a status code, optional labels, and an optional body.
public struct Response : Sendable {
    /// Response header containing the status code and labels
    public struct Header : Sendable {
        /// HTTP status code (e.g., 200, 404, 500)
        public let code: Int
        /// Optional labels for identifying this response (e.g., "success", "error")
        public let labels: [String]
        
        /// Creates a new response header
        /// - Parameters:
        ///   - code: HTTP status code
        ///   - labels: Optional identifying labels
        public init(code: Int, labels: [String]) {
            self.code = code
            self.labels = labels
        }
    }
    
    /// The response header
    public let header: Header
    /// The response body as raw data
    public let body: Data
    
    /// Creates a new response
    /// - Parameters:
    ///   - header: Response header with status code and labels
    ///   - body: Response body data
    public init(header: Header, body: Data) {
        self.header = header
        self.body = body
    }
}

/// Represents a complete NetMock document parsed from a `.nm` file
///
/// A NetMock document consists of:
/// - An optional version number
/// - A request header (HTTP method and URL)
/// - An optional response sequence defining the order responses should be returned
/// - One or more response definitions
///
/// Example NetMock file:
/// ```
/// GET https://api.example.com/users
///
/// 200
/// {"users": []}
/// ---
/// 500
/// {"error": "Internal Server Error"}
/// ```
public struct Document : Sendable {
    /// Optional format version (defaults to current version if not specified)
    public let version: VersionNumber?
    /// The HTTP request this document responds to
    public let header: Request
    /// Sequence of response identifiers defining order (empty means use first response)
    public let sequence: [Identifier]
    /// Available response definitions
    public var body: [Response]
    
    /// Creates a new NetMock document
    /// - Parameters:
    ///   - version: Optional format version
    ///   - header: The HTTP request this document responds to
    ///   - sequence: Response sequence (empty uses first response)
    ///   - body: Available response definitions
    public init(version: VersionNumber? = nil, header: Request, sequence: [Identifier] = [], body: [Response] = []) {
        self.version = version
        self.header = header
        self.sequence = sequence
        self.body = body
    }
}
