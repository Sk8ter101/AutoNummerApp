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
            .frame(width: 50, height: 50)
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
            .frame(width: 50, height: 50)
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
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(sortDescriptors: []) private var CoreNumber: FetchedResults<CoreDataAutoNummer>
    
    @State private var selectedNumber: Int?
    @State private var coreDataIndex: Int?
    @State private var isButtonPressed = false
    
    var body: some View {
        VStack {
            
            VStack {
                Text("Auto Nummern").font(.largeTitle)
                Text("by Kira").font(.caption).italic()
            }.padding(.top,100)
            Spacer()
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(1..<50,id : \.self) { number in
                        if (selectedNumber ?? 1 >= number) {
                            Button("\(number)", action: {
                                selectedNumber = number
                                //UserDefaults.standard.set(number, forKey: "selectedNumber")
                                let CoreNumber = CoreDataAutoNummer(context: viewContext)
                                CoreNumber.nummer = Int16(number)
                                try? viewContext.save()
                                print ("Button \(number) wurde gedrückt")
                            }
                            )
                            .buttonStyle(GreenButton())
                        } else {
                            Button("\(number)", action: {
                                selectedNumber = number
                                //UserDefaults.standard.set(number, forKey: "selectedNumber")
                                let CoreNumber = CoreDataAutoNummer(context: viewContext)
                                CoreNumber.nummer = Int16(number)
                                try? viewContext.save()
                                print ("Button \(number) wurde gedrückt")
                            }
                            )
                            .buttonStyle(RedButton())
                        }
                    }
                }
            }.padding(.bottom,150)
            Spacer()
        }
        .background(
            LinearGradient(gradient: Gradient(colors: [.white, .blue, .white]), startPoint: .top, endPoint: .bottom))
        .onAppear {
            if CoreNumber.count == 0 {
                selectedNumber = 11
            } else {
                print ("AN_Debug \(Date().formatted(date: .omitted, time: .standard)): Anzahl Einträge :  \(CoreNumber.count)")
                print ("AN_Debug \(Date().formatted(date: .omitted, time: .standard)): Es wurde  \(CoreNumber[CoreNumber.count-1].nummer) eingelesen.")
                coreDataIndex = CoreNumber.count-1
                selectedNumber = Int(CoreNumber[coreDataIndex ?? 0].nummer)
                
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)
            .receive(on: DispatchQueue.main)) { _ in
                //fetchRemoteChanges()
                coreDataIndex = CoreNumber.count-1
                print ("AN_Debug \(Date().formatted(date: .omitted, time: .standard)): Notification eingetroffen. CoreDataIndex = \(coreDataIndex ?? 0). Aktuelle Nummer = \(selectedNumber ?? 0). CoreNumber = \(CoreNumber[coreDataIndex ?? 0].nummer)")
                    //selectedNumber = Int(CoreNumber[CoreNumber.count-1].nummer)
                viewContext.perform {
                    do {
                        try viewContext.save()
                    } catch {
                        print("AN_Debug \(Date().formatted(date: .omitted, time: .standard)): Failed to save changes: \(error.localizedDescription)")
                    }
                }
            }
    }
}

#Preview {
    ContentView()
}
