//
//  iCloudManager.swift
//  AutoNummern
//
//  Created by Jörg-Olaf Hennig on 28.01.24.
//

import Foundation
import CloudKit

class iCloudManager: ObservableObject {
    
    private var database: CKDatabase
    private var container: CKContainer
    
    init() {
        self.container = CKContainer(identifier: "iCloud.com.olaf.hennig.Autonummern")
        self.database = self.container.publicCloudDatabase
    }
    
    func saveNumber(number: Int) {
        let record = CKRecord(recordType: "AutoNummer")
        record.setValuesForKeys(["Nummer" : number])
        
        // saving the record into the database
        self.database.save(record) { newRecord, error in
            if let error = error {
                DebugLogger.log("\(error.localizedDescription)")
            } else {
                DebugLogger.log("Record wurde gespeichert")// Record saved successfully.
            }
        }
    }
}
