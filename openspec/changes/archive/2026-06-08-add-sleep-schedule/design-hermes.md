## Context

Hermes 个人数据栈位于 `~/.hermes`，已有：

- **Cron**：`cron/jobs.json` → `Morning Briefing`，每天 `0 8 * * *`，脚本 `scripts/morning-briefing.py`，`no_agent: true`，输出推飞书。
- **营养**：`data/nutrition/recommend.py`（`auto` 判定 `day_type`）、`daily_log.json`（权威字段 `day_type`: `"training"` | `"rest"`，见 `skills/nutrition/nutrition-menu/references/system-spec.md`）。
- **晨报结构**：体重 / 学习 / 饮食；饮食段已调用 `recommend.py auto`。

睡眠追踪与目标推进**嵌入 Morning Briefing**，不新建 cron。

## Goals / Non-Goals

**Goals:**

- 解析 `pmset -g log` 获取昨夜最后一次 `Entering Sleep state due to 'Clamshell Sleep'`。
- 达标：合盖时刻 ≤ target + 10 分钟（含提前合盖）；达标则明晚 target 前推 10 分钟，下限 `22:30`。
- 未达标：target 不变。
- 初始 target：`00:00`（无历史时）。
- 写入 `~/.hermes/data/sleep/sleep_schedule.json`（含 `dayType`，在 `recommend.py auto` 之后读取）。
- 晨报追加 🌙 睡眠段落。
- 可选 `sleep_history.json` 存分析字段（桌宠不读）。

**Non-Goals:**

- 铃铛、霸屏、MalDaze 进程内逻辑。
- 修改 MalDaze Application Support 路径。
- 桌宠可读的营养 API 抽象层。
- 开盖瞬间触发（以 08:00 cron 为准）。

## Decisions

### Decision 1: 模块布局

```
~/.hermes/
  scripts/
    morning-briefing.py      # 扩展：调用 sleep 段
    sleep_tracker.py         # 新建：pmset + 算法 + JSON 写入 + 晨报文本
  data/sleep/
    sleep_schedule.json      # 契约（MalDaze 只读）
    sleep_history.json       # 可选，Hermes 自用
```

`sleep_tracker.py` 导出可测试函数，例如：

- `load_state() / save_state()`
- `parse_last_clamshell_sleep(for_date) -> datetime | None`
- `evaluate_and_advance(target, actual) -> new_target, met, delta_minutes`
- `build_schedule_json(day_type) -> dict`
- `format_briefing_section(...) -> str`

### Decision 2: pmset 解析

```bash
pmset -g log
```

在**昨日日历日**（或睡眠夜定义：与 target 对齐，跨 00:00 时 actual 可能为当日凌晨）时间范围内，取最后一条匹配：

```
Entering Sleep state due to 'Clamshell Sleep'
```

解析时间戳（locale/log 格式需 spike 一次固化 parser）。无匹配 → 晨报注明「昨夜未检测到合盖」，target 不变。

### Decision 3: 达标与推进算法

```python
delta_minutes = (actual - target).total_seconds() / 60  # 同睡眠夜 datetime
met = delta_minutes <= 10

if met:
    new_target = target - timedelta(minutes=10)
    if new_target.time() < time(22, 30):  # 不早于 22:30
        new_target = today_at(22, 30)
else:
    new_target = target
```

**无**「连续两天达标」逻辑。

### Decision 4: `sleep_schedule.json` 写入

Hermes **独占写**。每次 morning briefing 成功跑完睡眠段后原子写入（仿 `recommend.py` 的 `save_json` / 临时文件 rename）：

```json
{
  "schemaVersion": 1,
  "targetBedtime": "23:50",
  "lockBedtime": "23:55",
  "dayType": "training",
  "updatedAt": "2026-06-06T08:05:32-04:00"
}
```

- `lockBedtime` 必须由 Hermes 计算为 `targetBedtime + 5min`（跨午夜需正确处理）。
- `dayType` 来自 `_load_daily_log()["day_type"]` 或 `recommend.py status` 在 `auto` 之后；**必填**，缺失则脚本报错退出（cron `last_status: error`）。

### Decision 5: Morning Briefing 集成顺序

在 `morning-briefing.py` `main()` 中：

1. 体重段（已有）
2. 学习段（已有）
3. **睡眠段（新）**：`sleep_tracker.run_for_briefing()` → 打印 🌙 段落 → 写 JSON
4. 饮食段（已有 `get_diet_plan()`，内含 `recommend.py auto`）

**注意**：`dayType` 用于**今晚**提醒，应使用步骤 4 之前 `auto` 后的当日类型。若睡眠段在饮食之前，须在睡眠段内单独调用 `recommend.py auto`（与饮食段 idempotent），或调整顺序为：先 `auto`，再睡眠+饮食。

**推荐顺序调整**：

1. 体重
2. 学习
3. `recommend.py auto`（一次）
4. 睡眠（读 day_type，写 JSON，打印）
5. 饮食（`status` + plan，不再重复 auto）

### Decision 6: 晨报段落示例

```
🌙 睡眠调整
  昨晚合盖：00:08（目标 00:00，晚 8 分钟 ✅ 达标）
  今晚截止：23:50 铃铛 ／ 23:55 躺平霸屏
  今日类型：训练日
```

未达标、无合盖、目标触底等变体在 `format_briefing_section` 中覆盖。

### Decision 7: 强耦合声明（必须保留在本文档与 spec）

> **Known Fragile Coupling**  
> MalDaze 硬编码读取 `~/.hermes/data/sleep/sleep_schedule.json`。无版本协商、无 fallback。  
> Hermes 必须每日 08:00 cron 写入完整契约。  
> 排查：提醒异常 → 查 JSON；目标/合盖数据异常 → 查 `sleep_tracker.py` + `pmset -g log`。

**运行时总览文档（canonical）**：[docs/integrations/hermes.md](../../../docs/integrations/hermes.md)（Hermes 仅索引：`~/.hermes/docs/integrations/maldaze.md`）

## Risks / Trade-offs

- **[Risk] pmset 日志格式随 macOS 变化** → 单测夹固定样例 + 手动验证一条真机 log。
- **[Risk] 与 `recommend.py auto` 调用两次** → 合并为 briefing 开头一次 auto。
- **[Risk] 用户 08:00 前需要当日 target** → 昨夜 JSON 仍有效至 cron 更新；MalDaze 夜间只用「今晚」已写入的 target。

## Migration Plan

1. 创建 `data/sleep/`，写入初始 `sleep_schedule.json`（`00:00` / `00:05`，`dayType` 从当日 log 读）。
2. 实现 `sleep_tracker.py` + 单元测试（算法、跨午夜、22:30 下限）。
3. 改 `morning-briefing.py` 顺序与睡眠段。
4. 手动跑 `python3 scripts/morning-briefing.py` 验证输出与 JSON。
5. 开启 MalDaze 睡眠总开关做一晚联调。

## Open Questions

- pmset 时间戳解析需一次真机 spike（任务 1.1 Hermes）。
