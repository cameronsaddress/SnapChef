//
//  AppDelegate.swift
//  SnapChef
//
//  App delegate for TikTok SDK initialization
//

import UIKit
@preconcurrency import UserNotifications

#if canImport(TikTokOpenShareSDK)
import TikTokOpenShareSDK
#endif

#if canImport(TikTokOpenSDKCore)
import TikTokOpenSDKCore
#endif

#if canImport(TikTokOpenAuthSDK)
import TikTokOpenAuthSDK
#endif

class AppDelegate: NSObject, UIApplicationDelegate, @preconcurrency UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // TikTok SDK initialization with sandbox credentials
        // The SDK will be initialized when first used
        #if canImport(TikTokOpenShareSDK)
        // print("✅ TikTok OpenShareSDK available for use")
        #endif

        print("✅ AppDelegate initialized")
        UNUserNotificationCenter.current().delegate = self

        return true
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        // Handle TikTok callbacks through URL schemes
        // The TikTok SDK handles callbacks internally when sharing

        // TikTok callback handling removed - using direct URL scheme
        // if url.absoluteString.contains("tiktok") || url.absoluteString.contains("sbawj0946ft24i4wjv") {
        //     let handled = TikTokOpenSDKWrapper.shared.handleOpenURL(url)
        //     if handled {
        //         print("✅ TikTok callback handled by wrapper: \(url)")
        //         return true
        //     }
        // }

        // Let the app handle other URLs
        return false
    }

    func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL else {
            return false
        }

        return SocialShareManager.shared.handleIncomingURL(url)
    }

    // MARK: - Notification Delegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .badge, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let request = response.notification.request
        let actionIdentifier = response.actionIdentifier

        NotificationCenter.default.post(
            name: .snapchefNotificationAction,
            object: nil,
            userInfo: [
                "actionIdentifier": actionIdentifier,
                "categoryIdentifier": request.content.categoryIdentifier,
                "requestIdentifier": request.identifier,
                "payload": request.content.userInfo
            ]
        )

        if actionIdentifier == UNNotificationDefaultActionIdentifier ||
            actionIdentifier == "VIEW_CHALLENGE" ||
            actionIdentifier == "COOK_NOW" ||
            actionIdentifier == "ACCEPT_TEAM" {
            NotificationCenter.default.post(
                name: .snapchefNotificationTapped,
                object: nil,
                userInfo: [
                    "categoryIdentifier": request.content.categoryIdentifier,
                    "requestIdentifier": request.identifier,
                    "payload": request.content.userInfo
                ]
            )
        } else if actionIdentifier == "SNOOZE_REMINDER" {
            scheduleSnoozeReminder(from: request)
        }

        completionHandler()
    }

    private func scheduleSnoozeReminder(from request: UNNotificationRequest) {
        let originalIdentifier = request.identifier
        guard let category = NotificationCategory(rawValue: request.content.categoryIdentifier) else {
            print("⚠️ Skipping snooze - unknown category: \(request.content.categoryIdentifier)")
            return
        }

        var userInfo: [String: Any] = request.content.userInfo.reduce(into: [:]) { partialResult, pair in
            if let key = pair.key as? String {
                partialResult[key] = pair.value
            }
        }
        userInfo["snoozed"] = true
        userInfo["snoozed_from_id"] = request.identifier

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3_600, repeats: false)
        let identifier = "\(originalIdentifier)_snooze_\(Int(Date().timeIntervalSince1970))"

        Task { @MainActor in
            let didSchedule = NotificationManager.shared.scheduleNotification(
                identifier: identifier,
                title: request.content.title,
                body: request.content.body,
                subtitle: request.content.subtitle,
                category: category,
                userInfo: userInfo,
                trigger: trigger,
                priority: .low,
                deliveryPolicy: .transactional
            )

            if didSchedule {
                print("✅ Scheduled snoozed reminder for request: \(originalIdentifier)")
            } else {
                print("⏭️ Snoozed reminder was not scheduled for request: \(originalIdentifier)")
            }
        }
    }
}

extension Notification.Name {
    static let snapchefNotificationTapped = Notification.Name("snapchef_notification_tapped")
    static let snapchefNotificationAction = Notification.Name("snapchef_notification_action")
}
