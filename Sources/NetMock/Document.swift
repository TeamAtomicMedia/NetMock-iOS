//
//  Document.swift
//  NetMock
//
//  Created by Christopher Wainwright on 24/09/2025.
//

import Foundation


extension NetMock {
    public enum Method : String, CaseIterable, Sendable, Codable {
        case GET, PUT, POST, DELETE, PATCH
    }

    public enum Identifier : Equatable, Sendable {
        case label(String), code(Int), live
    }
    
    public struct Request : Equatable, Sendable, Hashable {
        
        public let method: Method
        public let url: URL
        
        init(method: Method, url: URL) {
            self.method = method
            self.url = url
        }
    }

    public struct Document : Sendable {
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
        
        init(version: VersionNumber?, header: Request, sequence: [Identifier] = [], body: [Response] = []) {
            self.version = version
            self.header = header
            self.sequence = sequence
            self.body = body
        }
    }
}
