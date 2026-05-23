import AppKit
import SwiftData
import SwiftUI

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Note.updatedAt, order: .reverse) private var notes: [Note]
    @State private var selectedNote: Note?
    @State private var selectedFilter: TagFilter = .all

    private enum TagFilter: Hashable {
        case all
        case tag(String)
    }

    private var allTags: [String] {
        Array(Set(notes.flatMap(\.tags))).sorted()
    }

    private var filteredNotes: [Note] {
        switch selectedFilter {
        case .all:
            return notes
        case .tag(let tag):
            return notes.filter { $0.tags.contains(tag) }
        }
    }

    private var navigationTitleText: String {
        switch selectedFilter {
        case .all:
            return "Notes"
        case .tag(let tag):
            return "#\(tag)"
        }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedFilter) {
                Section("Tags") {
                    Label("All Notes", systemImage: "tray.full")
                        .tag(TagFilter.all)

                    ForEach(allTags, id: \.self) { tag in
                        Label("#\(tag)", systemImage: "number")
                            .tag(TagFilter.tag(tag))
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
            .navigationTitle(navigationTitleText)
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

            Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)

            if !note.tags.isEmpty {
                Text(note.tags.map { "#\($0)" }.joined(separator: " "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if !note.imageDatas.isEmpty {
                Label(
                    "^[\(note.imageDatas.count) image](inflect: true)",
                    systemImage: "photo"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct NoteEditorView: View {
    @Bindable var note: Note
    @State private var previewData: Data?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
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

            if !note.imageDatas.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(note.imageDatas.enumerated()), id: \.offset) { _, data in
                            if let image = NSImage(data: data) {
                                Image(nsImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 180)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(.primary.opacity(0.1), lineWidth: 1)
                                    }
                                    .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .onTapGesture {
                                        previewData = data
                                    }
                            }
                        }
                    }
                }
                .frame(height: 188)
            }
        }
        .padding(20)
        .navigationTitle("Editor")
        .overlay {
            if let previewData {
                ImagePreviewOverlay(data: previewData) {
                    self.previewData = nil
                }
                .ignoresSafeArea()
            }
        }
    }
}
