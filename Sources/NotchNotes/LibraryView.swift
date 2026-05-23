import SwiftData
import SwiftUI

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Note.updatedAt, order: .reverse) private var notes: [Note]
    @State private var selectedNote: Note?
    @State private var selectedTag: String?

    private var allTags: [String] {
        Array(Set(notes.flatMap(\.tags))).sorted()
    }

    private var filteredNotes: [Note] {
        guard let selectedTag else {
            return notes
        }

        return notes.filter { $0.tags.contains(selectedTag) }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedTag) {
                Section("Tags") {
                    Text("All Notes")
                        .tag(String?.none)

                    ForEach(allTags, id: \.self) { tag in
                        Label("#\(tag)", systemImage: "number")
                            .tag(String?.some(tag))
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 220)
        } content: {
            List(filteredNotes, selection: $selectedNote) { note in
                NoteRow(note: note)
                    .tag(note)
            }
            .overlay {
                if filteredNotes.isEmpty {
                    ContentUnavailableView(
                        "No Notes",
                        systemImage: "square.and.pencil",
                        description: Text("Capture a note with Option-N.")
                    )
                }
            }
            .navigationTitle(selectedTag.map { "#\($0)" } ?? "Notes")
            .toolbar {
                ToolbarItem {
                    Button {
                        let note = Note(body: "")
                        modelContext.insert(note)
                        selectedNote = note
                    } label: {
                        Label("New Note", systemImage: "square.and.pencil")
                    }
                }
            }
        } detail: {
            if let selectedNote {
                NoteEditorView(note: selectedNote)
            } else {
                ContentUnavailableView(
                    "Select a Note",
                    systemImage: "note.text",
                    description: Text("Choose a note from the list or create a new one.")
                )
            }
        }
        .frame(minWidth: 860, minHeight: 560)
    }
}

private struct NoteRow: View {
    let note: Note

    private var title: String {
        let firstLine = note.body
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let firstLine, !firstLine.isEmpty else {
            return "Untitled Note"
        }

        return firstLine
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
                .lineLimit(1)

            Text(note.updatedAt, style: .relative)
                .font(.caption)
                .foregroundStyle(.secondary)

            if !note.tags.isEmpty {
                Text(note.tags.map { "#\($0)" }.joined(separator: " "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct NoteEditorView: View {
    @Bindable var note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(note.updatedAt, style: .date)
                    .foregroundStyle(.secondary)
                Text(note.updatedAt, style: .time)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .font(.caption)

            if !note.tags.isEmpty {
                HStack {
                    ForEach(note.tags, id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.quaternary, in: Capsule())
                    }
                }
            }

            TextEditor(
                text: Binding(
                    get: { note.body },
                    set: { note.updateBody($0) }
                )
            )
            .font(.system(size: 16))
            .scrollContentBackground(.hidden)
        }
        .padding(20)
        .navigationTitle("Editor")
    }
}
