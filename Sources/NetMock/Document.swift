//
//  Document.swift
//  NetMock
//
//  Created by Christopher Wainwright on 24/09/2025.
//

import Foundation

extension NetMock {
    struct Document {
        struct VersionNumber : Comparable {
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
        
        struct Header : Equatable  {
            enum Method: String, CaseIterable {
                case GET, PUT, POST, DELETE, PATCH
            }
            
            enum Identifier : Equatable {
                case label(String), code(Int), live
            }

            let method: Method
            let urlString: String
            let sequence: [Identifier]
        }
        
        
        struct Response {
            struct Header {
                let code: Int
                let labels: [String]
            }
            
            let header: Response.Header
            let body: Data?
        }
        
        let version: VersionNumber?
        let header: Header
        let body: [Response]
    }
}
