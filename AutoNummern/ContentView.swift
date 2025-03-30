//
//  ContentView.swift
//  AutoNummern
//
//  Created by Kira Hennig on 22.12.23.
//

import SwiftUI
import UserNotifications
import CloudKit
import CoreData

struct RedButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 60, height: 60)
            .padding()
            .background(.red)
            .foregroundStyle(.white)
            .clipShape(Capsule())
            .font(.title)
            .scaleEffect(configuration.isPressed ? 1.5 : 1)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct GreenButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 60, height: 60)
            .padding()
            .background(.green)
            .foregroundStyle(.white)
            .clipShape(Capsule())
            .font(.title)
            .scaleEffect(configuration.isPressed ? 1.5 : 1)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct GrowingButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(.red)
            .foregroundStyle(.white)
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 1.2 : 1)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct ContentView: View {
    
    // Get a reference to the managed object context from the environment.
    @Environment(\.managedObjectContext) private var managedObjectContext
    @FetchRequest(sortDescriptors: []) private var FetchedCoreNumber: FetchedResults<CoreDataAutoNummer>
//    @FetchRequest(sortDescriptors: [])
//    private var FetchCoreNumber: FetchedResults<CoreDataAutoNummer>

//    @State private var Autonummer: CoreDataAutoNummer?
    @State private var share: CKShare?   // ToDo Share muss wohl noch irgendwie gemanaged werden ?
    @State private var selectedNumber: Int?
    @State private var coreDataIndex: Int?
    @State private var isButtonPressed = false
    @State private var showShareSheet = false
    private let stack = CoreDataStack.shared
    
    var body: some View {
        VStack {
            
            VStack {
                Text("Auto Nummern").font(.largeTitle)
                Text("by Kira").font(.caption).italic()
            }.padding(.top,100)
            Spacer()
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(1..<200,id : \.self) { number in
                            if (selectedNumber ?? 1 >= number) {
                                Button("\(number)", action: {
                                    selectedNumber = number
                                    saveNumber(Int16(number))
                                  }
                                )
                                .buttonStyle(GreenButton())
                            } else {
                                Button("\(number)", action: {
                                    selectedNumber = number
                                    saveNumber(Int16(number))
                                    DebugLogger.log("FileManager URLs: \(FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask))")
                                  }
                                )
                                .buttonStyle(RedButton())
                            }
                        }
                    }
                    .onAppear {
                        // Springe zur vorgewählten Position
                        proxy.scrollTo(selectedNumber ?? 1, anchor: .center)
                    }.padding(.bottom,150)
                }
            }
            Spacer()
            Button {
                Task {
                    do {
                        // Timeout nach 30 Sekunden
                        try await withTimeout(seconds: 30) {
                            if !stack.isShared(object: FetchedCoreNumber.first!) {
                                await createShare(FetchedCoreNumber.first!)
                            }
                            showShareSheet = true
                            return () // Expliziter Return für Void
                        }
                    } catch {
                        DebugLogger.log("Sharing timeout or error: \(error)")
                    }
                }
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
        }
        .sheet(isPresented: $showShareSheet, content: {
          if let share = share {
            CloudSharingView(
              share: share,
              container: stack.ckContainer,
              autonummer: FetchedCoreNumber.first!
            )
          }
        })
        .background(
            LinearGradient(gradient: Gradient(colors: [.white, .blue, .white]), startPoint: .top, endPoint: .bottom))
        .onAppear {
            cleanupCoreData()
            logShareStatus()
            if FetchedCoreNumber.count == 0 {
                selectedNumber = 1
                DebugLogger.log("Keine Einträge gefunden, setze selectedNumber = 1")
            } else {
                DebugLogger.logCoreDataStatus(
                    count: FetchedCoreNumber.count,
                    lastNumber: Int(FetchedCoreNumber[FetchedCoreNumber.count-1].nummer)
                )
                coreDataIndex = FetchedCoreNumber.count-1
                selectedNumber = Int(FetchedCoreNumber[coreDataIndex!].nummer)
                self.share = stack.getShare(FetchedCoreNumber.first!)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)
            .receive(on: DispatchQueue.main)) { _ in
                //fetchRemoteChanges()
                coreDataIndex = FetchedCoreNumber.count-1
                DebugLogger.log("\(Date().formatted(date: .omitted, time: .standard)): Notification eingetroffen. CoreDataIndex = \(coreDataIndex ?? 0). Aktuelle Nummer = \(selectedNumber ?? 0). FetchedCoreNumber = \(FetchedCoreNumber[coreDataIndex ?? 0].nummer)", level: .info)
                    //selectedNumber = Int(CoreNumber[CoreNumber.count-1].nummer)
                managedObjectContext.perform {
                    do {
                        try managedObjectContext.save()
                    } catch {
                        DebugLogger.log("\(Date().formatted(date: .omitted, time: .standard)): Failed to save changes: \(error.localizedDescription)", level: .error)
                    }
                }
            }
    }

    private func saveNumber(_ number: Int16) {
        cleanupCoreData() // Erst alles löschen
        
        let context = managedObjectContext
        let newNumber = CoreDataAutoNummer(context: context)
        newNumber.nummer = number
        
        do {
            try context.save()
            DebugLogger.log("Neue Nummer gespeichert: \(number)", level: .info)
        } catch {
            DebugLogger.log("Fehler beim Speichern: \(error)", level: .error)
        }
    }
}
// MARK: Returns CKShare participant permission
extension ContentView {
  private func string(for permission: CKShare.ParticipantPermission) -> String {
    switch permission {
    case .unknown:
      return "Unknown"
    case .none:
      return "None"
    case .readOnly:
      return "Read-Only"
    case .readWrite:
      return "Read-Write"
    @unknown default:
      fatalError("MyDebug: A new value added to CKShare.Participant.Permission")
    }
  }

  private func string(for role: CKShare.ParticipantRole) -> String {
    switch role {
    case .owner:
      return "Owner"
    case .privateUser:
      return "Private User"
    case .publicUser:
      return "Public User"
    case .unknown:
      return "Unknown"
    @unknown default:
      fatalError("MyDebug: A new value added to CKShare.Participant.Role")
    }
  }

  private func string(for acceptanceStatus: CKShare.ParticipantAcceptanceStatus) -> String {
    switch acceptanceStatus {
    case .accepted:
      return "Accepted"
    case .removed:
      return "Removed"
    case .pending:
      return "Invited"
    case .unknown:
      return "Unknown"
    @unknown default:
      fatalError("MyDebug: A new value added to CKShare.Participant.AcceptanceStatus")
    }
  }
  
  private func createShare(_ autonummer: CoreDataAutoNummer) async {
    do {
        // Wenn bereits ein Share existiert, diesen verwenden
        if let existingShare = stack.getShare(autonummer) {
            self.share = existingShare
            DebugLogger.log("Existierender Share gefunden mit Teilnehmern: \(existingShare.participants.count)")
            DebugLogger.log("Share URL: \(existingShare.url?.absoluteString ?? "keine URL")")
            return
        }
        
        // Erstellen und speichern des Shares
        let (_, share, _) = try await stack.persistentContainer.share([autonummer], to: nil)
        share[CKShare.SystemFieldKey.title] = "AktuelleAutonummer"
        
        // Speichern des Shares auf dem Server
        try await stack.persistentContainer.persistUpdatedShare(share, in: stack.sharedPersistentStore)
        
        // Überprüfen ob der Share erfolgreich erstellt wurde
        if let persistedShare = stack.getShare(autonummer) {
            self.share = persistedShare
            DebugLogger.log("Neuer Share erfolgreich erstellt und gespeichert", level: .info)
            DebugLogger.log("Neue Share URL: \(persistedShare.url?.absoluteString ?? "keine URL")", level: .debug)
            DebugLogger.log("Share Besitzer: \(persistedShare.owner.userIdentity.nameComponents?.formatted() ?? "unbekannt")", level: .debug)
        } else {
            throw NSError(domain: "ShareError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Share wurde nicht persistiert"])
        }
    } catch {
        DebugLogger.log("Unerwarteter Fehler beim Share-Vorgang: \(error.localizedDescription)", level: .error)
        if let ckError = error as? CKError {
            DebugLogger.log("CloudKit Fehler Code: \(ckError.errorCode)", level: .error)
        }
    }
  }
    
//    private func createShare(_ autonummer: CoreDataAutoNummer) async {
//      do {
//        let (_, share, _) = try await stack.persistentContainer.share([autonummer], to: nil)
//        share[CKShare.SystemFieldKey.title] = "AktuelleAutonummer"
//        self.share = share
//      } catch {
//        print("Failed to create share")
//      }
//    }

  private func logShareStatus() {
      guard FetchedCoreNumber.first != nil else { 
        DebugLogger.log("Kein FirstRecord gefunden", level: .warning)
        return 
    }
  }

  private func cleanupCoreData() {
    let context = managedObjectContext
    let fetchRequest: NSFetchRequest<CoreDataAutoNummer> = CoreDataAutoNummer.fetchRequest()
    
    do {
        let numbers = try context.fetch(fetchRequest)
        
        // Speichere die letzte Nummer temporär
        let lastNumber = numbers.last?.nummer
        DebugLogger.log("Start Löschvorgang - Letzte Nummer war: \(lastNumber ?? -1)", level: .info)
        
        // Alle vorhandenen Einträge löschen
        for number in numbers {
            context.delete(number)
        }
        
        try context.save()
        
        // Wenn eine letzte Nummer existierte, speichere sie neu
        if let lastNumber = lastNumber {
            let newNumber = CoreDataAutoNummer(context: context)
            newNumber.nummer = lastNumber
            try context.save()
            DebugLogger.log("Letzte Nummer wiederhergestellt: \(lastNumber)", level: .info)
        }
        
        // Überprüfung
        let remainingNumbers = try context.fetch(fetchRequest)
        DebugLogger.log("Nach Bereinigung - Anzahl Einträge: \(remainingNumbers.count)", level: .info)
        DebugLogger.log("Aktuelle Nummer: \(remainingNumbers.first?.nummer ?? -1)", level: .info)
    } catch {
        DebugLogger.log("Fehler beim Löschen: \(error)", level: .error)
    }
  }
}

// Hilfsfunktion für Timeout
func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw TimeoutError()
        }
        
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}

struct TimeoutError: Error {}

//#Preview {
//    ContentView()
//}
