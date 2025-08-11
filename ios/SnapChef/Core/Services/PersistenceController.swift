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
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentCloudKitContainer

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "ChallengeModels")
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // Configure for CloudKit
            container.persistentStoreDescriptions.forEach { storeDescription in
                storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
                storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
                storeDescription.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.com.snapchefapp.app")
            }
        }
        
        container.loadPersistentStores { (storeDescription, error) in
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