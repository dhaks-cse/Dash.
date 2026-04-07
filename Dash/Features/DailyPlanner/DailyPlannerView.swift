//
//  DailyPlannerView.swift
//  Dash
//

import SwiftUI

struct DailyPlannerView: View {

    @StateObject private var viewModel = DailyPlannerViewModel()

    @State private var selectedTask: Task? = nil
    @State private var showingAddTask = false

    @State private var filter: Filter = .all
    @State private var showCalendar = false
    @State private var focusMode = false

    // refresh list to reset swipe state
    @State private var refreshID = UUID()

    enum Filter: String, CaseIterable, Identifiable {
        case all = "All"
        case today = "Today"
        case upcoming = "Upcoming"
        case completed = "Completed"

        var id: String { rawValue }
    }

    var filteredTasks: [Task] {

        var tasks: [Task]

        switch filter {

        case .all:
            tasks = viewModel.tasks

        case .today:
            tasks = viewModel.tasks.filter {
                Calendar.current.isDateInToday($0.dueDate)
            }

        case .upcoming:
            tasks = viewModel.tasks.filter {
                $0.dueDate > Date()
            }

        case .completed:
            tasks = viewModel.tasks.filter {
                $0.isCompleted
            }
        }

        if focusMode {
            tasks = tasks.filter {
                Calendar.current.isDateInToday($0.dueDate)
            }
        }

        return tasks.sorted {
            if $0.isCompleted == $1.isCompleted {
                return $0.dueDate < $1.dueDate
            }
            return !$0.isCompleted
        }
    }

    var progress: Double {

        guard !viewModel.tasks.isEmpty else { return 0 }

        let completed = viewModel.tasks.filter { $0.isCompleted }.count
        return Double(completed) / Double(viewModel.tasks.count)
    }

    var streak: Int {

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var streakCount = 0

        for offset in 0..<365 {

            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { break }

            let completed = viewModel.tasks.contains {
                $0.isCompleted && calendar.isDate($0.dueDate, inSameDayAs: date)
            }

            if completed {
                streakCount += 1
            } else {
                break
            }
        }

        return streakCount
    }

    var body: some View {

        NavigationView {

            ZStack {

                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {

                    VStack(alignment: .leading, spacing: 10) {

                        Text("Today's Progress")
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(.secondary)

                        ProgressView(value: progress)
                            .tint(.purple)
                            .scaleEffect(y: 1.4)

                        Text("\(viewModel.tasks.filter{$0.isCompleted}.count) of \(viewModel.tasks.count) tasks completed")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack {

                            HStack(spacing: 6) {
                                Image(systemName: "bolt.fill")
                                    .foregroundColor(.purple)

                                Text("\(streak) day streak")
                                    .font(.caption)
                            }

                            Spacer()

                            Button {

                                withAnimation {
                                    focusMode.toggle()
                                }

                            } label: {

                                HStack(spacing: 6) {
                                    Image(systemName: "scope")
                                    Text("Focus")
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
                    .padding(.top, 12)
                    .padding(.bottom, 12)

                    Divider()
                        .background(Color.white.opacity(0.15))
                        .padding(.horizontal, 18)

                    ScrollView(.horizontal, showsIndicators: false) {

                        HStack(spacing: 10) {

                            ForEach(Filter.allCases) { item in

                                Text(item.rawValue)
                                    .font(.subheadline)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(filter == item ? Color.purple : Color(UIColor.systemGray5))
                                    )
                                    .foregroundColor(filter == item ? .white : .primary)
                                    .onTapGesture {

                                        withAnimation {
                                            filter = item
                                        }
                                    }
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                    }

                    VStack(alignment: .leading, spacing: 12) {

                        HStack {

                            Text("Calendar")
                                .font(.headline)

                            Spacer()

                            Button {
                                withAnimation {
                                    showCalendar.toggle()
                                }
                            } label: {
                                Image(systemName: "calendar")
                                    .foregroundColor(.purple)
                            }
                        }
                        .padding(.horizontal, 18)

                        if showCalendar {

                            ScrollView(.horizontal, showsIndicators: false) {

                                HStack(spacing: 14) {

                                    ForEach(next7Days(), id: \.self) { date in

                                        VStack(spacing: 6) {

                                            Text(dayLabel(date))
                                                .font(.caption2)
                                                .foregroundColor(.secondary)

                                            Text(dayNumber(date))
                                                .font(.headline)

                                            Circle()
                                                .fill(hasTask(date) ? Color.purple : Color.clear)
                                                .frame(width: 5, height: 5)
                                        }
                                        .frame(width: 52, height: 62)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color(red: 0.15, green: 0.15, blue: 0.18))
                                        )
                                    }
                                }
                                .padding(.horizontal, 18)
                            }
                        }
                    }
                    .padding(.top, 6)
                    .padding(.bottom, 12)

                    Divider()
                        .background(Color.white.opacity(0.15))
                        .padding(.horizontal, 18)

                    List {

                        ForEach(filteredTasks) { task in

                            taskCard(task)
                                .listRowInsets(EdgeInsets())
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.black)
                                .padding(.vertical, 8)

                                .swipeActions(edge: .leading) {

                                    Button {

                                        var updated = task
                                        updated.isCompleted.toggle()

                                        withAnimation {
                                            viewModel.addOrUpdate(updated)
                                        }

                                    } label: {
                                        Label("Complete", systemImage: "checkmark")
                                    }
                                    .tint(.purple)
                                }

                                .swipeActions {

                                    Button {

                                        withAnimation {
                                            viewModel.delete(task)
                                        }

                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    .tint(.red)
                                }

                                .onTapGesture {

                                    // reset swipe state BEFORE navigating
                                    refreshID = UUID()

                                    selectedTask = task
                                }
                        }
                    }
                    .id(refreshID)
                    .scrollContentBackground(.hidden)
                    .listStyle(.plain)
                }

                VStack {

                    Spacer()

                    HStack {

                        Spacer()

                        Button {

                            showingAddTask = true

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

            .navigationTitle("Daily Planner")
            .navigationBarTitleDisplayMode(.inline)

            .onAppear {
                refreshID = UUID()
            }

            .sheet(isPresented: $showingAddTask) {
                AddTaskView(viewModel: viewModel)
            }

            .sheet(item: $selectedTask) { task in
                NavigationView {
                    EditTaskView(task: task, viewModel: viewModel)
                }
            }

            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    AppMenuButton()
                }
            }
        }
    }

    func taskCard(_ task: Task) -> some View {

        HStack(spacing: 14) {

            Button {

                var updated = task
                updated.isCompleted.toggle()

                withAnimation {
                    viewModel.addOrUpdate(updated)
                }

            } label: {

                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(task.isCompleted ? .purple : .gray)
                    .font(.system(size: 22))
            }

            VStack(alignment: .leading, spacing: 6) {

                HStack {

                    priorityBadge(task)

                    Text(task.title)
                        .font(.headline)
                        .strikethrough(task.isCompleted)
                        .foregroundColor(task.isCompleted ? .gray : .white)
                }

                if !task.notes.isEmpty {

                    Text(task.notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Text(task.dueDate, style: .date)
                    .font(.caption2)
                    .foregroundColor(task.dueDate < Date() && !task.isCompleted ? .red : .secondary)
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

    func priorityBadge(_ task: Task) -> some View {

        Text(task.priority.rawValue.capitalized)
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.purple.opacity(0.2))
            .foregroundColor(.purple)
            .cornerRadius(6)
    }

    func next7Days() -> [Date] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: start)
        }
    }

    func dayLabel(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated))
    }

    func dayNumber(_ date: Date) -> String {
        date.formatted(.dateTime.day())
    }

    func hasTask(_ date: Date) -> Bool {
        viewModel.tasks.contains { task in
            Calendar.current.isDate(task.dueDate, inSameDayAs: date)
        }
    }
}
