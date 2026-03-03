#if os(iOS)
  import UIKit
  import SwiftUI
  import UserNotifications
  import WidgetKit

  class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
      _ application: UIApplication,
      didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
      // Reload weather widget on every app launch
      WidgetCenter.shared.reloadTimelines(ofKind: "WeatherWidget")
      
      return true
    }

    func application(
      _ application: UIApplication,
      didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
    }

    func application(
      _ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
      // print("Failed to register for remote notifications: \(error)")
    }
  }
#endif
