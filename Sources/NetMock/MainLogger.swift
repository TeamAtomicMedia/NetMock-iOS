//
//  MainLogger.swift
//  NetMock
//
//  Created by Christopher Wainwright on 24/02/2026.
//

import Foundation
import OSLog

/// Logger for NetMock file loading and initialisation messages
internal let setupLogger = Logger(subsystem: "NetMock", category: "load")

/// Logger for NetMock request handling and response selection messages
internal let requestLogger = Logger(subsystem: "NetMock", category: "request")
