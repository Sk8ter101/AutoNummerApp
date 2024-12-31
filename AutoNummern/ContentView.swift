//
//  ContentView.swift
//  AutoNummern
//
//  Created by Kira Hennig on 22.12.23.
//

import SwiftUI
import UserNotifications
import CloudKit

struct RedButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 60, height: 60)
            .padding()
            .background(.red)
            .foregroundStyle(.white)
            .clipShape(Capsule())
            .font(.largeTitle)
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
            .font(.largeTitle)
            .scaleEffect(configuration.isPressed ? 1.5 : 1)
//            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
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
                                    let CoreNumber = CoreDataAutoNummer(context: managedObjectContext)
                                    CoreNumber.nummer = Int16(number)
                                    try? managedObjectContext.save()
                                    print ("Button \(number) wurde gedrückt")
                                  }
                                )
                                .buttonStyle(GreenButton())
                            } else {
                                Button("\(number)", action: {
                                    selectedNumber = number
                                    let CoreNumber = CoreDataAutoNummer(context: managedObjectContext)
                                    CoreNumber.nummer = Int16(number)
                                    try? managedObjectContext.save()
                                    print ("Button \(number) wurde gedrückt")
                                    print(FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask))
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
                if !stack.isShared(object: FetchedCoreNumber.first!) {
                    Task {
                        await createShare(FetchedCoreNumber.first!)
                    }
              }
              showShareSheet = true
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
            if FetchedCoreNumber.count == 0 {
                selectedNumber = 1
            } else {
                print ("AN_Debug \(Date().formatted(date: .omitted, time: .standard)): Anzahl Einträge :  \(FetchedCoreNumber.count)")
                print ("AN_Debug \(Date().formatted(date: .omitted, time: .standard)): Es wurde  \(FetchedCoreNumber[FetchedCoreNumber.count-1].nummer) eingelesen.")
                coreDataIndex = FetchedCoreNumber.count-1
                selectedNumber = Int(FetchedCoreNumber[coreDataIndex!].nummer)
                // Hier wird ausgegeben wer momentan die CoreData "shared"
                self.share = stack.getShare(FetchedCoreNumber.first!)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)
            .receive(on: DispatchQueue.main)) { _ in
                //fetchRemoteChanges()
                coreDataIndex = FetchedCoreNumber.count-1
                print ("AN_Debug \(Date().formatted(date: .omitted, time: .standard)): Notification eingetroffen. CoreDataIndex = \(coreDataIndex ?? 0). Aktuelle Nummer = \(selectedNumber ?? 0). FetchedCoreNumber = \(FetchedCoreNumber[coreDataIndex ?? 0].nummer)")
                    //selectedNumber = Int(CoreNumber[CoreNumber.count-1].nummer)
                managedObjectContext.perform {
                    do {
                        try managedObjectContext.save()
                    } catch {
                        print("AN_Debug \(Date().formatted(date: .omitted, time: .standard)): Failed to save changes: \(error.localizedDescription)")
                    }
                }
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
      fatalError("A new value added to CKShare.Participant.Permission")
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
      fatalError("A new value added to CKShare.Participant.Role")
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
      fatalError("A new value added to CKShare.Participant.AcceptanceStatus")
    }
  }
  
  private func createShare(_ autonummer: CoreDataAutoNummer) async {
    do {
      let (_, share, _) =
      try await stack.persistentContainer.share([autonummer], to: nil)
      share[CKShare.SystemFieldKey.title] = "AktuelleAutonummer"
      self.share = share
    } catch {
      print("Failed to create share")
    }
  }
}

//#Preview {
//    ContentView()
//}
