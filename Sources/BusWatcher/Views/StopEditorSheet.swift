import SwiftUI

struct StopEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(StopStore.self) private var store

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.stops) { stop in
                        StopEditorRow(stop: stop)
                            .accessibilityIdentifier("stopRow-\(stop.id)")
                    }
                    .onMove { from, to in store.move(from: from, to: to) }
                    .onDelete { offsets in store.remove(at: offsets) }
                }
                Section {
                    NavigationLink {
                        AddStopView(onCompleted: { dismiss() })
                    } label: {
                        Label("Add a stop", systemImage: "plus.circle")
                    }
                    .accessibilityIdentifier("addStopLink")
                }
            }
            .navigationTitle("Edit Stops")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { EditButton() }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .accessibilityIdentifier("editorCloseButton")
                }
            }
        }
    }
}

private struct StopEditorRow: View {
    let stop: StopConfig

    var body: some View {
        HStack(spacing: 12) {
            Text(stop.routeLabel)
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(stop.colorToken.color, in: RoundedRectangle(cornerRadius: 6))
            Text(stop.stopName)
                .font(.body)
            Spacer()
        }
    }
}
