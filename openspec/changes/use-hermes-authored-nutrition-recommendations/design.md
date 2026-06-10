## Context

当前营养集成有两条用户可见建议路径：

- 晨报在 `morning-briefing.py` 中调用 `plan_engine.py --full-day`，用动态食物集和固定燕麦生成一份全日饮食计划。
- MalDaze 饮食面板读取 `daily_log.json.panel.suggestions`，该字段由 `recommend.py` 的 Python 基线候选集基于当前剩余额度生成。

这两条路径都不是稳定的 Hermes/AI 推荐契约。桌宠前端没有本地重算，但它展示的是底层程序直接跑出的 `panel.suggestions`，所以会把“900g 酸奶”这类数学上可行、体验上离谱的结果暴露给用户。

项目约束：

- `daily_log.json` 仍是今日饮食事实 SSOT：日期、日型、records、targets、consumed、remaining。
- MalDaze 是只读 UI：不得本地压制、过滤、重排或重算 Hermes 建议。
- Hermes/MalDaze 之间仍采用本机文件契约，不引入 HTTP API。
- 契约缺失或过期时应 fail-loud：桌宠显示等待/过期状态，而不是生成替代建议。

## Goals / Non-Goals

**Goals:**

- 建立单一“用户可见饮食建议”契约：`~/.hermes/data/nutrition/recommendation.json`。
- 让晨报和飞书/Hermes 对话里给出的饮食建议写入同一份推荐快照。
- 让 MalDaze 饮食建议区只展示这份推荐快照，并明确区分 fresh、stale、missing、unavailable。
- 保留 `daily_log.json` 作为事实/指标来源，保留点击结构化食物项后调用 `recommend.py log` 的轻交互。
- 移除 `recommend.py` 自动生成用户可见建议的职责；`plan_engine.py` 只能作为候选生成工具。

**Non-Goals:**

- 在 MalDaze 内实现 AI、规划器或本地建议过滤。
- 让 `recommend.py` 自己调用 LLM 做最终推荐。
- 一次性重做整个营养系统、食物库、库存模型或长期饮食计划。
- 强制所有 Hermes 消息都必须包含饮食建议；只有当 Hermes 给出用户可见饮食建议时才必须写快照。

## Decisions

### D1 · 新建 `recommendation.json`，不复用 `daily_log.panel.suggestions`

选择独立文件：

```text
~/.hermes/data/nutrition/daily_log.json          # facts and metrics
~/.hermes/data/nutrition/recommendation.json     # Hermes-authored user-visible recommendation
```

理由：

- 两者生命周期不同：`daily_log` 每次记录/刷新都会变；推荐只有 Hermes 实际给出建议时才应该变。
- 两者语义不同：`daily_log.panel` 是派生指标视图；`recommendation.json` 是用户可见建议快照。
- 独立文件让 MalDaze 可以明确显示“建议已过期”，而不是被 `refresh-panel` 自动塞入一份程序建议。

备选：继续把建议放进 `daily_log.panel.suggestions`。否决，因为它会诱导 `recommend.py` 每次刷新都重新生成建议，重复当前问题。

### D2 · 推荐快照 schema

`recommendation.json` 使用 schemaVersion 1：

```json
{
  "schemaVersion": 1,
  "date": "2026-06-10",
  "generatedAt": "2026-06-10T09:30:00-04:00",
  "source": {
    "kind": "morning_briefing",
    "channel": "feishu"
  },
  "basedOn": {
    "dailyLogDate": "2026-06-10",
    "dailyLogPanelUpdatedAt": "2026-06-10T09:28:00-04:00",
    "recordsCount": 2
  },
  "state": "available",
  "summary": "今天还需要补蛋白和一点碳水，脂肪空间不多。",
  "suggestions": [
    {
      "label": "现在最合适",
      "rationale": "补蛋白，热量温和，不继续堆脂肪。",
      "items": [
        {
          "displayName": "去脂希腊酸奶 250g",
          "name": "希腊酸奶·去脂",
          "grams": 250,
          "loggable": true
        }
      ],
      "warnings": []
    }
  ]
}
```

字段原则：

- `summary` / `rationale` 是 Hermes 给用户看的自然语言。
- `items[].name` 必须是 `foods.json` 键名，只有 `loggable == true` 时必填。
- `items[].grams` 只有 `loggable == true` 时必填。
- `displayName` 允许展示更自然的文本。
- `warnings` 用于说明“钠偏高”“脂肪空间不足”等注意事项。
- 当 `state == "unavailable"` 时，第一版不新增单独 `reason` 字段；`summary` 承载用户可见原因/提示文案，`suggestions` 必须是空数组 `[]`。

### D3 · 新鲜度由事实快照决定

MalDaze 读取 `daily_log.json` 和 `recommendation.json` 后计算状态：

- fresh：`recommendation.date == daily_log.date` 且 `recommendation.basedOn.dailyLogPanelUpdatedAt == daily_log.panel.updatedAt`。
- stale：日期匹配但 `dailyLogPanelUpdatedAt` 不匹配，表示用户又记录/撤销/刷新过事实，推荐不再保证适用。
- missing：推荐文件不存在。
- unavailable：Hermes 明确写入 `state: "unavailable"`，例如暂时无法生成建议；payload 仍含 `summary`，但 `suggestions: []` 且无单独 `reason` 字段。

这是有意保守的：即使一次纯 `refresh-panel` 让建议过期，也比展示旧建议更安全。后续如需减少误判，可在 `daily_log.panel` 增加稳定 digest，再把新鲜度比较从 `updatedAt` 升级为 digest。

### D4 · 写入只通过 Hermes 推荐写入器

新增 Hermes 侧写入器，例如：

```bash
python3 ~/.hermes/data/nutrition/recommendation_store.py write --stdin
python3 ~/.hermes/data/nutrition/recommendation_store.py unavailable --reason "..."
```

`unavailable --reason` 是 CLI 便利参数：第一版将 `--reason` 写入/映射到 `summary`（MalDaze 可直接作为 UI 状态文案展示），不会写出单独 `reason` 字段；写入器必须同时保证 `state: "unavailable"` 与 `suggestions: []`。

写入器负责：

- 校验 schemaVersion、date、basedOn、suggestions 结构。
- 校验 loggable item 的 `name` 存在于 `foods.json` 且 `grams` 为正数。
- 对 unavailable snapshot 校验 `summary` 非空、`suggestions == []`、不存在单独 `reason` 字段。
- 原子写入 `recommendation.json`。
- 提供测试可复用的 load/validate helpers。

Hermes agent、nutrition-menu skill、morning briefing authoring path 调用写入器。不要让 agent 手写 JSON 到最终文件。

### D5 · `recommend.py` 退回事实引擎角色

`recommend.py` 保留：

- `status`
- `log`
- `trial`
- `calc`
- `refresh-panel` 的指标刷新
- day_type、weight、activity 等事实更新

`recommend.py` 不再生成用户可见 `suggestions`。第一版为了兼容 `add-nutrition-today-panel` 已定义的 `daily_log.panel` schema，`panel.suggestions` SHALL 保持为空数组 `[]`；MalDaze 新逻辑必须忽略它，不能把它作为推荐来源。未来若升级 `panel` schema v2，可再移除该字段。

`plan_engine.py` 可继续被 Hermes 用作候选方案来源，但候选方案必须经过 Hermes 推荐流程写入 `recommendation.json` 后才允许展示。

### D6 · 晨报营养建议进入 Hermes authoring path

当前 `Morning Briefing` cron 是 `no_agent: true`，直接运行 `morning-briefing.py`。本 change 需要调整营养建议的生成边界：

- `morning-briefing.py` 可以继续准备事实上下文：体重、day_type、remaining、records、候选方案。
- 用户可见的营养建议文本和 `recommendation.json` 快照必须由 Hermes authoring path 产出并写入。
- 如果晨报仍以 no-agent 脚本运行，则不得把 `plan_engine.py --full-day` 的原始输出标记为 fresh recommendation。

实现可以选择两种等价方式：

- 将 Morning Briefing cron 改为 agent-backed prompt，由 agent 调用脚本取上下文、写推荐快照、发送晨报。
- 保留脚本聚合非营养段，但把营养推荐段拆成一个 Hermes agent 子流程，成功后再拼接/发送。

### D7 · MalDaze 双文件读取

MalDaze 饮食面板：

- 继续从 `daily_log.json` 展示 dayLabel、targets、consumed、remaining、records。
- 从 `recommendation.json` 展示“现在可以吃”。
- 监听两个文件；任一变化都重新计算 fresh/stale/missing/unavailable。
- 对 `loggable == true` 的 item 显示点击与 1-9 快捷记录。
- 对不可记录的自然语言 item 只展示，不提供点击 log。
- 点击 log 成功后立即重读事实文件；建议区显示 stale/等待 Hermes 更新，直到新的 recommendation snapshot 写入。

## Risks / Trade-offs

- [Risk] 晨报从 no-agent 脚本转入 agent authoring 会增加调度复杂度。→ Mitigation：先让脚本输出结构化 nutrition context，再由 agent-backed wrapper 负责推荐与写入。
- [Risk] 推荐文件可能因 agent 失败而缺失或 stale。→ Mitigation：MalDaze 明确显示等待/过期状态，不回退生成建议。
- [Risk] JSON 被 agent 写坏会破坏 UI。→ Mitigation：所有写入走 `recommendation_store.py` 校验和原子写。
- [Risk] `dailyLogPanelUpdatedAt` 过于保守，纯刷新也会让建议 stale。→ Mitigation：接受保守语义；后续可升级 digest。
- [Risk] 活跃 change `add-nutrition-today-panel` 已实现 Python suggestions。→ Mitigation：本 change 先修正 OpenSpec 和文档，再在 apply 阶段移除/降级该路径。

## Migration Plan

1. 更新 active `add-nutrition-today-panel` 相关设计/规格/文档，声明 `panel.suggestions` 不再是用户可见建议来源；第一版保留 `panel.suggestions: []` 只作 schema 兼容。
2. Hermes 增加 `recommendation_store.py` 和 schema tests。
3. `recommend.py` 保留 metrics panel，停止生成用户可见 suggestions。
4. nutrition-menu skill 在每次给出饮食建议时调用 recommendation writer。
5. 晨报营养段改为 Hermes-authored recommendation 写入同一文件。
6. MalDaze 改为双文件读取：daily_log 展示事实，recommendation 展示建议。
7. 更新 integration smoke 和 manual QA：fresh、stale、missing、unavailable、loggable click。

Rollback：

- MalDaze 可隐藏推荐区或显示 stale/missing，不恢复本地计算。
- Hermes 可保留 `recommendation.json` 文件但停止写入；事实面板继续工作。

## Open Questions

- **Resolved**：第一版保留 `daily_log.panel.suggestions: []` 以兼容旧 decoder；MalDaze 必须忽略该字段，用户可见推荐只读 `recommendation.json`。
- Morning Briefing 最终采用 agent-backed 整体 job，还是脚本聚合 + agent 营养子流程？
