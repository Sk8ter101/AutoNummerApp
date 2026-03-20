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
    @State private var share: CKShare?
    @State private var selectedNumber: Int?
    @State private var coreDataIndex: Int?
    @State private var isButtonPressed = false
    @State private var showShareSheet = false
    @State private var isNewShare = false
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
                guard !showShareSheet else { return }
                guard let firstNumber = FetchedCoreNumber.first else {
                    DebugLogger.log("Kein Datensatz zum Teilen vorhanden", level: .warning)
                    return
                }

                if stack.isShared(object: firstNumber), let existingShare = stack.getShare(firstNumber) {
                    self.share = existingShare
                    self.isNewShare = false
                    DebugLogger.log("Existierender Share geladen mit \(existingShare.participants.count) Teilnehmern", level: .info)
                } else {
                    self.share = nil
                    self.isNewShare = true
                    DebugLogger.log("Neuer Share wird über Preparation-Handler erstellt", level: .info)
                }
                showShareSheet = true
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
            .disabled(showShareSheet)
        }
        .sheet(isPresented: $showShareSheet) {
          if let firstNumber = FetchedCoreNumber.first {
            if isNewShare {
              // Neuer Share: Preparation-Handler erstellt den Share
              // erst wenn der Benutzer die Einladung absendet
              CloudSharingPrepareView(
                container: stack.ckContainer,
                autonummer: firstNumber
              )
            } else if let share = share {
              // Existierender Share: Teilnehmer verwalten
              CloudSharingView(
                share: share,
                container: stack.ckContainer,
                autonummer: firstNumber
              )
            }
          }
        }
        .background(
            LinearGradient(gradient: Gradient(colors: [.white, .blue, .white]), startPoint: .top, endPoint: .bottom))
        .onAppear {
            // Cleanup alter Duplikate
            cleanupCoreData()
            
            if FetchedCoreNumber.count == 0 {
                selectedNumber = 1
                DebugLogger.log("Keine Einträge gefunden, setze selectedNumber = 1", level: .debug)
            } else {
                let lastIndex = FetchedCoreNumber.count - 1
                DebugLogger.logCoreDataStatus(
                    count: FetchedCoreNumber.count,
                    lastNumber: Int(FetchedCoreNumber[lastIndex].nummer)
                )
                coreDataIndex = lastIndex
                selectedNumber = Int(FetchedCoreNumber[lastIndex].nummer)

                // Sicherer Zugriff auf ersten Datensatz
                if let firstNumber = FetchedCoreNumber.first {
                    self.share = stack.getShare(firstNumber)
                    
                    if stack.isShared(object: firstNumber) {
                        DebugLogger.log("Objekt ist bereits geteilt", level: .info)
                    } else {
                        DebugLogger.log("Objekt ist nicht geteilt", level: .info)
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)
            .debounce(for: .seconds(2), scheduler: DispatchQueue.global(qos: .utility))
            .receive(on: DispatchQueue.main)) { _ in
                // Nach Remote-Änderungen die aktuelle Nummer aktualisieren
                guard let firstNumber = FetchedCoreNumber.first else { return }
                
                let newNumber = Int(firstNumber.nummer)
                if selectedNumber != newNumber {
                    DebugLogger.log("Nummer von anderem Gerät aktualisiert: \(selectedNumber ?? 0) → \(newNumber)", level: .info)
                    selectedNumber = newNumber
                }
                
                coreDataIndex = FetchedCoreNumber.count - 1
            }
    }

    private func saveNumber(_ number: Int16) {
        let context = managedObjectContext
        let fetchRequest: NSFetchRequest<CoreDataAutoNummer> = CoreDataAutoNummer.fetchRequest()
        
        do {
            let existingNumbers = try context.fetch(fetchRequest)
            
            if let existingNumber = existingNumbers.first {
                // UPDATE: Vorhandenen Eintrag aktualisieren (behält Share-Verbindung)
                existingNumber.nummer = number
                DebugLogger.log("Nummer aktualisiert: \(number)", level: .info)
            } else {
                // INSERT: Neuen Eintrag erstellen (nur wenn noch keiner existiert)
                let newNumber = CoreDataAutoNummer(context: context)
                newNumber.nummer = number
                DebugLogger.log("Neue Nummer erstellt: \(number)", level: .info)
            }
            
            try context.save()
            
            // Cleanup alte Duplikate nach dem Speichern
            cleanupCoreData()
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
    case .administrator:
      return "Administrator"
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
        
        // Wenn nur ein Eintrag existiert, nichts tun
        guard numbers.count > 1 else {
            DebugLogger.log("Nur ein oder kein Eintrag vorhanden - kein Cleanup nötig", level: .info)
            return
        }
        
        // Behalte den letzten (neuesten) Eintrag
        let lastNumber = numbers.last
        
        DebugLogger.log("Start Cleanup - \(numbers.count) Einträge gefunden, behalte Eintrag mit Nummer: \(lastNumber?.nummer ?? -1)", level: .info)
        
        // Lösche alle AUSSER dem letzten Eintrag
        for (index, number) in numbers.enumerated() {
            if index < numbers.count - 1 {
                DebugLogger.log("Lösche alten Eintrag: \(number.nummer)", level: .debug)
                context.delete(number)
            }
        }
        
        try context.save()
        
        // Überprüfung
        let remainingNumbers = try context.fetch(fetchRequest)
        DebugLogger.log("Nach Bereinigung - Anzahl Einträge: \(remainingNumbers.count)", level: .info)
        DebugLogger.log("Aktuelle Nummer: \(remainingNumbers.first?.nummer ?? -1)", level: .info)
    } catch {
        DebugLogger.log("Fehler beim Cleanup: \(error)", level: .error)
    }
  }
}

//#Preview {
//    ContentView()
//}
