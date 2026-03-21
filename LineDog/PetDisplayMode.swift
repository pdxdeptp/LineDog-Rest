/// 桌宠与菜单栏小狗的配色状态（休息红 / 计时中黑 / 已停止白身黑边 / 智能输入等待 LLM）。
enum PetDisplayMode: Equatable {
    case restingRed
    case runningBlack
    case pausedWhiteOutline
    case thinking
}
