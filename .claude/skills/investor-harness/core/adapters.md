# Data Adapters · Gangtise 数据接口全景 + 取数策略（v0.6）

> 所有 sk-* skill 与研究流水线统一按本文件取数。**充分利用 Gangtise OpenAPI 的全部覆盖**——能用 Gangtise 取到的就不要走外部；外部（Tavily/WebSearch）只作兜底。
>
> CLI：`gangtise`（gangtise-openapi-cli，本文件基于 **v0.17.0**，2026-06-15）。
> **v0.17.0 严格参数校验**：传未声明的 `--xxx` 选项会被 commander 直接拒为 `unknown option`（v0.16.0 之前会静默忽略）。**精确参数以 `gangtise <group> <cmd> --help` 为准**；个别 leaf 子命令的 `--help` 会回落到顶层帮助，此时可直接试运行，或查仓库文档 <https://github.com/gangtiser/gangtise-openapi-cli>。

---

## 核心原则

1. **Gangtise 优先**：行情/财务/观点/纪要/研报/公告/宏观/AI 能力都先用 Gangtise，覆盖不到再降级
2. **并行优先**：无依赖的数据源同时拉取，不要串行等待
3. **缓存复用**：同一天同一标的的数据直接读 `.cache/`，不重复调 API
4. **知识库优先**：先用 `ai knowledge-batch`，搜不到再用 Tavily/WebSearch
5. **精简字段**：`--field` 只选需要的，减少传输和解析

---

## 证券代码格式 & 代码查询

- **代码必带交易所后缀（实测）**：A股沪市 `.SH` / 深市 `.SZ`（如 `600000.SH`）；**港股 5 位 + `.HK`**（如 `00700.HK`，4 位 `0700.HK` 返空）；**美股 `.O`（纳斯达克）/ `.N`（纽交所）**，如 `AAPL.O`、`NVDA.O`——**不是 `.US`**。裸代码在 `fundamental` 报 `430009 非有效A股`、在 `quote` 返回空。
- **不确定代码 / 只知公司名** → 先查 `gangtise reference securities-search --keyword "{公司名}" --format json`（返回 `gtsCode`）。`gangtise lookup` 自 v0.16 起仅保留 `broker-org` / `meeting-org`，原行业/区域/题材/公告分类已由 `reference constant-list` / `concept-search` / `sector-constituents` 覆盖。

---

## 缓存规则

**位置** `{workspace_root}/.cache/` · **命名** `{ticker}_{data_type}_{YYYY-MM-DD}.{json|md}` · **TTL** 当日有效（次日即失效，按文件名日期判断）

调用前先查 `.cache/` 有无当日缓存：有则直接读、跳过 API；无则调 API → 写缓存 → 返回。

---

## Gangtise 数据接口全景（按用途）

> 这是 Gangtise 覆盖的全部能力，**研究时应主动调用对应接口，而不是只拉财务三表**。

### 行情 — `gangtise quote`
| 命令 | 用途 |
|---|---|
| `day-kline` / `day-kline-hk` / `day-kline-us` | A股 / 港股 / 美股 日 K（`--security <code>`，港股 `00700.HK`、美股 `AAPL.O`；`--start-date --end-date --limit --field --format`） |
| `index-day-kline` | 指数日 K |
| `minute-kline` | 分时 |
| `realtime` | A/HK/US 实时快照 |

### 财务 — `gangtise fundamental`
| 命令 | 用途 |
|---|---|
| `income-statement` / `-quarterly` / `-hk` | 利润表（A股年报 / 季报 / 港股）|
| `balance-sheet` / `-hk` · `cash-flow` / `-quarterly` / `-hk` | 资产负债表 / 现金流（A股年报 / 季报 / 港股；季报支持 `--period q1/q2/q3/q4/latest`）|
| `valuation-analysis` | 估值（`--indicator peTtm --indicator pbMrq`）|
| `earning-forecast` | 一致预期（`--consensus netIncome --consensus eps --consensus pe`）|
| `top-holders` | 股东（`--holder-type top10 --fiscal-year {y}`）|
| `main-business` | 主营拆分（`--breakdown product --period annual`）|

> ⚠️ A股三表（income/balance/cash-flow，含 `-quarterly`）实测**只返回最新一期**，`--fiscal-year/--period/--report-type/--start-date` 取不到多年历史。要历史趋势：走知识库（标市场共识）或让用户贴年报（标财报披露），**不要**把知识库转述数字当财报披露。港股 `-hk` 接口支持 `--period q1/h1/q3/h2/nsd/annual/latest`。

### 观点 / 纪要 / 研报 / 公告 — `gangtise insight <类> list`（部分含 `download`）
| 类别 | 命令 | 内容 |
|---|---|---|
| **观点** | `opinion list` · `summary list` · `independent-opinion` · `foreign-opinion` | 卖方观点 / 摘要 / 独立 / 外资观点 |
| **纪要** | `roadshow list` · `site-visit list` · `forum list` | 路演 / 调研 / 论坛·电话会纪要 |
| **研报** | `research list`+`download` · `foreign-report list`+`download` · `strategy list` | 研报 / 外资研报 / 策略报告 |
| **公告** | `announcement list`+`download` · `announcement-hk` | A股 / 港股公告 |

通用过滤参数（v0.17.0 实测）：

- **观点 / 研报通用**（`opinion list` / `research list` / `summary list` / `foreign-opinion list` / `independent-opinion list` / `foreign-report list`）：`--security <code>` `--start-time` `--end-time` `--keyword` `--rank-type`（1 综合 / 2 时间倒序）`--broker` `--industry` `--concept` `--rating` `--source` `--size` `--from` `--format json`
- **研报独有**（`research list`）：`--search-type`（1 标题 / 2 全文）`--rating-change` `--min-pages/--max-pages`
- **日程类参数已收窄**（v0.17.0 breaking）：
  - `roadshow list`：移除 `--object`
  - `site-visit list`：移除 `--participant-role` / `--broker-type`
  - `strategy list`：**仅保留** `--institution` / `--location`
  - `forum list`：**仅保留** `--research-area` / `--location`
- **公告**（`announcement list` / `announcement-hk list`）：移除原 `--announcement-type`；A股公告分类筛选用 `--category <constantId>`（`aShareAnnouncementCategory` 常量 ID，通过 `reference constant-list --category aShareAnnouncementCategory` 拿；如"中介公告"=103910806）
- **常量 ID 区分**（v0.17.0 明确）：
  - `--industry` 用 **`citicIndustry` 码**（中信一级行业，`1008001xx`，全命令通用）
  - `--research-area` 用 **`gangtiseIndustry` 码**（行业 `1008001xx` + 宏观/策略/固收/金工/海外等方向 `122000xxx`）
- `download` 子命令用于下原文 PDF/MD

### AI / Agent 能力 — `gangtise ai`
| 命令 | 用途 | 主要服务的 skill |
|---|---|---|
| `one-pager` | 一页通（公司速览）| company-deepdive |
| `investment-logic` | 投资逻辑 | thesis / company-deepdive |
| `peer-comparison` | 同业对比 | company-deepdive / industry-map |
| `earnings-review` (+`-check`) | 业绩点评 | earnings-preview |
| `theme-tracking` | 主题 / 行业脉络 | industry-map / catalyst / close-recap |
| `research-outline` | 调研提纲 | roadshow-questions / question-list |
| `security-clue` | 异动事件 / 卖方线索 | catalyst / close-recap / hourly-watch |
| `knowledge-batch` | 知识库批量检索（研报/纪要/公告/观点）| 几乎所有 skill |
| `hot-topic` | 当日热点 / 晨晚报主题 | briefing / daily-feed |
| `viewpoint-debate` (+`-check`) | 观点 PK / 多空辩论 | red-team / consensus-watch |
| `management-discuss-announcement` / `-earnings-call` | 管理层讨论（公告 / 业绩会）| earnings-preview / deepdive |
| `knowledge-resource-download` | 下载知识库资源原文 | — |

调用范式（实测）：`one-pager` 等 security 类 = `--security-code <code> --format json`；`knowledge-batch` = `--query "{标的} {关键词}" --resource-type 10 --resource-type 60 --top 15`；`security-clue` = `--security-code <code> --start-time <date> --end-time <date> --query-mode bySecurity|byIndustry`。其余精确参数见 `gangtise ai <cmd> --help`（个别 --help 会回落顶层，可试运行）。

### 宏观 / 概念 — `gangtise alternative`
| 命令 | 用途 |
|---|---|
| `edb-search` / `edb-data` | 宏观经济数据库（EDB）指标搜索 / 取数 |
| `concept-info` / `concept-securities` | 概念信息 / 概念成分股 |

### 参考 / 板块 — `gangtise reference`
| 命令 | 用途 |
|---|---|
| `securities-search` | 公司名 / 简称 → 证券代码（取数前先解析代码用）|
| `sector-search` / `sector-constituents` | 板块搜索 / 板块成分股 |
| `concept-search` | 概念搜索 |
| `constant-category` / `constant-list` | 枚举常量（行业/评级/类别等 ID）|

> **取数前先解析常量 ID**（v0.17 严格校验，传错会被拒）：先 `reference constant-category` 看有哪些常量类，再 `reference constant-list --category <name>` 取具体 ID。常用：A股公告分类 `aShareAnnouncementCategory`、中信一级行业 `citicIndustry`、Gangtise 研究方向 `gangtiseIndustry`、国内城市 `domesticCity`。

### 云盘 / 纪要库 / 电话会 / 股票池 — `gangtise vault`
| 命令 | 用途 |
|---|---|
| `drive-list` / `drive-download` | 个人云盘文件 |
| `record-list` / `record-download` | 纪要库 |
| `my-conference-list` / `-download` | 我的电话会 |
| `wechat-message-list` / `wechat-chatroom-list` | 微信消息 / 群 |
| `stock-pool-list` / `stock-pool-stocks` | 自建股票池 / 成分 |

---

## 并行取数策略（sk-company-deepdive 范式）

**Batch 1 — 财务核心（并行）**
```bash
gangtise fundamental income-statement --security-code {code} --field totalOpRev --field netProfitAttrParent --field basicEPS --format json
gangtise fundamental balance-sheet   --security-code {code} --field totalAssets --field totalParentEq --field monetaryAssets --field inventory --format json
gangtise fundamental cash-flow       --security-code {code} --field netOpCashFlows --format json
```
**Batch 2 — 估值 / 预期 / 行情（与 Batch 1 同时发起）**
```bash
gangtise fundamental earning-forecast    --security-code {code} --consensus netIncome --consensus eps --consensus pe --format json
gangtise fundamental valuation-analysis  --security-code {code} --indicator peTtm --indicator pbMrq --format json
gangtise quote day-kline --security {code} --limit 5 --field close --field pctChange --format json   # 港股 day-kline-hk（00700.HK 5位），美股 day-kline-us（AAPL.O）
```
**Batch 3 — 业务 / 股东 / AI 速览（并行）**
```bash
gangtise fundamental main-business --security-code {code} --breakdown product --period annual --format json
gangtise fundamental top-holders   --security-code {code} --holder-type top10 --format json
gangtise ai one-pager --security-code {code} --format json          # 一页通速览
```
**Batch 4 — 观点 / 研报 / 纪要 / 知识库（并行）**
```bash
gangtise ai knowledge-batch --query "{公司名} {业务关键词}" --resource-type 10 --resource-type 60 --top 15 --format json
gangtise insight research list --security {code} --rank-type 2 --size 20 --format json     # 最新研报
gangtise insight roadshow list --security {code} --size 10 --format json                   # 路演纪要
gangtise ai security-clue --security-code {code} --start-time {date} --end-time {date} --query-mode bySecurity --format json   # 异动/卖方线索（bySecurity|byIndustry）
```
**Batch 5 — 外部兜底（Gangtise 不足时）**：Tavily / WebSearch。

---

## 数据源优先级（按市场）

| 市场 | 优先级链 |
|---|---|
| **§A A股 / 公募** | Gangtise 全接口（行情/财务/观点/纪要/研报/公告/AI/EDB）→ `.cache` → `ai knowledge-batch` → Tavily → WebSearch/WebFetch → 用户贴材料 |
| **§H 港股** | Gangtise（`quote day-kline-hk` 用 `00700.HK` 5 位、`fundamental *-hk`、`insight announcement-hk`、AI、知识库）→ `.cache` → Tavily → WebFetch HKEX → 兜底 |
| **§U 美股** | Gangtise（`quote day-kline-us` 用 `AAPL.O`/`.N`、AI、知识库；**无三表财务**）→ `.cache` → Tavily → WebSearch SEC → WebFetch EDGAR → 兜底 |

---

## 精简字段速查

**利润表** `totalOpRev` `netProfitAttrParent` `basicEPS` `grossProfit` `rdExp`
**资产负债表** `totalAssets` `totalParentEq` `monetaryAssets` `inventory` `shortTermLoans` `longTermLoans`
**现金流** `netOpCashFlows` `netInvCashFlows` `netFinCashFlows`
**估值** `peTtm` `pbMrq` · **K线** `close` `pctChange` `volume` `amount`

---

## 对 LLM 的行为要求

- ✅ **充分利用 Gangtise**：研究一家公司不止拉三表——一页通(`ai one-pager`)、投资逻辑、同业对比、研报/纪要(`insight`)、异动线索(`ai security-clue`)、知识库都要按需调
- ✅ **并行**：无依赖的数据源同时调用 · ✅ **缓存**：先查 `.cache/` 再调 API · ✅ **精简**：`--field` 只选需要的
- ✅ **代码先解析**：不确定代码先 `reference securities-search`
- ✅ **常量先解析**：传 `--category` / `--industry` / `--research-area` 等需要 ID 的参数前，先 `reference constant-list --category <name>` 拿合法 ID（v0.17 严格校验，错 ID 会被拒）
- ❌ 不串行等所有数据拉完再分析 · ❌ 不重复拉当日已缓存数据 · ❌ 不把知识库转述数字当财报披露
