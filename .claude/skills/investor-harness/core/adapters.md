# Data Adapters · Gangtise 数据接口全景 + 取数策略

> 所有 sk-* skill 与研究流水线统一按本文件取数。**充分利用 Gangtise OpenAPI 的全部覆盖**——能用 Gangtise 取到的就不要走外部；外部（Tavily/WebSearch）只作兜底。
>
> CLI：`gangtise`（gangtise-openapi-cli，本文件基于 **v0.22.0**，2026-07-02）。
> **严格参数校验**（自 v0.17.0）：传未声明的 `--xxx` 会被 commander 拒为 `unknown option`。**精确参数以 `gangtise <group> <cmd> --help` 为准**；个别 leaf 的 `--help` 会回落顶层帮助，此时查仓库文档 <https://github.com/gangtiser/gangtise-openapi-cli> 或 `gangtise-openapi` skill 的 `references/commands/<group>.md`。
> **v0.18–v0.22 对齐（本文件已补录）**：`indicator`（EDE 证券级数据指标）整组、美股三表（`fundamental *-us`）、美股公告（`insight announcement-us`）、产业公众号（`insight official-account`）、个股看点（`ai stock-summary`）、首席 ID 搜索（`reference chiefs-search`）；同时吸收 v0.21/v0.22 的自动翻页、partial 结果、下载输出、token 自愈与重试语义。

---

## 核心原则

1. **Gangtise 优先**：行情/财务/观点/纪要/研报/公告/宏观/AI 能力都先用 Gangtise，覆盖不到再降级
2. **并行优先**：无依赖的数据源同时拉取，不要串行等待
3. **缓存复用**：同一天同一标的的数据直接读 `.cache/`，不重复调 API
4. **知识库优先**：先用 `ai knowledge-batch`，搜不到再用 Tavily/WebSearch
5. **精简字段**：`--field` 只选需要的，减少传输和解析

---

## v0.22 执行约束

- **自动翻页**：自动翻页接口省略 `--size` 会拉全量，不再因传了时间范围而限制默认条数。日常列表查询必须显式传 `--size N`；数据量未知时先用 `--size 1` 从 stderr 的 `Total` 探量级，再决定是否全量拉取。
- **partial 结果**：翻页页失败、K 线分片失败或服务端短页时，JSON 会带 `partial: true`，并可能带 `failedPages` / `failedShards`；非 JSON 行式输出会以退出码 3 标记。研究输出可保留已取数据，但必须写明"部分结果 / 待补拉"，不得当作完整样本。
- **token / retry**：CLI 已自愈 token 踢线、HTTP 4xx 错误信封，并自动重试 429、DNS/网络临时错误和 undici 超时。不要在 skill 里重复手写重试循环；若 CLI 仍失败，保留原始错误与命令。
- **下载输出**：`download --output` 会跟随最多 3 次跳转并实际落文件；跨域对象存储签名 URL 不带 Authorization。下载后仍需检查目标路径、文件大小与格式，不只看命令退出状态。
- **日期窗口**：`fundamental earning-forecast` 省略 `--start-date` 且传了 `--end-date` 时，v0.22 会按 `end-date - 1 year` 计算起点；若要比较固定预测窗口，仍显式传 `--start-date` / `--end-date`。
- **raw / format**：`raw call` 会本地拒绝 JSON endpoint 的 `--query` 和 download endpoint 的 `--body`，`--format` 会在请求前校验。拼错格式不会消耗接口调用，但也不能把本地校验错误当成远端无数据。

---

## 证券代码格式 & 代码查询

- **代码必带交易所后缀（实测）**：A股沪市 `.SH` / 深市 `.SZ`（如 `600000.SH`）、北交所 `.BJ`（8xx/4xx/9xx 开头，本 CLI 版本少实测，取数前先用 `reference securities-search` 确认 `gtsCode`）；**港股 5 位 + `.HK`**（如 `00700.HK`，不足 5 位先补 0，4 位 `0700.HK` 返空）；**美股 `.O`（纳斯达克）/ `.N`（纽交所）/ `.A`（NYSE American，少见、少实测）**，如 `AAPL.O`、`NVDA.O`——**不是 `.US`**。裸代码在 `fundamental` 报 `430009 非有效A股`、在 `quote` 返回空。
- **不确定代码 / 只知公司名** → 先查 `gangtise reference securities-search --keyword "{公司名}" --category stock --top 3 --format json`（返回 `gtsCode`；若匹配分低或多市场重名，先让用户选）。`gangtise lookup` 自 v0.16 起仅保留 `broker-org` / `meeting-org`，原行业/区域/题材/公告分类已由 `reference constant-list` / `concept-search` / `sector-constituents` 覆盖。

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

> 查"最近 N 条"K 线时，必须显式传 `--start-date` / `--end-date` 拉日期窗口，再按 `tradeDate` 排序取尾部；不要只用 `--limit N`，它截取的是查询窗口开头。日 K 只返回历史数据，盘中当前价 / 当日快照用 `quote realtime`。

### 财务 — `gangtise fundamental`
| 命令 | 用途 |
|---|---|
| `income-statement` / `-quarterly` / `-hk` / `-us` | 利润表（A股年报 / 季报 / 港股 / 美股）|
| `balance-sheet` / `-hk` / `-us` · `cash-flow` / `-quarterly` / `-hk` / `-us` | 资产负债表 / 现金流（A股年报 / 季报 / 港股 / 美股；A股季报支持 `--period q1/q2/q3/q4/latest`）|
| `valuation-analysis` | 估值（`--indicator peTtm --indicator pbMrq`）|
| `earning-forecast` | 一致预期（`--consensus netIncome --consensus eps --consensus pe`）|
| `top-holders` | 股东（`--holder-type top10 --fiscal-year {y}`）|
| `main-business` | 主营拆分（`--breakdown product --period annual`）|

> A/HK/US 三表均支持 `--start-date` / `--end-date` / `--fiscal-year` / `--period` / `--report-type`；查最新一期可省略时间或用 `--period latest`。A股单季度接口为 `income-statement-quarterly` / `cash-flow-quarterly`；港股 `-hk` 支持 `q1/h1/q3/h2/nsd/annual/latest`；美股 `-us` 支持 `q1/h1/q3/nsd/annual/latest`（**无 `h2`**）、`--report-type consolidated/standalone…`，且**不耗积分**。若某报告期无数据，明确标注缺口，不要把知识库转述数字当财报披露。

### 观点 / 纪要 / 研报 / 公告 — `gangtise insight <类> list`（部分含 `download`）
| 类别 | 命令 | 内容 |
|---|---|---|
| **观点** | `opinion list` · `summary list` · `independent-opinion` · `foreign-opinion` | 卖方观点 / 摘要 / 独立 / 外资观点 |
| **纪要** | `roadshow list` · `site-visit list` · `forum list` | 路演 / 调研 / 论坛·电话会纪要 |
| **研报** | `research list`+`download` · `foreign-report list`+`download` · `strategy list` | 研报 / 外资研报 / 策略报告 |
| **公告** | `announcement list`+`download` · `announcement-hk` · `announcement-us`+`download` | A股 / 港股 / 美股公告 |
| **公众号** | `official-account list`+`download` | 产业公众号资讯（`--category news/report/view…` 多选 · `--account-id` 限定账号）|

通用过滤参数（v0.22.0 实测沿用）：

- **观点 / 研报通用**（`opinion list` / `research list` / `summary list` / `foreign-opinion list` / `independent-opinion list` / `foreign-report list`）：`--security <code>` `--start-time` `--end-time` `--keyword` `--rank-type`（1 综合 / 2 时间倒序）`--broker` `--industry` `--concept` `--rating` `--source` `--size` `--from` `--format json`
- **研报独有**（`research list`）：`--search-type`（1 标题 / 2 全文）`--rating-change` `--min-pages/--max-pages`
- **日程类参数已收窄**（v0.17.0 breaking）：
  - `roadshow list`：移除 `--object`
  - `site-visit list`：移除 `--participant-role` / `--broker-type`
  - `strategy list`：**仅保留** `--institution` / `--location`
  - `forum list`：**仅保留** `--research-area` / `--location`
- **公告**（`announcement list` / `announcement-hk list` / `announcement-us list`）：移除原 `--announcement-type`；公告分类筛选用 `--category <constantId>`，A股查 `aShareAnnouncementCategory`、港股查 `hkShareAnnouncementCategory`、美股查 `usShareAnnouncementCategory`
- **常量 ID 区分**（v0.17.0 明确）：
  - `--industry` 用 **`citicIndustry` 码**（中信一级行业，`1008001xx`，全命令通用）
  - `--research-area` 用 **`gangtiseIndustry` 码**（行业 `1008001xx` + 宏观/策略/固收/金工/海外等方向 `122000xxx`）
- `download` 子命令用于下原文 PDF/MD

### AI / Agent 能力 — `gangtise ai`
| 命令 | 用途 | 主要服务的 skill |
|---|---|---|
| `one-pager` | 一页通（公司速览）| company-deepdive |
| `stock-summary` | 个股看点 / 投研总结（仅 A股/港股；`--security` 多只 或 `aShares`/`hkStocks` 全市场）| company-deepdive / briefing |
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

调用范式（v0.22.0 实测沿用）：`one-pager` / `investment-logic` / `peer-comparison` / `research-outline` = `--security-code <code> --format json`；`stock-summary` = `--security <code>` 或 `--security aShares|hkStocks`；`knowledge-batch` = `--query "{标的} {关键词}" --resource-type 10 --resource-type 60 --top 15 --format json`；`security-clue` = `--gts-code <证券代码或申万行业代码> --start-time "<datetime>" --end-time "<datetime>" --query-mode bySecurity|byIndustry --format json`。其余精确参数见 `gangtise ai <cmd> --help`（个别 --help 会回落顶层，可试运行）。

### 宏观 / 概念 — `gangtise alternative`
| 命令 | 用途 |
|---|---|
| `edb-search` / `edb-data` | 宏观经济数据库（EDB）指标搜索 / 取数 |
| `concept-info` / `concept-securities` | 概念信息 / 概念成分股 |

### 证券级数据指标（EDE）— `gangtise indicator`
| 命令 | 用途 |
|---|---|
| `search` | 指标搜索 → 拿 `indicatorCode`（`--keyword 收盘价/营业收入/总市值`；`--format json` 看 `parameterList` 必填参数）|
| `cross-section` | 截面：多指标 × 多证券、单日快照（`--indicator <code> --security <code> --date <yyyy-MM-dd>`）|
| `time-series` | 时序：多指标×单证券 或 单指标×多证券（`--start-date --end-date`；不支持多×多）|

> **EDE vs EDB 别混**：`indicator`（EDE）= 证券级指标（个股收盘价/成交量/总市值/财务科目，需 `--security`）；`alternative edb-*`（EDB）= 行业/宏观指标（无证券维度）。
> **取数前先 `search --format json` 看 `parameterList`**：不少指标有必填参数（`periodNum`/`startDate`/`fiscalYear`），用 `--indicator-param "code:参数=值"` 补，否则服务端报「必填参数 X 不能为空」。无数据统一返回 `null`（不报错、不丢行）。复权用 `--indicator-param "qte_close:adjustmentType=3"`（1不复权/2前/3后/4定点）。
> **市场覆盖以小样本实测为准，别信 `scopeList`**：`scopeList` 系统性漏报——`qte_close` 仅标「A股」，实测对 `00700.HK`、`AAPL.O` 同样返值，**不要据 `scopeList` 排除港美股**，直接小样本试取。
> **EDE 入库晚于 `quote`，最近交易日可能 `null`**：2026-06-27 实测 `qte_close` 对 `AAPL.O` 仅最近交易日 06-26 返 `null`，06-22~06-25 全有值（与 `day-kline-us` 收盘价逐日相等；`day-kline-us`/`realtime` 06-26 已有 283.78）。**取最近一日 `null` ≠ 不覆盖**，回退前一交易日即可；最新美股行情优先 `quote realtime` / `day-kline-us`（入库更及时）。

### 参考 / 板块 — `gangtise reference`
| 命令 | 用途 |
|---|---|
| `securities-search` | 公司名 / 简称 → 证券代码（取数前先解析代码用）|
| `chiefs-search` | 首席分析师 ID 搜索（`chiefId` 用于 `insight opinion list --chief <id>` 按首席筛选）|
| `sector-search` / `sector-constituents` | 板块搜索 / 板块成分股 |
| `concept-search` | 概念搜索 |
| `constant-category` / `constant-list` | 枚举常量（行业/评级/类别等 ID）|

> **取数前先解析常量 ID**（严格校验，传错会被拒）：先 `reference constant-category` 看有哪些常量类，再 `reference constant-list --category <name>` 取具体 ID。常用：A股公告分类 `aShareAnnouncementCategory`、港股公告分类 `hkShareAnnouncementCategory`、美股公告分类 `usShareAnnouncementCategory`、中信一级行业 `citicIndustry`、Gangtise 研究方向 `gangtiseIndustry`、国内城市 `domesticCity`。

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
gangtise quote day-kline --security {code} --start-date {start_date_45d} --end-date {end_date} --field close --field pctChange --format json   # 按 tradeDate 取尾部最近5条；港股 day-kline-hk，美股 day-kline-us
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
gangtise ai security-clue --gts-code {code} --start-time "{start_datetime}" --end-time "{end_datetime}" --query-mode bySecurity --format json   # 异动/卖方线索；行业查申万 821xxx.SWI + byIndustry
```
**Batch 5 — 外部兜底（Gangtise 不足时）**：Tavily / WebSearch。

---

## 数据源优先级（按市场）

| 市场 | 优先级链 |
|---|---|
| **§A A股 / 公募** | Gangtise 全接口（行情/财务/观点/纪要/研报/公告/产业公众号/AI/EDB/EDE）→ `.cache` → `ai knowledge-batch` → Tavily → WebSearch/WebFetch → 用户贴材料 |
| **§H 港股** | Gangtise（`quote day-kline-hk` 用 `00700.HK` 5 位、`quote realtime`、`fundamental *-hk`、`insight announcement-hk`、AI、知识库；EDE 可用——实测 `00700.HK` 有值，`scopeList` 标 A股 系漏报）→ `.cache` → Tavily → WebFetch HKEX → 兜底 |
| **§U 美股** | Gangtise（`quote day-kline-us` 用 `AAPL.O`/`.N`、`quote realtime`、`fundamental *-us` 三表、`insight announcement-us`、知识库；EDE 覆盖美股——实测 `AAPL.O` 历史日有值，但入库晚于 `quote`、最近交易日可能 `null`，最新行情优先 `quote realtime` / `day-kline-us`）→ `.cache` → Tavily → WebSearch SEC → WebFetch EDGAR → 兜底 |

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
- ✅ **常量先解析**：传 `--category` / `--industry` / `--research-area` 等需要 ID 的参数前，先 `reference constant-list --category <name>` 拿合法 ID（严格校验，错 ID 会被拒）
- ✅ **最近 K 线先拉窗口再截尾**：不要用裸 `--limit N` 代表最近 N 条；盘中当前价用 `quote realtime`
- ✅ **列表显式限量**：v0.22 自动翻页接口省略 `--size` 会拉全量；普通研究列表必须显式传 `--size N`，全量任务先探 `Total`
- ✅ **partial 不算完整成功**：遇 `partial: true`、`failedPages`、`failedShards` 或退出码 3，要标注部分结果并安排补拉
- ❌ 不串行等所有数据拉完再分析 · ❌ 不重复拉当日已缓存数据 · ❌ 不把知识库转述数字当财报披露
