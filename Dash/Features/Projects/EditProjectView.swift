//
//  EditProjectView.swift
//  Dash
//

import SwiftUI
import Foundation

struct EditProjectView: View {

    @Binding var project: Project
    @Binding var projects: [Project]

    @Environment(\.presentationMode) var presentationMode

    @State private var selectedLanguages = [String]()
    @State private var totalAmountText = ""

    let projectTypes = [
        "Android App","iOS App","Cross Platform App","Website",
        "Android App and Website","iOS App and Website",
        "Cross Platform App and Website","IOT","Others"
    ]

    let languages = [
        "Java","Kotlin","C++","Dart","Rust","Swift","Objective-C","SwiftUI",
        "React Native","Flutter","Xamarin","HTML","CSS","JavaScript",
        "Python","TypeScript","Go","MySQL","PostgreSQL","Node.js"
    ]

    let paymentMethods = [
        "Credit Card","Debit Card","PayPal","Bank Transfer","UPI","Other"
    ]

    var body: some View {

        ZStack {

            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {

                header

                ScrollView {

                    VStack(spacing: 14) {

                        section("Project Info", "folder.fill")

                        textField("Project Name", $project.name, "pencil")
                        textField("Developer", $project.developer, "hammer")
                        textField("Customer", $project.customer, "person")
                        textField("GitHub Repository", $project.githubRepo, "chevron.left.forwardslash.chevron.right")

                        divider

                        section("Timeline", "calendar")

                        dateField("Start Date", $project.startDate)
                        dateField("Expected End Date", $project.endDate)

                        divider

                        section("Tech Stack", "cpu")

                        picker("Project Type", $project.projectType, projectTypes, "iphone")

                        languageField

                        divider

                        section("Payment", "banknote")

                        picker("Payment Method", $project.paymentMethod, paymentMethods, "creditcard")

                        amountField

                        divider

                        section("Progress", "chart.bar.fill")

                        progressField

                        Color.clear.frame(height: 20)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                }

                bottomButton
            }
        }
        .onAppear {
            selectedLanguages = project.languagesUsed
                .components(separatedBy: ",")
                .filter { !$0.isEmpty }

            totalAmountText = project.totalAmount == 0 ? "" : "\(Int(project.totalAmount))"
        }
    }

    // MARK: Header

    var header: some View {

        HStack {

            Button {
                presentationMode.wrappedValue.dismiss()
            } label: {
                Text("Cancel")
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            Text("Edit Project")
                .font(.headline)
                .foregroundColor(.white)

            Spacer()

            Text("Cancel")
                .opacity(0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Color.black)
    }

    // MARK: Section

    func section(_ title: String, _ icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.purple)

            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .foregroundColor(.secondary)

            Spacer()
        }
    }

    // MARK: TextField

    func textField(_ placeholder: String, _ text: Binding<String>, _ icon: String) -> some View {

        HStack {

            Image(systemName: icon)
                .foregroundColor(.purple)

            TextField(placeholder, text: text)
                .foregroundColor(.white)
        }
        .padding(14)
        .background(card)
    }

    // MARK: DateField

    func dateField(_ label: String, _ binding: Binding<Date>) -> some View {

        HStack {

            Image(systemName: "calendar")
                .foregroundColor(.purple)

            DatePicker(label, selection: binding, displayedComponents: .date)
                .colorScheme(.dark)
        }
        .padding(14)
        .background(card)
    }

    // MARK: Picker

    func picker(_ label: String, _ selection: Binding<String>, _ options: [String], _ icon: String) -> some View {

        HStack {

            Image(systemName: icon)
                .foregroundColor(.purple)
                .frame(width: 20)

            Picker(label, selection: selection) {
                Text("Select").tag("")
                ForEach(options, id: \.self) {
                    Text($0).tag($0)
                }
            }
            .colorScheme(.dark)
            .tint(.purple)
            .frame(maxWidth: 220, alignment: .leading)

            Spacer()
        }
        .padding(14)
        .background(card)
    }

    // MARK: Languages

    var languageField: some View {

        VStack(alignment: .leading, spacing: 10) {

            MultiSelectPicker(
                selections: $selectedLanguages,
                options: languages,
                title: "Languages Used"
            )

            if !selectedLanguages.isEmpty {

                ScrollView(.horizontal, showsIndicators: false) {

                    HStack {

                        ForEach(selectedLanguages, id: \.self) { lang in

                            Text(lang)
                                .font(.caption)
                                .foregroundColor(.purple)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule()
                                        .fill(Color.purple.opacity(0.15))
                                )
                        }
                    }
                }
            }
        }
    }

    // MARK: Amount

    var amountField: some View {

        HStack {

            Image(systemName: "banknote")
                .foregroundColor(.purple)

            TextField("Total Amount", text: $totalAmountText)
                .keyboardType(.decimalPad)
                .foregroundColor(.white)
                .onChange(of: totalAmountText) { v in
                    if let n = Double(v) {
                        project.totalAmount = n
                    }
                }
        }
        .padding(14)
        .background(card)
    }

    // MARK: Progress

    var progressField: some View {

        VStack(spacing: 10) {

            HStack {
                Text("Progress")
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(Int(project.progress * 100))%")
                    .foregroundColor(.purple)
            }

            GeometryReader { geo in

                ZStack(alignment: .leading) {

                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(red: 0.18, green: 0.18, blue: 0.20))
                        .frame(height: 5)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.purple)
                        .frame(width: geo.size.width * CGFloat(project.progress), height: 5)
                }
            }
            .frame(height: 5)

            Slider(value: $project.progress, in: 0...1)
                .tint(.purple)
        }
        .padding(14)
        .background(card)
    }

    // MARK: Divider

    var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.05))
            .frame(height: 1)
    }

    // MARK: Bottom Button

    var bottomButton: some View {

        Button {

            save()
            presentationMode.wrappedValue.dismiss()

        } label: {

            Text("Save Changes")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.purple)
                )
        }
        .padding(20)
    }

    // MARK: Card Style

    var card: some View {

        RoundedRectangle(cornerRadius: 18)
            .fill(Color(red: 0.12, green: 0.12, blue: 0.14))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
            )
    }

    // MARK: Save

    func save() {

        project.languagesUsed = selectedLanguages.joined(separator: ",")

        if let data = try? JSONEncoder().encode(projects) {
            UserDefaults.standard.set(data, forKey: "projects")
        }
    }
}
