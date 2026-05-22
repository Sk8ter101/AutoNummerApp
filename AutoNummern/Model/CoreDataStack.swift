//
//  CoreDataStack.swift
//  AutoNummern
//
//  Created by Jörg-Olaf Hennig on 03.02.24.
//

import Foundation
import CloudKit
import CoreData

final class CoreDataStack: ObservableObject {
  static let shared = CoreDataStack()

  var ckContainer: CKContainer {
    let storeDescription = persistentContainer.persistentStoreDescriptions.first
    guard let identifier = storeDescription?.cloudKitContainerOptions?.containerIdentifier else {
      fatalError("Unable to get container identifier")
    }
    return CKContainer(identifier: identifier)
  }

  var context: NSManagedObjectContext {
    persistentContainer.viewContext
  }

  var privatePersistentStore: NSPersistentStore? {
    _privatePersistentStore
  }

  var sharedPersistentStore: NSPersistentStore? {
    _sharedPersistentStore
  }

  lazy var persistentContainer: NSPersistentCloudKitContainer = {
    let container = NSPersistentCloudKitContainer(name: "AutoNrModel")

    // Erstelle URLs für beide Stores
    guard let storeURL = container.persistentStoreDescriptions.first?.url else {
        fatalError("Konnte Store URL nicht finden")
    }
    
    let storeDirectory = storeURL.deletingLastPathComponent()
    let privateStoreURL = storeDirectory.appendingPathComponent("private.sqlite")
    let sharedStoreURL = storeDirectory.appendingPathComponent("shared.sqlite")
    
    // Einmalige Bereinigung v2: Lösche alle lokalen Stores um veraltete
    // Change-Tokens nach CloudKit Reset zu beseitigen. Zukünftige Resets
    // werden automatisch durch handleCloudKitEvent erkannt und behandelt.
    let cleanupKey = "didCleanupAllStores_v2"
    if !UserDefaults.standard.bool(forKey: cleanupKey) {
        Self.deleteStoreFiles(privateURL: privateStoreURL, sharedURL: sharedStoreURL)
        UserDefaults.standard.set(true, forKey: cleanupKey)
        DebugLogger.log("Einmalige Bereinigung aller lokalen Stores abgeschlossen (v2)", level: .info)
    }
    
    DebugLogger.log("Private Store URL: \(privateStoreURL.path)", level: .debug)
    DebugLogger.log("Shared Store URL: \(sharedStoreURL.path)", level: .debug)

    // Private Store Description
    let privateStoreDescription = NSPersistentStoreDescription(url: privateStoreURL)
    
    let privateOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.com.olaf.hennig.AutoNummernSpiel")
    privateOptions.databaseScope = .private
    privateStoreDescription.cloudKitContainerOptions = privateOptions
    
    privateStoreDescription.setOption(true as NSNumber,
        forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
    privateStoreDescription.setOption(true as NSNumber,
        forKey: NSPersistentHistoryTrackingKey)

    // Shared Store Description
    let sharedStoreDescription = NSPersistentStoreDescription(url: sharedStoreURL)
    
    let sharedOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.com.olaf.hennig.AutoNummernSpiel")
    sharedOptions.databaseScope = .shared
    sharedStoreDescription.cloudKitContainerOptions = sharedOptions
    
    sharedStoreDescription.setOption(true as NSNumber,
        forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
    sharedStoreDescription.setOption(true as NSNumber,
        forKey: NSPersistentHistoryTrackingKey)

    // Beide Store Descriptions setzen
    container.persistentStoreDescriptions = [privateStoreDescription, sharedStoreDescription]

    container.loadPersistentStores { [weak self] description, error in
        if let error = error {
            DebugLogger.log("FEHLER beim Laden des Stores: \(error)", level: .error)
            fatalError("Core Data Store konnte nicht geladen werden: \(error)")
        }

        // Persistent Stores zuweisen basierend auf database scope
        guard let loadedStore = container.persistentStoreCoordinator.persistentStores.first(where: {
            $0.url == description.url
        }) else {
            DebugLogger.log("Warnung: Konnte geladenen Store nicht finden für URL: \(description.url?.path ?? "unknown")", level: .warning)
            return
        }

        if description.cloudKitContainerOptions?.databaseScope == .private {
            self?._privatePersistentStore = loadedStore
            DebugLogger.log("✅ Private Store initialisiert: \(description.url?.lastPathComponent ?? "unknown")", level: .info)
        } else if description.cloudKitContainerOptions?.databaseScope == .shared {
            self?._sharedPersistentStore = loadedStore
            DebugLogger.log("✅ Shared Store initialisiert: \(description.url?.lastPathComponent ?? "unknown")", level: .info)
        }
    }

    container.viewContext.automaticallyMergesChangesFromParent = true
    container.viewContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy

    return container
  }()

  private var _privatePersistentStore: NSPersistentStore?
  private var _sharedPersistentStore: NSPersistentStore?
  /// Verhindert mehrfachen Cleanup im selben App-Lebenszyklus
  private var didResetStoresThisSession = false
  /// Wird true gesetzt, wenn die lokalen Stores wegen eines CloudKit Zone-Resets
  /// geleert wurden. Die UI bindet sich an dieses Flag, um einen Hinweis-Alert
  /// anzuzeigen, der den Benutzer zum manuellen Neustart auffordert.
  @Published var needsManualRestart: Bool = false

  private init() {
    #if DEBUG
    UserDefaults.standard.setValue("com.apple.CoreData", forKey: "com.apple.CoreData.CloudKitDebug")
    UserDefaults.standard.setValue("com.apple.CoreData", forKey: "com.apple.CoreData.SQLDebug")
    #endif

    // Stelle sicher, dass der persistente Container geladen ist,
    // bevor wir auf CloudKit-Events lauschen.
    _ = persistentContainer
    setupCloudKitMonitoring()
  }
}

// MARK: Save or delete from Core Data
extension CoreDataStack {
  func save() {
    if context.hasChanges {
      do {
        try context.save()
      } catch {
          DebugLogger.log("ViewContext save error: \(error)")
      }
    }
  }

  func delete(_ autonummer: CoreDataAutoNummer) {
    context.perform {
      self.context.delete(autonummer)
      self.save()
    }
  }
}

// MARK: Share a record from Core Data
extension CoreDataStack {
  func isShared(object: NSManagedObject) -> Bool {
    isShared(objectID: object.objectID)
  }

  func canEdit(object: NSManagedObject) -> Bool {
    return persistentContainer.canUpdateRecord(forManagedObjectWith: object.objectID)
  }

  func canDelete(object: NSManagedObject) -> Bool {
    return persistentContainer.canDeleteRecord(forManagedObjectWith: object.objectID)
  }

  func isOwner(object: NSManagedObject) -> Bool {
    guard isShared(object: object) else { return false }

    do {
      let shareDictionary = try persistentContainer.fetchShares(matching: [object.objectID])
      guard let share = shareDictionary[object.objectID] else {
        DebugLogger.log("Share nicht gefunden beim Prüfen des Besitzers", level: .warning)
        return false
      }

      if let currentUser = share.currentUserParticipant, currentUser == share.owner {
        return true
      }
      return false
    } catch {
      DebugLogger.log("Fehler beim Prüfen des Share-Besitzers: \(error.localizedDescription)", level: .error)
      return false
    }
  }

    func getShare(_ autonummer: CoreDataAutoNummer) -> CKShare? {
    guard isShared(object: autonummer) else { return nil }

    do {
      let shareDictionary = try persistentContainer.fetchShares(matching: [autonummer.objectID])
      guard let share = shareDictionary[autonummer.objectID] else {
        DebugLogger.log("Share nicht im Dictionary gefunden für ObjectID: \(autonummer.objectID)", level: .warning)
        return nil
      }
      share[CKShare.SystemFieldKey.title] = "AktuelleAutonummer"
      return share
    } catch {
      DebugLogger.log("Fehler beim Laden des CKShare: \(error.localizedDescription)", level: .error)
      if let ckError = error as? CKError {
        DebugLogger.log("CloudKit Error Code: \(ckError.code.rawValue)", level: .error)
      }
      return nil
    }
  }

  /// Liefert aus einer Liste von Objekten dasjenige, das aktuell einen CKShare besitzt.
  /// Wird als bevorzugter Update-Kandidat verwendet, damit die Share-Verbindung
  /// auch nach Sync-Duplikaten erhalten bleibt.
  func sharedObject<T: NSManagedObject>(in objects: [T]) -> T? {
    objects.first(where: { isShared(object: $0) })
  }

  private func isShared(objectID: NSManagedObjectID) -> Bool {
    var isShared = false
    if let persistentStore = objectID.persistentStore {
      if persistentStore == sharedPersistentStore {
        isShared = true
      } else {
        let container = persistentContainer
        do {
          let shares = try container.fetchShares(matching: [objectID])
          if shares.first != nil {
            isShared = true
          }
        } catch {
            DebugLogger.log("Failed to fetch share for \(objectID): \(error)")
        }
      }
    }
    return isShared
  }
}

extension CoreDataStack {
    func setupCloudKitMonitoring() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCloudKitEvent(_:)),
            name: NSPersistentCloudKitContainer.eventChangedNotification,
            object: persistentContainer
        )
    }
    
    @objc private func handleCloudKitEvent(_ notification: Notification) {
        guard let cloudEvent = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
            as? NSPersistentCloudKitContainer.Event else {
            return
        }

        // Detaillierte Event-Behandlung für verschiedene Typen
        switch cloudEvent.type {
        case .setup:
            if cloudEvent.succeeded {
                DebugLogger.log("CloudKit Setup erfolgreich", level: .info)
            } else {
                DebugLogger.log("CloudKit Setup fehlgeschlagen", level: .error)
            }

        case .import:
            if cloudEvent.succeeded {
                DebugLogger.log("CloudKit Import erfolgreich abgeschlossen", level: .info)
            } else {
                DebugLogger.log("CloudKit Import fehlgeschlagen", level: .warning)
            }

        case .export:
            if cloudEvent.succeeded {
                DebugLogger.log("CloudKit Export erfolgreich abgeschlossen", level: .info)
            } else {
                DebugLogger.log("CloudKit Export fehlgeschlagen", level: .warning)
            }

        @unknown default:
            DebugLogger.log("Unbekannter CloudKit Event-Typ", level: .debug)
        }

        // Fehlerbehandlung mit Details
        if let error = cloudEvent.error {
            DebugLogger.log("CloudKit Sync Error: \(error.localizedDescription)", level: .error)

            if let ckError = error as? CKError {
                DebugLogger.log("CloudKit Error Code: \(ckError.code.rawValue)", level: .error)

                // Reaktiver Cleanup: Bei "Zone Not Found" oder "User Deleted Zone"
                // wurden die Server-Zonen gelöscht (z.B. durch CloudKit Console
                // "Reset Environment"), aber die lokalen Stores haben noch veraltete
                // Change-Tokens. App muss neu starten um frische Stores zu laden.
                if containsZoneDeletedError(ckError) {
                    handleZoneDeletedError()
                    return
                }

                // Spezielle Behandlung für häufige Fehler
                switch ckError.code {
                case .networkUnavailable, .networkFailure:
                    DebugLogger.log("Netzwerkproblem - Sync wird automatisch wiederholt", level: .warning)

                case .notAuthenticated:
                    DebugLogger.log("iCloud Account nicht angemeldet", level: .error)

                case .quotaExceeded:
                    DebugLogger.log("iCloud Speicherplatz voll", level: .error)

                case .zoneBusy, .serviceUnavailable:
                    DebugLogger.log("CloudKit Service temporär nicht verfügbar - Retry erfolgt automatisch", level: .warning)

                default:
                    DebugLogger.log("CloudKit Fehlerdetails: \(ckError.localizedDescription)", level: .error)
                }
            }
        }
    }
    
    // MARK: - Reaktiver Store-Cleanup bei Zone-Fehlern
    
    /// Prüft ob ein CKError einen zoneNotFound- oder userDeletedZone-Fehler
    /// enthält, auch verschachtelt in partialFailure-Fehlern.
    private func containsZoneDeletedError(_ error: CKError) -> Bool {
        if error.code == .zoneNotFound || error.code == .userDeletedZone {
            return true
        }
        // partialFailure enthält einzelne Fehler pro Zone
        if error.code == .partialFailure,
           let partialErrors = error.partialErrorsByItemID {
            for (_, itemError) in partialErrors {
                if let ckPartialError = itemError as? CKError,
                   ckPartialError.code == .zoneNotFound || ckPartialError.code == .userDeletedZone {
                    return true
                }
            }
        }
        return false
    }
    
    /// Räumt nach einem CloudKit Zone-Reset die lokalen Stores auf und setzt
    /// `needsManualRestart`, damit die UI den Benutzer zum Neustart auffordert.
    /// Ein programmatisches `exit(0)` ist auf iOS App-Store-konform nicht
    /// erlaubt und ein Reload der Stores innerhalb desselben Prozesses ist
    /// bei NSPersistentCloudKitContainer nicht zuverlässig möglich.
    private func handleZoneDeletedError() {
        guard !didResetStoresThisSession else {
            DebugLogger.log("Store-Reset wurde in dieser Session bereits durchgeführt - ignoriere weiteren zoneNotFound-Fehler", level: .warning)
            return
        }
        didResetStoresThisSession = true

        DebugLogger.log("Zone Not Found erkannt - lokale Stores werden geleert, Benutzer wird zum Neustart aufgefordert", level: .error)

        guard let storeURL = persistentContainer.persistentStoreDescriptions.first?.url else {
            DebugLogger.log("Konnte Store-URL für Cleanup nicht ermitteln", level: .error)
            return
        }
        let storeDirectory = storeURL.deletingLastPathComponent()
        let privateURL = storeDirectory.appendingPathComponent("private.sqlite")
        let sharedURL = storeDirectory.appendingPathComponent("shared.sqlite")

        let coordinator = persistentContainer.persistentStoreCoordinator
        for store in coordinator.persistentStores {
            do {
                try coordinator.remove(store)
                DebugLogger.log("Store entladen: \(store.url?.lastPathComponent ?? "unknown")", level: .info)
            } catch {
                DebugLogger.log("Fehler beim Entladen des Stores: \(error)", level: .error)
            }
        }
        _privatePersistentStore = nil
        _sharedPersistentStore = nil

        Self.deleteStoreFiles(privateURL: privateURL, sharedURL: sharedURL)

        Task { @MainActor [weak self] in
            self?.needsManualRestart = true
        }
    }
    
    /// Löscht die SQLite-Dateien (inkl. WAL und SHM) für beide Stores.
    private static func deleteStoreFiles(privateURL: URL, sharedURL: URL) {
        let fm = FileManager.default
        let filesToDelete = [
            privateURL,
            URL(fileURLWithPath: privateURL.path + "-wal"),
            URL(fileURLWithPath: privateURL.path + "-shm"),
            sharedURL,
            URL(fileURLWithPath: sharedURL.path + "-wal"),
            URL(fileURLWithPath: sharedURL.path + "-shm")
        ]
        for url in filesToDelete {
            if fm.fileExists(atPath: url.path) {
                try? fm.removeItem(at: url)
                DebugLogger.log("Store-Datei gelöscht: \(url.lastPathComponent)", level: .warning)
            }
        }
    }
}
