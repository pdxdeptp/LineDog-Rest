import SwiftUI

struct LearningPreferencesView: View {
    let api: any AssistantAPIClientProtocol

    @State private var dailyCapacityMin: Int = 60
    @State private var isLoading: Bool = true
    @State private var isSaving: Bool = false
    @State private var errorMessage: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("学习偏好")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top)

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Label("每日学习容量", systemImage: "gauge")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    HStack {
                        Stepper(value: $dailyCapacityMin, in: 15...480, step: 15) {
                            Text("\(dailyCapacityMin) 分钟/天")
                                .font(.callout)
                        }
                        .onChange(of: dailyCapacityMin) { newValue in
                            Task { await save(newValue) }
                        }

                        if isSaving {
                            ProgressView().controlSize(.small)
                        }
                    }
                    .padding(.horizontal)

                    Text("每天可用于学习该资料的最大时间，调整后立即生效。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let prefs = try await api.getLearningPreferences()
            dailyCapacityMin = prefs.dailyCapacityMin
        } catch {
            errorMessage = "无法加载设置，请检查后端连接"
        }
        isLoading = false
    }

    private func save(_ value: Int) async {
        isSaving = true
        errorMessage = nil
        do {
            try await api.updateLearningPreferences(LearningPreferences(dailyCapacityMin: value))
        } catch {
            errorMessage = "保存失败，请重试"
        }
        isSaving = false
    }
}
