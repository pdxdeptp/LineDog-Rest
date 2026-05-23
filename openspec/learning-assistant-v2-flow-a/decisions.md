# Flow A Decisions

## Round 01 · 2026-05-23

### Decision Packet: OQ3 · Parse 质量与 guided clarification

**Question:** URL -> 初始计划前是否需要 guided clarification;如果需要,问什么、怎么问、问几个、问题如何生成、用户如何跳过。

**Options considered:**

- **A. 不问问题,只做 D29 decomposition pipeline.** 交互最轻,但继续让系统猜用户水平、目标深度和重点范围,one-shot 质量风险仍高。
- **B. 固定三问确认卡.** 稳定、可实现、可测试;问题过多时可能像盘问。
- **C. 动态轻量确认卡(最多三问,可跳过,有默认值).** 保留校准收益,同时控制交互成本。

**User proxy decision:** Adopt option C and write it as D30.

**D30 summary:** After URL preview, show a skippable clarification card with at most three questions: current level/familiarity, learning goal/depth, and focus/skip scope. Use chips/segmented choices with "not sure/use recommendation"; allow optional short text on the last question. Generate question structure from material-type templates, fill specific options from LLM preview, and provide a "generate rough plan directly" skip path.

**Tradeoff accepted:** The add-project flow becomes one lightweight step longer, but this is justified because parse quality is the core v1 failure point. The step is user-initiated and skippable, so it does not violate the v2 boundary that the assistant must not act proactively.

**Affected design artifacts:** US-2, D29, new D30, OQ3, implementation route for `study-plan`.

**Flow B implication:** `study-plan` can now be proposed. The first OpenSpec slice should include US-1 through US-5, D24, D29, and D30.
