//
//  NetMockLogging.swift
//  NetMock
//
//  Created by Christopher Wainwright on 17/10/2025.
//

import Foundation
import OSLog

extension NetMock {
    static let setupLogger = Logger(subsystem: "NetMock", category: "load")
    static let requestLogger = Logger(subsystem: "NetMock", category: "request")
    static let captureLogger = Logger(subsystem: "NetMock", category: "capture")
}
