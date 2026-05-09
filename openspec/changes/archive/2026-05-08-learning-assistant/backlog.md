# Backlog

未来考虑做，但不在当前 MVP 范围内。

## 基础设施

- **Python 后端生产打包**：当前路径发现（`findBackendDir()` 层 2）依赖 DerivedData `info.plist`，仅开发期有效。生产 .app 需要层 1 生效：将 `assistant_backend/` 打进 `.app/Contents/Resources/`。难点：`.venv/` 含平台相关 native binary，整体约 100–500 MB；Python 解释器需一并处理（bundle `Python.framework` 或用 PyInstaller 编译成单一 binary）。PyInstaller 方案最省事，届时 `spawnBackend()` 改为寻找编译后的 binary 而非 `.venv/bin/uvicorn`。

## 正向反馈 / 激励

- **狗狗 celebrating 动画**：完成任务或里程碑时触发专属动画状态。需要先准备图片素材，工作量未估算。
- **"我现在会了什么"能力日志**：完成一个资料后弹框，让用户用一句话记录新掌握的能力。存入本地日志，面试前可回看。入口门槛高（需要用户主动打字总结），需要想办法降低摩擦再做。

## 数据与智能

- **Effort estimation 自适应校准精度优化**：当前基础版用 reschedule_count + completion_rate 作为代理信号推断估算偏差，粒度较粗。更精确的方向：① 被动采集完成时间戳序列推算单任务耗时；② 引入"当天实际工作时长"作为归一化分母消除精力变量；③ 用贝叶斯更新替代滑动均值，对少量数据点更鲁棒。基础版上线积累数据后再评估是否值得做。
- **向量数据库 / 语义搜索**：接入 Chroma 或 Qdrant，支持"帮我找我之前学过的关于 agent memory 的笔记"类查询。接口已在 learning-data-layer spec 中预留。

## 资料解析

- **纯意图型资料**："我想学 LangGraph"——不带链接，系统自己去找资料并生成计划。复杂度高，暂不做。
- **八股爬虫**：爬小红书面经，汇总成八股复习大纲。涉及反爬，先手动处理。

## 其他功能线

- **心理 Therapist 对话**：绷不住时随时聊，语音或文字。接口预留，功能体系庞大，单独立项。
- **健身助手**：手机端，记录器械/重量/组数，推日拉日交替，桌面端互通。需要移动端，单独立项。
- **餐饮助手**：每三天备菜规划，爬有真人反馈的菜谱，热量记录。单独立项。
