//
//  NumberButton.swift
//  AutoNummern
//

import SwiftUI

/// Capsule-förmiger Button-Style für die Auto-Nummern-Auswahl.
/// Die Hintergrundfarbe signalisiert den Auswahlzustand
/// (z. B. grün für bereits erreichte, rot für noch nicht erreichte Nummern).
struct NumberButton: ButtonStyle {
    var background: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(minWidth: 60, minHeight: 60)
            .padding()
            .background(background)
            .foregroundStyle(.white)
            .clipShape(.capsule)
            .font(.title)
            .scaleEffect(configuration.isPressed ? 1.5 : 1)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}
