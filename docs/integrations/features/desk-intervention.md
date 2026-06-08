# 到时强提醒（desk-intervention）

Hub：[../hermes.md](../hermes.md) · 总目录：[../ROADMAP.md](../ROADMAP.md)

## 职责

| | Hermes | MalDaze |
|---|:------:|:-------:|
| 推断时长 / 建 cron | ✅ | ❌ |
| 到点写 `bell` 契约 | ✅ | ❌ |
| 读契约 / 中央铃铛 | ❌ | ✅ |
| 飞书对话发起 | ✅ | ❌ |

适用于：**煮鸡蛋、红薯、泡脚**等短计时强感知；**不进**苹果提醒事项列表。

## 飞书实际路径（cron + bell）

```
用户：「3 分钟后关鸡蛋」
  → Hermes cronjob create（schedule: 3m，自包含 prompt）
  → 等待由 cron 调度器负责（无桌宠右下角倒计时）
到点 cron 触发
  → intervention_request.py --kind bell --title "…"
  → MalDaze 中央铃铛
```

Hermes Agent **不会**在创建时写 `kind: countdown`；以 cron 计时 + 到点 `bell` 为准。

## 契约

**路径**：`~/.hermes/data/maldaze/intervention_request.json`（Hermes 写；MalDaze 读并消费）

飞书路径到点写入示例：

```json
{
  "schemaVersion": 1,
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "kind": "bell",
  "title": "快去关鸡蛋！煮好了",
  "requestedAt": "2026-06-07T23:23:16-04:00",
  "expiresAt": "2026-06-08T23:23:16-04:00"
}
```

### kind 语义（MalDaze）

| kind | 行为 | 飞书路径 |
|------|------|:--------:|
| `bell` | 立即中央铃铛 | ✅ 到点使用 |
| `countdown` | 右下角倒计时 → 结束铃铛 | ❌ 不由飞书创建；MalDaze 本地 ⌘⇧M 等仍可用 |
| `cancel` | 取消进行中的 Hermes 倒计时 | 按需 |

缺字段或非法值 → MalDaze **fail-loud**。

## 消费与 ack

1. MalDaze 启动 / FSEvents / 3s 轮询 / 唤醒 / 前台 → 读契约  
2. 校验通过 → 执行  
3. ack：`consumed/{id}.json`  
4. 同 `id` 已消费 → 忽略

## 前置条件（D7）

**到点写 bell 时 MalDaze 须运行。** `intervention_request.py` 写前 `pgrep`；未运行 → 报错、不写 JSON。

创建 cron 时桌宠可未开；用户需在到点前打开桌宠。

## Hermes 写端

| 项 | 路径 |
|----|------|
| Skill | `~/.hermes/skills/desk-intervention/SKILL.md` |
| 脚本 | `~/.hermes/scripts/intervention_request.py` |
| 计时 | `cronjob` 工具 / `cron/jobs.json` |

```bash
# 到点（飞书路径）
python3 ~/.hermes/scripts/intervention_request.py --kind bell --title "红薯煮好了"
```

## MalDaze 读端

| 模块 | 路径 |
|------|------|
| 契约 | `InterventionRequestContract.swift` |
| 消费者 | `InterventionRequestConsumer.swift` |
| 监听 | `InterventionRequestFileWatcher.swift` |
| 铃铛 | `presentCenterBellReminder` |

## 排查

| 现象 | 查什么 |
|------|--------|
| 创建后无桌宠倒计时 | **预期**；飞书路径用 cron，倒计时不在桌宠 |
| 到点无铃铛 | MalDaze 是否运行；`consumed/` 是否写入；cron `last_status` |
| 重复弹 | ack / 同 `id` 幂等 |
| 误建 cron 想取消 | `hermes cron list` → `remove` |

OpenSpec：`openspec/specs/desk-intervention/spec.md` · `desk-intervention-contract/spec.md`（MalDaze 消费语义；飞书写端以本文为准）
