## Context

- **已实现**: `FocusSessionStore` + 右栏列表；session 有 `startedAt`、`endedAt`、`durationSeconds`、`source`。
- **演进**:
  1. 离散格 + 一格一番茄 ❌
  2. 单条连续比例尺 ❌（用户仍想要格子形态）
  3. GitHub 式格子 + **accent 蓝连续比例填色**（非四级离散）+ **可扩展窗口** ✅

## Goals / Non-Goals

**Goals:**

- **默认窗口** `[today 08:00, today 24:00)`：GitHub 式小格阵列（30 分钟/格），无凌晨 session 时不占高度。
- **自动扩展**：若当日 session（含进行中）与 `[today 00:00, today 08:00)` 有重叠，**向左**扩展可见起点至「最早重叠格」的格起点（对齐 30 分钟，不早于 00:00）；右界仍为 24:00。
- **比例填色**：格内 **accent 蓝** 子矩形 = session 与 `[cellStart, cellEnd)` 的**精确时间重叠**（连续比例，非 GitHub 四级离散、非整格开关）。例：格内只学了 3 分钟 → 宽度 = 3/30 ≈ **10%**。
- 右栏纯操作；摘要 `N 个 · X 分钟`。

**Non-Goals:**

- 整格二值填色（有番茄就满格）。
- 无 off-hours 活动时仍展示 0–8 点空格。
- 7 日墙、点击详情、Hermes 写入。

## Decisions

### D1: 时间窗口 — 默认 8–24，凌晨有活动则扩展

- **Decision**:
  - `baseStart = today 08:00`, `baseEnd = today 24:00`（右界开区间 `[start, end)`）。
  - `offHours = [today 00:00, today 08:00)`。
  - 对当日 projection 中所有 session + in-progress，求与 `offHours` 的并集重叠；若为空 → `visibleStart = baseStart`；否则 `visibleStart = max(today 00:00, floor30(earliestOverlapStart))`。
  - `visibleEnd = baseEnd`（不因 session 向右扩展；跨午夜 session 的 00:00 之后段落入 offHours 扩展，23:xx–24:00 段仍在默认窗内）。
- **Rationale**: 平时紧凑；夜猫/早起学习时自动露出对应格，不裁掉 0–8 点真实记录。
- **刻度**: 仅标注落在 `[visibleStart, visibleEnd)` 内的锚点（如 `6  8  12  16  20  24` 或 `8  12  16  20  24`），caption2 tertiary。

### D2: 格子粒度 — 30 分钟（效率与可读性平衡）

- **Decision**: 固定 **30 分钟/格**；格数 `N = (visibleEnd - visibleStart) / 30min`。
  - 默认：16h → **32 格**。
  - 最大扩展（00:00 起）：24h → **48 格**。
- **Rationale**:
  - 15 分钟 → 默认 64 格，~360pt 宽下每格 ~5pt，部分填色难辨；实现与测试成本更高。
  - 60 分钟 → 25 分钟番茄在单格内只剩「占 42% 宽」，丢失「从第几分钟开始」的位置感。
  - **30 分钟**：25min 番茄典型占一格大部分宽度；跨格 session 最多 2–3 格，视觉仍连续；SwiftUI 48 个 `RoundedRectangle` 可接受。
- **Alternative rejected**: 动态粒度（窄窗 15min、宽窗 30min）— 同屏格尺寸漂移，与 GitHub 固定格感不一致。

### D3: 格内填色 — accent 蓝、连续 overlap 比例

- **Decision**: 对每个格 `[cellStart, cellEnd)`：
  1. 合并当日所有 session（及 in-progress 至 `now`）与该格的交集区间（并集，避免叠色超 100%）。
  2. 对并集每一段画 **水平子矩形**（**从左往右**填，leading → trailing）：
     - `startFraction = (segStart - cellStart) / cellDuration` — 距格**左缘**的比例偏移
     - `widthFraction = segDuration / cellDuration` — 向右延伸的宽度比例（连续浮点，不量化到 1/4 格或整格开关）
     - 渲染：`x = startFraction × cellWidth`，子矩形左缘对齐该点，**向右**展开；**禁止**从右缘向左锚定或 trailing 对齐
  3. 样式：
     - 格底：`controlBackgroundColor` + separator 描边（空轨）
     - fill：`Color.accentColor.opacity(0.9)`；宽度严格按 overlap 比例（3min/30min = 10% 格宽）
  4. `w < 2pt` 时仍画 2pt 下限（极短片段可见）。
- **包含** `stoppedEarly` 与 `completed`；**不**按番茄个数整格开关。
- **「非离散」含义**：不是 GitHub 式 0/1/2/3/4 档色阶，而是 **真实分钟数 → 真实像素比例**；用户口语里的「灰阶」指这种连续比例，**不是** UI 用灰色。
- **Alternative rejected**: GitHub 式 4 级离散色阶；整格有番茄就满格；从格右缘向左增长的 fill。

**示例（左→右）**:

```text
14:00–14:30 格内 14:10–14:25（15 分钟）:
┌──────────────────┐
│ ░░░░▓▓▓▓▓▓▓▓▓▓▓▓ │  左 33% 空，向右涂 50% 宽（10min 偏移 + 15min 时长）

14:00–14:30 格内仅 14:00–14:03（3 分钟）:
┌──────────────────┐
│ ▓▓░░░░░░░░░░░░░░ │  从左缘起涂 10% 宽（3/30）
```

### D4: 跨格 session 与 in-progress

- **Decision**: 相邻格各自按 overlap 画同色 accent fill；边缘对齐时 **视觉连续**（同色、格间距 3pt 内仍可读）。
- **in-progress**: 涂至 `now`；涉及 `now` 的格内 fill **右缘** 可选 subtle pulse（opacity 0.9→1.0）。

### D5: 布局

- **Decision**: 固定 **16 列**；行数 `ceil(N / 16)`（默认 2 行，扩展后 3 行等）。
- 行内时间 **从左到右、从上到下** 递增（首格 = `visibleStart`）。
- 同行摘要：左 label「专注」、中 grid、右 `N 个 · X 分钟`。

### D6: 摘要与空态

- `N` 仅 `source: completed`；`X` 含 stoppedEarly + in-progress（与窗口无关，全日统计）。
- 空态：`今天还没有专注`；格阵仍显示空轨（浅灰底+描边），不造假 fill。
- 有 session 但全在默认窗外且未触发扩展（不应出现，因扩展会覆盖 off-hours）— model 测试覆盖。

### D7: Hermes header

- `budgetLine` + 同行 `· 完成 done/total`；移除 `progressLine` ProgressView。

### D8: Model

```text
FocusDayTimelineCellGridModel
  visibleStart, visibleEnd  // derived: default 08–24, expand start if off-hours overlap
  cellDuration: 30min
  columns: 16
  → cells[i]: merged [(startFraction, widthFraction)] in [0,1]
```

输入：`AppViewModel` projection + `now`；不直读 JSON。

### D9: 右栏

- 删除 `todayFocusSection` / Dashboard 对 `FocusSessionTodaySection` 的使用。

## Risks / Trade-offs

- **扩展后 3 行** → header 略增高；仅在有凌晨/夜间段时出现。
- **跨日 session**（23:40–00:20）→ 今日视图按 `startedAt` 日历日归属；00:00 后段靠左扩展显示，23:40–24:00 在默认窗内。
- **与 GitHub 异同**：同 — 格阵列 + 时间位置；异 — 格内 **accent 蓝连续比例** fill（非四级离散）；窗口可向左扩。

## Migration Plan

1. `FocusDayTimelineCellGridModel` + `FocusDayTimelineCellGridView`
2. 接入 `todayHeader`；Hermes 内联数字
3. 删右栏 focus list；tests + MANUAL_QA

## Open Questions

- P1.5 hover 单格：`06:00–06:30 · 已学 18 分钟`（可选）。
