# Scope Decision（用户拍板 · 2026-06-07）

来源：`opsx:product-deepen` 决策表 D1–D7。

## 用户决策摘要

| ID | 决策 |
|----|------|
| **D1** | **A** — 无消费回执；Hermes 写契约成功即回复，不轮询桌宠 ack |
| **D2** | **A** — 新 Hermes countdown **覆盖**任意进行中的倒计时（含 ⌘⇧M） |
| **D3** | **不做** — 不增加「隐藏 Smart Input」设置；SmartReminder 入口保持现状 |
| **D4** | **推荐** — 单条日待办直接创建；批量/重复规则需确认 |
| **D5** | **对齐桌宠** — Hermes 写入与桌宠 Dashboard 相同的提醒列表（iCloud 同步列表） |
| **D6** | **delete 日历格** + **本地 JSON 保留全历史**（`projects.json` / `daily_log.json` 不删完成记录） |
| **D7** | **fail-loud** — 桌宠未运行时 Hermes **拒绝**写 intervention，飞书明显报错 |

## 范围影响

### 纳入本 change

- 域 B：MalDaze 进程检测（Hermes 写端）；并发覆盖；P0 技术默认（ack、迟到启动、title 文案等）
- 域 A：提醒列表读取 `com.maldaze.MalDaze` UserDefaults；创建确认策略
- 域 C：complete 删日历 + 历史文件语义文档化
- 域 D：晨报段级降级

### 移出本 change

- `MalDazeDefaults.showSmartInputEntry` 及右键隐藏（tasks-maldaze §3.2）
- `desk-pet-controls` spec 中 Smart Input 隐藏 / legacy 文案相关 delta（保留「不修改 Smart Input 行为」兼容说明即可）
- P1-1 消费回执契约
- M-B7 可选状态卡（仍可选，默认不做）

### Non-goals（强化）

- 桌宠未开时由 Hermes 降级为系统通知（用户明确要求报错，不做降级）
- 修改 SmartReminder 入口、快捷键、设置分类（本 change 不动）

## Final Scope Decision

**ADD SMALL ITEMS THEN CONTINUE** — 用户 D1–D7 已并入 artifact；P0 技术默认已写入 design/spec/tasks；无 split。

**边界**：coherent（三域 + 晨报；MalDaze 仅域 B；Smart Input 零改动）

## 下一步

`opsx:apply-readiness unify-personal-assistant` → 通过后 `opsx:apply`
