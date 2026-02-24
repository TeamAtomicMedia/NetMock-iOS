//
//  LoadError.swift
//  NetMock
//
//  Created by Christopher Wainwright on 23/02/2026.
//

import Foundation

/// Errors that can occur when loading a NetMock document from a file
public enum LoadError: Error {
    /// The file format is invalid (e.g., not UTF-8 encoded)
    case invalidFileFormat
    /// The parser could not completely parse the file contents
    case incompleteParse
    /// The URL specified in the file header could not be parsed
    case invalidURL
}
