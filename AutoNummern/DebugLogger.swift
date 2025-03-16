import Foundation
import CloudKit
import os.log

struct DebugLogger {
    // Logging Level enum
    enum LogLevel: Int {
        case error = 0
        case warning = 1
        case info = 2
        case debug = 3
        
        var prefix: String {
            switch self {
            case .error: return "MyDebug: [ERROR]"
            case .warning: return "MyDebug: [WARNING]"
            case .info: return "MyDebug: [INFO]"
            case .debug: return "MyDebug: [DEBUG]"
            }
        }
    }
    
    // Aktuelles Logging-Level - nur Meldungen mit diesem Level oder wichtiger werden angezeigt
    static var currentLogLevel: LogLevel = .debug  // Temporär auf .debug gesetzt für Tests
    
    private static func printDebug(
        _ message: String,
        level: LogLevel,
        file: String,
        function: String,
        line: Int
    ) {
        guard level.rawValue <= currentLogLevel.rawValue else { return }
        
        let filename = (file as NSString).lastPathComponent
        let debugMessage = "\(level.prefix) [\(filename):\(line) - \(function)] \(message)"
        
        // Nur eine Ausgabemethode verwenden
        print(debugMessage)
    }
    
    static func log(
        _ message: String,
        level: LogLevel = .debug,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        printDebug(message, level: level, file: file, function: function, line: line)
    }

    static func logCoreDataStatus(
        count: Int,
        lastNumber: Int,
        level: LogLevel = .info,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        printDebug("CoreData Status:", level: level, file: file, function: function, line: line)
        printDebug("Anzahl Einträge: \(count)", level: level, file: file, function: function, line: line)
        printDebug("Letzte Nummer: \(lastNumber)", level: level, file: file, function: function, line: line)
    }

    static func logShareStatus(
        isShared: Bool,
        share: CKShare?,
        level: LogLevel = .info,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        printDebug("Share Status:", level: level, file: file, function: function, line: line)
        printDebug("Is Shared: \(isShared)", level: level, file: file, function: function, line: line)
        
        if let share = share {
            printDebug("Share Owner: \(share.owner.userIdentity.nameComponents?.formatted() ?? "Unknown")", 
                      level: level, file: file, function: function, line: line)
            printDebug("Participants: \(share.participants.count)", 
                      level: level, file: file, function: function, line: line)
        } else {
            printDebug("No share object available", 
                      level: level, file: file, function: function, line: line)
        }
    }
} 
