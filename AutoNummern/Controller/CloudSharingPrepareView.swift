//
//  CloudSharingPrepareView.swift
//  AutoNummern
//

import CloudKit
import SwiftUI

/// Wrapper-ViewController der den UICloudSharingController über die
/// UIKit-Präsentationskette anzeigt. UICloudSharingController funktioniert
/// nicht korrekt wenn er direkt als SwiftUI .sheet Content eingebettet wird –
/// der Preparation-Handler wird dann nie aufgerufen.
struct CloudSharingPrepareView: UIViewControllerRepresentable {
    let container: CKContainer
    let autonummer: CoreDataAutoNummer
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> CloudSharingPrepareCoordinator {
        CloudSharingPrepareCoordinator(autonummer: autonummer, dismiss: dismiss)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let wrapper = UIViewController()
        wrapper.view.backgroundColor = .clear
        context.coordinator.wrapper = wrapper
        return wrapper
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Präsentiere den UICloudSharingController sobald der Wrapper sichtbar ist.
        // Task @MainActor stellt sicher, dass der Wrapper komplett in
        // der View-Hierarchie eingehängt ist bevor wir darüber präsentieren.
        guard !context.coordinator.didPresent else { return }
        context.coordinator.didPresent = true

        let stack = CoreDataStack.shared
        let autonummer = self.autonummer
        let container = self.container
        let coordinator = context.coordinator

        Task { @MainActor in
            guard uiViewController.view.window != nil else {
                DebugLogger.log("Wrapper hat kein Window - kann Share Controller nicht präsentieren", level: .error)
                coordinator.didPresent = false
                return
            }

            let sharingController = UICloudSharingController { (_, preparationHandler: @escaping (CKShare?, CKContainer?, Error?) -> Void) in
                DebugLogger.log("Preparation-Handler aufgerufen - erstelle Share...", level: .info)
                Task { @MainActor in
                    do {
                        let (_, share, _) = try await stack.persistentContainer.share([autonummer], to: nil)
                        share[CKShare.SystemFieldKey.title] = "AktuelleAutonummer"
                        DebugLogger.log("Share über Preparation-Handler erstellt", level: .info)
                        DebugLogger.log("Share URL: \(share.url?.absoluteString ?? "keine URL")", level: .debug)
                        preparationHandler(share, container, nil)
                    } catch {
                        DebugLogger.log("Fehler beim Erstellen des Shares: \(error)", level: .error)
                        preparationHandler(nil, nil, error)
                    }
                }
            }

            sharingController.modalPresentationStyle = .formSheet
            sharingController.delegate = coordinator

            DebugLogger.log("Share Controller wird über UIKit präsentiert", level: .debug)
            uiViewController.present(sharingController, animated: true)
        }
    }
}
