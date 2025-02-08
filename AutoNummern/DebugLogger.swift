import Foundation
import CloudKit

struct DebugLogger {
    static let prefix = "MyDebug"
    
    static func log(_ message: String, function: String = #function, file: String = #file, line: Int = #line) {
        #if DEBUG
        let filename = (file as NSString).lastPathComponent
        print("\(prefix): [\(filename):\(line) - \(function)] \(message)")
        #endif
    }
    
    // Spezifische Logging-Funktionen für verschiedene Bereiche
    static func logShareStatus(isShared: Bool, share: CKShare?) {
        log("Share-Status:")
        log("IsShared: \(isShared)")
        if let share = share {
            log("Aktueller Share: \(share)")
            log("Teilnehmer: \(share.participants.count)")
            log("Share-Typ: \(share[CKShare.SystemFieldKey.shareType] ?? "Nicht definiert")")
        } else {
            log("Kein aktiver Share gefunden")
        }
    }
    
    static func logCoreDataStatus(count: Int, lastNumber: Int?) {
        log("CoreData Status:")
        log("Anzahl Einträge: \(count)")
        if let number = lastNumber {
            log("Letzte Nummer: \(number)")
        }
    }
} 
