//
//  CloudSharingPrepareCoordinator.swift
//  AutoNummern
//

import CloudKit
import SwiftUI

/// Coordinator für `CloudSharingPrepareView` – schließt das SwiftUI .sheet
/// wenn der UICloudSharingController geschlossen wird.
final class CloudSharingPrepareCoordinator: NSObject, UICloudSharingControllerDelegate {
    let stack = CoreDataStack.shared
    let autonummer: CoreDataAutoNummer
    let dismiss: DismissAction
    var wrapper: UIViewController?
    var didPresent = false

    init(autonummer: CoreDataAutoNummer, dismiss: DismissAction) {
        self.autonummer = autonummer
        self.dismiss = dismiss
    }

    func itemTitle(for csc: UICloudSharingController) -> String? {
        "AktuelleAutonummer"
    }

    func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
        DebugLogger.log("Failed to save share: \(error)", level: .error)
        dismiss()
    }

    func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
        DebugLogger.log("Saved the share", level: .info)
        dismiss()
    }

    func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
        if !stack.isOwner(object: autonummer) {
            stack.delete(autonummer)
        }
        dismiss()
    }
}
