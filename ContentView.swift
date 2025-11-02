import SwiftUI
import UserNotifications

private let fallDetectedNotification = Notification.Name("fallDetected")

struct ContentView: View {
    @StateObject private var fd = FallDetector()
    @EnvironmentObject var app: AppData

    @AppStorage("timerMinutes") private var mins: Int = 0
    @AppStorage("timerSeconds") private var secs: Int = 0

    @State private var remain: Int = 0
    @State private var running: Bool = false
    @State private var notified: Bool = false

    @StateObject private var notify = EmergencyNotifier.shared

    private var total: Int { max(0, mins * 60 + secs) }

    @State private var prog: Double = 0
    @State private var showImmediate: Bool = false

    var body: some View {
        ZStack {
            (fd.isRed ? app.accentColor : Color(.systemBackground))
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                if fd.isRed {
                    if showImmediate {
                        VStack(spacing: 16) {
                            Spacer()
                            Text("Fall Detected")
                                .font(.largeTitle).bold()
                                .foregroundStyle(.red)
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color.white)
                                )
                                .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)
                            Spacer()
                        }
                    } else {
                        VStack(spacing: 16) {
                            VStack(spacing: 8) {
                                Text(fmt(remain))
                                    .font(.headline)
                                    .monospacedDigit()
                                    .foregroundStyle(.primary)

                                ProgressView(value: prog, total: 1.0)
                                    .progressViewStyle(.linear)
                                    .tint(app.accentColor)
                                    .frame(height: 16)
                                    .clipShape(Capsule())
                            }
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.white)
                            )
                            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)

                            HStack(spacing: 12) {
                                Button {
                                    running = false
                                    notified = false
                                    Task { @MainActor in
                                        fd.reset()
                                    }
                                } label: {
                                    Text("I Am Okay.")
                                        .font(.headline).bold()
                                        .foregroundStyle(.green)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
                                }
                                .accessibilityIdentifier("homepageOkayButton")

                                Button {
                                    Task { await notifyNotOkay() }
                                } label: {
                                    Text("I Am Not Okay.")
                                        .font(.headline).bold()
                                        .foregroundStyle(.red)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
                                }
                                .accessibilityIdentifier("homepageNotOkayButton")
                            }
                        }
                    }
                } else {
                    Text("Listening for sudden movements…")
                        .foregroundStyle(.secondary)
                        .padding()
                }
            }
            .padding()
        }
        .onAppear {
            if fd.isRed {
                start()
            }
            Task { await notify.requestAuthorization() }
        }
        .onChange(of: fd.isRed) { _, isRed in
            if isRed {
                if total == 0 {
                    showImmediate = true
                    Task {
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                        await notifyTimeout()
                    }
                } else {
                    showImmediate = false
                }
                start()
            } else {
                running = false
                notified = false
                remain = total
                showImmediate = false
            }
        }
        .onChange(of: total) { _, _ in
            if fd.isRed {
                start()
            } else {
                remain = total
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("SafeStep")
                    .font(.headline)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: SimpleSettingsView()) {
                    Image(systemName: "gearshape")
                }
            }
        }
    }
    
    private func start() {
        remain = total
        running = total > 0
        notified = false
        if total > 0 {
            prog = 0
        }
        if running {
            Task { await tick() }
        }
    }

    private func reset() {
        remain = total
    }

    private func fmt(_ v: Int) -> String {
        let m = v / 60
        let s = v % 60
        return String(format: "%d:%02d", m, s)
    }

    private func tick() async {
        let tot = max(1, total)
        var elapsed: Double = Double(tot - remain)
        let step: UInt64 = 16_666_667
        while running && remain > 0 {
            try? await Task.sleep(nanoseconds: step)
            if !running { break }
            elapsed += 1.0 / 60.0
            let clamped = min(max(elapsed / Double(tot), 0), 1)
            await MainActor.run {
                withAnimation(.linear(duration: 1.0 / 60.0)) {
                    prog = clamped
                }
                if Int(elapsed.rounded(.down)) == (tot - remain) + 1 {
                    remain = max(remain - 1, 0)
                }
            }
        }
        if running && remain == 0 && !notified {
            await notifyTimeout()
        }
    }

    private func notifyTimeout() async {
        app.logFallOnTimeout()
        app.sendEmailOnTimeout()
        notified = true
        running = false
        await notify.notifyImmediate(reason: "Notifying emergency contacts about your fall")
        await MainActor.run {
            fd.reset()
            showImmediate = false
        }
    }

    private func notifyNotOkay() async {
        notified = true
        running = false
        await notify.notifyImmediate(reason: "Notifying emergency contacts about your fall")
        await MainActor.run {
            fd.reset()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppData())
}
