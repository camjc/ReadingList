import Foundation
import CoreData

class BookMapping_14_15: NSEntityMigrationPolicy { //swiftlint:disable:this type_name

    @objc func currentPercentage(forCurrentPage currentPage: NSNumber?, totalPages: NSNumber?) -> NSNumber? {
        guard let currentPage = currentPage, let totalPages = totalPages else { return nil }
        guard currentPage.int32Value <= totalPages.int32Value else { return NSNumber(100) }
        let percentage = Int16(round((Float(currentPage.int32Value) / Float(totalPages.int32Value)) * 100))
        return NSNumber(value: percentage)
    }
}
