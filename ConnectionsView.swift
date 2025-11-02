import SwiftUI

struct ConnectionsView: View {
    @EnvironmentObject var app: AppData
    @State private var showAdd = false
    @State private var editEmail: ConnectionEmail? = nil

    var body: some View {
        List {
            if app.conns.isEmpty {
                VStack(alignment: .center, spacing: 8) {
                    Text("No connections yet")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Tap + to add an email")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 40)
            } else {
                ForEach(app.conns) { item in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(item.email)
                                .font(.body)
                                .foregroundStyle(.primary)
                        }
                        Spacer()
                        Button {
                            editEmail = item
                        } label: {
                            Image(systemName: "pencil")
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 8)

                        Button(role: .destructive) {
                            app.deleteConnection(id: item.id)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                    .contentShape(Rectangle())
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Connections")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showAdd = true }) {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add email")
            }
        }
        .sheet(isPresented: $showAdd) {
            AddOrEditEmailView(mode: .add) { email in
                app.addConnection(email: email)
            }
            .presentationDetents([.medium])
        }
        .sheet(item: $editEmail) { editEmailItem in
            AddOrEditEmailView(mode: .edit(existing: editEmailItem)) { updated in
                app.updateConnection(id: editEmailItem.id, email: updated)
            }
            .presentationDetents([.medium])
        }
    }
}

private struct AddOrEditEmailView: View {
    enum Mode: Equatable {
        case add
        case edit(existing: ConnectionEmail)
    }

    let mode: Mode
    var onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var email: String = ""

    init(mode: Mode, onSave: @escaping (String) -> Void) {
        self.mode = mode
        self.onSave = onSave
        switch mode {
        case .add:
            _email = State(initialValue: "")
        case .edit(let existing):
            _email = State(initialValue: existing.email)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Email")) {
                    TextField("example@email.com", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(email)
                        dismiss()
                    }
                    .disabled(!isValidEmail(email))
                }
            }
        }
    }

    private var title: String {
        switch mode {
        case .add: return "Add Email"
        case .edit: return "Edit Email"
        }
    }
}

// Simple email validation (basic format check)
private func isValidEmail(_ email: String) -> Bool {
    let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return false }

    // Use NSDataDetector to find email-like patterns
    let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
    let range = NSRange(location: 0, length: (trimmed as NSString).length)
    let matches = detector?.matches(in: trimmed, options: [], range: range) ?? []

    // Exactly one match and it must cover the whole string and be a mailto link
    guard matches.count == 1,
          let match = matches.first,
          match.range.location == 0,
          match.range.length == range.length,
          match.url?.scheme == "mailto",
          let matched = match.url?.absoluteString.replacingOccurrences(of: "mailto:", with: "")
    else { return false }

    // Basic domain validation: ensure there's one '@', a host with at least one '.', and a 2+ letter TLD.
    let parts = matched.split(separator: "@")
    guard parts.count == 2 else { return false }
    let host = parts[1]
    let hostParts = host.split(separator: ".")
    guard hostParts.count >= 2, let tld = hostParts.last, tld.count >= 2 else { return false }

    // Forbid spaces and control characters
    if matched.rangeOfCharacter(from: .whitespacesAndNewlines) != nil { return false }

    return true
}

#Preview {
    NavigationStack {
        ConnectionsView()
            .environmentObject(AppData())
    }
}
