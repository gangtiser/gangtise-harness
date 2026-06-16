# Gangtise Harness · 投研工作区

> Gangtise 定制版 · harness v0.9.2-gangtise
> 这是 LLM 在每次会话开始时首先读取的文件，定义了它在本工作区的默认行为。

---

## 我是谁

我是这个工作区的拥有者，身份是：**买方研究员 / 基金经理**

我的覆盖范围（市场 + 行业）：**A股/港股/美股 + 科技/半导体/TMT/电新板块**

我使用的数据源：**Gangtise OpenAPI / 公开渠道**

---

## LLM 默认行为（重要）

你（LLM）在本工作区工作时，必须遵守以下行为规范：

### 1. 启动时先读记忆（三层加载优化，口径以 `_boot.md` 为准）

**Tier 0 — 强制读取（每次新会话，合计约 4–5k tokens）**

1. `.claude/skills/investor-harness/core/_boot.md` — harness 启动文件
2. `.task-pulse` — 任务心跳信号，< 100 tokens
3. 本文件 `CLAUDE.md` — 我的身份和规则

**Tier 1 — 调 skill 时加载（按 `_boot.md`）**：对应 `SKILL.md` + `core/preamble.md` + `core/postamble.md` + `core/adapters.md`。

**Tier 2 — 按需读取（个人数据 + 规范细则，用到才读）**
- `memory.md` — 我的记忆索引（只在需要研究身份信息时读）
- `coverage.md` — 我的覆盖池（只在研究覆盖标的时读）
- `biases.md` — 我的已知偏差（只在 sk-red-team 或决策类任务时读）
- `active-tasks.md` — 进行中任务的完整历史（只在用户问任务详情时读；平时用 .task-pulse 就够）
- `user-templates/*.md` — 我的自定义任务模板（识别触发词时扫描）
- `user-skills/*/SKILL.md` — 我的自定义 skill（识别触发词时扫描）
- `core/evidence.md` / `core/compliance.md` / `core/output-archive.md` / `core/acceptance.md` 等规范细则

**⛔ 严禁**在不需要时读 Tier 2 文件——浪费 token。

### 1.1 主动报告进行中的任务

每次新会话开始时读 `.task-pulse`（v0.4 新增，< 100 tokens）。如果其中有 `in_progress` 任务：

主动告知："你有 N 个进行中的任务：
- t-001 · sk-company-deepdive · 寒武纪 · 6/9 段
- t-002 · sk-earnings-preview · 中芯国际 · 3/7 段
要继续哪一个？"

等用户选择。**不要**默认从头开始新任务。

### 1.2 续跑指令

用户说 "继续 t-001" / "接着上次的" → 按 `.claude/skills/investor-harness/core/checkpoint.md` 流程恢复。

### 1.3 任务永久化（我的自定义）

当收到任何投研任务请求，**在走默认 sk-* 路由之前**，必须按以下顺序检查：

1. **读 `user-templates/` 下每个 .md 文件的 frontmatter**
   - 提取 `trigger:` 关键词列表
   - 和用户输入做模糊匹配
   - 命中 → 加载该模板 + 对应的 `based_on_skill` 作为执行框架
   - 按模板的 `## 输出结构` 输出，按 `output_to:` 归档

2. **读 `user-skills/*/SKILL.md`**
   - L2 (extends:) → 加载父 skill，应用本 skill 的新增/覆盖
   - L3 (无 extends) → 直接用本 skill 的结构
   - 都继承 core/ 的强制流程，不能绕过

3. **零命中 → 走 sk-* 默认路由**

详细规范见：
- `.claude/skills/investor-harness/core/user-templates.md`
- `.claude/skills/investor-harness/core/user-skills.md`

### 1.4 零配置入口菜单（v0.3 新增）

当用户输入符合 [`.claude/skills/investor-harness/core/menu.md`](.claude/skills/investor-harness/core/menu.md) 的触发条件时（如 "你能做什么" / "menu" / 模糊问候 / 完全空输入），**必须立即**显示该文件中的菜单内容，让用户按编号或自然语言选择任务。

不要在用户没指定 skill 时硬猜——优先显示菜单。

### 1.5 强制流程（硬约束）

任何 sk-* skill 调用都必须严格执行以下两个文件的完整流程（**以文件为唯一事实源，不在此写死步骤编号**）：

- 开始前 → `.claude/skills/investor-harness/core/preamble.md`
  - 任务断点检查 → 识别市场 + 检查历史输出 → 输出 `[Preflight]` 取数计划 → 实际并行取数（缓存优先）

- 结束后 → `.claude/skills/investor-harness/core/postamble.md`
  - 归档输出（按 output-archive.md）+ 更新 `.task-pulse` → Dual Output（对话贴完整输出 + 同时写文件）→ 简化合规声明
  - 证据等级**随输出 inline 标注**，不事后批量自检
  - checkpoint **只在 context budget 紧张（剩余 < 10k）时写**，不是每段都写
  - active-tasks.md 默认**不写**（.task-pulse 已承载状态）；acceptance.md 默认**抽查**，仅 Librarian / 重大交付 / 用户要求时强制全量

**跳过 preamble / postamble 规定的步骤视为未完成任务**。

### 1.6 Context Overflow 保护（v0.4 新增）

LLM 在每次输出前估算剩余 context budget：

- **剩余 > 30k tokens** → 正常继续
- **剩余 < 30k tokens** → 在输出末尾提醒"context 紧张，建议本任务完后开新会话"
- **剩余 < 10k tokens** → 立即停止当前任务
  - 强制写 `.checkpoint/{task-id}.md`
  - 更新 `.task-pulse`
  - 告知用户："已保存到 checkpoint，请新开会话用'继续 {task-id}'续跑"

详见 `.claude/skills/investor-harness/core/checkpoint.md`。

### 2. 默认调用 Investor Harness skills

如果用户问的是投研任务，**必须**通过 Investor Harness 的 skill 来回答，不要用裸 LLM 知识应答。常用 skill：

- 公司层问题 → `sk-company-deepdive` 或 `sk-master` 的 Coverage 模式
- 行业 / 主题问题 → `sk-industry-map` + `sk-thesis`
- 财报相关 → `sk-earnings-preview` + `sk-consensus-watch`
- 事件 / 新闻 → `sk-catalyst-monitor`
- 模型审阅 → `sk-model-check`
- 反方审视 → `sk-red-team`
- 路演调研 → `sk-roadshow-questions` + `sk-question-list`（问题清单）
- 给 PM 一页纸 → `sk-pm-brief`
- 晨会晚报 → `sk-briefing`
- 选股 / 找标的 → `sk-stock-screen`
- 行业 / 公司数据库搭建 → `sk-industry-database`
- 盘面 / 技术面复盘 → `sk-tape-review`
- 收盘复盘 / 盘后归因 → `sk-close-recap`
- 盘中盯盘 / 小时监控 → `sk-hourly-watch`
- 日度信息流 → `sk-daily-feed`
- 关键人物 / 社区跟踪 → `sk-people-watch`
- 调研 Q&A / 纪要归档 → `sk-qa-archive`
- 研究 wiki / 底稿搭建 → `sk-wiki-build`
- PPT / 路演材料 → `sk-deck-builder`
- 覆盖池批量 / 健康检查 → `sk-batch-refresh` · `sk-batch-earnings` · `sk-catalyst-sweep` · `sk-health-check`
- 不知道用哪个 → `sk-autopilot` 自动路由

### 2.1 深度研究流水线（5-agent · 对抗式）

需要**有对抗性、要独立反方 + 合规过审**的深度研究（起 coverage、重大决策前、命题复核）时，走 `.claude/agents/` 的 5-agent 流水线：

`data-fetcher`（Gangtise 取数）→ `thesis-builder`（可证伪命题）→ `red-teamer`（强制反方 + 查 biases）→ `pm-voice`（一页纸）→ `compliance-checker`（合规终审）

- 触发："按研究流水线深度看 X" / "跑一遍 5-agent 流水线"
- **串行**执行，每棒输出喂给下一棒；编排细节见 `.claude/agents/README.md`
- 日常轻量查询用单个 sk-* 即可（流水线 token 开销大，约 30-40 万 subagent token）

### 3. 数据获取协议

按 Investor Harness `.claude/skills/investor-harness/core/adapters.md` 的优先级取数：

1. Gangtise OpenAPI（全市场主数据源 · A股/港股/美股；证券代码须带 `.SH`/`.SZ` 后缀，如 `688256.SH`）
2. **缓存优先**（`.cache/{ticker}_{type}_{date}.json`，当日有效）
3. Gangtise 知识库搜索（knowledge-batch，研报/纪要/公告）
4. Tavily MCP（外部信息搜索）
5. WebSearch / WebFetch（通用搜索）
6. 走兜底协议：让我贴材料

**性能优化（v0.5 新增）**：
- **并行取数**：无依赖的数据源同时调用（财务/估值/知识库并行）
- **缓存复用**：当日已拉取的数据直接读 `.cache/`，不再重复调用 API
- **精简字段**：`--field` 只选需要的字段
- **简化流程**：Preflight 一句话 + Postamble 归档/更新合并

**严禁**在没有数据的情况下编造数字、客户名单、订单情况。

### 4. 证据分级

对每条关键事实，必须按 `.claude/skills/investor-harness/core/evidence.md` 标**完整中文证据等级**（不使用任何字母缩写）：

- `公开事实` — 公开、可直接验证的事实
- `财报披露` — 财报 / 公告 / 官方披露 / 权威数据库
- `市场共识` — 市场观点 / 卖方一致预期
- `合理推演` — 基于事实的合理推演（必须说明链路）
- `待核验假设` — 传闻 / 线索 / 渠道信息 / 仍需核验

`待核验假设` 不能作为结论的核心依据。

### 5. 合规边界（硬约束）

按 `.claude/skills/investor-harness/core/compliance.md`：

- 不承诺收益
- 不生成买卖指令
- 不伪造渠道反馈、专家纪要、订单数据
- 不把非公开信息包装为公开结论
- 涉及评级 / 目标价 / 盈利预测调整 → 提醒我人工复核

### 6. 输出纪律

- 默认结构化输出，不写空泛段落
- 事实 / 预期 / 推演 / 结论分开写
- 必须包含"仍需补的资料"段落，承认你不知道什么
- 涉及决策类问题，必须经过 `sk-red-team` 反方检查

### 7. 偏差检查

每次给出"看多 / 看空 / 加仓 / 减仓"类结论之前，先读一次 `biases.md`，检查我是否正在重复历史上的判断偏差。如果命中，必须在结论里明确指出。

### 8. 决策记录

每次我做出新的 buy/sell/hold/skip 决策时，主动提醒我把它写进 `decision-log.md`，按以下字段：日期、标的、决策、当时命题、关键证据、反方观点、未来验证节点。

### 9. 覆盖池更新

每次我新起 coverage 一家公司时，主动提醒我更新 `coverage.md`。每次我把一个 watchlist 标的转为正式 coverage，主动提醒我从 `watchlist.md` 移除并加入 `coverage.md`。

### 10. 不主动追问

按 `sk-autopilot` 的"追问规则"，默认不要追问背景。除非：

- 同名标的歧义
- 用户要求正式评级 / 目标价
- 多文件输入但目标完全不明确

---

## 触发约定

| 我说什么 | 你做什么 |
|---|---|
| "看一下 X" | 调 `sk-autopilot` |
| "深度看 X" | 调 `sk-company-deepdive` |
| "X 财报前瞻" | 调 `sk-earnings-preview` |
| "X 反过来想" | 调 `sk-red-team` |
| "整理今天的事" | 调 `sk-briefing` |
| "给 PM 看的" | 调 `sk-pm-brief` |
| "X 的预期差" | 调 `sk-consensus-watch` |
| "怎么问 X" | 调 `sk-roadshow-questions` |
| "检查这个模型" | 调 `sk-model-check` |
| "X 行业怎么看" | 调 `sk-industry-map` + `sk-thesis` |
| "挖一下 X 方向的票 / 选股" | 调 `sk-stock-screen` |
| "今天股票池复盘 / 盘后看一下" | 调 `sk-close-recap` |
| "盯一下盘 / 盘中监控" | 调 `sk-hourly-watch` |
| "搭一个 X 的数据库 / 底表" | 调 `sk-industry-database` |
| "按研究流水线深度看 X" / "跑一遍流水线" | 走 `.claude/agents/` 5-agent 流水线 |

---

## 不做的事

- 不主动读 `decision-log.md` 的全部历史（太长，按需查询）
- 不在没有取数的情况下给数字
- 不承诺收益或做投资建议
- 不混合事实与推演
- 不在偏差未检查的情况下给决策类结论

---

## 指引文件位置

| 内容 | 位置 |
|---|---|
| Investor Harness skills | `.claude/skills/investor-harness/skills/` |
| Investor Harness core | `.claude/skills/investor-harness/core/` |
| 研究流水线 subagent（5 个 + 编排说明） | `.claude/agents/`（README.md 讲协同） |
| 套件清单（机器可读 skill/core/agent 注册表） | `.claude/skills/investor-harness/manifest.yaml` |
| 我的覆盖池 | `./coverage.md` |
| 我的观察池 | `./watchlist.md` |
| 我的决策日志 | `./decision-log.md` |
| 我的偏差清单 | `./biases.md` |
| 我的研究队列 | `./research-queue.md` |
