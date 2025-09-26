//
//  Persistence.swift
//  Feather
//
//  Created by samara on 10.04.2025.
//

import CoreData
import Foundation // Add this for FileManager and URL

// MARK: - Class
final class Storage: ObservableObject {
	static let shared = Storage()
	let container: NSPersistentContainer
	
	private let _name: String = "Feather"
	
	init(inMemory: Bool = false) {
		container = NSPersistentContainer(name: _name)
		
		let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
		let docsStoreURL = documentsDirectory.appendingPathComponent("Feather.sqlite")
		
		let libraryDirectory = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0].appendingPathComponent("Application Support")
		let libraryStoreURL = libraryDirectory.appendingPathComponent("Feather.sqlite")
		
		if inMemory {
			container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
		} else {
			var storeURL = docsStoreURL
			if !FileManager.default.fileExists(atPath: docsStoreURL.path) && FileManager.default.fileExists(atPath: libraryStoreURL.path) {
				do {
					try FileManager.default.copyItem(at: libraryStoreURL, to: docsStoreURL)
					
					let walURL = libraryStoreURL.appendingPathExtension("sqlite-wal")
					let docsWalURL = docsStoreURL.appendingPathExtension("sqlite-wal")
					if FileManager.default.fileExists(atPath: walURL.path) {
						try FileManager.default.copyItem(at: walURL, to: docsWalURL)
					}
					
					let shmURL = libraryStoreURL.appendingPathExtension("sqlite-shm")
					let docsShmURL = docsStoreURL.appendingPathExtension("sqlite-shm")
					if FileManager.default.fileExists(atPath: shmURL.path) {
						try FileManager.default.copyItem(at: shmURL, to: docsShmURL)
					}
					
					// Clean up old files
					try FileManager.default.removeItem(at: libraryStoreURL)
					if FileManager.default.fileExists(atPath: walURL.path) {
						try FileManager.default.removeItem(at: walURL)
					}
					if FileManager.default.fileExists(atPath: shmURL.path) {
						try FileManager.default.removeItem(at: shmURL)
					}
				} catch {
					print("Failed to migrate database: \(error)")
					storeURL = libraryStoreURL
				}
			}
			container.persistentStoreDescriptions.first!.url = storeURL
		}
		
		container.loadPersistentStores(completionHandler: { (storeDescription, error) in
			if let error = error as NSError? {
				fatalError("Unresolved error \(error), \(error.userInfo)")
			}
		})
		
		container.viewContext.automaticallyMergesChangesFromParent = true
	}
	
	var context: NSManagedObjectContext {
		container.viewContext
	}
	
	func saveContext() {
		DispatchQueue.main.async {
			if self.context.hasChanges {
				try? self.context.save()
			}
		}
	}
	
	func clearContext<T: NSManagedObject>(request: NSFetchRequest<T>) {
		let deleteRequest = NSBatchDeleteRequest(fetchRequest: (request as? NSFetchRequest<NSFetchRequestResult>)!)
		_ = try? context.execute(deleteRequest)
	}
	
	func countContent<T: NSManagedObject>(for type: T.Type) -> String {
		let request = T.fetchRequest()
		return "\((try? context.count(for: request)) ?? 0)"
	}
}
