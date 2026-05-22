//
//  ContentView.swift
//  AutoNummern
//
//  Created by Kira Hennig on 22.12.23.
//

import SwiftUI
import CloudKit
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var managedObjectContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \CoreDataAutoNummer.nummer, ascending: true)]
    ) private var fetchedCoreNumbers: FetchedResults<CoreDataAutoNummer>

    @State private var selectedNumber: Int?
    @State private var shareSheetMode: ShareSheetMode?
    @ObservedObject private var stack = CoreDataStack.shared

    var body: some View {
        VStack {
            VStack {
                Text("Auto Nummern").font(.largeTitle)
                Text("by Kira").font(.caption).italic()
            }
            .padding(.top, 64)

            Spacer()

            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 10) {
                        ForEach(1..<200, id: \.self) { number in
                            Button("\(number)") {
                                select(number)
                            }
                            .buttonStyle(NumberButton(
                                background: (selectedNumber ?? 1) >= number ? .green : .red
                            ))
                        }
                    }
                    .padding(.bottom)
                    .onAppear {
                        proxy.scrollTo(selectedNumber ?? 1, anchor: .center)
                    }
                }
                .scrollIndicators(.hidden)
            }

            Spacer()

            Button("Teilen", systemImage: "square.and.arrow.up", action: openShareSheet)
                .labelStyle(.iconOnly)
                .disabled(shareSheetMode != nil)
        }
        .sheet(item: $shareSheetMode) { mode in
            switch mode {
            case .existing(let share, let target):
                CloudSharingView(
                    share: share,
                    container: stack.ckContainer,
                    autonummer: target
                )
            case .new(let target):
                CloudSharingPrepareView(
                    container: stack.ckContainer,
                    autonummer: target
                )
            }
        }
        .background(
            LinearGradient(gradient: Gradient(colors: [.white, .blue, .white]), startPoint: .top, endPoint: .bottom)
        )
        .alert("Neustart erforderlich", isPresented: $stack.needsManualRestart) {
        } message: {
            Text("Die iCloud-Daten wurden zurückgesetzt. Bitte beende die App vollständig und starte sie erneut, damit die Synchronisation neu aufgebaut werden kann.")
        }
        .task {
            await observeRemoteChanges()
        }
        .onAppear(perform: setup)
    }

    // MARK: - Aktionen

    private func select(_ number: Int) {
        selectedNumber = number
        saveNumber(Int16(number))
    }

    private func openShareSheet() {
        guard let target = canonicalNumber() else {
            DebugLogger.log("Kein Datensatz zum Teilen vorhanden", level: .warning)
            return
        }

        if stack.isShared(object: target), let existingShare = stack.getShare(target) {
            DebugLogger.log("Existierender Share geladen mit \(existingShare.participants.count) Teilnehmern", level: .info)
            shareSheetMode = .existing(share: existingShare, target: target)
        } else {
            DebugLogger.log("Neuer Share wird über Preparation-Handler erstellt", level: .info)
            shareSheetMode = .new(target: target)
        }
    }

    // MARK: - Lebenszyklus

    private func setup() {
        cleanupCoreData()

        guard !fetchedCoreNumbers.isEmpty else {
            selectedNumber = 1
            DebugLogger.log("Keine Einträge gefunden, setze selectedNumber = 1", level: .debug)
            return
        }

        let canonical = canonicalNumber()
        DebugLogger.logCoreDataStatus(
            count: fetchedCoreNumbers.count,
            lastNumber: Int(canonical?.nummer ?? 0)
        )
        selectedNumber = Int(canonical?.nummer ?? 1)

        if let canonical {
            let shared = stack.isShared(object: canonical)
            DebugLogger.log(shared ? "Objekt ist bereits geteilt" : "Objekt ist nicht geteilt", level: .info)
        }
    }

    /// Beobachtet Remote-Change-Notifications vom Persistent Store mit
    /// einer 2-Sekunden-Debounce. Bricht laufende Debounce-Tasks ab, wenn
    /// neue Notifications eintreffen, und reagiert mit `applyRemoteChange()`.
    private func observeRemoteChanges() async {
        var debounce: Task<Void, Never>?
        for await _ in NotificationCenter.default.notifications(named: .NSPersistentStoreRemoteChange) {
            debounce?.cancel()
            debounce = Task { @MainActor in
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                applyRemoteChange()
            }
        }
    }

    private func applyRemoteChange() {
        guard let canonical = canonicalNumber() else { return }
        let newNumber = Int(canonical.nummer)
        if selectedNumber != newNumber {
            DebugLogger.log("Nummer von anderem Gerät aktualisiert: \(selectedNumber ?? 0) → \(newNumber)", level: .info)
            selectedNumber = newNumber
        }
    }

    // MARK: - Core Data

    /// Bevorzugt den Datensatz mit aktivem CKShare als kanonische Quelle,
    /// fällt sonst auf den Eintrag mit der höchsten Nummer zurück.
    private func canonicalNumber() -> CoreDataAutoNummer? {
        let entries = Array(fetchedCoreNumbers)
        return stack.sharedObject(in: entries) ?? entries.last
    }

    private func saveNumber(_ number: Int16) {
        let context = managedObjectContext
        let fetchRequest: NSFetchRequest<CoreDataAutoNummer> = CoreDataAutoNummer.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \CoreDataAutoNummer.nummer, ascending: true)]

        do {
            let existingNumbers = try context.fetch(fetchRequest)

            if let target = stack.sharedObject(in: existingNumbers) ?? existingNumbers.last {
                target.nummer = number
                DebugLogger.log("Nummer aktualisiert: \(number)", level: .info)
            } else {
                let newNumber = CoreDataAutoNummer(context: context)
                newNumber.nummer = number
                DebugLogger.log("Neue Nummer erstellt: \(number)", level: .info)
            }

            try context.save()
            cleanupCoreData(in: context)
        } catch {
            DebugLogger.log("Fehler beim Speichern: \(error)", level: .error)
        }
    }

    private func cleanupCoreData() {
        cleanupCoreData(in: managedObjectContext)
    }

    /// Löscht alle Datensätze außer dem geteilten (falls vorhanden) bzw. dem
    /// Eintrag mit der höchsten Nummer. So bleibt die Share-Verbindung auch
    /// nach Sync-Duplikaten erhalten.
    private func cleanupCoreData(in context: NSManagedObjectContext) {
        let fetchRequest: NSFetchRequest<CoreDataAutoNummer> = CoreDataAutoNummer.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \CoreDataAutoNummer.nummer, ascending: true)]

        do {
            let numbers = try context.fetch(fetchRequest)

            guard numbers.count > 1 else {
                DebugLogger.log("Nur ein oder kein Eintrag vorhanden - kein Cleanup nötig", level: .info)
                return
            }

            let keeper = stack.sharedObject(in: numbers) ?? numbers.last
            DebugLogger.log("Start Cleanup - \(numbers.count) Einträge gefunden, behalte Eintrag mit Nummer: \(keeper?.nummer ?? -1)", level: .info)

            for number in numbers where number != keeper {
                DebugLogger.log("Lösche alten Eintrag: \(number.nummer)", level: .debug)
                context.delete(number)
            }

            try context.save()

            let remainingNumbers = try context.fetch(fetchRequest)
            DebugLogger.log("Nach Bereinigung - Anzahl Einträge: \(remainingNumbers.count)", level: .info)
            DebugLogger.log("Aktuelle Nummer: \(remainingNumbers.first?.nummer ?? -1)", level: .info)
        } catch {
            DebugLogger.log("Fehler beim Cleanup: \(error)", level: .error)
        }
    }
}


