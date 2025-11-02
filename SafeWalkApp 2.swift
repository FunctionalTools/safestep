import SwiftUI
import UserNotifications
import UIKit
import FirebaseCore

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    static var appDataProvider: () -> AppData? = { nil }

    private func configureNavigationBarAppearance(isDark: Bool) {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = isDark ? .black : .white
        appearance.titleTextAttributes = [.foregroundColor: isDark ? UIColor.white : UIColor.black]
        appearance.largeTitleTextAttributes = [.foregroundColor: isDark ? UIColor.white : UIColor.black]

        let navigationBar = UINavigationBar.appearance()
        navigationBar.standardAppearance = appearance
        navigationBar.scrollEdgeAppearance = appearance
        navigationBar.compactAppearance = appearance
        navigationBar.tintColor = isDark ? .white : .black
        navigationBar.barStyle = isDark ? .black : .default

        UIBarButtonItem.appearance().tintColor = isDark ? .white : .black
    }

    func updateNavigationBarAppearance(isDark: Bool) {
        configureNavigationBarAppearance(isDark: isDark)
    }

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {

        FirebaseApp.configure()
        configureNavigationBarAppearance(isDark: false)
        print("✅ Firebase configured:", FirebaseApp.app() != nil)

        let center = UNUserNotificationCenter.current()
        center.delegate = self

        let fallCategory = UNNotificationCategory(
            identifier: "FALL_DETECTED",
            actions: [],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        center.setNotificationCategories([fallCategory])

        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
        if let appData = Self.appDataProvider() {
            appData.handleNotificationPayload(notification.request.content.userInfo)
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        if let appData = Self.appDataProvider() {
            appData.handleNotificationPayload(response.notification.request.content.userInfo)
        }
        completionHandler()
    }
}

@main
struct SafeStepApp: App {
    @StateObject private var appData = AppData()
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            AppStartGate {
                NavigationView {
                    ContentView()
                        .preferredColorScheme(appData.isdark ? .dark : .light)
                }
                .tint(appData.isdark ? .white : .black)
                .toolbarBackground(appData.isdark ? Color.black : Color.white, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarColorScheme(appData.isdark ? .dark : .light, for: .navigationBar)
                .environmentObject(appData)
                .onAppear {
                    AppDelegate.appDataProvider = { [weak appData] in appData }
                    appData.requestNotificationPermission()
                    appDelegate.updateNavigationBarAppearance(isDark: appData.isdark)
                }
                .onChange(of: appData.isdark) { _, newValue in
                    appDelegate.updateNavigationBarAppearance(isDark: newValue)
                }
                .onDisappear {
                    AppDelegate.appDataProvider = { nil }
                }
                .sheet(item: $appData.pending) { record in
                    NavigationView {
                        HistoryDetailView(record: record)
                            .environmentObject(appData)
                    }
                }
            }
        }
    }
}
