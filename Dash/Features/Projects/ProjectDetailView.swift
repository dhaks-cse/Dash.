//
//  ProjectDetailView.swift
//  Dash
//
//  Created by Trijal Gunaseelan on 11/22/24.
//

import SwiftUI

struct ProjectDetailView: View {
    @Binding var project: Project
    @Binding var projects: [Project] 
    @State private var showingEditProject = false
    @State private var lastEditedDate: Date? = nil
    @State private var isPaymentDone: Bool = false
    @State private var isProjectCompleted: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HStack {
                    Spacer()
                    Text(project.name)
                        .font(.system(size: 28, weight: .semibold))
                        .fontWeight(.semibold)
                        .foregroundColor(.purple)
                        .padding(.top, -20)
                        .padding(.bottom, 30)
                    Spacer()
                    Button(action: {
                        showingEditProject = true
                    }) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top)

                detailRow(title: "Developer", value: project.developer)
                detailRow(title: "Customer", value: project.customer)
                detailRow(title: "Start Date", value: formattedDate(project.startDate))
                detailRow(title: "Expected End Date", value: formattedDate(project.endDate))
                detailRow(title: "Project Type", value: project.projectType)
                detailRow(title: "Languages Used", value: project.languagesUsed)
                detailRow(title: "Total Amount", value: String(project.totalAmount))
                detailRow(title: "Payment Method", value: project.paymentMethod)
                
                HStack {
                    detailRow(title: "GitHub Repo", value: project.githubRepo)
                    if !project.githubRepo.isEmpty {
                        Button(action: {
                            if let url = URL(string: project.githubRepo) {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            Image(systemName: "arrow.up.right.square.fill")
                                .font(.title2)
                                .foregroundColor(.purple)
                        }
                    }
                }

                VStack {
                    Text("Project Progress")
                        .font(.title2)
                        .padding(.top)
                    ProgressView(value: project.progress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .padding(.horizontal)
                }

                VStack {
                    if daysRemaining() > 0 {
                        HStack {
                            Image(systemName: "hourglass.bottomhalf.fill")
                                .font(.title)
                                .foregroundColor(.purple)
                            Text("\(daysRemaining()) days remaining")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                    }
                }

                Toggle(isOn: $isPaymentDone) {
                    Text("Payment Done")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                .padding(.horizontal)
                .onChange(of: isPaymentDone) { newValue in
                    project.isPaymentDone = newValue
                    autoSave()
                }

                Toggle(isOn: $isProjectCompleted) {
                    Text("Project Completed")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                .padding(.horizontal)
                .onChange(of: isProjectCompleted) { newValue in
                    project.isProjectCompleted = newValue
                    autoSave()
                }
                
                if let lastEdited = lastEditedDate {
                    Text("Last Edited: \(formattedDate(lastEdited))")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.top, 5)
                }

                Spacer()
            }
            .padding()
        }
        .background(Color.black.ignoresSafeArea())
        .sheet(isPresented: $showingEditProject) {
            EditProjectView(project: $project, projects: $projects)
        }
        .onAppear {
            isPaymentDone = project.isPaymentDone
            isProjectCompleted = project.isProjectCompleted
        }
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text("\(title):")
                .font(.headline)
                .foregroundColor(.primary)
            Spacer()
            Text(value)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private func daysRemaining() -> Int {
        let calendar = Calendar.current
        let currentDate = Date()
        let components = calendar.dateComponents([.day], from: currentDate, to: project.endDate)
        return max(0, components.day ?? 0)
    }

    private func autoSave() {
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index] = project
        } else {
            projects.append(project)
        }
        
        if let data = try? JSONEncoder().encode(projects) {
            UserDefaults.standard.set(data, forKey: "projects")
        }
    }
}
