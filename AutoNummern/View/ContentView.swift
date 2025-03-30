func createShare(_ autoNummer: CoreDataAutoNummer) async throws {
    // Prüfen ob bereits ein Share existiert
    if let existingShare = try? await autoNummer.persistentStore?.lookupShare(for: autoNummer) {
        shareStore = existingShare
        return
    }
    
    // Share in der privaten Datenbank erstellen
    let newShare = CKShare(rootRecord: CKRecord(recordType: "CoreDataAutoNummer"))
    newShare[CKShare.SystemFieldKey.title] = "Geteilte AutoNummer"
    
    try await autoNummer.managedObjectContext.share([autoNummer], to: newShare)
    shareStore = newShare
} 