# 实施任务索引

本 change 跨 **MalDaze** 与 **Hermes** 两个运行时，任务分文档维护：

| 文档 | 范围 | 建议顺序 |
|------|------|----------|
| [tasks-hermes.md](./tasks-hermes.md) | `~/.hermes` Python、cron、JSON 写入 | **先**（产出契约供桌宠读取） |
| [tasks-maldaze.md](./tasks-maldaze.md) | 本 repo Swift 提醒执行器 | **后**（依赖契约文件） |

`opsx:apply` 默认执行 **MalDaze** 任务（`tasks-maldaze.md`）。Hermes 任务需在同一机器按 `tasks-hermes.md` 完成；联调前 Hermes §1–§3 应至少完成一次。

## 依赖关系

```
tasks-hermes 1–3 ──► sleep_schedule.json 存在且有效
        │
        ▼
tasks-maldaze 1–6 ──► 桌宠睡眠提醒可用
        │
        ▼
tasks-hermes 5 + tasks-maldaze 6.2 ──► 端到端联调
```

## MalDaze 任务摘要

详见 [tasks-maldaze.md](./tasks-maldaze.md)。

## 1. 契约读取（MalDaze）

- [x] 1.1 新增 `SleepScheduleContractReader` 与模型校验
- [x] 1.2 契约读取单元测试

## 2. SleepReminderController（MalDaze）

- [x] 2.1 新建 Controller 与 Timer 链
- [x] 2.2 铃铛链（复用 `presentCenterBellReminder`）
- [x] 2.3 lockBedtime 霸屏（fullscreen `presentRest`）
- [x] 2.4 唤醒 / FSEvents 重调度
- [x] 2.5 anchor 与 dayType 单元测试

## 3. 合盖取消（MalDaze）

- [x] 3.1 `willSleep` 取消睡眠霸屏
- [x] 3.2 关闭睡眠铃铛浮层
- [x] 3.3 合盖路径测试/文档

## 4. AppViewModel 集成（MalDaze）

- [x] 4.1 UserDefaults 开关键
- [x] 4.2 启停与错误状态
- [x] 4.3 与番茄休息优先级

## 5. UI（MalDaze）

- [x] 5.1 控制面板睡眠开关
- [x] 5.2 契约错误展示
- [x] 5.3 设置页镜像

## 6. 验证（MalDaze）

- [x] 6.1 fixture JSON 手动验证
- [x] 6.2 与 Hermes 联调

> **说明**：上表 checkbox 与 `tasks-maldaze.md` 同步，供 `opsx:apply` 跟踪 MalDaze 进度。Hermes 任务 checkbox 仅列在 [tasks-hermes.md](./tasks-hermes.md)。
