//
//  Settings.swift
//  books
//
//  Created by Andrew Bennet on 23/10/2016.
//  Copyright © 2016 Andrew Bennet. All rights reserved.
//

import UIKit
import Foundation
import SVProgressHUD
import SwiftyJSON
import CSVImporter

class Settings: UITableViewController, NavBarConfigurer, UIDocumentMenuDelegate, UIDocumentPickerDelegate {
    
    var navBarChangedDelegate: NavBarChangedDelegate!
    
    @IBOutlet weak var addTestDataCell: UITableViewCell!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        #if !DEBUG
            addTestDataCell.isHidden = true
        #endif
    }
    
    func configureNavBar(_ navBar: UINavigationItem) {
        // Configure the navigation item
        navBar.title = "Settings"
        navBar.rightBarButtonItem = nil
        navBar.leftBarButtonItem = nil
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        switch (indexPath.section, indexPath.row) {
        case (0, 0):
            // "About"
            UIApplication.shared.openUrlPlatformSpecific(url: URL(string: "https://andrewbennet.github.io/readinglist")!)
        case (0, 2):
            // "Rate"
            UIApplication.shared.openUrlPlatformSpecific(url: URL(string: "itms-apps://itunes.apple.com/app/\(appleAppId)")!)
            
        case (1, 0):
            exportData()
        case (1, 1):
            requestImport()
        case (1, 2):
            deleteAllData()
        case (1, 3):
            // "Use Test Data"
            #if DEBUG
                loadTestData()
            #endif
        default:
            break
        }
    }
    
    func deleteAllData() {
        
        // The CONFIRM DELETE action:
        let confirmDelete = UIAlertController(title: "Final Warning", message: "This action is irreversible. Are you sure you want to continue?", preferredStyle: .alert)
        confirmDelete.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
            appDelegate.booksStore.deleteAllData()
            // Relayout the tables. Their empty data sets sometimes are in the wrong place after deleting everything.
            // TODO: look into making this work better
            appDelegate.splitViewController.tabbedViewController.readingTabView.layoutSubviews()
            appDelegate.splitViewController.tabbedViewController.finishedTabView.layoutSubviews()
        })
        confirmDelete.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // The initial WARNING action
        let areYouSure = UIAlertController(title: "Warning", message: "This will delete all books saved in the application. Are you sure you want to continue?", preferredStyle: .alert)
        areYouSure.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
            self.present(confirmDelete, animated: true)
        })
        areYouSure.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        self.present(areYouSure, animated: true)
    }
    
    func exportData() {
        SVProgressHUD.show(withStatus: "Generating...")
        
        let exporter = CsvExporter(csvExport: Book.csvExport)
        
        appDelegate.booksStore.getAllAsync(callback: {
            exporter.addData($0)
            self.renderAndServeCsvExport(exporter)
        }, onFail: {
            NSLog($0.localizedDescription)
            SVProgressHUD.dismiss()
            SVProgressHUD.showError(withStatus: "Error collecting data.")
        })
    }
    
    func renderAndServeCsvExport(_ exporter: CsvExporter<Book>) {
        DispatchQueue.global(qos: .userInitiated).async {
            
            // Write the document to a temporary file
            let exportFileName = "Reading List Export - \(Date().toString(withDateFormat: "yyyy-MM-dd hh-mm")).csv"
            let temporaryFilePath = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(exportFileName)
            do {
                try exporter.write(to: temporaryFilePath)
            }
            catch {
                NSLog(error.localizedDescription)
                DispatchQueue.main.async {
                    SVProgressHUD.dismiss()
                    SVProgressHUD.showError(withStatus: "Error exporting data.")
                }
                return
            }
            
            // Present a dialog with the resulting file (presenting it on the main thread, of course)
            let activityViewController = UIActivityViewController(activityItems: [temporaryFilePath], applicationActivities: [])
            activityViewController.excludedActivityTypes = [
                UIActivityType.assignToContact, UIActivityType.saveToCameraRoll, UIActivityType.postToFlickr, UIActivityType.postToVimeo,
                UIActivityType.postToTencentWeibo, UIActivityType.postToTwitter, UIActivityType.postToFacebook, UIActivityType.openInIBooks
            ]
            
            DispatchQueue.main.async {
                SVProgressHUD.dismiss()
                self.present(activityViewController, animated: true, completion: nil)
            }
        }
    }
    
    func requestImport() {
        let documentImport = UIDocumentMenuViewController.init(documentTypes: ["public.comma-separated-values-text"], in: .import)
        documentImport.delegate = self
        self.present(documentImport, animated: true)
    }
    
    func documentMenu(_ documentMenu: UIDocumentMenuViewController, didPickDocumentPicker documentPicker: UIDocumentPickerViewController) {
        documentPicker.delegate = self
        self.present(documentPicker, animated: true, completion: nil)
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        SVProgressHUD.show(withStatus: "Importing")
        
        DispatchQueue.global(qos: .userInitiated).async {
            let importer = CSVImporter<(BookMetadata, BookReadingInformation)>(path: url.path)
            let importResults = importer.importRecords(structure: {_ in}, recordMapper: BookMetadata.csvImport)
            
            DispatchQueue.main.async {
                var duplicateBookCount = 0
                for importResult in importResults {
                    if let isbn13 = importResult.0.isbn13, appDelegate.booksStore.isbnExists(isbn13) {
                        duplicateBookCount += 1
                    }
                    else {
                        appDelegate.booksStore.create(from: importResult.0, readingInformation: importResult.1)
                    }
                }
                
                var statusMessage = "\(importResults.count - duplicateBookCount) books imported."
                if duplicateBookCount != 0 {
                    statusMessage += " \(duplicateBookCount) books ignored due to duplicate ISBN."
                }
                SVProgressHUD.showInfo(withStatus: statusMessage)
            }
        }
    }
    
    
    
    #if DEBUG
    func loadTestData() {
        
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        
        let testJsonData = JSON(data: NSData.fromMainBundle(resource: "example_books", type: "json") as Data)
        appDelegate.booksStore.deleteAllData()
        
        let requestDispatchGroup = DispatchGroup()
        var sortIndex = -1
        
        for testBook in testJsonData.array! {
            let parsedData = BookImport.fromJson(testBook)
            
            if parsedData.1.readState == .toRead {
                sortIndex += 1
            }
            let thisSort = sortIndex
            
            requestDispatchGroup.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                GoogleBooksAPI.supplementMetadataWithImage(parsedData.0) {
                    DispatchQueue.main.sync {
                        appDelegate.booksStore.create(from: parsedData.0, readingInformation: parsedData.1, bookSort: thisSort)
                        requestDispatchGroup.leave()
                    }
                }
            }
        }
        
        requestDispatchGroup.notify(queue: .main) {
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
        }
    }
    #endif
}
