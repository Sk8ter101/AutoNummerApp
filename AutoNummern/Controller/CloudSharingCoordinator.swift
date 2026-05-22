//
//  CloudSharingCoordinator.swift
//  AutoNummern
//

import CloudKit
import UIKit

final class CloudSharingCoordinator: NSObject, UICloudSharingControllerDelegate {
    let stack = CoreDataStack.shared
    let autonummer: CoreDataAutoNummer

    init(autonummer: CoreDataAutoNummer) {
        self.autonummer = autonummer
    }

    func itemTitle(for csc: UICloudSharingController) -> String? {
        "AktuelleAutonummer"
    }

    func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
        DebugLogger.log("Failed to save share: \(error)", level: .error)
    }

    func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
        DebugLogger.log("Saved the share", level: .info)
    }

    func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
        if !stack.isOwner(object: autonummer) {
            stack.delete(autonummer)
        }
    }
}
