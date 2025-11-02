import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var app: AppData
    @State private var nm: String = ""
    @State private var ag: String = ""

    var body: some View {
        Form {
            Section(header: Text("Profile")) {
                TextField("Name (required)", text: $nm)
                    .textInputAutocapitalization(.words)
                TextField("Age (optional)", text: $ag)
                    .keyboardType(.numberPad)
            }
            Section(footer: Text("Name is required to enable email alerts.")) {
                Button("Save") {
                    app.nm = nm.trimmingCharacters(in: .whitespacesAndNewlines)
                    app.agstr = ag.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                .disabled(nm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .onAppear {
            nm = app.nm
            ag = app.agstr
        }
        .navigationTitle("Profile")
    }
}

#Preview {
    NavigationStack {
        ProfileView()
            .environmentObject(AppData())
    }
}
