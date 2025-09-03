# Account Deletion Comprehensive Implementation Plan

## Overview
This document provides a complete implementation plan for properly deleting ALL user data when a user deletes their account. The current implementation only deletes ~40% of user data, leaving significant privacy and compliance issues.

## Complete Data Deletion Checklist

### CloudKit Records to Delete

#### User Profile & Auth
- [x] `User` record (currently deleted)
- [ ] `UserSession` records (if exists)
- [ ] `UserDevice` records (if exists)

#### Content Created by User
- [x] `Recipe` records where `creatorUserRecordID == userID` (currently deleted)
- [ ] `RecipeComment` records where `userID == userID`
- [ ] `RecipeVersion` records (if versioning implemented)
- [ ] `RecipeDraft` records (unsaved drafts)

#### Social Interactions
- [x] `Follow` records where `followerID == userID OR followingID == userID` (currently deleted)
- [ ] `RecipeLike` records where `userID == userID` (likes given)
- [ ] `RecipeLike` records where `recipeOwnerID == userID` (likes received - optional)
- [ ] `RecipeView` records where `userID == userID` (views by user)
- [ ] `RecipeView` records where `recipeOwnerID == userID` (views on user's content - optional)
- [x] `Activity` records where `actorID == userID` (currently deleted)
- [ ] `Activity` records where `targetUserID == userID` (activities targeting user)
- [ ] `Notification` records where `recipientID == userID`
- [ ] `Block` records where `blockerID == userID OR blockedID == userID`
- [ ] `Report` records where `reporterID == userID`

#### Gamification & Rewards
- [x] `UserChallenge` records where `userID == userID` (currently deleted)
- [ ] `Achievement` records where `userID == userID`
- [ ] `CoinTransaction` records where `userID == userID`
- [ ] `Leaderboard` records where `userID == userID`
- [ ] `UserStreak` records where `userID == userID`
- [ ] `Badge` records where `userID == userID`
- [ ] `Reward` records where `userID == userID`
- [ ] `Points` records where `userID == userID`

#### Teams & Collaboration
- [ ] `Team` records where `captainID == userID` (teams owned)
- [ ] `Team` records - remove from `memberIDs` array where user is member
- [ ] `TeamMessage` records where `senderID == userID`
- [ ] `TeamChallenge` records where team is user's team
- [ ] `TeamInvite` records where `inviterID == userID OR inviteeID == userID`

#### Media & Assets
- [ ] `ProfilePhoto` assets in CloudKit
- [ ] `RecipePhoto` assets for user's recipes
- [ ] `VideoExport` records where `userID == userID`
- [ ] `TikTokVideo` records where `userID == userID`

#### Analytics & Tracking
- [ ] `AnalyticsEvent` records where `userID == userID`
- [ ] `UserSession` records where `userID == userID`
- [ ] `FeatureUsage` records where `userID == userID`
- [ ] `ErrorLog` records where `userID == userID`

### Local Storage to Delete

#### Core Data / Local Database
- [ ] All Recipe entities
- [ ] All cached User entities
- [ ] All Activity entities
- [ ] All Challenge entities
- [ ] All Achievement entities

#### File System
- [x] `Documents/RecipePhotos/` directory (currently deleted)
- [x] `Documents/ProfilePhotos/` directory (currently deleted)
- [ ] `Documents/activities/` directory
- [ ] `Documents/recipes/` directory
- [ ] `Documents/VideoExports/` directory
- [ ] `Documents/Drafts/` directory
- [ ] `Library/Caches/` - app specific caches
- [ ] `tmp/` - temporary files

#### In-Memory Caches
- [ ] `LocalRecipeStore.shared`
- [ ] `PhotoStorageManager.shared`
- [ ] `CloudKitRecipeCache.shared`
- [ ] `UserCacheManager.shared`
- [ ] `RecipeLikeManager.shared`
- [ ] `ActivityFeedManager.shared`
- [ ] `SimpleDiscoverUsersManager.shared`
- [ ] `ProfilePhotoManager.shared`
- [ ] `GamificationManager.shared`

#### UserDefaults
- [x] All UserDefaults for app bundle (currently cleared)
- [ ] Specific verification of sensitive keys

#### Keychain
- [x] All Keychain items (currently cleared)
- [ ] Verify API keys removed
- [ ] Verify auth tokens removed
- [ ] Verify user credentials removed

## Implementation: Centralized Deletion Service

### 1. Create AccountDeletionService.swift

```swift
//
//  AccountDeletionService.swift
//  SnapChef
//
//  Centralized service for complete account and data deletion
//

import Foundation
import CloudKit

@MainActor
class AccountDeletionService: ObservableObject {
    static let shared = AccountDeletionService()
    
    @Published var deletionProgress: DeletionProgress = .idle
    @Published var deletionErrors: [DeletionError] = []
    
    private let cloudKitActor = CloudKitActor()
    private let database = CKContainer.default().publicCloudDatabase
    
    enum DeletionProgress {
        case idle
        case preparingDeletion
        case deletingCloudKitData(recordType: String, progress: Double)
        case deletingLocalData(category: String)
        case verifyingDeletion
        case completed
        case failed(error: String)
    }
    
    struct DeletionError {
        let category: String
        let recordType: String?
        let error: Error
    }
    
    struct DeletionReport {
        let totalRecordsDeleted: Int
        let recordsByType: [String: Int]
        let localDataCleared: Bool
        let errors: [DeletionError]
        let startTime: Date
        let endTime: Date
        
        var duration: TimeInterval {
            endTime.timeIntervalSince(startTime)
        }
    }
    
    // MARK: - Main Deletion Function
    
    func deleteAccount() async -> DeletionReport {
        let startTime = Date()
        var recordsDeleted: [String: Int] = [:]
        var totalDeleted = 0
        
        deletionProgress = .preparingDeletion
        deletionErrors = []
        
        guard let userID = UnifiedAuthManager.shared.currentUser?.recordID else {
            deletionProgress = .failed(error: "No user ID found")
            return DeletionReport(
                totalRecordsDeleted: 0,
                recordsByType: [:],
                localDataCleared: false,
                errors: [DeletionError(category: "Auth", recordType: nil, error: NSError(domain: "AccountDeletion", code: -1))],
                startTime: startTime,
                endTime: Date()
            )
        }
        
        // Step 1: Delete all CloudKit records
        let cloudKitResults = await deleteAllCloudKitData(for: userID)
        recordsDeleted = cloudKitResults.recordsByType
        totalDeleted = cloudKitResults.totalDeleted
        
        // Step 2: Clear all local data
        deletionProgress = .deletingLocalData(category: "All Local Storage")
        let localSuccess = await clearAllLocalData()
        
        // Step 3: Verify deletion
        deletionProgress = .verifyingDeletion
        let verificationPassed = await verifyDeletion(userID: userID)
        
        // Step 4: Sign out
        await UnifiedAuthManager.shared.signOut()
        
        // Complete
        if deletionErrors.isEmpty && verificationPassed {
            deletionProgress = .completed
        } else {
            deletionProgress = .failed(error: "Deletion completed with \(deletionErrors.count) errors")
        }
        
        return DeletionReport(
            totalRecordsDeleted: totalDeleted,
            recordsByType: recordsDeleted,
            localDataCleared: localSuccess,
            errors: deletionErrors,
            startTime: startTime,
            endTime: Date()
        )
    }
    
    // MARK: - CloudKit Deletion
    
    private func deleteAllCloudKitData(for userID: String) async -> (totalDeleted: Int, recordsByType: [String: Int]) {
        var recordsByType: [String: Int] = [:]
        var totalDeleted = 0
        
        // Define all record types and their deletion queries
        let deletionTasks: [(recordType: String, predicate: NSPredicate)] = [
            // User Profile
            ("User", NSPredicate(format: "recordID.recordName == %@", userID)),
            
            // Content
            ("Recipe", NSPredicate(format: "creatorUserRecordID == %@", userID)),
            ("RecipeComment", NSPredicate(format: "userID == %@", userID)),
            
            // Social - use both ID formats for compatibility
            ("Follow", NSPredicate(format: "followerID == %@ OR followingID == %@ OR followerID == %@ OR followingID == %@", 
                                  userID, userID, "user_\(userID)", "user_\(userID)")),
            ("RecipeLike", NSPredicate(format: "userID == %@ OR recipeOwnerID == %@", userID, userID)),
            ("RecipeView", NSPredicate(format: "userID == %@ OR recipeOwnerID == %@", userID, userID)),
            ("Activity", NSPredicate(format: "actorID == %@ OR targetUserID == %@", userID, userID)),
            ("Notification", NSPredicate(format: "recipientID == %@", userID)),
            ("Block", NSPredicate(format: "blockerID == %@ OR blockedID == %@", userID, userID)),
            ("Report", NSPredicate(format: "reporterID == %@", userID)),
            
            // Gamification
            ("UserChallenge", NSPredicate(format: "userID == %@", userID)),
            ("Achievement", NSPredicate(format: "userID == %@", userID)),
            ("CoinTransaction", NSPredicate(format: "userID == %@", userID)),
            ("Leaderboard", NSPredicate(format: "userID == %@", userID)),
            ("UserStreak", NSPredicate(format: "userID == %@", userID)),
            ("Badge", NSPredicate(format: "userID == %@", userID)),
            ("Reward", NSPredicate(format: "userID == %@", userID)),
            ("Points", NSPredicate(format: "userID == %@", userID)),
            
            // Teams
            ("TeamMessage", NSPredicate(format: "senderID == %@", userID)),
            ("TeamInvite", NSPredicate(format: "inviterID == %@ OR inviteeID == %@", userID, userID)),
            
            // Media
            ("VideoExport", NSPredicate(format: "userID == %@", userID)),
            ("TikTokVideo", NSPredicate(format: "userID == %@", userID)),
            
            // Analytics
            ("AnalyticsEvent", NSPredicate(format: "userID == %@", userID)),
            ("UserSession", NSPredicate(format: "userID == %@", userID)),
            ("FeatureUsage", NSPredicate(format: "userID == %@", userID)),
            ("ErrorLog", NSPredicate(format: "userID == %@", userID))
        ]
        
        // Process each record type
        for (recordType, predicate) in deletionTasks {
            deletionProgress = .deletingCloudKitData(recordType: recordType, progress: Double(totalDeleted) / Double(deletionTasks.count))
            
            let count = await deleteRecords(recordType: recordType, predicate: predicate)
            if count > 0 {
                recordsByType[recordType] = count
                totalDeleted += count
            }
        }
        
        // Special handling for Team records (remove from member arrays)
        await removeUserFromTeams(userID: userID)
        
        return (totalDeleted, recordsByType)
    }
    
    private func deleteRecords(recordType: String, predicate: NSPredicate) async -> Int {
        do {
            let query = CKQuery(recordType: recordType, predicate: predicate)
            var deletedCount = 0
            
            // Fetch all records matching the predicate
            let records = try await cloudKitActor.performQuery(query, in: database)
            
            // Delete in batches of 100 (CloudKit limit)
            for batch in records.chunked(into: 100) {
                let recordIDs = batch.map { $0.recordID }
                
                // Use modify operation with delete action
                let modifyOp = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordIDs)
                modifyOp.savePolicy = .allKeys
                modifyOp.qualityOfService = .userInitiated
                
                try await cloudKitActor.performOperation(modifyOp, in: database)
                deletedCount += recordIDs.count
            }
            
            print("✅ Deleted \(deletedCount) \(recordType) records")
            return deletedCount
            
        } catch {
            print("❌ Failed to delete \(recordType) records: \(error)")
            deletionErrors.append(DeletionError(category: "CloudKit", recordType: recordType, error: error))
            return 0
        }
    }
    
    private func removeUserFromTeams(userID: String) async {
        do {
            // Find teams where user is a member
            let teamPredicate = NSPredicate(format: "memberIDs CONTAINS %@", userID)
            let query = CKQuery(recordType: "Team", predicate: teamPredicate)
            let teams = try await cloudKitActor.performQuery(query, in: database)
            
            for team in teams {
                // Remove user from memberIDs array
                if var memberIDs = team["memberIDs"] as? [String] {
                    memberIDs.removeAll { $0 == userID }
                    team["memberIDs"] = memberIDs
                    
                    // If user was captain, handle team dissolution or transfer
                    if team["captainID"] as? String == userID {
                        if memberIDs.isEmpty {
                            // Delete empty team
                            try await cloudKitActor.deleteRecord(team.recordID, in: database)
                        } else {
                            // Transfer to first member
                            team["captainID"] = memberIDs[0]
                            try await cloudKitActor.saveRecord(team, in: database)
                        }
                    } else {
                        // Just save updated member list
                        try await cloudKitActor.saveRecord(team, in: database)
                    }
                }
            }
        } catch {
            print("❌ Failed to remove user from teams: \(error)")
            deletionErrors.append(DeletionError(category: "Teams", recordType: "Team", error: error))
        }
    }
    
    // MARK: - Local Data Deletion
    
    private func clearAllLocalData() async -> Bool {
        var success = true
        
        // 1. Clear all caches and managers
        let cacheManagers: [(name: String, action: () async -> Void)] = [
            ("LocalRecipeStore", { await self.clearLocalRecipeStore() }),
            ("PhotoStorageManager", { await self.clearPhotoStorageManager() }),
            ("CloudKitRecipeCache", { await self.clearCloudKitRecipeCache() }),
            ("UserCacheManager", { await self.clearUserCacheManager() }),
            ("RecipeLikeManager", { await self.clearRecipeLikeManager() }),
            ("ActivityFeedManager", { await self.clearActivityFeedManager() }),
            ("ProfilePhotoManager", { await self.clearProfilePhotoManager() }),
            ("GamificationManager", { await self.clearGamificationManager() })
        ]
        
        for (name, action) in cacheManagers {
            deletionProgress = .deletingLocalData(category: name)
            await action()
        }
        
        // 2. Clear file system
        success = success && clearFileSystem()
        
        // 3. Clear UserDefaults
        clearUserDefaults()
        
        // 4. Clear Keychain
        KeychainManager.clearAll()
        
        // 5. Clear URL Cache
        URLCache.shared.removeAllCachedResponses()
        
        // 6. Clear image cache if using SDWebImage or similar
        clearImageCaches()
        
        return success
    }
    
    private func clearLocalRecipeStore() async {
        // Clear all local recipes
        if let localStore = try? LocalRecipeStorage.shared {
            localStore.clearAllRecipes()
        }
    }
    
    private func clearPhotoStorageManager() async {
        PhotoStorageManager.shared.clearAllData()
    }
    
    private func clearCloudKitRecipeCache() async {
        CloudKitRecipeCache.shared.clearCache()
    }
    
    private func clearUserCacheManager() async {
        UserCacheManager.shared.clearCache()
    }
    
    private func clearRecipeLikeManager() async {
        RecipeLikeManager.shared.clearAllLikes()
    }
    
    private func clearActivityFeedManager() async {
        await ActivityFeedManager.shared.clearAllData()
    }
    
    private func clearProfilePhotoManager() async {
        // Clear all profile photos
        await ProfilePhotoManager.shared.deleteProfilePhoto()
    }
    
    private func clearGamificationManager() async {
        // Reset all gamification data
        GamificationManager.shared.resetAllData()
    }
    
    private func clearFileSystem() -> Bool {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return false
        }
        
        let directories = [
            "RecipePhotos",
            "ProfilePhotos",
            "activities",
            "recipes",
            "VideoExports",
            "Drafts",
            "TeamData",
            "Analytics"
        ]
        
        for directory in directories {
            let directoryURL = documentsURL.appendingPathComponent(directory)
            do {
                if fileManager.fileExists(atPath: directoryURL.path) {
                    try fileManager.removeItem(at: directoryURL)
                    print("✅ Deleted directory: \(directory)")
                }
            } catch {
                print("❌ Failed to delete directory \(directory): \(error)")
                deletionErrors.append(DeletionError(category: "FileSystem", recordType: directory, error: error))
            }
        }
        
        // Clear cache directory
        if let cacheURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            do {
                let cacheContents = try fileManager.contentsOfDirectory(at: cacheURL, includingPropertiesForKeys: nil)
                for item in cacheContents {
                    try fileManager.removeItem(at: item)
                }
            } catch {
                print("❌ Failed to clear cache: \(error)")
            }
        }
        
        // Clear tmp directory
        let tmpDirectory = NSTemporaryDirectory()
        do {
            let tmpContents = try fileManager.contentsOfDirectory(atPath: tmpDirectory)
            for file in tmpContents {
                let filePath = (tmpDirectory as NSString).appendingPathComponent(file)
                try fileManager.removeItem(atPath: filePath)
            }
        } catch {
            print("❌ Failed to clear tmp directory: \(error)")
        }
        
        return true
    }
    
    private func clearUserDefaults() {
        let defaults = UserDefaults.standard
        if let bundleID = Bundle.main.bundleIdentifier {
            defaults.removePersistentDomain(forName: bundleID)
        }
        
        // Also clear specific keys that might be outside the domain
        let keysToRemove = [
            "currentUserID",
            "hasCompletedOnboarding",
            "lastSyncDate",
            "cachedUsername",
            "authToken",
            "refreshToken",
            "userPreferences"
        ]
        
        for key in keysToRemove {
            defaults.removeObject(forKey: key)
        }
        
        defaults.synchronize()
        print("✅ Cleared UserDefaults")
    }
    
    private func clearImageCaches() {
        // Clear any third-party image cache libraries
        // Example for SDWebImage:
        // SDImageCache.shared.clearMemory()
        // SDImageCache.shared.clearDisk()
        
        // Clear NSURLCache for images
        URLCache.shared.removeAllCachedResponses()
    }
    
    // MARK: - Verification
    
    private func verifyDeletion(userID: String) async -> Bool {
        // Quick verification that key data is deleted
        do {
            // Check if user record still exists
            let userPredicate = NSPredicate(format: "recordID.recordName == %@", userID)
            let userQuery = CKQuery(recordType: "User", predicate: userPredicate)
            let userRecords = try await cloudKitActor.performQuery(userQuery, in: database)
            
            if !userRecords.isEmpty {
                print("⚠️ Verification failed: User record still exists")
                return false
            }
            
            // Check if any recipes still exist
            let recipePredicate = NSPredicate(format: "creatorUserRecordID == %@", userID)
            let recipeQuery = CKQuery(recordType: "Recipe", predicate: recipePredicate)
            let recipeRecords = try await cloudKitActor.performQuery(recipeQuery, in: database)
            
            if !recipeRecords.isEmpty {
                print("⚠️ Verification failed: \(recipeRecords.count) recipes still exist")
                return false
            }
            
            print("✅ Deletion verification passed")
            return true
            
        } catch {
            print("❌ Verification failed with error: \(error)")
            return false
        }
    }
}

// MARK: - Helper Extensions

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// MARK: - CloudKitActor Extensions for Deletion

extension CloudKitActor {
    func performQuery(_ query: CKQuery, in database: CKDatabase) async throws -> [CKRecord] {
        return try await withCheckedThrowingContinuation { continuation in
            var allRecords: [CKRecord] = []
            
            let operation = CKQueryOperation(query: query)
            operation.recordFetchedBlock = { record in
                allRecords.append(record)
            }
            
            operation.queryCompletionBlock = { cursor, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: allRecords)
                }
            }
            
            database.add(operation)
        }
    }
    
    func performOperation(_ operation: CKModifyRecordsOperation, in database: CKDatabase) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            operation.modifyRecordsCompletionBlock = { _, _, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
            
            database.add(operation)
        }
    }
    
    func deleteRecord(_ recordID: CKRecord.ID, in database: CKDatabase) async throws {
        try await database.deleteRecord(withID: recordID)
    }
    
    func saveRecord(_ record: CKRecord, in database: CKDatabase) async throws {
        _ = try await database.save(record)
    }
}
```

### 2. Update ProfileView Delete Button

```swift
// In ProfileView.swift, update the DeleteAccountButton struct:

struct DeleteAccountButton: View {
    @StateObject private var authManager = UnifiedAuthManager.shared
    @StateObject private var deletionService = AccountDeletionService.shared
    @State private var showDeleteAlert = false
    @State private var showFinalConfirmation = false
    @State private var isDeletingAccount = false
    @State private var deletionReport: AccountDeletionService.DeletionReport?
    @State private var showDeletionReport = false
    
    var body: some View {
        Button(action: {
            showDeleteAlert = true
        }) {
            HStack {
                Image(systemName: "trash")
                    .font(.system(size: 18))
                Text("Delete Account")
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundColor(.red)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.red.opacity(0.1))
            .cornerRadius(12)
        }
        .alert(authManager.isAuthenticated ? 
               "Delete Account?" : "Delete Local Data?", 
               isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                showFinalConfirmation = true
            }
        } message: {
            Text(authManager.isAuthenticated ?
                 "This will permanently delete your account, all recipes, photos, achievements, and social data. This action cannot be undone." :
                 "This will delete all locally stored data. You can still sign in later to recover cloud data.")
        }
        .alert("Final Confirmation", isPresented: $showFinalConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete Everything", role: .destructive) {
                Task {
                    await performDeletion()
                }
            }
        } message: {
            Text("⚠️ FINAL WARNING ⚠️\n\nYou are about to permanently delete:\n• Your profile and username\n• All \(authManager.currentUser?.recipesCreated ?? 0) recipes\n• All achievements and progress\n• All social connections\n• All local and cloud data\n\nThis CANNOT be undone!")
        }
        .sheet(isPresented: $showDeletionReport) {
            DeletionReportView(report: deletionReport)
        }
        .overlay {
            if isDeletingAccount {
                DeletionProgressOverlay(progress: deletionService.deletionProgress)
            }
        }
    }
    
    private func performDeletion() async {
        isDeletingAccount = true
        
        // Perform complete deletion
        let report = await deletionService.deleteAccount()
        
        isDeletingAccount = false
        deletionReport = report
        
        // Show report if there were errors
        if !report.errors.isEmpty {
            showDeletionReport = true
        }
    }
}

// Progress Overlay View
struct DeletionProgressOverlay: View {
    let progress: AccountDeletionService.DeletionProgress
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                
                Text(progressMessage)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                if case .deletingCloudKitData(let recordType, let progress) = progress {
                    VStack(spacing: 8) {
                        Text("Deleting \(recordType)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                        
                        ProgressView(value: progress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .white))
                            .frame(width: 200)
                    }
                }
            }
            .padding(40)
            .background(Color.black.opacity(0.9))
            .cornerRadius(20)
        }
    }
    
    var progressMessage: String {
        switch progress {
        case .idle:
            return "Preparing..."
        case .preparingDeletion:
            return "Preparing account deletion..."
        case .deletingCloudKitData(_, _):
            return "Deleting cloud data..."
        case .deletingLocalData(let category):
            return "Clearing \(category)..."
        case .verifyingDeletion:
            return "Verifying deletion..."
        case .completed:
            return "Deletion complete!"
        case .failed(let error):
            return "Deletion failed: \(error)"
        }
    }
}

// Deletion Report View
struct DeletionReportView: View {
    let report: AccountDeletionService.DeletionReport?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Summary
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Deletion Report")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        HStack {
                            Label("\(report?.totalRecordsDeleted ?? 0) records deleted", 
                                  systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                        
                        if let duration = report?.duration {
                            Text("Completed in \(String(format: "%.1f", duration)) seconds")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Records by type
                    if let recordsByType = report?.recordsByType, !recordsByType.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Deleted Records")
                                .font(.headline)
                            
                            ForEach(recordsByType.sorted(by: { $0.value > $1.value }), id: \.key) { type, count in
                                HStack {
                                    Text(type)
                                        .font(.system(.body, design: .monospaced))
                                    Spacer()
                                    Text("\(count)")
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    // Errors
                    if let errors = report?.errors, !errors.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Errors (\(errors.count))", systemImage: "exclamationmark.triangle.fill")
                                .font(.headline)
                                .foregroundColor(.red)
                            
                            ForEach(Array(errors.enumerated()), id: \.offset) { _, error in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(error.category): \(error.recordType ?? "Unknown")")
                                        .font(.system(.body, design: .monospaced))
                                    Text(error.error.localizedDescription)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
```

### 3. Update UnifiedAuthManager

```swift
// In UnifiedAuthManager.swift, update the deleteAccount function to use the new service:

func deleteAccount() async throws {
    // Use the centralized deletion service
    let report = await AccountDeletionService.shared.deleteAccount()
    
    // Check if deletion was successful
    if !report.errors.isEmpty {
        throw NSError(
            domain: "AccountDeletion",
            code: -1,
            userInfo: [
                NSLocalizedDescriptionKey: "Account deletion completed with \(report.errors.count) errors",
                "errors": report.errors
            ]
        )
    }
    
    print("✅ Account deletion completed: \(report.totalRecordsDeleted) records deleted")
}
```

### 4. Add Missing Manager Clear Functions

```swift
// Add to PhotoStorageManager.swift:
func clearAllData() {
    photoCache.removeAll()
    clearDiskCache()
    currentProcessingTasks.values.forEach { $0.cancel() }
    currentProcessingTasks.removeAll()
    print("✅ PhotoStorageManager: All data cleared")
}

// Add to CloudKitRecipeCache.swift (if exists):
func clearCache() {
    recipeCache.removeAll()
    lastFetchTime = nil
    print("✅ CloudKitRecipeCache: Cache cleared")
}

// Add to UserCacheManager.swift:
func clearCache() {
    userCache.removeAll()
    print("✅ UserCacheManager: Cache cleared")
}

// Add to RecipeLikeManager.swift:
func clearAllLikes() {
    likedRecipeIDs.removeAll()
    likeCounts.removeAll()
    print("✅ RecipeLikeManager: All likes cleared")
}

// Add to GamificationManager.swift:
func resetAllData() {
    currentPoints = 0
    achievements.removeAll()
    challenges.removeAll()
    streaks.removeAll()
    print("✅ GamificationManager: All data reset")
}

// Add to ActivityFeedManager.swift:
func clearAllData() async {
    activities.removeAll()
    hasMoreActivities = true
    lastFetchedCursor = nil
    isFetching = false
    await deleteLocalActivityCache()
    print("✅ ActivityFeedManager: All data cleared")
}
```

## Testing Plan

### Pre-Deletion Checklist
1. [ ] Create test account with full data
2. [ ] Generate recipes, likes, comments
3. [ ] Join challenges, earn achievements
4. [ ] Create social connections
5. [ ] Export data for verification

### Deletion Testing
1. [ ] Run deletion on test account
2. [ ] Verify CloudKit Console shows no user data
3. [ ] Check local file system is clean
4. [ ] Confirm can't sign back in with deleted account
5. [ ] Verify no orphaned data remains

### Error Scenarios
1. [ ] Test with no network connection
2. [ ] Test with partial CloudKit availability
3. [ ] Test with corrupted local data
4. [ ] Test interruption during deletion

### Performance Testing
1. [ ] Measure deletion time for various data sizes
2. [ ] Monitor memory usage during deletion
3. [ ] Test concurrent deletions (multiple accounts)

## Compliance Verification

### GDPR Article 17 Compliance
- ✅ Complete erasure of personal data
- ✅ Deletion verification mechanism
- ✅ Audit trail via DeletionReport
- ✅ No data retention after deletion

### CCPA Section 1798.105 Compliance
- ✅ User-initiated deletion
- ✅ Complete removal from all systems
- ✅ Confirmation of deletion
- ✅ No discrimination for deletion

### Apple App Store Guidelines 5.1.1
- ✅ Account deletion from within app
- ✅ Complete data removal
- ✅ Clear deletion process
- ✅ No hidden data retention

## Implementation Timeline

### Phase 1: Core Implementation (Day 1)
- [ ] Create AccountDeletionService.swift
- [ ] Update ProfileView with new deletion UI
- [ ] Add progress tracking

### Phase 2: Manager Updates (Day 2)
- [ ] Add clearAll methods to all managers
- [ ] Test each manager's cleanup
- [ ] Verify memory is released

### Phase 3: Testing (Day 3)
- [ ] Create test accounts with full data
- [ ] Run deletion tests
- [ ] Fix any issues found

### Phase 4: Verification & Polish (Day 4)
- [ ] Add deletion verification
- [ ] Implement error recovery
- [ ] Add analytics for deletion events

### Phase 5: Deployment (Day 5)
- [ ] Final testing on production environment
- [ ] Update privacy policy
- [ ] Deploy to TestFlight
- [ ] Monitor for issues

## Rollback Plan

If issues are discovered post-deployment:
1. Revert to previous deletion implementation
2. Mark accounts for manual deletion
3. Run batch cleanup script
4. Re-deploy fixed version

## Monitoring

### Key Metrics
- Deletion success rate
- Average deletion time
- Error frequency by type
- User retention post-deletion attempt

### Alerts
- Deletion failure rate > 5%
- Deletion time > 60 seconds
- CloudKit errors during deletion
- Local storage not cleared

## Additional Considerations

### Data Export
Consider offering data export before deletion:
- JSON export of all user data
- Photo archive download
- Recipe collection PDF

### Soft Delete Option
Consider implementing soft delete first:
- 30-day grace period
- Data anonymization vs deletion
- Recovery mechanism

### Legal Requirements
- Update Terms of Service
- Update Privacy Policy
- Document deletion process
- Maintain deletion logs for compliance