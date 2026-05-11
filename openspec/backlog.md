# Global Backlog

> 跨闭环发现的发散项，按模块索引。每条标注来源（change + 哪一步发现）、优先级（P1/P2/P3）、预估规模（S/M/L/XL）、状态（deferred / 待探索 / 已拒绝）。

---

## 索引

| 模块 | 条目数 | P1 | P2 | P3 |
|------|--------|----|----|-----|
| [infrastructure](#infrastructure-基础设施) | 3 | 0 | 1 | 2 |
| [pet-visuals](#pet-visuals-桌宠视觉) | 1 | 0 | 0 | 1 |
| [learning-data-layer](#learning-data-layer-学习数据层) | 2 | 0 | 1 | 1 |
| [material-ingestion](#material-ingestion-资料摄入) | 2 | 0 | 1 | 1 |
| [progress-feedback](#progress-feedback-进度反馈) | 1 | 0 | 1 | 0 |
| [independent-features](#independent-features-独立功能线) | 3 | 0 | 0 | 3 |

---

## infrastructure 基础设施

### P2 — Python 后端生产打包

- **描述：** 当前 `findBackendDir()` 依赖 DerivedData info.plist，仅开发期有效。生产 .app 需将 `assistant_backend/` 打进 `.app/Contents/Resources/`，含 Python 解释器与 `.venv/`（~100–500MB）。PyInstaller 编译成单一 binary 最省事，届时 `spawnBackend()` 改为寻找编译后 binary。
- **来源：** 初始 backlog（未绑定特定 change）
- **规模：** L
- **依赖：** 无
- **状态：** deferred

### P3 — XPC Service 后端 helper 评估

- **描述：** 若后续需要更符合 Mac App Store / sandbox 语境的原生 helper 边界，评估将当前 localhost FastAPI helper 迁移或包裹为 XPC Service。当前后端是 Python/FastAPI/LangGraph，属于较大架构迁移，不阻塞当前方案。
- **来源：** 初始 backlog
- **规模：** XL
- **依赖：** 生产打包方案确定后
- **状态：** future

### P3 — SMAppService LoginItem / LaunchAgent

- **描述：** 仅当产品语义改为"主 App 退出后学习助手仍需后台运行"时再评估 bundled LoginItem 或 LaunchAgent。当前退出即收束。
- **来源：** 初始 backlog
- **规模：** M
- **依赖：** 产品决策变更
- **状态：** future

---

## pet-visuals 桌宠视觉

### P3 — 狗狗 celebrating 动画

- **描述：** 完成任务或里程碑时触发专属庆祝动画状态。需要先准备图片素材。
- **来源：** 初始 backlog
- **规模：** M（素材依赖大）
- **依赖：** 动画素材到位
- **状态：** deferred

---

## learning-data-layer 学习数据层

### P2 — 向量数据库 / 语义搜索

- **描述：** 接入 Chroma 或 Qdrant，支持"帮我找我之前学过的关于 agent memory 的笔记"类查询。接口已在 `specs/learning-data-layer/` 中预留。
- **来源：** 初始 backlog
- **规模：** L
- **依赖：** 无，可独立做
- **状态：** deferred

### P3 — Effort estimation 自适应校准精度优化

- **描述：** 当前基础版用 `reschedule_count` + `completion_rate` 作为代理信号推断估算偏差，粒度粗。更精确方向：① 被动采集完成时间戳序列推算单任务耗时；② 引入"当天实际工作时长"作为归一化分母；③ 用贝叶斯更新替代滑动均值。基础版上线积累数据后再评估。
- **来源：** 初始 backlog
- **规模：** M
- **依赖：** 闭环二点五（calibrate-unit-study-time-estimates）完成后有数据基础
- **状态：** deferred

---

## material-ingestion 资料摄入

### P2 — 纯意图型资料

- **描述：** "我想学 LangGraph"——不带链接，系统自己去找资料并生成计划。需要接入搜索 + 自主评估资料质量 + 生成结构。
- **来源：** 初始 backlog
- **规模：** L
- **依赖：** 闭环二 ingestion 完成 + 搜索能力接入
- **状态：** deferred

### P3 — 八股爬虫

- **描述：** 爬小红书面经，汇总成八股复习大纲。涉及反爬。
- **来源：** 初始 backlog
- **规模：** M
- **依赖：** 反爬策略
- **状态：** deferred（先手动处理）

---

## progress-feedback 进度反馈

### P2 — "我现在会了什么"能力日志

- **描述：** 完成一个资料后弹框，让用户用一句话记录新掌握的能力。存入本地日志，面试前可回看。当前入口门槛高（需要用户主动打字总结），需要降低摩擦再做。
- **来源：** 初始 backlog
- **规模：** S
- **依赖：** 闭环三（今日学习工作台）完成后有自然插入点
- **状态：** deferred

---

## independent-features 独立功能线

以下均属于独立产品线，不在 MalDaze 学习助手主线范围内，单独立项。

### P3 — 心理 Therapist 对话

- **描述：** 绷不住时随时聊，语音或文字。接口预留，功能体系庞大。
- **来源：** 初始 backlog
- **规模：** XL
- **状态：** future（单独立项）

### P3 — 健身助手

- **描述：** 手机端，记录器械/重量/组数，推日拉日交替，桌面端互通。
- **来源：** 初始 backlog
- **规模：** XL
- **状态：** future（单独立项）

### P3 — 餐饮助手

- **描述：** 每三天备菜规划，爬有真人反馈的菜谱，热量记录。
- **来源：** 初始 backlog
- **规模：** L
- **状态：** future（单独立项）

---

## 维护规则

- **新条目追加：** 由 product-deepen 或 scope-decision 发现的 P2/P3 项，按模块归类追加到对应 section，标注来源 change 名称
- **P1 项不进 backlog：** P1 直接进入当前 change 或下一个闭环的 scope
- **条目提升：** 当某个 deferred 项在 scope-decision 中被认定应该进入当前 change 时，从 backlog 移除并写入对应 change 的 scope
- **重复检查：** 追加前先在 backlog 中搜索是否已有同模块同主题条目，避免重复
- **最后更新：** 2026-05-10（初始重构）
