import SwiftUI

/// 对话视图：消息气泡列表 + 输入框 + 提案确认卡片。
struct ChatView: View {
    @ObservedObject var vm: LearningAssistantViewModel

    @State private var inputText = ""
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // 消息列表
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(vm.chatMessages) { msg in
                            messageBubble(msg)
                                .id(msg.id)
                        }

                        if vm.isSendingMessage {
                            thinkingBubble
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onChange(of: vm.chatMessages.count) { _ in
                    if let last = vm.chatMessages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            // 提案卡片
            if let proposal = vm.currentProposal {
                proposalCard(proposal)
            }

            Divider()

            // 输入框
            inputBar
        }
    }

    // MARK: - Message Bubble

    @ViewBuilder
    private func messageBubble(_ msg: ChatMessage) -> some View {
        HStack {
            if msg.role == .user { Spacer(minLength: 40) }
            Text(msg.text)
                .font(.callout)
                .foregroundStyle(msg.role == .user ? Color.white : Color.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    msg.role == .user
                        ? Color.accentColor
                        : Color(.controlBackgroundColor),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
                .textSelection(.enabled)
            if msg.role == .assistant { Spacer(minLength: 40) }
        }
    }

    // MARK: - Thinking bubble

    private var thinkingBubble: some View {
        HStack {
            ProgressView()
                .controlSize(.small)
            Text("思考中…")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.leading, 10)
    }

    // MARK: - Proposal Card

    private func proposalCard(_ proposal: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("变更提案", systemImage: "doc.badge.ellipsis")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.primary)

            Text(proposal)
                .font(.callout)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Button("确认") {
                    Task { await vm.confirmProposal(confirmed: true) }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button("取消") {
                    Task { await vm.confirmProposal(confirmed: false) }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.orange.opacity(0.3), lineWidth: 0.5)
        )
        .padding(.horizontal, 10)
        .padding(.bottom, 6)
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("发消息给助手…", text: $inputText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
                .focused($inputFocused)
                .onSubmit {
                    sendIfNotEmpty()
                }

            Button {
                sendIfNotEmpty()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(inputText.trimmingCharacters(in: .whitespaces).isEmpty
                                     ? Color.secondary : Color.accentColor)
            }
            .buttonStyle(.plain)
            .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || vm.isSendingMessage)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private func sendIfNotEmpty() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, !vm.isSendingMessage else { return }
        inputText = ""
        Task { await vm.sendMessage(text) }
    }
}
