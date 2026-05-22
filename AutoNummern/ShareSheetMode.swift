//
//  ShareSheetMode.swift
//  AutoNummern
//

import CloudKit
import Foundation

/// Modi für das Share-Sheet. Ermöglicht `sheet(item:)` mit sicherem
/// Unwrapping statt mehrerer optionaler State-Variablen.
enum ShareSheetMode: Identifiable {
    case existing(share: CKShare, target: CoreDataAutoNummer)
    case new(target: CoreDataAutoNummer)

    var id: String {
        switch self {
        case .existing(let share, _): "existing-\(share.recordID.recordName)"
        case .new: "new"
        }
    }
}
