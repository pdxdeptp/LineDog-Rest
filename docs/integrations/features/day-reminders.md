# 日待办（day-reminders）

Hub：[../hermes.md](../hermes.md) · 总目录：[../ROADMAP.md](../ROADMAP.md)

## 职责

| | Hermes | MalDaze |
|---|:------:|:-------:|
| 自然语言创建 / 完成 / 推迟 / 删除 | ✅ | ❌ |
| 写苹果「提醒事项」 | ✅ | ❌ |
| 飞书对话主入口 | ✅ | ❌ |
| Dashboard「计划」侧栏只读快操 | ❌ | ✅（可选，非本功能写端） |

**明确排除**：Hermes → MalDaze → EventKit 协作队列。日待办业务**不需要桌宠**。

## SSOT

苹果 **EventKit 提醒事项**（系统「提醒事项」App）。Hermes 通过本机 CLI 读写；MalDaze 侧栏仅直连 EventKit 供桌面快操，与 Hermes 无文件契约。

## Hermes 写端

| 项 | 路径 / 命令 |
|----|-------------|
| Skill | `~/.hermes/skills/day-reminders/SKILL.md` |
| CLI | `~/.hermes/scripts/day_reminders.py` |
| 晨报段 | `~/.hermes/scripts/morning-briefing.py` → 📋 今日提醒 |
| 写入方式 | `remindctl` ≥ 0.3.0（首选，含 `--repeat`）或 `osascript` 回退（见 skill references） |

重复提醒：`day_reminders.py create --repeat weekly`（需 `brew upgrade remindctl`）。`weekly` 锚定在 `--due` 的星期几。

### 提醒列表（与桌宠对齐 · D5）

Hermes 写入列表 = 桌宠 Dashboard 所选列表（iCloud 同步，与手机一致）：

```bash
defaults read com.maldaze.MalDaze MalDaze.remindersSelectedCalendarIdentifier
```

未设置时与桌宠相同 fallback：「提醒事项」/ `Reminders` → 第一张可写列表。建议在桌宠 Dashboard 选一次列表。

### 对话能力

| 意图 | 示例 | 确认 |
|------|------|------|
| 创建单条 | 「明天下午去银行」 | 直接写 |
| 创建单条 + 明确重复 | 「每周五 18:00 找爸妈视频」 | 直接写（`--due` + `--repeat weekly`） |
| 创建批量 / 含糊重复 | 「加三个待办」「工作日早上九点」 | 先预览再确认 |
| 列出今日 | 「今天有什么待办」 | — |
| 完成 | 「银行那条完成了」 | — |
| 推迟 | 「超市推迟到明天」 | — |
| 删除 | 「删掉某某提醒」 | — |

## MalDaze 边界

- **SmartReminder**（右键 / ⌘⇧<）：legacy 备用入口，非主路径；见 OpenSpec `desk-pet-controls` delta。
- **Dashboard 计划侧栏**：保留完成/推迟/删除；**不**承担创建主入口。

## 与域 B 区分

| | 日待办（本页） | 到时强提醒 |
|--|----------------|------------|
| 例子 | 今天去银行 | 30 分钟后红薯好了 |
| 存储 | 苹果提醒事项 | 无持久列表；`intervention_request.json` |
| 到点表现 | 系统通知 / 提醒 App | cron 等待 + 桌宠中央铃铛 |
| 桌宠 | 不参与写 | 读契约执行 |

## 排查

| 现象 | 查什么 |
|------|--------|
| 飞书创建失败 | Hermes skill 日志、`day_reminders.py` 退出码、提醒事项权限 |
| 重复写不进去 | `day_reminders.py status` 看 `repeat_supported`；升级 `brew upgrade remindctl` |
| 侧栏有、飞书没有 | 正常：侧栏读 EventKit，与 Hermes 无同步要求 |
| 晨报无提醒段 | `morning-briefing.py` 是否调用 list-today |

OpenSpec：`openspec/specs/hermes-day-reminders/spec.md`
