//
//  ContentView.swift
//  AutoNummern
//
//  Created by Kira Hennig on 22.12.23.
//

import SwiftUI
import UserNotifications

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
    @State private var selectedNumber: Int?
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
                                UserDefaults.standard.set(number, forKey: "selectedNumber")
                                print ("Button \(number) wurde gedrückt")
                            }
                            )
                            .buttonStyle(GreenButton())
                        } else {
                            Button("\(number)", action: {
                                selectedNumber = number
                                UserDefaults.standard.set(number, forKey: "selectedNumber1")
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
            if let number = UserDefaults.standard.value(forKey: "selectedNumber") as? Int {
                selectedNumber = number
            }
        }
    }
}

func requestAuthorization(options: UNAuthorizationOptions = []) async throws -> Bool

#Preview {
    ContentView()
}
