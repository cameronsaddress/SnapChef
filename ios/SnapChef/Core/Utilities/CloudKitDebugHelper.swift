import Foundation
import CloudKit

/// Debug helper for CloudKit development and troubleshooting
struct CloudKitDebugHelper {
    
    /// Test if CloudKit is available and accessible
    static func testCloudKitAvailability() async -> Bool {
        do {
            let container = CKContainer.default()
            let accountStatus = try await container.accountStatus()
            
            print("🔍 CloudKit Account Status: \(accountStatus)")
            
            switch accountStatus {
            case .available:
                print("✅ CloudKit is available")
                return true
            case .noAccount:
                print("❌ No iCloud account configured")
                return false
            case .restricted:
                print("❌ iCloud account is restricted")
                return false
            case .couldNotDetermine:
                print("❌ Could not determine iCloud account status")
                return false
            case .temporarilyUnavailable:
                print("⚠️ iCloud account temporarily unavailable")
                return false
            @unknown default:
                print("❓ Unknown iCloud account status")
                return false
            }
        } catch {
            print("❌ Error checking CloudKit availability: \(error)")
            return false
        }
    }
    
    /// Test user discovery queries individually
    static func testUserDiscoveryQueries() async {
        print("🧪 Testing CloudKit User Discovery Queries...")
        
        let container = CKContainer.default()
        let database = container.publicCloudDatabase
        
        // Test 1: Basic user query
        print("\n1️⃣ Testing basic user query...")
        await testQuery(
            database: database,
            recordType: CloudKitConfig.userRecordType,
            predicate: NSPredicate(format: "%K >= %d", CKField.User.totalPoints, 0),
            description: "Users with totalPoints >= 0"
        )
        
        // Test 2: Recent users query
        print("\n2️⃣ Testing recent users query...")
        let weekAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        await testQuery(
            database: database,
            recordType: CloudKitConfig.userRecordType,
            predicate: NSPredicate(format: "%K >= %@", CKField.User.lastActiveAt, weekAgo as NSDate),
            description: "Users active in last 7 days"
        )
        
        // Test 3: New users query
        print("\n3️⃣ Testing new users query...")
        let monthAgo = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        await testQuery(
            database: database,
            recordType: CloudKitConfig.userRecordType,
            predicate: NSPredicate(format: "%K >= %@", CKField.User.createdAt, monthAgo as NSDate),
            description: "Users created in last 30 days"
        )
        
        // Test 4: Username search query
        print("\n4️⃣ Testing username search query...")
        await testQuery(
            database: database,
            recordType: CloudKitConfig.userRecordType,
            predicate: NSPredicate(format: "%K BEGINSWITH[cd] %@", CKField.User.username, "chef"),
            description: "Usernames starting with 'chef'"
        )
        
        // Test 5: Activity query (if exists)
        print("\n5️⃣ Testing activity query...")
        await testQuery(
            database: database,
            recordType: CloudKitConfig.activityRecordType,
            predicate: NSPredicate(format: "TRUEPREDICATE"),
            description: "All activity records"
        )
    }
    
    private static func testQuery(database: CKDatabase, recordType: String, predicate: NSPredicate, description: String) async {
        do {
            let query = CKQuery(recordType: recordType, predicate: predicate)
            let operation = CKQueryOperation(query: query)
            operation.resultsLimit = 5 // Limit for testing
            
            var recordCount = 0
            var hasError = false
            
            operation.recordMatchedBlock = { _, result in
                switch result {
                case .success:
                    recordCount += 1
                case .failure(let error):
                    print("   ❌ Record error: \(error)")
                    hasError = true
                }
            }
            
            operation.queryResultBlock = { result in
                switch result {
                case .success:
                    if hasError {
                        print("   ⚠️ Query completed with some record errors")
                    } else {
                        print("   ✅ Query successful")
                    }
                    print("   📊 Found \(recordCount) records")
                case .failure(let error):
                    print("   ❌ Query failed: \(error)")
                    if let ckError = error as? CKError {
                        print("      Code: \(ckError.code.rawValue)")
                        print("      Description: \(ckError.localizedDescription)")
                    }
                }
            }
            
            await database.add(operation)
            
        } catch {
            print("   ❌ Failed to create query: \(error)")
        }
    }
    
    /// Check what fields are actually queryable by attempting queries
    static func checkFieldQueryability() async {
        print("🔍 Checking CloudKit field queryability...")
        
        let container = CKContainer.default()
        let database = container.publicCloudDatabase
        
        let userFields = [
            (CKField.User.username, "username"),
            (CKField.User.displayName, "displayName"),
            (CKField.User.authProvider, "authProvider"),
            (CKField.User.totalPoints, "totalPoints"),
            (CKField.User.createdAt, "createdAt"),
            (CKField.User.lastLoginAt, "lastLoginAt"),
            (CKField.User.lastActiveAt, "lastActiveAt")
        ]
        
        for (fieldName, description) in userFields {
            print("\n🧪 Testing field: \(description) (\(fieldName))")
            
            let testValue: Any
            if fieldName.contains("At") {
                testValue = Date().addingTimeInterval(-86400) as NSDate // 1 day ago
            } else if fieldName == CKField.User.totalPoints {
                testValue = 0
            } else {
                testValue = "test"
            }
            
            do {
                let predicate: NSPredicate
                if fieldName.contains("At") {
                    predicate = NSPredicate(format: "%K >= %@", fieldName, testValue as! NSDate)
                } else if fieldName == CKField.User.totalPoints {
                    predicate = NSPredicate(format: "%K >= %d", fieldName, testValue as! Int)
                } else {
                    predicate = NSPredicate(format: "%K BEGINSWITH[cd] %@", fieldName, testValue as! String)
                }
                
                let query = CKQuery(recordType: CloudKitConfig.userRecordType, predicate: predicate)
                let operation = CKQueryOperation(query: query)
                operation.resultsLimit = 1
                
                var queryCompleted = false
                var queryError: Error?
                
                operation.queryResultBlock = { result in
                    queryCompleted = true
                    switch result {
                    case .success:
                        print("   ✅ \(description) is queryable")
                    case .failure(let error):
                        queryError = error
                        print("   ❌ \(description) is NOT queryable: \(error)")
                    }
                }
                
                await database.add(operation)
                
            } catch {
                print("   ❌ \(description) query setup failed: \(error)")
            }
        }
    }
    
    /// Print current CloudKit configuration for debugging
    static func printCloudKitConfiguration() {
        print("📋 CloudKit Configuration:")
        print("   Container: \(CloudKitConfig.containerIdentifier)")
        print("   User Record Type: \(CloudKitConfig.userRecordType)")
        print("   Activity Record Type: \(CloudKitConfig.activityRecordType)")
        print("   Recipe Record Type: \(CloudKitConfig.recipeRecordType)")
        
        print("\n📋 User Fields:")
        print("   Username: \(CKField.User.username)")
        print("   Display Name: \(CKField.User.displayName)")
        print("   Total Points: \(CKField.User.totalPoints)")
        print("   Created At: \(CKField.User.createdAt)")
        print("   Last Active: \(CKField.User.lastActiveAt)")
    }
}

#if DEBUG
extension CloudKitDebugHelper {
    /// Development-only comprehensive CloudKit test
    static func runComprehensiveTest() async {
        print("🚀 Starting Comprehensive CloudKit Test...")
        
        // Test 1: Availability
        print("\n=== Test 1: CloudKit Availability ===")
        let isAvailable = await testCloudKitAvailability()
        
        guard isAvailable else {
            print("❌ CloudKit not available, stopping tests")
            return
        }
        
        // Test 2: Configuration
        print("\n=== Test 2: Configuration ===")
        printCloudKitConfiguration()
        
        // Test 3: Field Queryability
        print("\n=== Test 3: Field Queryability ===")
        await checkFieldQueryability()
        
        // Test 4: User Discovery
        print("\n=== Test 4: User Discovery Queries ===")
        await testUserDiscoveryQueries()
        
        print("\n🏁 Comprehensive CloudKit test completed!")
    }
}
#endif