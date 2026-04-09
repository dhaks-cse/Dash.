//
//  EditNoteView.swift
//  Dash
//

import SwiftUI
import UserNotifications

struct EditNoteView: View {

    @Binding var note: Note
    @ObservedObject var viewModel: NotesViewModel
    @Environment(\.presentationMode) var presentationMode

    @State private var isImagePickerPresented = false
    @State private var selectedImage: IdentifiableImage? = nil
    @State private var tags: String = ""
    @State private var showingLinkInput = false
    @State private var linkText = ""
    @State private var showReminderPicker = false
    @State private var reminderDate = Date().addingTimeInterval(3600)
    @State private var isReminderSet = false

    // Quick List — bullet items as an ordered array for drag-to-reorder
    @State private var bulletItems: [BulletItem] = []
    @State private var isQuickList: Bool = false
    @State private var newBulletText: String = ""

    var wordCount: Int { note.content.split(separator: " ").count }
    var charCount: Int { note.content.count }
    var readMin: Int {
        let minutes = Double(wordCount) / 200.0
        return max(1, Int(ceil(minutes)))
    }

    // MARK: - BulletItem model (local, view-only)

    struct BulletItem: Identifiable {
        let id = UUID()
        var text: String
        var checked: Bool = false
    }

    // MARK: - Body

    var body: some View {

        Form {

            // MARK: Note Title

            Section(header: Text("Note Title").font(.headline)) {

                TextField("Enter note title", text: $note.title)
                    .onChange(of: note.title) { _ in autoSave() }
            }

            // MARK: Notes / Content — shows Quick List editor if isQuickList, else plain TextEditor

            if isQuickList {

                Section(header:
                    HStack {
                        Text("Quick List").font(.headline)
                        Spacer()
                        // Add new bullet item
                        Button {
                            withAnimation {
                                bulletItems.append(BulletItem(text: ""))
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.purple)
                        }
                    }
                ) {
                    // Drag-to-reorder list of bullet items
                    ForEach($bulletItems) { $item in
                        HStack(spacing: 10) {
                            // Tap to check/uncheck
                            Button {
                                item.checked.toggle()
                                syncBulletsToContent()
                                autoSave()
                            } label: {
                                Image(systemName: item.checked ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(item.checked ? .purple : .gray)
                                    .font(.system(size: 20))
                            }
                            .buttonStyle(.plain)

                            TextField("Item", text: $item.text, onCommit: {
                                syncBulletsToContent()
                                autoSave()
                            })
                            .foregroundColor(item.checked ? .secondary : .primary)
                            .strikethrough(item.checked)
                        }
                    }
                    .onMove { from, to in
                        bulletItems.move(fromOffsets: from, toOffset: to)
                        syncBulletsToContent()
                        autoSave()
                    }
                    .onDelete { offsets in
                        bulletItems.remove(atOffsets: offsets)
                        syncBulletsToContent()
                        autoSave()
                    }
                }

            } else {

                Section(header: Text("Notes").font(.headline)) {

                    ZStack(alignment: .topLeading) {
                        if note.content.isEmpty {
                            Text("Write something…")
                                .foregroundColor(Color(UIColor.placeholderText))
                                .padding(.top, 8)
                                .padding(.leading, 4)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $note.content)
                            .frame(minHeight: 120)
                            .onChange(of: note.content) { value in
                                if value.hasSuffix("\n• ") == false, value.last == "\n" {
                                    let lines = value.split(separator: "\n")
                                    if let last = lines.last, last.hasPrefix("• ") {
                                        note.content += "• "
                                    }
                                }
                                autoSave()
                            }
                    }
                }
            }
            // MARK: Stats

            Section(header: Text("Stats").font(.headline)) {

                HStack(spacing: 0) {
                    statSeg(value: "\(charCount)", label: "chars")
                    Divider()
                    statSeg(value: "\(wordCount)", label: "words")
                    Divider()
                    statSeg(value: "~\(readMin)m", label: "read")
                }
                .frame(maxWidth: .infinity)
            }

            // MARK: Due Date & Time

            Section(header: Text("Due Date & Time").font(.headline)) {

                if isReminderSet {

                    DatePicker(
                        "Due",
                        selection: $reminderDate,
                        in: Date()...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .onChange(of: reminderDate) { newDate in
                        note.reminder = newDate
                        // Reschedule notification with updated time
                        scheduleNotification(for: note, at: newDate)
                        autoSave()
                    }

                    Button(role: .destructive) {
                        isReminderSet = false
                        note.reminder = nil
                        cancelNotification(for: note)
                        autoSave()
                    } label: {
                        HStack {
                            Image(systemName: "xmark.circle")
                            Text("Remove Reminder")
                        }
                    }

                } else {

                    Button {
                        isReminderSet = true
                        note.reminder = reminderDate
                        // Schedule the local notification
                        scheduleNotification(for: note, at: reminderDate)
                        autoSave()
                    } label: {
                        HStack {
                            Image(systemName: "clock")
                            Text("Set Reminder")
                        }
                        .foregroundColor(.purple)
                    }
                }
            }

            // MARK: Tags

            Section(header: Text("Tags").font(.headline)) {

                HStack(spacing: 6) {
                    Image(systemName: "number")
                        .foregroundColor(.secondary)
                    TextField("#ideas  #work  #study", text: $tags)
                }
            }


            // MARK: Attachments

            Section(header: Text("Attachments").font(.headline)) {

                Button {
                    isImagePickerPresented = true
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    HStack {
                        Image(systemName: "photo.badge.plus")
                        Text("Add Photo")
                    }
                    .foregroundColor(.purple)
                }

                if !note.images.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(note.images) { img in
                                Image(uiImage: img.image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 78, height: 70)
                                    .clipped()
                                    .cornerRadius(12)
                                    .onTapGesture { selectedImage = img }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

        }
        .navigationBarTitleDisplayMode(.inline)
        .accentColor(.purple)

        .toolbar {

            ToolbarItem(placement: .principal) {
                Text(
                    note.title.isEmpty
                        ? "New Note"
                        : (note.title.count > 25
                           ? String(note.title.prefix(25)) + "…"
                           : note.title)
                )
                .font(.headline)
                .lineLimit(1)
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    syncBulletsToContent()
                    autoSave()
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(.purple)
            }

            // Centered quick-insert buttons in bottom bar
            ToolbarItemGroup(placement: .bottomBar) {
                Spacer()
                // Toggle Quick List mode
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    if isQuickList {
                        // Exit Quick List — sync back to plain text
                        syncBulletsToContent()
                        isQuickList = false
                    } else {
                        // Enter Quick List — parse existing content into bullets
                        parseBulletsFromContent()
                        isQuickList = true
                    }
                } label: {
                    Image(systemName: isQuickList ? "list.bullet.circle.fill" : "list.bullet")
                        .font(.system(size: 18))
                        .foregroundColor(isQuickList ? .purple : .secondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer()
                tbBtn("checklist")   { note.content += "\n☑ " }
                Spacer()
                tbBtn("link")        { showingLinkInput = true }
                Spacer()
                tbBtn("clock", tint: isReminderSet ? .purple : .secondary) {
                    isReminderSet = true
                    note.reminder = reminderDate
                    scheduleNotification(for: note, at: reminderDate)
                    autoSave()
                }
                Spacer()
            }
        }

        .onAppear {
            // Detect if this is a quick list note
            if note.title == "Quick List" || note.content.hasPrefix("• ") {
                parseBulletsFromContent()
                isQuickList = true
            }
            isReminderSet = note.reminder != nil
            if let r = note.reminder { reminderDate = r }
        }

        .sheet(isPresented: $isImagePickerPresented) {
            ImagePicker(images: $note.images)
        }
        .alert("Insert Link", isPresented: $showingLinkInput) {
            TextField("https://example.com", text: $linkText)
            Button("Add") {
                note.content += "\n🔗 \(linkText)\n"
                linkText = ""
                autoSave()
            }
            Button("Cancel", role: .cancel) {}
        }
        .fullScreenCover(item: $selectedImage) { img in
            ImageViewer(image: img.image)
        }
        .onDisappear {
            let title = note.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let content = note.content.trimmingCharacters(in: .whitespacesAndNewlines)

            if title.isEmpty && content.isEmpty {
                viewModel.notes.removeAll { $0.id == note.id }
            } else {
                autoSave()
            }
        }
    }

    // MARK: - Quick List helpers

    /// Parse note.content lines into bulletItems for reorderable UI
    private func parseBulletsFromContent() {
        let lines = note.content
            .components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        bulletItems = lines.map { line -> BulletItem in
            var text = line
            var checked = false
            if text.hasPrefix("✓ ") { text = String(text.dropFirst(2)); checked = true }
            else if text.hasPrefix("• ") { text = String(text.dropFirst(2)) }
            return BulletItem(text: text, checked: checked)
        }
        if bulletItems.isEmpty {
            bulletItems = [BulletItem(text: "")]
        }
    }

    /// Write bulletItems back into note.content
    private func syncBulletsToContent() {
        guard isQuickList else { return }
        note.content = bulletItems
            .map { item in
                item.checked ? "✓ \(item.text)" : "• \(item.text)"
            }
            .joined(separator: "\n")
    }

    // MARK: - Notification helpers

    /// Schedule a local notification for this note at the given date
    private func scheduleNotification(for note: Note, at date: Date) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }

            let content = UNMutableNotificationContent()
            content.title = note.title.isEmpty ? "Note Reminder" : note.title
            content.body  = note.content.isEmpty
                ? "You have a reminder for this note."
                : String(note.content.prefix(100))
            content.sound = .default
            content.badge = 1

            let comps = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: date
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

            // Use note.id as the notification identifier so we can cancel/replace it
            let request = UNNotificationRequest(
                identifier: note.id.uuidString,
                content: content,
                trigger: trigger
            )

            UNUserNotificationCenter.current().add(request) { _ in }
        }
    }

    /// Cancel any pending notification for this note
    private func cancelNotification(for note: Note) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [note.id.uuidString])
    }

    // MARK: - Stat Segment

    private func statSeg(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Toolbar Button

    private func tbBtn(_ icon: String, tint: Color = .secondary, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(tint)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    func autoSave() {

        let title = note.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let content = note.content.trimmingCharacters(in: .whitespacesAndNewlines)

        if !title.isEmpty || !content.isEmpty {
            viewModel.addOrUpdate(note: note)
        }
    }
}
