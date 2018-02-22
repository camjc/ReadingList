import Foundation
import UIKit
import SVProgressHUD
import Fabric
import Crashlytics

class DataVC: UITableViewController, UIDocumentPickerDelegate, UIDocumentMenuDelegate {
    
    static let importIndexPath = IndexPath(row: 0, section: 1)
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch (indexPath.section, indexPath.row) {
        case (0, 0):
            exportData()
        case (DataVC.importIndexPath.section, DataVC.importIndexPath.row):
            requestImport()
        default:
            break
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    func requestImport() {
        let documentImport = UIDocumentMenuViewController(documentTypes: ["public.comma-separated-values-text"], in: .import)
        documentImport.delegate = self
        if let popPresenter = documentImport.popoverPresentationController {
            let cell = tableView(tableView, cellForRowAt: DataVC.importIndexPath)
            popPresenter.sourceRect = cell.frame
            popPresenter.sourceView = self.tableView
            popPresenter.permittedArrowDirections = .up
        }
        present(documentImport, animated: true)
    }
    
    func documentMenu(_ documentMenu: UIDocumentMenuViewController, didPickDocumentPicker documentPicker: UIDocumentPickerViewController) {
        documentPicker.delegate = self
        present(documentPicker, animated: true, completion: nil)
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        SVProgressHUD.show(withStatus: "Importing")
        UserEngagement.logEvent(.csvImport)
        
        BookCSVImporter().startImport(fromFileAt: Bundle.main.url(forResource: "examplebooks", withExtension: "csv")!) { results in
            var statusMessage = "\(results.success) books imported."
            
            if results.duplicate != 0 { statusMessage += " \(results.duplicate) rows ignored due pre-existing data." }
            if results.error != 0 { statusMessage += " \(results.error) rows ignored due to invalid data." }
            SVProgressHUD.showInfo(withStatus: statusMessage)
        }
    }
    
    func exportData() {
        UserEngagement.logEvent(.csvExport)
        SVProgressHUD.show(withStatus: "Generating...")
        
        let listNames = ObjectQuery<List>().sorted(\List.name).fetch(fromContext: PersistentStoreManager.container.viewContext).map{$0.name}
        let exporter = CsvExporter(csvExport: Book.BuildCsvExport(withLists: listNames))
        
        ObjectQuery<Book>().sorted(\Book.readState).sorted("sort").sorted(\Book.startedReading).sorted(\Book.finishedReading)
            .fetchAsync(fromContext: PersistentStoreManager.container.viewContext) {
            exporter.addData($0)
            self.renderAndServeCsvExport(exporter)
        }
    }
    
    func renderAndServeCsvExport(_ exporter: CsvExporter<Book>) {
        DispatchQueue.global(qos: .userInitiated).async {
            
            // Write the document to a temporary file
            let exportFileName = "Reading List - \(UIDevice.current.name) - \(Date().string(withDateFormat: "yyyy-MM-dd hh-mm")).csv"
            let temporaryFilePath = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(exportFileName)
            do {
                try exporter.write(to: temporaryFilePath)
            }
            catch {
                Crashlytics.sharedInstance().recordError(error)
                DispatchQueue.main.async {
                    SVProgressHUD.dismiss()
                    SVProgressHUD.showError(withStatus: "Error exporting data.")
                }
                return
            }

            
            // Present a dialog with the resulting file
            let activityViewController = UIActivityViewController(activityItems: [temporaryFilePath], applicationActivities: [])
            activityViewController.excludedActivityTypes = [
                UIActivityType.addToReadingList,
                UIActivityType.assignToContact, UIActivityType.saveToCameraRoll, UIActivityType.postToFlickr, UIActivityType.postToVimeo,
                UIActivityType.postToTencentWeibo, UIActivityType.postToTwitter, UIActivityType.postToFacebook, UIActivityType.openInIBooks
            ]
            
            if let popPresenter = activityViewController.popoverPresentationController {
                let cell = self.tableView.cellForRow(at: IndexPath(row: 0, section: 0))!
                popPresenter.sourceRect = cell.frame
                popPresenter.sourceView = self.tableView
                popPresenter.permittedArrowDirections = .any
            }
            
            DispatchQueue.main.async {
                SVProgressHUD.dismiss()
                self.present(activityViewController, animated: true, completion: nil)
            }
        }
    }
}