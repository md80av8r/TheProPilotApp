//
//  PilotNote.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 10/27/25.
//


// NotesView.swift - Notepad Interface for ProPilot
import SwiftUI

// MARK: - Note Model
struct PilotNote: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var content: String
    var dateCreated: Date
    var dateModified: Date
    var category: NoteCategory
    var isPinned: Bool = false
    
    enum NoteCategory: String, Codable, CaseIterable {
        case general = "General"
        case flightBrief = "Flight Brief"
        case procedures = "Procedures"
        case maintenance = "Maintenance"
        case training = "Training"
        case weather = "Weather"
        
        var icon: String {
            switch self {
            case .general: return "note.text"
            case .flightBrief: return "airplane.circle"
            case .procedures: return "list.bullet.clipboard"
            case .maintenance: return "wrench.and.screwdriver"
            case .training: return "graduationcap"
            case .weather: return "cloud.sun"
            }
        }
        
        var color: Color {
            switch self {
            case .general: return LogbookTheme.accentBlue
            case .flightBrief: return LogbookTheme.accentGreen
            case .procedures: return LogbookTheme.accentOrange
            case .maintenance: return .red
            case .training: return .purple
            case .weather: return .cyan
            }
        }
    }
}

// MARK: - Notes Store
class NotesStore: ObservableObject {
    @Published var notes: [PilotNote] = []
    
    private let fileURL: URL = {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.propilot.app") else {
            fatalError("Unable to access App Group container")
        }
        return container.appendingPathComponent("notes.json")
    }()
    
    init() {
        load()
    }
    
    func load() {
        do {
            let data = try Data(contentsOf: fileURL)
            notes = try JSONDecoder().decode([PilotNote].self, from: data)
            print("📝 Loaded \(notes.count) notes")
        } catch {
            print("Failed to load notes: \(error)")
            notes = []
        }
    }
    
    func save() {
        do {
            let data = try JSONEncoder().encode(notes)
            try data.write(to: fileURL)
            print("📝 Saved \(notes.count) notes")
        } catch {
            print("Failed to save notes: \(error)")
        }
    }
    
    func addNote(_ note: PilotNote) {
        notes.insert(note, at: 0) // Add to beginning
        save()
    }
    
    func updateNote(_ note: PilotNote) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index] = note
            save()
        }
    }
    
    func deleteNote(_ note: PilotNote) {
        notes.removeAll { $0.id == note.id }
        save()
    }
    
    func togglePin(_ note: PilotNote) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index].isPinned.toggle()
            // Re-sort: pinned notes first
            notes.sort { lhs, rhs in
                if lhs.isPinned != rhs.isPinned {
                    return lhs.isPinned
                }
                return lhs.dateModified > rhs.dateModified
            }
            save()
        }
    }
}

// MARK: - Main Notes View
struct NotesView: View {
    @StateObject private var notesStore = NotesStore()
    @State private var showingNewNote = false
    @State private var selectedNote: PilotNote?
    @State private var showingNoteDetail = false
    @State private var searchText = ""
    @State private var selectedCategory: PilotNote.NoteCategory? = nil
    
    private var filteredNotes: [PilotNote] {
        var result = notesStore.notes
        
        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }
        
        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.content.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return result
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search notes...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                }
                .padding()
                .background(LogbookTheme.fieldBackground)
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Category filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        CategoryFilterButton(
                            title: "All",
                            isSelected: selectedCategory == nil,
                            action: { selectedCategory = nil }
                        )
                        
                        ForEach(PilotNote.NoteCategory.allCases, id: \.self) { category in
                            CategoryFilterButton(
                                title: category.rawValue,
                                icon: category.icon,
                                color: category.color,
                                isSelected: selectedCategory == category,
                                action: { selectedCategory = category }
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                
                if filteredNotes.isEmpty {
                    emptyStateView
                } else {
                    notesList
                }
            }
            .background(LogbookTheme.navy)
            .navigationTitle("Notes")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingNewNote = true }) {
                        Image(systemName: "square.and.pencil")
                            .foregroundColor(LogbookTheme.accentGreen)
                    }
                }
            }
            .sheet(isPresented: $showingNewNote) {
                NoteEditorView(notesStore: notesStore, note: nil)
            }
            .sheet(item: $selectedNote) { note in
                NoteEditorView(notesStore: notesStore, note: note)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "note.text")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text(searchText.isEmpty ? "No Notes Yet" : "No Results")
                .font(.title2)
                .foregroundColor(.white)
            
            Text(searchText.isEmpty ? "Tap + to create your first note" : "Try a different search term")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var notesList: some View {
        List {
            ForEach(filteredNotes) { note in
                NoteRowView(note: note)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedNote = note
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            withAnimation {
                                notesStore.deleteNote(note)
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            withAnimation {
                                notesStore.togglePin(note)
                            }
                        } label: {
                            Label(note.isPinned ? "Unpin" : "Pin", systemImage: note.isPinned ? "pin.slash" : "pin")
                        }
                        .tint(LogbookTheme.accentOrange)
                    }
                    .listRowBackground(LogbookTheme.navyLight)
            }
        }
        .listStyle(PlainListStyle())
        .background(LogbookTheme.navy)
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Note Row
struct NoteRowView: View {
    let note: PilotNote
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if note.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundColor(LogbookTheme.accentOrange)
                }
                
                Text(note.title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Spacer()
                
                Image(systemName: note.category.icon)
                    .font(.caption)
                    .foregroundColor(note.category.color)
            }
            
            Text(note.content)
                .font(.subheadline)
                .foregroundColor(.gray)
                .lineLimit(2)
            
            HStack {
                Text(note.category.rawValue)
                    .font(.caption2)
                    .foregroundColor(note.category.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(note.category.color.opacity(0.2))
                    .cornerRadius(6)
                
                Spacer()
                
                Text(note.dateModified.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Category Filter Button
struct CategoryFilterButton: View {
    let title: String
    var icon: String? = nil
    var color: Color = LogbookTheme.accentBlue
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                Text(title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .foregroundColor(isSelected ? .white : .gray)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? color : Color.clear)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? color : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

// MARK: - Note Editor View
struct NoteEditorView: View {
    @ObservedObject var notesStore: NotesStore
    let note: PilotNote?
    
    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""
    @State private var content: String = ""
    @State private var selectedCategory: PilotNote.NoteCategory = .general
    @FocusState private var titleFocused: Bool
    @FocusState private var contentFocused: Bool
    
    var isEditing: Bool { note != nil }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Title field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Title")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                    
                    TextField("Note title...", text: $title)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding()
                        .background(LogbookTheme.fieldBackground)
                        .cornerRadius(10)
                        .padding(.horizontal)
                        .focused($titleFocused)
                }
                .padding(.top)
                
                // Category picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Category")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(PilotNote.NoteCategory.allCases, id: \.self) { category in
                                CategoryButton(
                                    category: category,
                                    isSelected: selectedCategory == category,
                                    action: { selectedCategory = category }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.top, 8)
                
                // Content area
                VStack(alignment: .leading, spacing: 8) {
                    Text("Content")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                    
                    TextEditor(text: $content)
                        .font(.body)
                        .foregroundColor(.white)
                        .scrollContentBackground(.hidden)
                        .background(LogbookTheme.fieldBackground)
                        .cornerRadius(10)
                        .padding(.horizontal)
                        .focused($contentFocused)
                }
                .padding(.top, 8)
                
                Spacer()
            }
            .background(LogbookTheme.navy)
            .navigationTitle(isEditing ? "Edit Note" : "New Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.red)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "Update" : "Save") {
                        saveNote()
                    }
                    .foregroundColor(LogbookTheme.accentGreen)
                    .fontWeight(.semibold)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if let note = note {
                    title = note.title
                    content = note.content
                    selectedCategory = note.category
                }
                // Auto-focus title for new notes
                if !isEditing {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        titleFocused = true
                    }
                }
            }
        }
    }
    
    private func saveNote() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        
        if let existingNote = note {
            var updatedNote = existingNote
            updatedNote.title = trimmedTitle
            updatedNote.content = content
            updatedNote.category = selectedCategory
            updatedNote.dateModified = Date()
            notesStore.updateNote(updatedNote)
        } else {
            let newNote = PilotNote(
                title: trimmedTitle,
                content: content,
                dateCreated: Date(),
                dateModified: Date(),
                category: selectedCategory
            )
            notesStore.addNote(newNote)
        }
        
        dismiss()
    }
}

// MARK: - Category Button
struct CategoryButton: View {
    let category: PilotNote.NoteCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.title3)
                    .foregroundColor(isSelected ? .white : category.color)
                
                Text(category.rawValue)
                    .font(.caption2)
                    .foregroundColor(isSelected ? .white : .gray)
            }
            .frame(width: 80, height: 80)
            .background(isSelected ? category.color : LogbookTheme.fieldBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(category.color, lineWidth: isSelected ? 2 : 1)
            )
        }
    }
}