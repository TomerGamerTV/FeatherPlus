//
//  Persistence.swift
//  Feather
//
//  Created by samara on 10.04.2025.
//

import CoreData
import Foundation

// MARK: - Storage
final class Storage: ObservableObject {
	static let shared = Storage()
	let container: NSPersistentContainer
	
	private let _name: String = "Feather"

	init(inMemory: Bool = false) {
		container = NSPersistentContainer(name: _name)

		if inMemory {
			container.persistentStoreDescriptions.first?.url =
				URL(fileURLWithPath: "/dev/null")
		} else {
			container.persistentStoreDescriptions.first?.url = _preparePersistentStoreURL()
		}

		_loadPersistentStoreAggressively()
		container.viewContext.automaticallyMergesChangesFromParent = true
		container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
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

	private func _preparePersistentStoreURL() -> URL {
		let fm = FileManager.default
		let documentsDirectory = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
		let docsStoreURL = documentsDirectory.appendingPathComponent("Feather.sqlite")
		let libraryDirectory = fm.urls(for: .libraryDirectory, in: .userDomainMask)[0]
			.appendingPathComponent("Application Support")
		let libraryStoreURL = libraryDirectory.appendingPathComponent("Feather.sqlite")

		guard !fm.fileExists(atPath: docsStoreURL.path),
			  fm.fileExists(atPath: libraryStoreURL.path) else {
			return docsStoreURL
		}

		do {
			try fm.copyItem(at: libraryStoreURL, to: docsStoreURL)

			let walURL = libraryStoreURL.appendingPathExtension("sqlite-wal")
			let docsWalURL = docsStoreURL.appendingPathExtension("sqlite-wal")
			if fm.fileExists(atPath: walURL.path) {
				try fm.copyItem(at: walURL, to: docsWalURL)
			}

			let shmURL = libraryStoreURL.appendingPathExtension("sqlite-shm")
			let docsShmURL = docsStoreURL.appendingPathExtension("sqlite-shm")
			if fm.fileExists(atPath: shmURL.path) {
				try fm.copyItem(at: shmURL, to: docsShmURL)
			}

			try fm.removeItem(at: libraryStoreURL)
			if fm.fileExists(atPath: walURL.path) {
				try fm.removeItem(at: walURL)
			}
			if fm.fileExists(atPath: shmURL.path) {
				try fm.removeItem(at: shmURL)
			}

			return docsStoreURL
		} catch {
			print("Failed to migrate database: \(error)")
			return libraryStoreURL
		}
	}

	private func _loadPersistentStoreAggressively() {
		container.loadPersistentStores { description, error in
			if error != nil {
				self._destroyStore(at: description.url)
				self.container.loadPersistentStores { _, error in
					if let error {
						fatalError("Core Data unrecoverable: \(error)")
					}
				}
			}
		}
	}

	private func _destroyStore(at url: URL?) {
		guard let url else { return }

		let base = url.deletingPathExtension()
		let fm = FileManager.default

		let files = [
			base.appendingPathExtension("sqlite"),
			base.appendingPathExtension("sqlite-wal"),
			base.appendingPathExtension("sqlite-shm")
		]

		for file in files {
			try? fm.removeItem(at: file)
		}
		
		try? FileManager.default.removeFileIfNeeded(at: FileManager.default.signed)
		try? FileManager.default.removeFileIfNeeded(at: FileManager.default.unsigned)
		try? FileManager.default.removeFileIfNeeded(at: FileManager.default.certificates)
		UserDefaults.standard.set(0, forKey: "feather.selectedCert")
	}
}
