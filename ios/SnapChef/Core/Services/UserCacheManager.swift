import Foundation
import CloudKit

/// Centralized cache manager for user data to reduce redundant CloudKit fetches
/// Provides significant performance improvements for activity feeds and social features
@MainActor
class UserCacheManager: ObservableObject {
    static let shared = UserCacheManager()
    
    // MARK: - Private Types
    
    private struct CachedUser {
        let username: String
        let displayName: String?
        let bio: String?
        let avatarData: Data?
        let followerCount: Int
        let followingCount: Int
        let recipesCreated: Int
        let fetchTime: Date
    }
    
    // MARK: - Properties
    
    /// In-memory cache of user data
    private var cache: [String: CachedUser] = [:]
    
    /// Cache timeout in seconds (30 minutes for user data)
    private let cacheTimeout: TimeInterval = 1800
    
    /// Reference to CloudKit actor for safe operations
    private let cloudKitActor = CloudKitActor()
    
    /// CloudKit database reference
    private let publicDatabase = CKContainer(identifier: "iCloud.com.snapchefapp.app").publicCloudDatabase
    
    // MARK: - Initialization
    
    private init() {
        print("🗄️ UserCacheManager initialized")
    }
    
    // MARK: - Public Methods
    
    /// Get user info from cache or CloudKit
    func getUserInfo(_ userID: String) async -> (username: String, displayName: String?, bio: String?, avatar: Data?) {
        // Check cache first
        if let cached = getCachedUser(userID) {
            print("✅ Cache hit for user: \(userID)")
            return (cached.username, cached.displayName, cached.bio, cached.avatarData)
        }
        
        print("🔍 Cache miss for user: \(userID), fetching from CloudKit...")
        
        // Fetch from CloudKit
        let info = await fetchUserFromCloudKit(userID)
        
        // Cache the result
        if let info = info {
            cacheUser(userID, info: info)
            return (info.username, info.displayName, info.bio, info.avatarData)
        }
        
        // Return defaults if fetch failed
        return ("Anonymous", nil, nil, nil)
    }
    
    /// Get basic user display info (username and avatar only)
    func getUserDisplayInfo(_ userID: String) async -> (username: String, avatar: Data?) {
        let info = await getUserInfo(userID)
        return (info.username, info.avatar)
    }
    
    /// Batch fetch multiple users efficiently
    func batchFetchUsers(_ userIDs: [String]) async -> [String: (username: String, displayName: String?, avatar: Data?)] {
        var result: [String: (username: String, displayName: String?, avatar: Data?)] = [:]
        var uncachedIDs: [String] = []
        
        // First, get all cached users
        for userID in userIDs {
            if let cached = getCachedUser(userID) {
                result[userID] = (cached.username, cached.displayName, cached.avatarData)
                print("✅ Batch cache hit for user: \(userID)")
            } else {
                uncachedIDs.append(userID)
            }
        }
        
        // Batch fetch uncached users from CloudKit
        if !uncachedIDs.isEmpty {
            print("🔍 Batch fetching \(uncachedIDs.count) uncached users from CloudKit...")
            
            // Create record IDs with proper "user_" prefix
            let recordIDs = uncachedIDs.map { userID in
                let recordName = userID.hasPrefix("user_") ? userID : "user_\(userID)"
                return CKRecord.ID(recordName: recordName)
            }
            
            do {
                // Use CloudKitActor for safe batch fetch
                var records: [CKRecord.ID: Result<CKRecord, Error>] = [:]
                
                // Fetch each record individually using CloudKitActor
                for recordID in recordIDs {
                    do {
                        let record = try await cloudKitActor.fetchRecord(with: recordID)
                        records[recordID] = .success(record)
                    } catch {
                        records[recordID] = .failure(error)
                    }
                }
                
                for (recordID, fetchResult) in records {
                    switch fetchResult {
                    case .success(let record):
                        let userID = recordID.recordName.replacingOccurrences(of: "user_", with: "")
                        let username = record["username"] as? String ?? "Anonymous"
                        let displayName = record["displayName"] as? String
                        let bio = record["bio"] as? String
                        
                        // Fetch avatar data if available
                        var avatarData: Data?
                        if let asset = record["profilePictureAsset"] as? CKAsset,
                           let url = asset.fileURL,
                           let data = try? Data(contentsOf: url) {
                            avatarData = data
                        }
                        
                        let followerCount = Int(record["followerCount"] as? Int64 ?? 0)
                        let followingCount = Int(record["followingCount"] as? Int64 ?? 0)
                        let recipesCreated = Int(record["recipesCreated"] as? Int64 ?? 0)
                        
                        // Cache the user
                        let cachedUser = CachedUser(
                            username: username,
                            displayName: displayName,
                            bio: bio,
                            avatarData: avatarData,
                            followerCount: followerCount,
                            followingCount: followingCount,
                            recipesCreated: recipesCreated,
                            fetchTime: Date()
                        )
                        cache[userID] = cachedUser
                        
                        result[userID] = (username, displayName, avatarData)
                        print("✅ Batch fetched and cached user: \(userID)")
                        
                    case .failure(let error):
                        print("⚠️ Failed to fetch user \(recordID.recordName): \(error)")
                        result[recordID.recordName.replacingOccurrences(of: "user_", with: "")] = ("Anonymous", nil, nil)
                    }
                }
            }
        }
        
        return result
    }
    
    /// Get user stats from cache or CloudKit
    func getUserStats(_ userID: String) async -> (followers: Int, following: Int, recipes: Int) {
        // Check cache first
        if let cached = getCachedUser(userID) {
            return (cached.followerCount, cached.followingCount, cached.recipesCreated)
        }
        
        // Fetch full info which includes stats
        _ = await getUserInfo(userID)
        
        // Try cache again after fetch
        if let cached = getCachedUser(userID) {
            return (cached.followerCount, cached.followingCount, cached.recipesCreated)
        }
        
        return (0, 0, 0)
    }
    
    /// Invalidate cache for a specific user
    func invalidateUser(_ userID: String) {
        cache.removeValue(forKey: userID)
        print("🗑️ Invalidated cache for user: \(userID)")
    }
    
    /// Clear entire cache
    func clearCache() {
        cache.removeAll()
        print("🧹 Cleared entire user cache")
    }
    
    /// Get cache statistics for debugging
    func getCacheStats() -> (hits: Int, size: Int, oldestEntry: Date?) {
        let oldestEntry = cache.values.map { $0.fetchTime }.min()
        return (0, cache.count, oldestEntry) // hits would need to be tracked separately
    }
    
    // MARK: - Private Methods
    
    /// Check if cached user is still valid
    private func getCachedUser(_ userID: String) -> CachedUser? {
        guard let cached = cache[userID] else { return nil }
        
        // Check if cache is still valid
        if Date().timeIntervalSince(cached.fetchTime) < cacheTimeout {
            return cached
        }
        
        // DISABLED: Never expire cache - always return cached data
        return cached
        
        // Original expiration code disabled:
        // cache.removeValue(forKey: userID)
        // print("⏰ Cache expired for user: \(userID)")
        // return nil
    }
    
    /// Fetch user from CloudKit
    private func fetchUserFromCloudKit(_ userID: String) async -> CachedUser? {
        do {
            // Add "user_" prefix if not present
            let recordName = userID.hasPrefix("user_") ? userID : "user_\(userID)"
            let recordID = CKRecord.ID(recordName: recordName)
            
            // Use CloudKitActor for safe fetch
            let record = try await cloudKitActor.fetchRecord(with: recordID)
            
            let username = record["username"] as? String ?? "Anonymous"
            let displayName = record["displayName"] as? String
            let bio = record["bio"] as? String
            
            // Fetch avatar data if available
            var avatarData: Data?
            if let asset = record["profilePictureAsset"] as? CKAsset,
               let url = asset.fileURL,
               let data = try? Data(contentsOf: url) {
                avatarData = data
            }
            
            let followerCount = Int(record["followerCount"] as? Int64 ?? 0)
            let followingCount = Int(record["followingCount"] as? Int64 ?? 0)
            let recipesCreated = Int(record["recipesCreated"] as? Int64 ?? 0)
            
            return CachedUser(
                username: username,
                displayName: displayName,
                bio: bio,
                avatarData: avatarData,
                followerCount: followerCount,
                followingCount: followingCount,
                recipesCreated: recipesCreated,
                fetchTime: Date()
            )
        } catch {
            print("❌ Failed to fetch user from CloudKit: \(error)")
            return nil
        }
    }
    
    /// Cache user info
    private func cacheUser(_ userID: String, info: CachedUser) {
        cache[userID] = info
        // print("💾 Cached user: \(userID) (username: \(info.username))")
        
        // DISABLED: Never prune cache - keep all user data forever
        // Was: if cache.count > 100 { remove oldest 20 entries }
        // We want to keep all user data permanently
    }
}

// Extension removed - using the one from ActivityFeedView.swift