//
//  Document.swift
//  NetMock
//
//  Created by Christopher Wainwright on 24/09/2025.
//

import Foundation


extension NetMock {
    /// HTTP Method for NetMock file / captured response
    public enum Method : String, CaseIterable, Sendable, Codable {
        case GET, PUT, POST, DELETE, PATCH
    }
    
    /// An identifier present in the header of a NetMock file, **includes** `#Live`
    public enum Identifier : Equatable, Sendable, Codable, ExpressibleByStringLiteral, ExpressibleByIntegerLiteral {
        case mock(Mock), live
        
        static func code(_ code: Int) -> Self { .mock(.code(code)) }
        static func label(_ label: String) -> Self { .mock(.label(label)) }
        
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
        
        init(method: Method, url: URL) {
            self.method = method
            self.url = url
        }
    }

    struct Document : Sendable {
        struct VersionNumber : Comparable, Sendable {
            let major: Int
            let minor: Int
            let patch: Int?
            
            static func < (lhs: Self, rhs: Self) -> Bool {
                lhs.major == rhs.major
                    ? lhs.minor == rhs.minor
                        ? lhs.patch ?? 0 < rhs.patch ?? 0
                        : lhs.minor < rhs.minor
                    : lhs.major < rhs.major
            }
        }
    
        
        struct Response : Sendable {
            struct Header : Sendable {
                let code: Int
                let labels: [String]
            }
            
            let header: Header
            let body: Data?
        }
        
        let version: VersionNumber?
        let header: Request
        let sequence: [Identifier]
        var body: [Response]
        
        init(version: VersionNumber? = nil, header: Request, sequence: [Identifier] = [], body: [Response] = []) {
            self.version = version
            self.header = header
            self.sequence = sequence
            self.body = body
        }
    }
}
