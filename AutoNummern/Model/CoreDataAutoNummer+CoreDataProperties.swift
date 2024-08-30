//
//  CoreDataAutoNummer+CoreDataProperties.swift
//  AutoNummern
//
//  Created by Jörg-Olaf Hennig on 04.02.24.
//
//

import Foundation
import CoreData


extension CoreDataAutoNummer {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CoreDataAutoNummer> {
        return NSFetchRequest<CoreDataAutoNummer>(entityName: "CoreDataAutoNummer")
    }

    @NSManaged public var nummer: Int16

}

extension CoreDataAutoNummer : Identifiable {

}
