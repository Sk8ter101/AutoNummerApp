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

  var privatePersistentStore: NSPersistentStore {
    guard let privateStore = _privatePersistentStore else {
      fatalError("Private store is not set")
    }
    return privateStore
  }

  var sharedPersistentStore: NSPersistentStore {
    guard let sharedStore = _sharedPersistentStore else {
      fatalError("Shared store is not set")
    }
    return sharedStore
  }

  lazy var persistentContainer: NSPersistentCloudKitContainer = {
    let container = NSPersistentCloudKitContainer(name: "AutoNrModel")

    // Private Store konfigurieren
    guard let privateStoreDescription = container.persistentStoreDescriptions.first else {
        fatalError("Konnte private Store Description nicht finden")
    }

    let privateOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.com.olaf.hennig.AutoNummernSpiel")
    privateOptions.databaseScope = .private
    privateStoreDescription.cloudKitContainerOptions = privateOptions

    // Shared Store konfigurieren - mit sicherem URL handling
    guard let privateURL = privateStoreDescription.url,
          let sharedStoreURL = privateURL.deletingLastPathComponent().appendingPathComponent("shared.sqlite") as URL? else {
        fatalError("Konnte Shared Store URL nicht erstellen")
    }

    let sharedStoreDescription = NSPersistentStoreDescription(url: sharedStoreURL)

    let sharedOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.com.olaf.hennig.AutoNummernSpiel")
    sharedOptions.databaseScope = .shared
    sharedStoreDescription.cloudKitContainerOptions = sharedOptions

    // Remote Change Notifications aktivieren
    privateStoreDescription.setOption(true as NSNumber,
        forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
    sharedStoreDescription.setOption(true as NSNumber,
        forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

    // Beide Store Descriptions setzen
    container.persistentStoreDescriptions = [privateStoreDescription, sharedStoreDescription]

    container.loadPersistentStores { [weak self] description, error in
        if let error = error {
            fatalError("Core Data Store konnte nicht geladen werden: \(error)")
        }

        // KRITISCHER FIX: Persistent Stores zuweisen basierend auf database scope
        guard let loadedStore = container.persistentStoreCoordinator.persistentStores.first(where: {
            $0.url == description.url
        }) else {
            DebugLogger.log("Warnung: Konnte geladenen Store nicht finden für URL: \(description.url?.path ?? "unknown")", level: .warning)
            return
        }

        if description.cloudKitContainerOptions?.databaseScope == .private {
            self?._privatePersistentStore = loadedStore
            DebugLogger.log("Private Store initialisiert: \(description.url?.lastPathComponent ?? "unknown")", level: .info)
        } else if description.cloudKitContainerOptions?.databaseScope == .shared {
            self?._sharedPersistentStore = loadedStore
            DebugLogger.log("Shared Store initialisiert: \(description.url?.lastPathComponent ?? "unknown")", level: .info)
        }
    }

    container.viewContext.automaticallyMergesChangesFromParent = true
    // FIX: Korrekter Merge Policy - Server-Daten haben Vorrang für iCloud-Sync
    container.viewContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy

    return container
  }()

  private var _privatePersistentStore: NSPersistentStore?
  private var _sharedPersistentStore: NSPersistentStore?
  private init() {
    #if DEBUG
    UserDefaults.standard.setValue("com.apple.CoreData", forKey: "com.apple.CoreData.CloudKitDebug")
    UserDefaults.standard.setValue("com.apple.CoreData", forKey: "com.apple.CoreData.SQLDebug")
    #endif
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
}
