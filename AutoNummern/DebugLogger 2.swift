import Foundation

struct DebugLogger {
    private static func printDebug(
        _ message: String,
        file: String,
        function: String,
        line: Int
    ) {
        let filename = (file as NSString).lastPathComponent
        print("MyDebug: [\(filename):\(line) - \(function)] \(message)")
    }
    
    static func log(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        printDebug(message, file: file, function: function, line: line)
    }

    static func logCoreDataStatus(
        count: Int,
        lastNumber: Int,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        printDebug("CoreData Status:", file: file, function: function, line: line)
        printDebug("Anzahl Einträge: \(count)", file: file, function: function, line: line)
        printDebug("Letzte Nummer: \(lastNumber)", file: file, function: function, line: line)
    }

    static func logShareStatus(
        isShared: Bool,
        share: CKShare?,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        printDebug("Share Status:", file: file, function: function, line: line)
        printDebug("Is Shared: \(isShared)", file: file, function: function, line: line)
        
        if let share = share {
            printDebug("Share Owner: \(share.owner.userIdentity.nameComponents?.formatted() ?? "Unknown")", 
                      file: file, function: function, line: line)
            printDebug("Participants: \(share.participants.count)", 
                      file: file, function: function, line: line)
        } else {
            printDebug("No share object available", 
                      file: file, function: function, line: line)
        }
    }
} 