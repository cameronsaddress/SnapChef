import CoreData
import CloudKit

@MainActor
struct PersistenceController {
    static let shared = PersistenceController()

    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext

        // Add sample data for previews if needed
        do {
            try viewContext.save()
        } catch {
            // In preview mode, log error but don't crash
            print("Preview Core Data save error: \(error.localizedDescription)")
            // Preview data is transient, so failure is acceptable
        }
        return result
    }()

    let container: NSPersistentCloudKitContainer

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "ChallengeModels")

        if inMemory {
            guard let firstStoreDescription = container.persistentStoreDescriptions.first else {
                print("Warning: No persistent store descriptions found")
                return
            }
            firstStoreDescription.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // Configure for CloudKit
            container.persistentStoreDescriptions.forEach { storeDescription in
                storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
                storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
                storeDescription.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.com.snapchefapp.app")
            }
        }

        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                // In production, handle this error appropriately
                print("Core Data failed to load: \(error), \(error.userInfo)")

                // For development, we'll continue without persistence
                // This allows the app to run even if Core Data setup fails
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
