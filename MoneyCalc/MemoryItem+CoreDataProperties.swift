//
//  MemoryItem+CoreDataProperties.swift
//  MoneyCalc
//
//  Created by Barry Hall on 2021-11-25.
//
//

import Foundation
import CoreData


extension MemoryItem {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<MemoryItem> {
        return NSFetchRequest<MemoryItem>(entityName: "MemoryItem")
    }

    @NSManaged public var name: String
    @NSManaged public var tagClass: Int
    @NSManaged public var tagIndex: Int
    @NSManaged public var value: Double

}

extension MemoryItem : Identifiable {

}
