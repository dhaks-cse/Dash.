//
//  ProjectView.swift
//  Dash
//

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

    private enum DS {
        static let bg = Color.black
        static let card = Color(red: 0.12, green: 0.12, blue: 0.14)
        static let inputFill = Color(red: 0.18, green: 0.18, blue: 0.20)
        static let border = Color.white.opacity(0.12)

        static let textPri = Color.white
        static let textSec = Color(UIColor.systemGray2)
        static let textTer = Color(UIColor.systemGray3)

        static let accent = Color.purple
        static let green = Color.green
        static let orange = Color.orange
        static let red = Color.red

        static let hPad: CGFloat = 18
        static let cardR: CGFloat = 18
    }

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

    // MARK: Body

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottomTrailing) {

                DS.bg.ignoresSafeArea()

                VStack(spacing: 0) {
                    headerBar
                    searchBar
                    statsRow
                    filterBar
                    projectList
                }

                plannerFAB {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    showingAddProject = true
                }

                // Hidden NavigationLink — logic unchanged
                NavigationLink(
                    destination: selectedProject.map { proj in
                        ProjectDetailView(
                            project: Binding(
                                get: {
                                    projects.first { $0.id == proj.id } ?? proj
                                },
                                set: { nv in
                                    if let i = projects.firstIndex(where: { $0.id == proj.id }) {
                                        projects[i] = nv
                                        saveProjects()
                                    }
                                }
                            ),
                            projects: $projects
                        )
                    },
                    isActive: Binding(
                        get: { selectedProject != nil },
                        set: { if !$0 { selectedProject = nil } }
                    )
                ) { EmptyView() }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingAddProject) {
                AddProjectView(projects: $projects)
            }
            .onAppear { loadProjects() }
        }
    }

    // MARK: Header — bell · title · menu, identical rhythm to NotesView / Planner

    var headerBar: some View {
        HStack {
            // Icon placeholder (matches planner left-icon position)
            Image(systemName: "folder")
                .font(.system(size: 17, weight: .regular))
                .foregroundColor(DS.textSec)
                .frame(width: 36, height: 36)

            Spacer()

            VStack(spacing: 2) {
                Text("Projects")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(DS.textPri)
                Text("\(projects.count) total")
                    .font(.system(size: 12))
                    .foregroundColor(DS.textSec)
            }

            Spacer()

            AppMenuButton()
                .frame(width: 36, height: 36)
                .foregroundColor(DS.textSec)
        }
        .padding(.horizontal, DS.hPad)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(DS.bg)
    }

    // MARK: Search — same as NotesView

    var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(DS.textTer)

            TextField("Search projects…", text: $searchText)
                .font(.system(size: 15))
                .foregroundColor(DS.textPri)
                .tint(DS.accent)

            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(DS.textTer)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(DS.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(DS.border, lineWidth: 0.5)
        )
        .padding(.horizontal, DS.hPad)
        .padding(.bottom, 12)
    }

    // MARK: Stats Row — three metric cards, same layout as planner's progress row

    var statsRow: some View {
        HStack(spacing: 8) {
            statCard(value: "\(activeCount)",    label: "Active",  color: DS.accent,  icon: "bolt.fill")
            statCard(value: "\(completedCount)", label: "Done",    color: DS.green,   icon: "checkmark.seal.fill")
            statCard(value: "\(overdueCount)",   label: "Overdue", color: DS.red,     icon: "exclamationmark.triangle.fill")
        }
        .padding(.horizontal, DS.hPad)
        .padding(.bottom, 12)
    }

    private func statCard(value: String, label: String, color: Color, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(DS.textPri)
                Text(label)
                    .font(.system(size: 11))
                    .foregroundColor(DS.textSec)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(DS.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(DS.border, lineWidth: 0.5)
        )
    }

    // MARK: Filter Bar — planner pill segmented bar

    var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SortOption.allCases) { opt in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { sortOption = opt }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Text(opt.rawValue)
                            .font(.system(size: 14, weight: sortOption == opt ? .medium : .regular))
                            .foregroundColor(sortOption == opt ? DS.textPri : DS.textSec)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(sortOption == opt ? DS.accent : DS.card)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DS.hPad)
        }
        .padding(.bottom, 12)
    }

    // MARK: Project List

    var projectList: some View {
        Group {
            if sortedProjects.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(sortedProjects) { project in
                        projectCard(project)
                            .listRowInsets(EdgeInsets(top: 4, leading: DS.hPad, bottom: 4, trailing: DS.hPad))
                            .listRowSeparator(.hidden)
                            .listRowBackground(DS.bg)
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
                .background(DS.bg)
            }
        }
    }

    // MARK: Project Card — mirrors planner task card structure exactly

    private func projectCard(_ project: Project) -> some View {

        let today = Calendar.current.startOfDay(for: Date())
        let end   = Calendar.current.startOfDay(for: project.endDate)
        let days  = Calendar.current.dateComponents([.day], from: today, to: end).day ?? 0

        let deadlineColor: Color = project.isProjectCompleted ? DS.textTer
            : (days < 0 ? DS.red : days <= 10 ? DS.orange : DS.green)

        return HStack(alignment: .top, spacing: 14) {

            // Left: status circle — mirrors planner task completion circle
            ZStack {
                if project.isProjectCompleted {
                    Circle()
                        .fill(DS.green)
                        .frame(width: 22, height: 22)
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                } else if days < 0 {
                    Circle()
                        .strokeBorder(DS.red, lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                    Image(systemName: "exclamationmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(DS.red)
                } else {
                    Circle()
                        .strokeBorder(DS.border, lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                    Image(systemName: "folder")
                        .font(.system(size: 9))
                        .foregroundColor(DS.textTer)
                }
            }
            .padding(.top, 2)

            // Right: content block
            VStack(alignment: .leading, spacing: 8) {

                // Title + status badge — mirrors planner's "Medium" / "High" pill
                HStack(alignment: .top) {
                    Text(project.name.isEmpty ? "Untitled" : project.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(project.isProjectCompleted ? DS.textSec : DS.textPri)
                        .strikethrough(project.isProjectCompleted, color: DS.textTer)
                        .lineLimit(1)

                    Spacer()

                    // Status pill — same pill style as planner priority tag
                    if project.isProjectCompleted {
                        statusPill("Completed", color: DS.green)
                    } else if days < 0 {
                        statusPill("Overdue", color: DS.red)
                    } else if !project.projectType.isEmpty {
                        statusPill(project.projectType, color: DS.accent)
                    }
                }

                // Customer / developer meta
                if !project.customer.isEmpty || !project.developer.isEmpty {
                    HStack(spacing: 12) {
                        if !project.customer.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "person")
                                    .font(.system(size: 10))
                                Text(project.customer)
                                    .font(.system(size: 13))
                                    .lineLimit(1)
                            }
                            .foregroundColor(DS.textSec)
                        }
                        if !project.developer.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "hammer")
                                    .font(.system(size: 10))
                                Text(project.developer)
                                    .font(.system(size: 13))
                                    .lineLimit(1)
                            }
                            .foregroundColor(DS.textTer)
                        }
                        Spacer()
                    }
                }

                // Progress bar — mirrors planner's Today's Progress bar exactly
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(DS.inputFill)
                            .frame(height: 5)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(project.isProjectCompleted ? DS.green : DS.accent)
                            .frame(width: geo.size.width * CGFloat(project.progress), height: 5)
                    }
                }
                .frame(height: 5)

                // Footer meta row
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 9))
                        Text(deadlineLabel(for: project))
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(deadlineColor)

                    Text("·")
                        .foregroundColor(DS.textTer)

                    Text("\(Int(project.progress * 100))%")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(DS.textTer)

                    Spacer()

                    // Amount badge
                    if project.totalAmount > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "banknote")
                                .font(.system(size: 9))
                            Text(String(format: "%.0f", project.totalAmount))
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(DS.green)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(DS.green.opacity(0.12)))
                    }

                    // GitHub link
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
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(DS.accent)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(DS.accent.opacity(0.12)))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(DS.card)
        .clipShape(RoundedRectangle(cornerRadius: DS.cardR, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.cardR, style: .continuous)
                .stroke(DS.border, lineWidth: 0.5)
        )
    }

    // Status pill — same pill style as planner "Medium" / "High" priority badge
    private func statusPill(_ label: String, color: Color) -> some View {
        Text(label)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.15)))
    }

    // MARK: Empty State

    var emptyState: some View {
        VStack(spacing: 14) {
            Spacer().frame(height: 80)
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(DS.textTer)
            Text("No Projects Yet")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(DS.textSec)
            Text("Tap + to create your first project")
                .font(.system(size: 14))
                .foregroundColor(DS.textTer)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func plannerFAB(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(Circle().fill(DS.accent))
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .padding(.trailing, 20)
        .padding(.bottom, 24)
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
