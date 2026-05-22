//
//  CloudSharingView.swift
//  AutoNummern
//

import CloudKit
import SwiftUI

/// View für einen bereits existierenden Share (zum Verwalten von Teilnehmern).
struct CloudSharingView: UIViewControllerRepresentable {
    let share: CKShare
    let container: CKContainer
    let autonummer: CoreDataAutoNummer

    func makeCoordinator() -> CloudSharingCoordinator {
        CloudSharingCoordinator(autonummer: autonummer)
    }

    func makeUIViewController(context: Context) -> UICloudSharingController {
        share[CKShare.SystemFieldKey.title] = "AktuelleAutonummer"
        let controller = UICloudSharingController(share: share, container: container)
        controller.modalPresentationStyle = .formSheet
        controller.delegate = context.coordinator

        DebugLogger.log("Share Controller created (existierender Share)", level: .debug)
        DebugLogger.log("Share participants: \(share.participants.count)", level: .debug)

        return controller
    }

    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {
    }
}
