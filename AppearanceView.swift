import SwiftUI

struct AppearanceView: View {
    @EnvironmentObject var app: AppData

    var body: some View {
        Form(content: {
            Section {
                Text("Theme").font(.headline)
                Picker("Appearance", selection: $app.isdark) {
                    Text("Light").tag(false as Bool)
                    Text("Dark").tag(true as Bool)
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Appearance")
                .accessibilityValue(app.isdark ? "Dark" : "Light")
            }

            if app.isdark {
                Text("Dark Mode is enabled. Colors are adjusted for better contrast.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("Light Mode is enabled.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Text("Accent Color").font(.headline)
                Picker("Accent Color", selection: Binding(get: { app.accent }, set: { app.accent = $0 })) {
                    Text("Red").tag("Red" as String).foregroundStyle(.red)
                    Text("Blue").tag("Blue" as String).foregroundStyle(.blue)
                    Text("Green").tag("Green" as String).foregroundStyle(.green)
                    Text("Orange").tag("Orange" as String).foregroundStyle(.orange)
                    Text("Purple").tag("Purple" as String).foregroundStyle(.purple)
                    Text("Pink").tag("Pink" as String).foregroundStyle(.pink)
                    Text("Teal").tag("Teal" as String).foregroundStyle(.teal)
                    Text("Indigo").tag("Indigo" as String).foregroundStyle(.indigo)
                    Text("Mint").tag("Mint" as String).foregroundStyle(.mint)
                }
            }
        })
        .navigationTitle("Appearance")
    }
}

#Preview {
    NavigationStack {
        AppearanceView()
            .environmentObject(AppData())
    }
}
