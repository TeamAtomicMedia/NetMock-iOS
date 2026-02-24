//
//  NetMockLogging.swift
//  NetMock
//
//  Created by Christopher Wainwright on 17/10/2025.
//

import Foundation
import OSLog

/// Logger for NetMock file loading and initialisation messages
public let setupLogger = Logger(subsystem: "NetMock", category: "load")

/// Logger for NetMock request handling and response selection messages
public let requestLogger = Logger(subsystem: "NetMock", category: "request")

/// Logger for NetMock response capture and file generation messages
public let captureLogger = Logger(subsystem: "NetMock", category: "capture")
