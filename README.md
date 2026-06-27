# Gangtise Harness · 投研工作 harness

> 面向**买方研究员 / 基金经理**的 AI 投研任务执行规范。把 LLM 从"会聊天的助手"约束成"守纪律的研究员"——强制它在做投研时**不出现幻觉、不丢失上下文、不输出杂乱**。
>
> 基线源自 [investor-harness](https://github.com/joansongjr/investor-harness)（MIT）· 本仓库为 **Gangtise 定制版（v0.9.2-gangtise）**。

---

## 它解决什么

LLM 直接答投研问题有三个老毛病，本 harness 用机制逐一封堵：

| 痛点 | 表现 | 封堵机制 |
|---|---|---|
| **幻觉** | 编数字、把猜测当事实、套话风险 | 强制取数协议 + 五级证据分级 + "仍需补的资料"段 + 合规红线 |
| **健忘** | 忘了之前的研究、重复劳动、断在半路 | 持久化记忆 + `.task-pulse` 心跳 + `.checkpoint` 断点续跑 |
| **不成体系** | 自由发挥、结构随机、无法 review/复用 | 28 个标准化 skill + 输出归档协议 + 验收清单 |
| **上下文溢出** | 长任务跑着跑着崩 | 三层懒加载（Tier 0/1/2）+ 输出文件化 + 断点续跑 |

## 定制要点（相对上游）

- **命名**：统一 `sk-*`
- **数据源**：统一走 **Gangtise OpenAPI**（实时/历史行情、A/HK/US 财务三表、估值、一致预期、股东、主营、公告、产业公众号、EDE 证券级指标、AI 能力），外部搜索保留 **Tavily**，通用兜底 WebSearch/WebFetch。详见 `core/adapters.md`
- **证据分级**：完整中文标签 `公开事实 / 财报披露 / 市场共识 / 合理推演 / 待核验假设`，不使用字母缩写

---

## 28 个 skill（按层）

| 层 | skill | 用途 |
|---|---|---|
| **入口** | `sk-master` · `sk-autopilot` | 7 模式总控 / 模糊请求自动路由 |
| **框架** | `sk-thesis` · `sk-industry-map` | 可证伪命题 / 行业产业链图谱 |
| **选股** | `sk-stock-screen` | 条件选股、多策略对比 |
| **研究** | `sk-company-deepdive` · `sk-earnings-preview` · `sk-model-check` · `sk-consensus-watch` · `sk-industry-database` | 公司深度（9 段）/ 财报前瞻 / 模型校验 / 预期差 / 数据库搭建 |
| **跟踪** | `sk-catalyst-monitor` · `sk-roadshow-questions` · `sk-close-recap` · `sk-hourly-watch` · `sk-people-watch` | 催化剂 / 调研问题 / 收盘复盘 / 盘中盯盘 / 关键人物 |
| **反方** | `sk-red-team` | 强制空头审视（先查 `biases.md`） |
| **交付** | `sk-pm-brief` · `sk-briefing` | PM 一页纸 / 晨会晚报 |
| **技术面** | `sk-tape-review` | 盘面 + 技术面复盘 |
| **演示** | `sk-deck-builder` | PPT / 路演材料 |
| **批量** | `sk-batch-refresh` · `sk-batch-earnings` · `sk-catalyst-sweep` | 覆盖池批量刷新 / 财报季批量 / 催化扫描 |
| **Librarian** | `sk-wiki-build` · `sk-daily-feed` · `sk-question-list` · `sk-health-check` · `sk-qa-archive` | 研究 wiki / 日度信息流 / 问题清单 / 健康检查 / 纪要归档 |

> 不确定用哪个 → 说"看一下 X"走 `sk-autopilot`，或输入 "menu" 看入口菜单。机器可读的完整注册表见 `manifest.yaml`。

## 5-agent 研究流水线（对抗式深度研究）

需要独立反方 + 合规过审的深度研究（起 coverage、重大决策前、命题复核）时，触发 `.claude/agents/` 的串行流水线：

```
用户 → 主对话（协调员）
  │
  ├─ 1. data-fetcher        只按 adapters.md 用 Gangtise 取数、标证据等级，不分析
  ├─ 2. thesis-builder      收数据 → 可证伪命题 + 必要条件（带证伪阈值）
  ├─ 3. red-teamer          强制空头审视 + 查 biases.md，攻击必要条件
  ├─ 4. pm-voice            压成可决策一页纸（Action / 入场 / 卖出条件）
  └─ 5. compliance-checker  红线终审（不承诺收益 / 不下指令 / 评级目标价需人工复核）
            ↓
       协调员汇总 + 双输出（对话贴全文 + 归档 coverage/{ticker}/）
```

- 触发："**按研究流水线深度看 X**" / "跑一遍 5-agent 流水线"
- 日常轻量查询用单个 `sk-*` 即可（流水线 token 开销大）
- 编排细节见 [`.claude/agents/README.md`](.claude/agents/README.md)

---

## 核心机制

- **三层懒加载**：Tier 0 启动必读（`_boot` + `.task-pulse` + `CLAUDE.md`，≈4–5k token）→ Tier 1 调 skill 时加载（SKILL + preamble + postamble + adapters）→ Tier 2 按需（evidence / compliance / acceptance）
- **强制流程**：任何 skill 调用前走 `core/preamble.md`（识别市场 → 查历史输出 → Preflight 取数计划 → 实际取数），结束走 `core/postamble.md`（归档 + 更新 `.task-pulse` → 双输出 + 仍需补的资料 → 合规声明；证据随输出 inline 标注、验收默认抽查）
- **证据分级**：每条关键事实带中文标签；关键结论必须由 `公开事实`/`财报披露` 支撑，`待核验假设` 不能作为结论唯一依据
- **双输出纪律**：对话贴完整内容（云端用户直读）+ 同时写文件归档，不只回摘要
- **断点续跑**：context 紧张（剩余 < 10k）时写 `.checkpoint`，新会话用"继续 {task-id}"恢复
- **合规红线**：不承诺收益、不下买卖指令、不伪造渠道/订单、评级与目标价标"需人工复核"

## 目录结构

```
gangtise-harness/
├── CLAUDE.md                      # LLM 行为规则（每次会话首读）
├── manifest.yaml → .claude/...    # 套件清单
├── .claude/
│   ├── agents/                    # 5 个研究流水线 subagent + README
│   └── skills/investor-harness/
│       ├── skills/                # 28 个 sk-* skill
│       ├── core/                  # 强制流程 + 规范（preamble/postamble/adapters/evidence/...）
│       ├── setup/workspace/       # 工作区文件模板（*.template）
│       └── manifest.yaml
├── user-templates/                # L1 自定义任务模板（日报/周报/月报示例）
├── user-skills/                   # L2 继承 / L3 自创 skill 示例
│
│  ↓ 以下为运行时生成、.gitignore 排除（不入库）
├── coverage/ themes/ briefings/   # 研究产出
├── coverage.md watchlist.md ...   # 个人投研记忆 / 决策 / 观察
└── .cache/ .checkpoint/ .task-pulse
```

## 前置依赖：Gangtise OpenAPI CLI

数据层依赖 **[gangtise-openapi-cli](https://github.com/gangtiser/gangtise-openapi-cli)**（命令行 `gangtise`，提供实时/历史行情 / 财务三表（A股·港股·美股）/ 估值 / 一致预期 / 股东 / 主营 / 公告 / 产业公众号 / 证券级数据指标（EDE）/ AI 能力）。它是主数据源——没有它，只能退到 Tavily / WebSearch 兜底。

```bash
# 安装（需 Node.js）
npm install -g gangtise-openapi-cli

# 验证（本 harness 基于 v0.20.0 验证，2026-06-27）
gangtise --version

# 自检一条实时行情（代码须带市场后缀）
gangtise quote realtime --security 600000.SH --format json
```

- **认证 / 配置**：按 CLI 仓库文档完成 → <https://github.com/gangtiser/gangtise-openapi-cli>
- **代码格式**：证券代码须带交易所后缀（A 股 `.SH` / `.SZ` / `.BJ`，港股 5 位 + `.HK`，美股 `.O` / `.N` / `.A`），裸代码会报错或返回空
- **调用约定**：所有 `gangtise` 命令封装在 `core/adapters.md`，skill 不直接写死命令——换 CLI 版本或参数只改 adapters

## 快速开始

1. 安装并认证上面的 **Gangtise OpenAPI CLI**，再把本仓库放进你的工作区（或作为 `.claude/` 子集）
2. 从 `.claude/skills/investor-harness/setup/workspace/*.template` 生成你自己的 live 文件：`coverage.md` / `watchlist.md` / `decision-log.md` / `biases.md` / `people-watch.md` / `research-queue.md` / `active-tasks.md` / `memory.md` / `selection-pipeline.md` / `knowledge-index.md`
3. 按需改 `CLAUDE.md` 顶部"我是谁"（覆盖范围 + 数据源）
4. 新会话 LLM 先读 `CLAUDE.md` + `core/_boot.md`，然后：
   - "看一下 X" → `sk-autopilot`
   - "深度看 X 财报前瞻 / 反过来想 X" → 对应 skill
   - "按研究流水线深度看 X" → 5-agent 流水线

## 数据源协议

按 `core/adapters.md` 优先级逐级降级：

```
1. Gangtise OpenAPI   全市场主数据源（A股/港股/美股；A股 .SH/.SZ/.BJ，港股 00700.HK，美股 AAPL.O / XOM.N）
2. .cache/            当日缓存复用，不重复调 API
3. Gangtise 知识库     knowledge-batch（研报/纪要/公告/观点）
4. Tavily             外部信息搜索
5. WebSearch/WebFetch 通用兜底（SEC EDGAR / HKEX 等官方披露站）
6. 兜底协议            让用户贴材料，不编数据
```

## 用户定制层（L1 / L2 / L3）

harness 在走默认 `sk-*` 路由前，先检查用户定制：

- **L1 任务模板**（`user-templates/*.md`）：命中 `trigger:` 关键词 → 用模板的输出结构 + `based_on_skill` 父框架（如日报/周报/月报）
- **L2 继承 skill**（`user-skills/*/SKILL.md` 带 `extends:`）：加载父 skill，叠加新增/覆盖
- **L3 自创 skill**（无 `extends:`）：直接用本 skill 结构，仍继承 core 强制流程

## 数据隐私

本仓库**只含框架**。所有真实研究产出（`coverage/` `themes/` `briefings/`）、个人决策记忆（`decision-log.md` `biases.md` `watchlist.md` `coverage.md` 等）、运行缓存（`.cache/` `.checkpoint/` `.task-pulse`）均由 `.gitignore` 排除，**不入库**。模板（`setup/workspace/*.template`）随框架发布，新用户据此生成自己的 live 文件。

## 致谢 & License

- 方法论与骨架源自 [investor-harness](https://github.com/joansongjr/investor-harness)（作者 Joan Song，MIT License）
- 本定制版沿用 MIT License
