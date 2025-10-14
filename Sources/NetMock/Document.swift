//
//  Document.swift
//  NetMock
//
//  Created by Christopher Wainwright on 24/09/2025.
//

import Foundation


extension NetMock {
    public enum Method : String, CaseIterable, Sendable {
        case GET, PUT, POST, DELETE, PATCH
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
        
        struct Header : Equatable, Sendable  {
            enum Identifier : Equatable, Sendable {
                case label(String), code(Int), live
            }

            let method: Method
            let urlString: String
            let sequence: [Identifier]
            
            init(method: Method, urlString: String, sequence: [Identifier]) {
                self.method = method
                self.urlString = urlString
                self.sequence = sequence
            }
        }
        
        
        struct Response : Sendable {
            struct Header : Sendable {
                let code: Int
                let labels: [String]
            }
            
            let header: Response.Header
            let body: Data?
        }
        
        let version: VersionNumber?
        let header: Header
        var body: [Response]
    }
}
