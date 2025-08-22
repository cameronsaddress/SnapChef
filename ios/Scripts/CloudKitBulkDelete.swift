import SwiftUI
import CloudKit

// Add this temporary view to your app to delete all CloudKit data
struct CloudKitBulkDeleteView: View {
    @State private var isDeleting = false
    @State private var deletionProgress = ""
    @State private var totalDeleted = 0
    @State private var isDryRun = true
    @State private var showConfirmation = false
    
    let container = CKContainer.default()
    var database: CKDatabase { container.publicCloudDatabase }
    
    // Your CloudKit record types
    let recordTypes = [
        "User",
        "Recipe", 
        "Activity",
        "Challenge",
        "ChallengeProgress",
        "Achievement",
        "Leaderboard",
        "RecipeLike",
        "Team",
        "TeamMessage"
        // "UserProfile" removed - not a valid record type, use "User" instead
    ]
    
    var body: some View {
        VStack(spacing: 20) {
            Text("CloudKit Data Management")
                .font(.largeTitle)
                .bold()
            
            if isDeleting {
                ProgressView()
                Text(deletionProgress)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Deleted: \(totalDeleted) records")
                    .font(.headline)
            } else {
                VStack(spacing: 15) {
                    Toggle("Dry Run Mode", isOn: $isDryRun)
                        .padding(.horizontal)
                    
                    Text(isDryRun ? "Will show what would be deleted without actually deleting" : "⚠️ WILL DELETE ALL DATA")
                        .foregroundColor(isDryRun ? .secondary : .red)
                        .font(.caption)
                    
                    Button(action: {
                        if isDryRun {
                            startDeletion()
                        } else {
                            showConfirmation = true
                        }
                    }) {
                        Label(isDryRun ? "Preview Deletion" : "Delete All Data", 
                              systemImage: isDryRun ? "eye" : "trash")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isDryRun ? Color.blue : Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }
            }
            
            Spacer()
        }
        .padding()
        .alert("Confirm Deletion", isPresented: $showConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete Everything", role: .destructive) {
                startDeletion()
            }
        } message: {
            Text("This will permanently delete ALL CloudKit data. This cannot be undone. Are you absolutely sure?")
        }
    }
    
    func startDeletion() {
        Task {
            await deleteAllData()
        }
    }
    
    @MainActor
    func deleteAllData() async {
        isDeleting = true
        totalDeleted = 0
        
        for recordType in recordTypes {
            deletionProgress = "Processing \(recordType)..."
            let count = await deleteRecords(ofType: recordType)
            totalDeleted += count
        }
        
        deletionProgress = "Complete!"
        isDeleting = false
    }
    
    func deleteRecords(ofType recordType: String) async -> Int {
        var deletedCount = 0
        var cursor: CKQueryOperation.Cursor?
        
        repeat {
            do {
                let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
                
                let (matchResults, nextCursor) = try await database.records(
                    matching: query,
                    desiredKeys: nil,
                    resultsLimit: 100,
                    continuingMatchFrom: cursor
                )
                
                let recordIDs = matchResults.compactMap { result -> CKRecord.ID? in
                    guard case .success(let record) = result.1 else { return nil }
                    return record.recordID
                }
                
                if !recordIDs.isEmpty {
                    if isDryRun {
                        print("[DRY RUN] Would delete \(recordIDs.count) \(recordType) records")
                        deletedCount += recordIDs.count
                    } else {
                        // Actually delete the records
                        for recordID in recordIDs {
                            do {
                                _ = try await database.deleteRecord(withID: recordID)
                                deletedCount += 1
                                
                                // Update UI
                                await MainActor.run {
                                    self.totalDeleted += 1
                                }
                            } catch {
                                print("Failed to delete record: \(error)")
                            }
                        }
                    }
                }
                
                cursor = nextCursor
                
                // Small delay to avoid rate limiting
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                
            } catch {
                print("Error querying \(recordType): \(error)")
                break
            }
        } while cursor != nil
        
        print("Processed \(deletedCount) \(recordType) records")
        return deletedCount
    }
}

// To use this view, temporarily add it to your app:
// 1. Add this view to your ContentView or ProfileView
// 2. Run the app
// 3. Use the interface to delete data
// 4. Remove the view when done

// Example usage in ProfileView:
/*
.sheet(isPresented: $showingDeleteTool) {
    CloudKitBulkDeleteView()
}
*/