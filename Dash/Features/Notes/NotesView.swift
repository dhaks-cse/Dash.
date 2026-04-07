//
//  NotesView.swift
//  Dash
//

import SwiftUI
import UserNotifications

struct NotesView: View {

    @StateObject private var viewModel = NotesViewModel()

    @State private var selectedNote: Note? = nil
    @State private var searchText = ""
    @State private var pinnedNotes: Set<UUID> = []
    @State private var refreshID = UUID()

    @State private var notificationsEnabled = false
    @State private var showNotificationAlert = false
    @State private var showUnlockPrompt = false
    @State private var showNoteUnlock = false
    @State private var noteToUnlock: Note?
    @State private var enteredPassword = ""
 
    enum SortOption: String, CaseIterable, Identifiable {
        case createdDescending = "Newest"
        case createdAscending  = "Oldest"
        case titleAscending    = "A–Z"
        case titleDescending   = "Z–A"
        var id: String { rawValue }
    }

    @State private var sortOption: SortOption = .createdDescending

    // MARK: - Derived

    var filteredNotes: [Note] {
        guard !searchText.isEmpty else { return viewModel.notes }
        return viewModel.notes.filter {
            $0.title.lowercased().contains(searchText.lowercased()) ||
            $0.content.lowercased().contains(searchText.lowercased())
        }
    }

    var sortedNotes: [Note] {
        let base: [Note]
        switch sortOption {
        case .createdDescending: base = filteredNotes.sorted { $0.createdAt > $1.createdAt }
        case .createdAscending:  base = filteredNotes.sorted { $0.createdAt < $1.createdAt }
        case .titleAscending:    base = filteredNotes.sorted { $0.title.lowercased() < $1.title.lowercased() }
        case .titleDescending:   base = filteredNotes.sorted { $0.title.lowercased() > $1.title.lowercased() }
        }
        return base.sorted { pinnedNotes.contains($0.id) && !pinnedNotes.contains($1.id) }
    }

    var pinnedList: [Note]   { sortedNotes.filter {  pinnedNotes.contains($0.id) } }
    var unpinnedList: [Note] { sortedNotes.filter { !pinnedNotes.contains($0.id) } }

    // Note count stats
    var totalNotes: Int    { viewModel.notes.count }
    var withReminder: Int  { viewModel.notes.filter { $0.reminder != nil }.count }

    // MARK: - Body

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {

                    // ── Stats header — mirrors planner's progress header ──
                    statsHeader

                    Divider()
                        .background(Color.white.opacity(0.15))
                        .padding(.horizontal, 18)

                    // ── Filter / Sort bar — mirrors planner's filter bar ──
                    filterBar

                    // ── Search bar below filter ──
                    searchBar

                    Divider()
                        .background(Color.white.opacity(0.15))
                        .padding(.horizontal, 18)

                    // ── Notes list ──
                    notesSection
                }

                // FAB
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            let n = Note(title: "", content: "")
                            viewModel.notes.append(n)
                            selectedNote = n
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                                .padding(20)
                                .background(Circle().fill(Color.purple))
                                .shadow(radius: 8)
                        }
                        .padding(.bottom, 24)
                        .padding(.trailing, 22)
                    }
                }
            }
            .navigationTitle("Notes")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selectedNote) { note in
                NavigationView {
                    EditNoteView(
                        note: Binding(
                            get: { viewModel.notes.first { $0.id == note.id } ?? note },
                            set: { newValue in
                                if let index = viewModel.notes.firstIndex(where: { $0.id == newValue.id }) {
                                    viewModel.notes[index] = newValue
                                }
                            }
                        ),
                        viewModel: viewModel
                    )
                }
            }
            .onAppear {
                refreshID = UUID()
                checkNotificationStatus()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        requestOrToggleNotifications()
                    } label: {
                        Image(systemName: "bell")
                            .foregroundColor(.white)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    AppMenuButton()
                }
            }
            .alert("Reminder Notifications", isPresented: $showNotificationAlert) {
                Button("Enable") {
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                        DispatchQueue.main.async { notificationsEnabled = granted }
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Unlock Note", isPresented: $showUnlockPrompt) {

                SecureField("Enter password", text: $enteredPassword)

                Button("Unlock") {

                    let appPassword = UserDefaults.standard.string(forKey: "appPassword") ?? ""

                    if enteredPassword == appPassword {

                        if let note = noteToUnlock,
                           let index = viewModel.notes.firstIndex(where: {$0.id == note.id}) {

                            viewModel.notes[index].isLocked = false
                            openNote(viewModel.notes[index])
                        }
                    }

                    enteredPassword = ""
                }

                Button("Cancel", role: .cancel) {
                    enteredPassword = ""
                }

            }
            message: {
                Text("Allow Dash to send you reminder notifications for your notes.")
            }
            
            .fullScreenCover(isPresented: $showNoteUnlock) {

                PINLockView(onUnlock: {

                    if let note = noteToUnlock,
                       let index = viewModel.notes.firstIndex(where: { $0.id == note.id }) {

                        viewModel.notes[index].isLocked = false
                        openNote(viewModel.notes[index])
                    }

                    showNoteUnlock = false
                })

            }
        }
    }

    private var editNoteNavigationLink: some View {
        NavigationLink(
            destination: selectedNote.map { sel in
                EditNoteView(
                    note: Binding(
                        get: { viewModel.notes.first { $0.id == sel.id } ?? sel },
                        set: { nv in
                            if let i = viewModel.notes.firstIndex(where: { $0.id == nv.id }) {
                                viewModel.notes[i] = nv
                            }
                        }
                    ),
                    viewModel: viewModel
                )
            },
            isActive: Binding(
                get: { selectedNote != nil },
                set: { if !$0 { selectedNote = nil } }
            )
        ) {
            EmptyView()
        }
    }

    // MARK: - Stats Header (mirrors planner's progress header)

    var statsHeader: some View {
        VStack(alignment: .leading, spacing: 10) {

            Text("Your Notes")
                .font(.subheadline.weight(.bold))
                .foregroundColor(.secondary)

            Text("\(totalNotes) note\(totalNotes == 1 ? "" : "s") · \(withReminder) with reminder\(withReminder == 1 ? "" : "s")")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "pin.fill")
                        .foregroundColor(.purple)
                    Text("\(pinnedNotes.count) pinned")
                        .font(.caption)
                }

                Spacer()

                // Quick-compose shortcut
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    let n = Note(title: "", content: "• ")
                    viewModel.notes.append(n)
                    selectedNote = n
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "list.bullet")
                        Text("Quick List")
                    }
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.purple.opacity(0.2))
                    .cornerRadius(8)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 6)
        .padding(.bottom, 6)
    }

    // MARK: - Filter Bar (mirrors planner exactly)

    var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(SortOption.allCases) { opt in
                    Text(opt.rawValue)
                        .font(.subheadline)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(
                                sortOption == opt
                                    ? Color.purple
                                    : Color(UIColor.systemGray5)
                            )
                        )
                        .foregroundColor(sortOption == opt ? .white : .primary)
                        .onTapGesture {
                            withAnimation { sortOption = opt }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 6)
        }
    }

    // MARK: - Search Bar

    var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(.secondary)

            TextField("Search notes…", text: $searchText)
                .font(.subheadline)
                .foregroundColor(.primary)
                .tint(.purple)

            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color(red: 0.12, green: 0.12, blue: 0.14))
        .cornerRadius(12)
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 10)
    }

    // MARK: - Notes Section

    var notesSection: some View {
        List {
            if !pinnedList.isEmpty {
                HStack {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundColor(.purple)
                    Text("Pinned")
                        .font(.headline)
                    Spacer()
                }
                .padding(.horizontal, 18)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.black)
                .padding(.top, 6)

                ForEach(pinnedList) { note in
                    noteCard(note)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.black)
                        .padding(.vertical, 8)
                        .swipeActions(edge: .leading) {
                            Button {
                                togglePin(note)
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            } label: {
                                Label("Unpin", systemImage: "pin.slash")
                            }
                            .tint(.purple)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) { deleteNote(note) } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button { share(note) } label: {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                            .tint(Color(UIColor.systemGray3))
                        }
                        .onTapGesture {

                            if note.isLocked {
                                noteToUnlock = note
                                showUnlockPrompt = true
                            } else {
                                openNote(note)
                            }

                        }
                        .onLongPressGesture {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            togglePin(note)
                        }
                }
            }

            if !unpinnedList.isEmpty {
                if !pinnedList.isEmpty {
                    HStack {
                        Text("All Notes")
                            .font(.headline)
                        Spacer()
                    }
                    .padding(.horizontal, 18)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.black)
                    .padding(.top, 6)
                }

                ForEach(unpinnedList) { note in
                    noteCard(note)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.black)
                        .padding(.vertical, 8)
                        .swipeActions(edge: .leading) {
                            Button {
                                togglePin(note)
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            } label: {
                                Label("Pin", systemImage: "pin")
                            }
                            .tint(.purple)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) { deleteNote(note) } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button { share(note) } label: {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                            .tint(Color(UIColor.systemGray3))
                        }
                        .onTapGesture { openNote(note) }
                        .contextMenu {

                            

                            Button(role: .destructive) {
                                deleteNote(note)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }

                            Divider()

                            Button {
                                togglePin(note)
                            } label: {
                                Label("Pin Note", systemImage: "pin")
                            }

                            Button {
                                duplicateNote(note)
                            } label: {
                                Label("Duplicate Note", systemImage: "doc.on.doc")
                            }
                        }
                }
            }

            if sortedNotes.isEmpty {
                emptyState
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.black)
            }

            Color.clear.frame(height: 90)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
        }
        .id(refreshID)
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Note Card (mirrors taskCard exactly, with purple left vertical line)

    func noteCard(_ note: Note) -> some View {
        HStack(spacing: 14) {

            // Purple vertical line on left — always shown, aesthetic accent
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.purple)
                .frame(width: 3, height: 44)

            VStack(alignment: .leading, spacing: 6) {

                HStack {
                    noteBadge(note)

                    HStack(spacing: 6) {
                        
                        
                        Text(note.title.isEmpty ? "Untitled" : note.title)
                        
                            .font(.headline)
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }

                    Spacer()

                    if let first = note.images.first {
                        Image(uiImage: first.image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 34, height: 34)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }

                if !note.content.isEmpty {
                    Text(note.content)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Text(note.createdAt, style: .date)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(red: 0.12, green: 0.12, blue: 0.14))
                .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 3)
        )
        .padding(.horizontal, 16)
    }

    func noteBadge(_ note: Note) -> some View {
        let label: String = {
            if pinnedNotes.contains(note.id) { return "Pinned" }
            if note.reminder != nil           { return "Reminder" }
            return "Note"
        }()

        return Text(label)
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.purple.opacity(0.2))
            .foregroundColor(.purple)
            .cornerRadius(6)
    }

    // MARK: - Empty State

    var emptyState: some View {
        VStack(spacing: 14) {
            Spacer().frame(height: 60)
            Image(systemName: "note.text")
                .font(.system(size: 38, weight: .light))
                .foregroundColor(.secondary)
            Text("No Notes Yet")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Tap + to write your first note")
                .font(.caption)
                .foregroundColor(Color(UIColor.systemGray3))
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    private func openNote(_ note: Note) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        refreshID = UUID()
        selectedNote = note
    }

    func togglePin(_ note: Note) {
        if pinnedNotes.contains(note.id) { pinnedNotes.remove(note.id) }
        else { pinnedNotes.insert(note.id) }
    }

    func deleteNote(_ note: Note) {
        viewModel.notes.removeAll { $0.id == note.id }
    }

    func share(_ note: Note) {
        let vc = UIActivityViewController(
            activityItems: ["\(note.title)\n\n\(note.content)"],
            applicationActivities: nil
        )
        UIApplication.shared.windows.first?.rootViewController?.present(vc, animated: true)
    }
    
    func duplicateNote(_ note: Note) {

        var newNote = Note(
            id: UUID(),
            title: note.title,
            content: note.content,
            images: note.images,
            createdAt: Date(),
            colorHex: note.colorHex,
            reminder: note.reminder
        )
        newNote.isLocked = note.isLocked

        viewModel.notes.insert(newNote, at: 0)
    }
    

    // MARK: - Notifications

    private func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationsEnabled = settings.authorizationStatus == .authorized
            }
        }
    }

    private func requestOrToggleNotifications() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                if settings.authorizationStatus == .notDetermined {
                    showNotificationAlert = true
                } else if settings.authorizationStatus == .authorized {
                    // Already enabled — show a summary alert of upcoming reminders
                    notificationsEnabled = true
                    showNotificationAlert = true
                } else {
                    // Denied — direct to Settings
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }
        }
    }
}
