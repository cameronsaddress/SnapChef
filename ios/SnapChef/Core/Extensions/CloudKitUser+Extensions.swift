import Foundation
import UIKit

// MARK: - CloudKitUser to User Conversion
extension CloudKitUser {
    func toUser() -> User {
        User(
            id: self.recordID ?? UUID().uuidString,
            email: self.email,
            name: self.displayName,
            username: self.username ?? self.displayName,
            profileImageURL: self.profileImageURL,
            subscription: Subscription(
                tier: self.subscriptionTier == "premium" ? .premium : self.subscriptionTier == "basic" ? .basic : .free,
                status: .active,
                expiresAt: nil,
                autoRenew: false
            ),
            credits: self.coinBalance,
            deviceId: UIDevice.current.identifierForVendor?.uuidString ?? "unknown",
            createdAt: self.createdAt,
            lastLoginAt: self.lastLoginAt,
            totalPoints: self.totalPoints,
            currentStreak: self.currentStreak,
            longestStreak: self.longestStreak,
            challengesCompleted: self.challengesCompleted,
            recipesShared: self.recipesShared,
            isProfilePublic: self.isProfilePublic,
            showOnLeaderboard: self.showOnLeaderboard
        )
    }
}