import Foundation
import UserNotifications
import SwiftUI
import Combine

public struct FallRecord: Identifiable, Codable {
    public let id: UUID
    public let date: Date
    public let gForce: Double
}

public struct ConnectionEmail: Identifiable, Codable, Equatable {
    public let id: UUID
    public var email: String
}

final class AppData: ObservableObject {
    private let histKey = "fallHistory_v1"
    private let connKey = "connections_v1"
    
    @Published var lastg: Double? = nil
    @Published var hist: [FallRecord] = [] {
        didSet { saveHistory() }
    }
    @Published var pending: FallRecord? = nil
    @Published var conns: [ConnectionEmail] = [] {
        didSet { saveConnections() }
    }
    @AppStorage("isDarkMode") var isdark: Bool = false
    
    @AppStorage("fallThresholdG") var thrg: Double = 2.2 {
        didSet { thrg = min(max(thrg, 1.2), 4.0) }
    }
    
    @AppStorage("userName") var nm: String = ""
    @AppStorage("userAge") var agstr: String = ""
    
    var ag: Int? {
        Int(agstr)
    }
    
    @AppStorage("accentColorName") var accent: String = "Red"
    
    var accentColor: Color {
        switch accent {
        case "Blue": return .blue
        case "Green": return .green
        case "Orange": return .orange
        case "Purple": return .purple
        case "Pink": return .pink
        case "Teal": return .teal
        case "Indigo": return .indigo
        case "Mint": return .mint
        default: return .red
        }
    }
    
    private var cdt: Timer? = nil
    private var incd: Bool = false

    func requestNotificationPermission() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { granted, error in
                if let error = error {
                    print("🔔 Notification permission error: \(error.localizedDescription)")
                } else {
                    print("🔔 Notification permission granted: \(granted)")
                }
            }
    }
    
    func scheduleFallNotification(speedG: Double? = nil) {
        let content = UNMutableNotificationContent()
        content.title = "Sudden Movement Detected"
        let g = speedG
        if let g = g {
            content.body = String(format: "Possible fall detected. Peak acceleration: %.2fg", g)
            content.userInfo = ["fallSpeedG": g]
        } else {
            content.body = "Possible fall detected."
        }
        content.sound = .default
        content.categoryIdentifier = "FALL_DETECTED"

        let request = UNNotificationRequest(identifier: UUID().uuidString,
                                            content: content,
                                            trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("🔔 Failed to schedule notification: \(error.localizedDescription)")
            } else {
                print("🔔 Fall notification scheduled")
            }
        }
    }
    
    func handleFallDetected() {
        if incd { return }

        let category = UNNotificationCategory(identifier: "FALL_DETECTED", actions: [], intentIdentifiers: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
        DispatchQueue.main.async {
            self.scheduleFallNotification(speedG: self.lastg)

            self.incd = true
            self.cdt?.invalidate()
            self.cdt = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { [weak self] _ in
                self?.incd = false
            }
        }
    }
    
    func logFallOnTimeout() {
        DispatchQueue.main.async {
            self.hist.append(FallRecord(id: UUID(), date: Date(), gForce: self.lastg ?? self.thrg))
        }
    }
    
    func sendEmailOnTimeout() {
        let n = self.nm.trimmingCharacters(in: .whitespacesAndNewlines)
        let recipients = self.recips
        let g = self.lastg
        guard !n.isEmpty, !recipients.isEmpty else {
            if n.isEmpty { print("📧 Skipping email: user name not set in Profile.") }
            if recipients.isEmpty { print("📧 Skipping email: no connection emails saved.") }
            return
        }
        DispatchQueue.global(qos: .background).async {
            EmailService.sendFallDetectedEmail(to: recipients, name: n, age: self.ag, gForce: g)
        }
    }
    
    func clearHistory() {
        hist.removeAll()
        cdt?.invalidate()
        cdt = nil
        incd = false
    }
    
    func deleteFall(id: UUID) {
        hist.removeAll { $0.id == id }
    }
    
    func addConnection(email: String) {
        let trim = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trim.isEmpty else { return }
        conns.append(ConnectionEmail(id: UUID(), email: trim))
    }

    func updateConnection(id: UUID, email: String) {
        let trim = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trim.isEmpty else { return }
        if let idx = conns.firstIndex(where: { $0.id == id }) {
            conns[idx].email = trim
        }
    }

    func deleteConnection(id: UUID) {
        conns.removeAll { $0.id == id }
    }

    private func saveConnections() {
        do {
            let d = try JSONEncoder().encode(conns)
            UserDefaults.standard.set(d, forKey: connKey)
        } catch {
            print("💾 Failed to save connections: \(error)")
        }
    }

    private func loadConnections() -> [ConnectionEmail] {
        guard let d = UserDefaults.standard.data(forKey: connKey) else { return [] }
        do {
            return try JSONDecoder().decode([ConnectionEmail].self, from: d)
        } catch {
            print("💾 Failed to load connections: \(error)")
            return []
        }
    }
    
    private func saveHistory() {
        do {
            let d = try JSONEncoder().encode(hist)
            UserDefaults.standard.set(d, forKey: histKey)
        } catch {
            print("💾 Failed to save history: \(error)")
        }
    }

    private func loadHistory() -> [FallRecord] {
        guard let d = UserDefaults.standard.data(forKey: histKey) else { return [] }
        do {
            return try JSONDecoder().decode([FallRecord].self, from: d)
        } catch {
            print("💾 Failed to load history: \(error)")
            return []
        }
    }
    
    func handleNotificationPayload(_ userInfo: [AnyHashable: Any]) {
        if let g = userInfo["fallSpeedG"] as? Double {
            DispatchQueue.main.async {
                self.lastg = g
                if let lat = self.hist.sorted(by: { $0.date > $1.date }).first {
                    self.pending = lat
                }
            }
        }
    }
    
    var recips: [String] {
        conns.map { $0.email }
    }
    
    func toggleTheme() {
        isdark.toggle()
    }
    
    init() {
        self.hist = loadHistory()
        self.conns = loadConnections()
        NotificationCenter.default.addObserver(forName: .fallDetectedNotification, object: nil, queue: .main) { [weak self] note in
            if let g = note.userInfo?["fallSpeedG"] as? Double {
                self?.lastg = g
            }
            self?.handleFallDetected()
        }
    }
}
