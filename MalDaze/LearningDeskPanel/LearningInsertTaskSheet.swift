import SwiftUI

struct LearningInsertTaskSheet: View {
    let projects: [LearningProjectOption]
    let defaultDate: String
    let onSubmit: (String, String, Int, String) -> Void
    let onCancel: () -> Void

    @State private var title = ""
    @State private var duration = 45
    @State private var pickedDate = Date()
    @State private var projectId: String

    init(
        projects: [LearningProjectOption],
        defaultDate: String,
        onSubmit: @escaping (String, String, Int, String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.projects = projects
        self.defaultDate = defaultDate
        self.onSubmit = onSubmit
        self.onCancel = onCancel
        _projectId = State(initialValue: projects.first?.id ?? "")
        if let parsed = Self.parseISODate(defaultDate) {
            _pickedDate = State(initialValue: parsed)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("添加学习任务")
                .font(.headline)

            if projects.isEmpty {
                Text("没有可添加任务的活跃项目。请先在 Hermes 对话发送链接创建学习项目。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Form {
                    TextField("任务标题", text: $title)
                    Stepper("时长：\(duration) 分钟", value: $duration, in: 5...240, step: 5)
                    Section("日期") {
                        ScrollMonthDatePicker(selection: $pickedDate, accessibilityLabel: "任务日期")
                            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    }
                    Picker("项目", selection: $projectId) {
                        ForEach(projects) { project in
                            Text(project.name).tag(project.id)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .formStyle(.grouped)
            }

            HStack {
                Spacer()
                Button("取消", action: onCancel)
                Button("添加") {
                    onSubmit(projectId, title.trimmingCharacters(in: .whitespacesAndNewlines), duration, Self.isoDate(pickedDate))
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSubmit)
            }
        }
        .padding(20)
        .frame(width: 360)
        .frame(minHeight: 520)
        .onChange(of: projects.map(\.id)) { _ in
            if !projects.contains(where: { $0.id == projectId }) {
                projectId = projects.first?.id ?? ""
            }
        }
    }

    private var canSubmit: Bool {
        !projects.isEmpty
            && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !projectId.isEmpty
    }

    private static func parseISODate(_ iso: String) -> Date? {
        let parts = iso.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var comps = DateComponents()
        comps.year = parts[0]
        comps.month = parts[1]
        comps.day = parts[2]
        return Calendar.current.date(from: comps)
    }

    private static func isoDate(_ date: Date) -> String {
        let cal = Calendar.current
        let y = cal.component(.year, from: date)
        let m = cal.component(.month, from: date)
        let d = cal.component(.day, from: date)
        return String(format: "%04d-%02d-%02d", y, m, d)
    }
}
