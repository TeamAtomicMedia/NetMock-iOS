//
//  NetMockLogging.swift
//  NetMock
//
//  Created by Christopher Wainwright on 17/10/2025.
//

import Foundation
import OSLog

public let setupLogger = Logger(subsystem: "NetMock", category: "load")
public let requestLogger = Logger(subsystem: "NetMock", category: "request")
public let captureLogger = Logger(subsystem: "NetMock", category: "capture")
