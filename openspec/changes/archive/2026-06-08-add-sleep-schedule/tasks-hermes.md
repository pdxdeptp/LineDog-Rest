# Hermes 实施任务

> 运行时：`~/.hermes`（本 repo 外）。设计见 [design-hermes.md](./design-hermes.md)。Spec：`hermes-sleep-tracker`、`sleep-schedule-contract`（写入侧）。

## 1. pmset 与数据目录

- [x] 1.1 Spike：在本机 `pmset -g log` 取样，固化 Clamshell Sleep 行解析器
- [x] 1.2 创建 `~/.hermes/data/sleep/` 与初始 `sleep_schedule.json`（`00:00` / `00:05`）

## 2. sleep_tracker 模块

- [x] 2.1 新建 `~/.hermes/scripts/sleep_tracker.py`（或 `data/sleep/` 包）：`parse_last_clamshell_sleep`、`evaluate_and_advance`、`build_schedule_json`
- [x] 2.2 实现达标算法（delta ≤ 10）、前推 10min、下限 22:30
- [x] 2.3 实现 `lockBedtime = target + 5min`（跨午夜）
- [x] 2.4 原子写入 `sleep_schedule.json`；可选 `sleep_history.json`
- [x] 2.5 单元测试：达标/未达标/触底/跨午夜/无合盖

## 3. Morning Briefing 集成

- [x] 3.1 调整 `morning-briefing.py`：在饮食计划前统一调用 `recommend.py auto` 一次
- [x] 3.2 插入 🌙 睡眠段：调用 `sleep_tracker`，打印晨报，写 JSON
- [x] 3.3 `dayType` 缺失时脚本报错退出（cron 可见 `last_status: error`）
- [x] 3.4 手动运行 `python3 scripts/morning-briefing.py` 验证飞书输出格式（睡眠段已验证；饮食段因 `foods.json` 缺「希腊酸奶」条目在 plan_engine 处失败，与睡眠改动无关）

## 4. 文档与耦合声明

- [x] 4.1 在 `~/.hermes` 相关 README 或 `system-spec` 旁注记：MalDaze 强依赖 `sleep_schedule.json` 路径与字段
- [x] 4.2 记录排查路径：提醒异常 → JSON；目标异常 → pmset + sleep_tracker

## 5. 联调

- [x] 5.1 cron + `updatedAt` 回写：`integration_smoke` `sleep_updated_at_roundtrip` + `sleep_morning_briefing_cron`
- [x] 5.2 端到端：`integration_smoke` sleep 段 + `sleep_tracker` pytest；一晚目视见 MANUAL_QA §域 D
