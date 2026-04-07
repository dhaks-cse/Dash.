//  ProjectView.swift
//  Dash

import SwiftUI

struct ProjectView: View {

    @State private var projects: [Project] = []
    @State private var showingAddProject = false
    @State private var selectedProject: Project? = nil
    @State private var searchText = ""

    enum SortOption: String, CaseIterable, Identifiable {
        case startDateDescending = "Newest"
        case startDateAscending  = "Oldest"
        case nameAscending       = "A–Z"
        case nameDescending      = "Z–A"
        case completedFirst      = "Completed"
        case activeFirst         = "Active"
        case dueSoon             = "Due Soon"
        var id: String { rawValue }
    }

    @State private var sortOption: SortOption = .startDateDescending

    // MARK: Derived

    var filteredProjects: [Project] {
        if searchText.isEmpty { return projects }
        return projects.filter {
            $0.name.lowercased().contains(searchText.lowercased()) ||
            $0.customer.lowercased().contains(searchText.lowercased()) ||
            $0.developer.lowercased().contains(searchText.lowercased())
        }
    }

    var sortedProjects: [Project] {
        switch sortOption {
        case .startDateDescending: return filteredProjects.sorted { $0.startDate > $1.startDate }
        case .startDateAscending:  return filteredProjects.sorted { $0.startDate < $1.startDate }
        case .nameAscending:       return filteredProjects.sorted { $0.name.lowercased() < $1.name.lowercased() }
        case .nameDescending:      return filteredProjects.sorted { $0.name.lowercased() > $1.name.lowercased() }
        case .completedFirst:      return filteredProjects.sorted { ($0.isProjectCompleted ? 0 : 1) < ($1.isProjectCompleted ? 0 : 1) }
        case .activeFirst:         return filteredProjects.sorted { ($0.isProjectCompleted ? 0 : 1) > ($1.isProjectCompleted ? 0 : 1) }
        case .dueSoon:             return filteredProjects.sorted { $0.endDate < $1.endDate }
        }
    }

    var activeCount:    Int { projects.filter { !$0.isProjectCompleted }.count }
    var completedCount: Int { projects.filter {  $0.isProjectCompleted }.count }
    var overdueCount:   Int {
        projects.filter {
            !$0.isProjectCompleted &&
            Calendar.current.startOfDay(for: $0.endDate) < Calendar.current.startOfDay(for: Date())
        }.count
    }

    var progress: Double {
        guard !projects.isEmpty else { return 0 }
        return Double(completedCount) / Double(projects.count)
    }

    var body: some View {
        NavigationView {
            ZStack {

                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {

                    // MARK: Progress Section — matches DailyPlanner's Today's Progress block
                    VStack(alignment: .leading, spacing: 10) {

                        Text("Projects Overview")
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(.secondary)

                        ProgressView(value: progress)
                            .tint(.purple)
                            .scaleEffect(y: 1.4)

                        Text("\(completedCount) of \(projects.count) projects completed")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text("\(overdueCount) overdue")
                                    .font(.caption)
                            }

                            Spacer()

                            HStack(spacing: 6) {
                                Image(systemName: "bolt.fill")
                                    .foregroundColor(.purple)
                                Text("\(activeCount) active")
                                    .font(.caption)
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 12)

                    Divider()
                        .background(Color.white.opacity(0.15))
                        .padding(.horizontal, 18)

                    // MARK: Search Bar
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)

                        TextField("Search projects…", text: $searchText)
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .tint(.purple)

                        if !searchText.isEmpty {
                            Button { searchText = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(red: 0.12, green: 0.12, blue: 0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                    )
                    .padding(.horizontal, 18)
                    .padding(.top, 10)
                    .padding(.bottom, 4)

                    // MARK: Filter Pills — matches DailyPlanner's filter pill row exactly
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(SortOption.allCases) { opt in
                                Text(opt.rawValue)
                                    .font(.subheadline)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(sortOption == opt ? Color.purple : Color(UIColor.systemGray5))
                                    )
                                    .foregroundColor(sortOption == opt ? .white : .primary)
                                    .onTapGesture {
                                        withAnimation {
                                            sortOption = opt
                                        }
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    }
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                    }

                    Divider()
                        .background(Color.white.opacity(0.15))
                        .padding(.horizontal, 18)

                    // MARK: Project List
                    if sortedProjects.isEmpty {
                        emptyState
                    } else {
                        List {
                            ForEach(sortedProjects) { project in
                                projectCard(project)
                                    .listRowInsets(EdgeInsets())
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.black)
                                    .padding(.vertical, 8)
                                    .onTapGesture {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        selectedProject = project
                                    }
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) { deleteProject(project) } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }

                            Color.clear.frame(height: 100)
                                .listRowInsets(EdgeInsets())
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .background(Color.black)
                    }
                }

                // MARK: FAB — matches DailyPlanner FAB exactly
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            showingAddProject = true
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
            .navigationTitle("Projects")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingAddProject) {
                AddProjectView(projects: $projects)
                    .sheet(item: $selectedProject) { proj in
                        NavigationView {
                            ProjectDetailView(
                                project: Binding(
                                    get: { projects.first { $0.id == proj.id } ?? proj },
                                    set: { nv in
                                        if let i = projects.firstIndex(where: { $0.id == proj.id }) {
                                            projects[i] = nv
                                            saveProjects()
                                        }
                                    }
                                ),
                                projects: $projects
                            )
                        }
                    }
            }
            .onAppear { loadProjects() }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    AppMenuButton()
                }
            }
        }
    }

    // MARK: Project Card — matches DailyPlanner taskCard structure exactly

    private func projectCard(_ project: Project) -> some View {

        let today = Calendar.current.startOfDay(for: Date())
        let end   = Calendar.current.startOfDay(for: project.endDate)
        let days  = Calendar.current.dateComponents([.day], from: today, to: end).day ?? 0

        return HStack(spacing: 14) {

            // Completion circle — mirrors DailyPlanner's checkmark circle button (non-interactive display)
            Image(systemName: project.isProjectCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundColor(project.isProjectCompleted ? .purple : .gray)
                .font(.system(size: 22))

            VStack(alignment: .leading, spacing: 6) {

                HStack {

                    // Status badge — mirrors DailyPlanner priorityBadge pill exactly
                    if project.isProjectCompleted {
                        statusPill("Completed")
                    } else if days < 0 {
                        Text("Overdue")
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.2))
                            .foregroundColor(.red)
                            .cornerRadius(6)
                    } else if !project.projectType.isEmpty {
                        statusPill(project.projectType)
                    }

                    Text(project.name.isEmpty ? "Untitled" : project.name)
                        .font(.headline)
                        .strikethrough(project.isProjectCompleted)
                        .foregroundColor(project.isProjectCompleted ? .gray : .white)
                        .lineLimit(1)
                }

                // Customer / developer — mirrors DailyPlanner's notes line
                if !project.customer.isEmpty || !project.developer.isEmpty {
                    HStack(spacing: 10) {
                        if !project.customer.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "person")
                                    .font(.system(size: 10))
                                Text(project.customer)
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                        }
                        if !project.developer.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "hammer")
                                    .font(.system(size: 10))
                                Text(project.developer)
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .foregroundColor(.secondary)
                }

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(red: 0.18, green: 0.18, blue: 0.20))
                            .frame(height: 4)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.purple)
                            .frame(width: geo.size.width * CGFloat(project.progress), height: 4)
                    }
                }
                .frame(height: 4)

                // Footer row — mirrors DailyPlanner's dueDate caption line
                HStack(spacing: 6) {
                    Text(deadlineLabel(for: project))
                        .font(.caption2)
                        .foregroundColor(
                            project.isProjectCompleted ? .secondary :
                            (days < 0 ? .red : .secondary)
                        )

                    Text("·")
                        .foregroundColor(.secondary)
                        .font(.caption2)

                    Text("\(Int(project.progress * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Spacer()

                    if project.totalAmount > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "banknote")
                                .font(.system(size: 9))
                            Text(String(format: "%.0f", project.totalAmount))
                                .font(.caption2.weight(.semibold))
                        }
                        .foregroundColor(.purple)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.purple.opacity(0.15)))
                    }

                    if !project.githubRepo.isEmpty {
                        Button {
                            if let url = URL(string: project.githubRepo) {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "chevron.left.forwardslash.chevron.right")
                                    .font(.system(size: 9, weight: .semibold))
                                Text("Repo")
                                    .font(.caption2.weight(.medium))
                            }
                            .foregroundColor(.purple)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.purple.opacity(0.15)))
                        }
                        .buttonStyle(.plain)
                    }
                }
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

    // Status pill — mirrors DailyPlanner priorityBadge exactly
    private func statusPill(_ label: String) -> some View {
        Text(label)
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.purple.opacity(0.2))
            .foregroundColor(.purple)
            .cornerRadius(6)
    }

    // MARK: Empty State

    var emptyState: some View {
        VStack(spacing: 14) {
            Spacer().frame(height: 80)
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(.secondary)
            Text("No Projects Yet")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.secondary)
            Text("Tap + to create your first project")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Helpers

    private func deadlineLabel(for project: Project) -> String {
        let today = Calendar.current.startOfDay(for: Date())
        let end   = Calendar.current.startOfDay(for: project.endDate)
        let days  = Calendar.current.dateComponents([.day], from: today, to: end).day ?? 0
        if project.isProjectCompleted { return "Completed" }
        switch days {
        case ..<0:  return "Overdue \(-days)d"
        case 0:     return "Due today"
        case 1:     return "Tomorrow"
        default:    return "\(days)d left"
        }
    }

    private func deleteProject(_ project: Project) {
        projects.removeAll { $0.id == project.id }
        saveProjects()
    }

    private func loadProjects() {
        if let data  = UserDefaults.standard.data(forKey: "projects"),
           let saved = try? JSONDecoder().decode([Project].self, from: data) {
            projects = saved
        }
    }

    private func saveProjects() {
        if let data = try? JSONEncoder().encode(projects) {
            UserDefaults.standard.set(data, forKey: "projects")
        }
    }
}
