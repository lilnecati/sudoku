//
//  PendingFirebaseOperation+CoreDataProperties.swift
//  Sudoku
//
//  Created by Necati Yıldırım on 29.01.2025.
//
//

import Foundation
import CoreData


extension PendingFirebaseOperation {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PendingFirebaseOperation> {
        return NSFetchRequest<PendingFirebaseOperation>(entityName: "PendingFirebaseOperation")
    }

    @NSManaged public var operationID: UUID?
    @NSManaged public var dataType: String?
    @NSManaged public var dataID: String?
    @NSManaged public var action: String?
    @NSManaged public var timestamp: Date?
    @NSManaged public var attemptCount: Int16
    @NSManaged public var lastAttemptTimestamp: Date?
    @NSManaged public var payload: Data?

}

extension PendingFirebaseOperation : Identifiable {

}
