/// Copyright (c) 2022 Razeware LLC
/// 
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
/// 
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
/// 
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
/// 
/// This project and source code may use libraries or frameworks that are
/// released under various Open-Source licenses. Use of those libraries and
/// frameworks are governed by their own individual licenses.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import CloudKit
import SwiftUI

/// View für einen bereits existierenden Share (zum Verwalten von Teilnehmern)
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
    // DispatchQueue.main.async stellt sicher, dass der Wrapper komplett in
    // der View-Hierarchie eingehängt ist bevor wir darüber präsentieren.
    guard !context.coordinator.didPresent else { return }
    context.coordinator.didPresent = true
    
    let stack = CoreDataStack.shared
    let autonummer = self.autonummer
    let container = self.container
    let coordinator = context.coordinator
    
    DispatchQueue.main.async {
      guard let presenter = uiViewController.view.window != nil ? uiViewController : nil else {
        DebugLogger.log("Wrapper hat kein Window - kann Share Controller nicht präsentieren", level: .error)
        coordinator.didPresent = false
        return
      }
      
      let sharingController = UICloudSharingController { (controller, preparationHandler: @escaping (CKShare?, CKContainer?, Error?) -> Void) in
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
      presenter.present(sharingController, animated: true)
    }
  }
}

/// Coordinator für CloudSharingPrepareView – schließt das SwiftUI .sheet
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
    return "AktuelleAutonummer"
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

final class CloudSharingCoordinator: NSObject, UICloudSharingControllerDelegate {
    let stack = CoreDataStack.shared
    let autonummer: CoreDataAutoNummer
    init(autonummer: CoreDataAutoNummer) {
    self.autonummer = autonummer
  }

    func itemTitle(for csc: UICloudSharingController) -> String? {
        return "AktuelleAutonummer"
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
