//
//  LoadError.swift
//  NetMock
//
//  Created by Christopher Wainwright on 23/02/2026.
//

import Foundation

public enum LoadError: Error {
    case invalidFileFormat
    case incompleteParse
    case invalidURL
}
