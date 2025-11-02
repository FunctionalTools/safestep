import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var app: AppData
    @State private var showClear = false
    @State private var itemDel: FallRecord? = nil
    @State private var showDel = false

    var body: some View {
        List {
            ForEach(app.hist.sorted(by: { $0.date > $1.date })) { record in
                NavigationLink(destination: HistoryDetailView(record: record)) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(dateString(for: record.date))
                                .font(.headline)
                            Text(timeString(for: record.date))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(String(format: "%.2fg", record.gForce))
                            .font(.headline)
                        Button(role: .destructive) {
                            itemDel = record
                            showDel = true
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 6)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        itemDel = record
                        showDel = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            if app.hist.isEmpty {
                EmptyView()
            }
        }
        .navigationTitle("History")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(role: .destructive) {
                    showClear = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
            }
        }
        .alert("Are you sure you want to clear all history?", isPresented: $showClear) {
            Button("No", role: .cancel) {}
            Button("Yes", role: .destructive) { app.clearHistory() }
        }
        .alert("Delete this entry?", isPresented: $showDel, presenting: itemDel) { record in
            Button("No", role: .cancel) { itemDel = nil }
            Button("Yes", role: .destructive) {
                app.deleteFall(id: record.id)
                itemDel = nil
            }
        } message: { record in
            Text("This will remove the selected fall from history.")
        }
    }

    private func dateString(for date: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        return df.string(from: date)
    }
    private func timeString(for date: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .none
        df.timeStyle = .short
        return df.string(from: date)
    }
}

#Preview {
    NavigationStack { HistoryView().environmentObject(AppData()) }
}
