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
    
    // Shared Store konfigurieren
    let sharedStoreURL = privateStoreDescription.url?.deletingLastPathComponent().appendingPathComponent("shared.sqlite")
    let sharedStoreDescription = NSPersistentStoreDescription(url: sharedStoreURL!)
    
    let sharedOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.com.olaf.hennig.AutoNummernSpiel")
    sharedOptions.databaseScope = .shared
    sharedStoreDescription.cloudKitContainerOptions = sharedOptions
    
    // Beide Store Descriptions setzen
    container.persistentStoreDescriptions = [privateStoreDescription, sharedStoreDescription]
    
    container.loadPersistentStores { description, error in
        if let error = error {
            fatalError("Core Data Store konnte nicht geladen werden: \(error)")
        }
    }
    
    container.viewContext.automaticallyMergesChangesFromParent = true
    container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    
    container.persistentStoreDescriptions.first?.setOption(true as NSNumber, 
        forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
    
    container.persistentStoreDescriptions.first?.cloudKitContainerOptions?.databaseScope = .private
    
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
    guard let share = try? persistentContainer.fetchShares(matching: [object.objectID])[object.objectID] else {
        DebugLogger.log("Get ckshare error")
      return false
    }
    if let currentUser = share.currentUserParticipant, currentUser == share.owner {
      return true
    }
    return false
  }

    func getShare(_ autonummer: CoreDataAutoNummer) -> CKShare? {
    guard isShared(object: autonummer) else { return nil }
    guard let shareDictionary = try? persistentContainer.fetchShares(matching: [autonummer.objectID]),
      let share = shareDictionary[autonummer.objectID] else {
        DebugLogger.log("Unable to get CKShare")
      return nil
    }
    share[CKShare.SystemFieldKey.title] = "AktuelleAutonummer"
    return share
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
        
        if cloudEvent.type == .setup {
            print("CloudKit Setup Status: \(cloudEvent.succeeded)")
        }
        
        if let error = cloudEvent.error {
            print("CloudKit Sync Error: \(error.localizedDescription)")
        }
    }
}
