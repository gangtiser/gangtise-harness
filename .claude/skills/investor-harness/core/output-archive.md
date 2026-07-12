# Output Archive · 归档命名规范

> 所有 sk-* skill 的输出都要按本规范归档，不许散落在临时目录。
> 这是治"不成体系"的物理基础——没有归档协议，所有的"半年后回看"承诺都是空话。

---

## 为什么必须归档

1. **可 diff**：三个月后重跑同一个 skill，可以和上次输出做 diff
2. **可 review**：团队成员可以读到你的研究，PM 可以审计你的工作
3. **可引用**：其他 skill 可以读到同标的的历史输出（见 [preamble.md](preamble.md)）
4. **可追溯**：每次决策都能查到当时的研究底稿
5. **可批量更新**：周度刷新等批量任务依赖归档结构

---

## 默认目录结构

### 单股研究

```
{coverage_root}/
├── {ticker}_{name}/                  ← 一家公司一个目录
│   ├── INDEX.md                      ← 公司元数据 + 当前命题摘要
│   │
│   ├── thesis/                       ← sk-thesis 输出
│   │   ├── 2026-04-07-thesis.md
│   │   └── 2026-07-15-thesis-update.md
│   │
│   ├── deepdive/                     ← sk-company-deepdive 输出
│   │   ├── 2026-04-07-deepdive.md
│   │   └── 2026-08-20-deepdive-update.md
│   │
│   ├── earnings/                     ← sk-earnings-preview 输出
│   │   ├── 2026-04-07-earnings-preview.md
│   │   ├── 2026-04-07-earnings-postmortem.md
│   │   ├── 2026-07-15-earnings-preview.md
│   │   └── 2026-07-15-earnings-postmortem.md
│   │
│   ├── catalysts/                    ← sk-catalyst-monitor 输出
│   │   └── 2026-04-07-event-{name}.md
│   │
│   ├── consensus/                    ← sk-consensus-watch 输出
│   │   └── 2026-04-07-consensus.md
│   │
│   ├── red-team/                     ← sk-red-team 输出
│   │   └── 2026-04-07-redteam.md
│   │
│   ├── model/                        ← sk-model-check 输出 + 模型文件
│   │   └── 2026-04-07-modelcheck.md
│   │
│   ├── roadshow/                     ← sk-roadshow-questions 输出
│   │   └── 2026-04-07-roadshow.md
│   │
│   ├── pm-brief/                     ← sk-pm-brief 输出
│   │   └── 2026-04-07-pmbrief.md
│   │
│   ├── decks/                        ← sk-deck-builder 输出（最终交付 PPTX/PDF）
│   │   ├── 2026-04-07-deck-ic-pitch.pptx
│   │   └── _project/                 ← 生成器工作目录（源材料/草稿，不入 INDEX 指针）
│   │
│   ├── data/                         ← 原始数据快照（财报、公告等）
│   │   ├── 2024-annual-report.pdf
│   │   └── 2025-Q3-financials.json
│   │
│   └── notes/                        ← 路演纪要、调研、专家访谈
│       └── 2026-04-05-management-call.md
```

### 行业 / 主题研究

```
{workspace_root}/themes/
└── {theme-slug}/
    ├── INDEX.md
    ├── 2026-04-07-industry-map.md       ← sk-industry-map 输出
    ├── 2026-04-07-thesis.md             ← sk-thesis 输出
    └── members/                         ← 主题相关公司的索引（软链 / md 链接）
        ├── 寒武纪 → ../../coverage/688256_寒武纪/
        └── 海光信息 → ../../coverage/688041_海光信息/
```

### 晨会 / 简报

```
{workspace_root}/briefings/
├── 2026-04-07-morning.md             ← sk-briefing 输出
├── 2026-04-07-evening.md
├── health-check-2026-07-12.md        ← sk-health-check 输出（canonical 归档位置）
├── weekly/
│   ├── 2026-W14-coverage-review.md   ← 历史周报（早于 2026-W28，无 frontmatter，doctor 不回填/跳过）
│   └── 2026-W29-coverage-review.md   ← 新周报（2026-W28 起需 frontmatter）
└── monthly/
    └── 2026-07-pm-report.md          ← 月报（月度 PM 汇报）
```

---

## 命名规范

### 文件名格式

```
{YYYY-MM-DD}-{skill-short}[-{descriptor}].md
```

| 字段 | 说明 | 示例 |
|---|---|---|
| `YYYY-MM-DD` | 必填，输出当天日期 | `2026-04-07` |
| `skill-short` | skill 的简称（见下表） | `deepdive` / `thesis` / `earnings` |
| `descriptor` | 可选，区分同日多次输出 | `update` / `postmortem` / `q4-special` |

二进制交付（`decks/` 的 PPTX/PDF）同理：`{YYYY-MM-DD}-deck[-{descriptor}].pptx`。生成器时间戳命名的历史旧件不追改，但 INDEX 指针必须指向最终交付件。

### Skill 简称对照表

| Full skill name | Short name |
|---|---|
| `sk-master` | `master` |
| `sk-autopilot` | `autopilot` |
| `sk-thesis` | `thesis` |
| `sk-industry-map` | `industry` |
| `sk-company-deepdive` | `deepdive` |
| `sk-earnings-preview` | `earnings` |
| `sk-model-check` | `modelcheck` |
| `sk-consensus-watch` | `consensus` |
| `sk-catalyst-monitor` | `catalyst` |
| `sk-roadshow-questions` | `roadshow` |
| `sk-red-team` | `redteam` |
| `sk-pm-brief` | `pmbrief` |
| `sk-briefing` | `briefing` |
| `sk-batch-refresh` | `batch-refresh` |
| `sk-batch-earnings` | `batch-earnings` |
| `sk-catalyst-sweep` | `catalyst-sweep` |
| `sk-tape-review` | `tape` |
| `sk-deck-builder` | `deck` |
| `sk-stock-screen` | `screen` |
| `sk-industry-database` | `industry-db` |
| `sk-close-recap` | `close-recap` |
| `sk-hourly-watch` | `hourly` |
| `sk-daily-feed` | `daily-feed` |
| `sk-people-watch` | `people` |
| `sk-question-list` | `questions` |
| `sk-qa-archive` | `qa` |
| `sk-wiki-build` | `wiki` |
| `sk-health-check` | `health` |

> **目录名 ≠ 文件短名**：一级子目录用可读的连字符形式，文件名才用上表 short name。二者刻意不同的：`red-team/`（短名 `redteam`）、`pm-brief/`（`pmbrief`）、`catalysts/`（`catalyst`）、`model/`（`modelcheck`）；其余目录名 = short name。**完整路径** = `{ticker}_{name}/{目录名}/{YYYY-MM-DD}-{short}.md`。

### Ticker 目录命名

```
{ticker}_{name}/
```

- `ticker` 优先用交易所代码（A 股 6 位、港股 4-5 位、美股字母）
- `name` 用公司中文名（A 股、港股）或英文名（美股）
- 例：`688256_寒武纪/`、`0700_腾讯控股/`、`NVDA_NVIDIA/`

---

## 配置：coverage_root 在哪

每个工作区的 `CLAUDE.md` 必须声明 `coverage_root` 路径。例如：

```yaml
# In CLAUDE.md
coverage_root: ../覆盖公司库
workspace_root: ./
```

如果用户没设置：
- 默认 `coverage_root: ./coverage`
- 默认 `workspace_root: ./`

skills 在归档前必须读 CLAUDE.md 拿到这两个值。

---

## INDEX.md 的作用

每个 ticker 目录下的 `INDEX.md` 是该公司的"元数据 + 命题摘要"：

```markdown
# {Ticker} {Name}

**market**: CN-A
**sector**: 半导体
**started_coverage**: 2026-01-15
**last_updated**: 2026-04-07
**current_thesis**: "AI 算力国产替代龙头，2026 思元 590 量产是关键拐点"
**conviction**: medium
**latest_outputs**:
  - thesis: thesis/2026-04-07-thesis.md
  - deepdive: deepdive/2026-04-07-deepdive.md
  - earnings: earnings/2026-04-07-earnings-preview.md
  - red-team: red-team/2026-04-07-redteam.md
**next_catalysts**:
  - 2026-05-XX 公司业绩会
  - 2026-Q2 思元 590 量产指引
**watchlist_triggers**:
  - 思元 590 量产延后 → 下修
  - BIS 进一步收紧 → 上修
```

INDEX.md 是 LLM **每次** preamble 检查的首要文件。

---

## 产物 Frontmatter（血缘与时效）

自 2026-07-12 起，新归档的 .md 产物在文件头部加 YAML frontmatter（**历史文件不回填**）：

```yaml
---
target_type: ticker          # ticker / theme / market / portfolio / workspace
target_id: 300502.SZ         # ticker 带交易所后缀；theme 用主题 slug；market 用市场名；portfolio 用池名；workspace 固定 harness
as_of: 2026-07-12            # 数据基准日
skill: sk-earnings-preview
status: final                # final / draft / stale
supersedes: 2026-04-28-earnings-preview.md   # 可选：被本文替代的上一版（同目录文件名）
verification_due: 2026-08-30                 # 可选：命题/数据的下次验证节点
---
```

- 必填 5 项：`target_type` / `target_id` / `as_of` / `skill` / `status`；`supersedes` / `verification_due` 按需
- `target_type` 取值：个股 `ticker`（target_id 如 `300502.SZ`）· 行业/主题 `theme`（如 `AI-capex`）· 全市场筛选 `market`（如 `CN-A`）· 覆盖池批量/晨报晚报 `portfolio`（如 `coverage-pool`）· 健康检查等仓库级产物 `workspace`（固定 `harness`）——briefing、选股、批量刷新这类非个股产物由此自然表达
- **时效传播**：刷新类任务（sk-batch-refresh 等）产出新文件时，新文 `supersedes` 指回旧文；**仅当旧文本身已有 frontmatter** 时才把旧文 `status` 改为 `stale`。若旧文是 2026-07-12 前的历史文件（无 frontmatter），按"历史文件不回填"优先：不改旧文，血缘由新文 `supersedes` 单向承载——半年后回看仍能分清"最新结论"与"过时底稿"
- 分工：INDEX.md 的 `latest_outputs` 管"每类最新指针"，frontmatter 管"文与文之间的血缘链"
- `scripts/harness-doctor.sh` 会校验 2026-07-12 起新增产物的 5 项必填 + 值合法（`target_type`/`status` 枚举、`as_of` 真实日历、拒绝 `""`/`null`/`~` 占位与重复键），并覆盖周报（`YYYY-Www-*.md`）/ 月报（`YYYY-MM-*.md`）/ 健康检查（`health-check-YYYY-MM-DD.md`）等非日期前缀产物；LLM 漏写或写错会被拦下

---

## 历史输出的引用机制

当 preamble.md 发现历史输出时，LLM 应该：

1. 读取最近一份同 skill 的输出，diff 与本次的差异
2. 读取该公司的 INDEX.md 拿到 current_thesis
3. 读取相关其他 skill 的最近一份（如果做 deepdive，读 thesis；如果做 earnings preview，读 deepdive 和 consensus）
4. 在本次输出顶部声明：`本次为更新 — 上次 deepdive 2026-01-15，上次 thesis 2026-02-20`

---

## 团队场景（预留）

未来团队版会增加：
- `coverage_root` 区分 `team-coverage/` vs `personal-coverage/`
- 输出归档时自动加 `author` 字段
- 团队 review 工作流

当前 v0.3 只支持单人工作区。
