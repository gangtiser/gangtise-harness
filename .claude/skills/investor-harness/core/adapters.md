# Data Adapters · Gangtise 数据接口全景 + 取数策略

> 所有 sk-* skill 与研究流水线统一按本文件取数。**充分利用 Gangtise OpenAPI 的全部覆盖**——能用 Gangtise 取到的就不要走外部；外部（Tavily/WebSearch）只作兜底。
>
> CLI：`gangtise`（gangtise-openapi-cli，本文件基于 **v0.27.0**，2026-07-11）。
> **严格参数校验**（自 v0.17.0）：传未声明的 `--xxx` 会被 commander 拒为 `unknown option`。**精确参数以 `gangtise <group> <cmd> --help` 为准**；个别 leaf 的 `--help` 会回落顶层帮助，此时查仓库文档 <https://github.com/gangtiser/gangtise-openapi-cli> 或 `gangtise-openapi` skill 的 `references/commands/<group>.md`。
> **v0.18–v0.27 对齐（本文件已补录）**：`indicator`（EDE 证券级数据指标）整组、美股三表（`fundamental *-us`）、美股公告（`insight announcement-us`）、产业公众号（`insight official-account`）、个股看点（`ai stock-summary`）、首席 ID 搜索（`reference chiefs-search`）、A股资金流向（`quote fund-flow`）、机构 ID 搜索（`reference institution-search`）、**投资者问答（`insight qa`）、研报图表（`insight report-image`）、公众号 ID 搜索（`reference official-account-search`）、endpoint 清单（`raw list`）、EDE 官方扩至港美股**；同时吸收 v0.21/v0.22 的自动翻页、partial 结果、下载输出、token 自愈与重试语义，v0.23 无翻页行情端点撞 `--limit` 的 partial 标记，以及 **v0.26/v0.27 贵档端点 no-replay 计费安全语义**。

---

## 核心原则

1. **Gangtise 优先**：行情/财务/观点/纪要/研报/公告/宏观/AI 能力都先用 Gangtise，覆盖不到再降级
2. **并行优先**：无依赖的数据源同时拉取，不要串行等待
3. **缓存复用**：同一天同一标的的数据直接读 `.cache/`，不重复调 API
4. **知识库优先**：先用 `ai knowledge-batch`，搜不到再用 Tavily/WebSearch
5. **精简字段**：`--field` 只选需要的，减少传输和解析

---

## v0.22–v0.27 执行约束

- **自动翻页**：自动翻页接口省略 `--size` 会拉全量，不再因传了时间范围而限制默认条数。日常列表查询必须显式传 `--size N`；数据量未知时先用 `--size 1` 从 stderr 的 `Total` 探量级，再决定是否全量拉取。
- **partial 结果**：翻页页失败、K 线分片失败或服务端短页时，JSON 会带 `partial: true`，并可能带 `failedPages` / `failedShards`；非 JSON 行式输出会以退出码 3 标记。**v0.23 起，无翻页行情端点（`quote fund-flow` / `minute-kline` / 显式多标的日 K `day-kline`·`-hk`·`-us` / `index-day-kline`）返回行数撞上单次 `--limit` 时同样标 `partial` + 退出码 3 + stderr 警告，不再静默截断；`--limit` 现本地校验 ≤ 10000（`--security all` 仍走日期分片自动补全，不受影响）。v0.27 起全市场分片截断时另输出 `truncatedShards`（具体日期区间，与 `failedShards` 对称），可据此定向缩窗补拉。**研究输出可保留已取数据，但必须写明"部分结果 / 待补拉"，不得当作完整样本。
- **token / retry / 计费安全（v0.24–v0.27 重点）**：CLI 已自愈 token 踢线，自动重试 429（尊重 `Retry-After`）、DNS/连接期错误和 undici 超时；AI 同步生成端点（`one-pager` / `investment-logic` / `peer-comparison` / `theme-tracking` / `research-outline` / `management-discuss-*`）内置 120s 超时下限，**不必再手动前缀 `GANGTISE_TIMEOUT_MS`**（v0.24）。**v0.26 起 13 个贵档端点改 no-replay**——`one-pager` / `investment-logic` / `peer-comparison` / `research-outline` / `theme-tracking` / `management-discuss-*`×2 / `hot-topic` / `knowledge-batch` / `earnings-review get-id` / `viewpoint-debate get-id` / `concept-info` / `concept-securities` 遇 5xx / 超时 / `999999` **不再自动重放**（平台按次计费且缓存命中不豁免；仅请求未发出的连接错误、429 和 token 自愈仍重试）；v0.27 起 50 积分/篇的 `summary` / `foreign-report` / `my-conference` download 同样 no-replay。**LLM 侧配套：贵档命令失败不要条件反射式重跑**——先判失败原因（`999999` 多为无数据、参数错要改参数），确需手动重试要知道每次都计费。便宜的按条计费 list 类维持自动重试；不要在 skill 里手写重试循环，若 CLI 仍失败，保留原始错误与命令。
- **下载输出**：`download --output` 会跟随最多 3 跳重定向并实际落文件（v0.26 起超限或缺 `Location` 直接报错，不再把跳转页 HTML 存成文件）；跨域对象存储签名 URL 不带 Authorization。v0.26 起所有 `--output` 落盘为**原子写**（先写同目录 `.part` 成功后 rename，重跑失败不毁已有旧文件）。下载后仍需检查目标路径、文件大小与格式，不只看命令退出状态。
- **日期窗口**：`fundamental earning-forecast` 省略 `--start-date` 且传了 `--end-date` 时，v0.22 会按 `end-date - 1 year` 计算起点；v0.24 起默认 `--end-date`（today）按本机本地日期计算（不再用 UTC，CST 凌晨不会错算成昨天）。若要比较固定预测窗口，仍显式传 `--start-date` / `--end-date`。
- **raw / format**：`raw list` 列出全部已注册 endpoint key（含 method / path / description，v0.24），配合 `raw call <key>` 使用，不必翻文档记 key；`raw call` 会本地拒绝 JSON endpoint 的 `--query` 和 download endpoint 的 `--body`，`--format` 会在请求前校验。拼错格式不会消耗接口调用，但也不能把本地校验错误当成远端无数据。
- **大结果集**：≥5 万行且走 table/json/markdown（或 jsonl/csv 未带 `--output`）时 stderr 会提示改用 `--format jsonl --output <path>` 流式落盘（v0.24）；大样本导出直接按此办理。
- **本地上限 / 枚举白名单（v0.25–v0.26）**：`--top`（`report-image` / `knowledge-batch` ≤20，reference 六个搜索命令 ≤10）、`edb-search --limit` ≤200、`indicator search --limit` ≤100，超限本地报错（服务端对超限值**静默截断**不报错）；`securities-search` / `institution-search` / `official-account-search` 的 `--category` 有本地白名单（服务端对拼错分类静默返全量或空，会伪装成"无结果"）。枚举参数照 `--help` 拼写，别猜。

---

## 证券代码格式 & 代码查询

- **代码必带交易所后缀（实测）**：A股沪市 `.SH` / 深市 `.SZ`（如 `600000.SH`）、北交所 `.BJ`（8xx/4xx/9xx 开头，本 CLI 版本少实测，取数前先用 `reference securities-search` 确认 `gtsCode`）；**港股 5 位 + `.HK`**（如 `00700.HK`，不足 5 位先补 0，4 位 `0700.HK` 返空）；**美股 `.O`（纳斯达克）/ `.N`（纽交所）/ `.A`（NYSE American，少见、少实测）**，如 `AAPL.O`、`NVDA.O`——**不是 `.US`**。裸代码在 `fundamental` 报 `430009 非有效A股`、在 `quote` 返回空。
- **不确定代码 / 只知公司名** → 先查 `gangtise reference securities-search --keyword "{公司名}" --category stock --top 3 --format json`（返回 `gtsCode`；若匹配分低或多市场重名，先让用户选）。`gangtise lookup` 自 v0.16 起仅保留 `broker-org` / `meeting-org`，原行业/区域/题材/公告分类已由 `reference constant-list` / `concept-search` / `sector-constituents` 覆盖；**按名称找券商/机构 ID（`--broker` / `--institution` 入参）优先用 `reference institution-search`（服务端搜索、结果带 `usageScopes` 标明适用接口），`lookup broker-org` / `meeting-org` 退为全量枚举用**。

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
| `fund-flow` | A股个股日频资金流向（沪深京；`--security <code>`〔日期可省，默认近 1 年〕或 `aShares` 全市场〔**须显式 `--start-date`/`--end-date`**，CLI 按日自动分片、跳过周末〕；主力/小中大特大单净流入及占比，`--field mainNetInflow` 等；免费）|

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
| **公众号** | `official-account list`+`download` | 产业公众号资讯（`--category news/report/view…` 多选 · `--account-id` 限定账号，ID 用 `reference official-account-search` 查）|
| **问答** | `qa list` | 投资者问答——历史问答库（互动平台 / 电话会 / 调研纪要中的提问与回答，**仅 `--source interactive` 来源可当公开问答引用**，电话会/调研纪要来源须核出处再定证据等级；`--security-code` 必填 · `--source conference/interactive/survey` 多选 · `--question-category` 11 类（订单客户 `ordersAndCustomers`、产能项目 `capacityAndProjects`、财务数据 `financialData` 等，见 `--help`）· `--answer-important 1/0` 按关键信息标记过滤（省略拉全部，会前对照类任务勿预过滤——回避式回答正是追问线索）；自动翻页单页上限 500、**省略 `--size` 拉全量**，0.1 积分/条，日常带时间窗 + `--size 200` 起步）|
| **研报图表** | `report-image list`+`download` | 按关键词搜研报图片：`list` 返回 `chunkId`+元数据（`--keyword` 必填 · `--top` ≤20 · `--source-id` 限定单篇；**免费**），`download --chunk-id` 下 JPEG 原图（0.1 积分/张）|

通用过滤参数（v0.23.0 实测，v0.27.0 沿用）：

- **观点 / 研报通用**（`opinion list` / `research list` / `summary list` / `foreign-opinion list` / `independent-opinion list` / `foreign-report list`）：`--security <code>` `--start-time` `--end-time` `--keyword` `--rank-type`（1 综合 / 2 时间倒序）`--broker` `--industry` `--concept` `--rating` `--source` `--size` `--from` `--format json`
- **研报独有**（`research list`）：`--search-type`（1 标题 / 2 全文）`--rating-change` `--min-pages/--max-pages`
- **日程类参数已收窄**（v0.17.0 breaking）：
  - `roadshow list`：移除 `--object`
  - `site-visit list`：移除 `--participant-role` / `--broker-type`
  - `strategy list`：**仅保留** `--institution` / `--location`
  - `forum list`：**仅保留** `--research-area` / `--location`
- **公告**（`announcement list` / `announcement-hk list` / `announcement-us list`）：移除原 `--announcement-type`；公告分类筛选用 `--category <constantId>`，A股查 `aShareAnnouncementCategory`、港股查 `hkShareAnnouncementCategory`、美股查 `usShareAnnouncementCategory`。A股公告的 `--start-time`/`--end-time` 按运行机器时区换算，跨机器要精确边界改传 13 位毫秒时间戳
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

调用范式（v0.23.0 实测，v0.27.0 沿用；贵档 no-replay 计费语义见「执行约束」）：`one-pager` / `investment-logic` / `peer-comparison` / `research-outline` = `--security-code <code> --format json`；`stock-summary` = `--security <code>` 或 `--security aShares|hkStocks`；`knowledge-batch` = `--query "{标的} {关键词}" --resource-type 10 --resource-type 60 --top 15 --format json`；`security-clue` = `--gts-code <证券代码或申万行业代码> --start-time "<datetime>" --end-time "<datetime>" --query-mode bySecurity|byIndustry --format json`。其余精确参数见 `gangtise ai <cmd> --help`（个别 --help 会回落顶层，可试运行）。

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
> **市场覆盖：v0.25 起官方扩至 A股/港股/美股**（此前 `scopeList` 系统性漏报仅标 A股，实测 `00700.HK`、`AAPL.O` 一直有值，官方现已确认三市场）；个别指标覆盖仍以小样本实测为准，不要据 `scopeList` 排除。美股代码用 `.O`/`.N` 交易所后缀——官方示例的 `AAPL.US` 查不到数据。
> **`999999` = 查询无数据**（节假日 / 未来日期 / 未覆盖标的）：v0.27 起 `indicator` 三端点对它不再自动重试（此前每次空查询白烧 3 个请求 + ~4 秒）。遇到先检查查询条件——换交易日、确认标的覆盖、补必填参数——不是"稍后重试"。
> **EDE 入库晚于 `quote`，最近交易日可能 `null`**：2026-06-27 实测 `qte_close` 对 `AAPL.O` 仅最近交易日 06-26 返 `null`，06-22~06-25 全有值（与 `day-kline-us` 收盘价逐日相等；`day-kline-us`/`realtime` 06-26 已有 283.78）。**取最近一日 `null` ≠ 不覆盖**，回退前一交易日即可；最新美股行情优先 `quote realtime` / `day-kline-us`（入库更及时）。

### 参考 / 板块 — `gangtise reference`
| 命令 | 用途 |
|---|---|
| `securities-search` | 公司名 / 简称 → 证券代码（取数前先解析代码用）|
| `chiefs-search` | 首席分析师 ID 搜索（`chiefId` 用于 `insight opinion list --chief <id>` 按首席筛选）|
| `institution-search` | 机构 ID 搜索（`--keyword` 机构名 → `institutionId` + `usageScopes`；`--category` 五类 domesticBroker/foreignInstitution/opinionInstitution/foreignOpinionInstitution/leadInstitution；用于各 `insight` list 的 `--broker` / `--institution`；免费）|
| `official-account-search` | 公众号 ID 搜索（`--keyword` 公众号名/机构/关键字 → `accountId`，喂 `insight official-account list --account-id`；`--category` 四类 listedCompany/broker/government/media 可重复——**未分类账号 `category=null`，要全量就别传**；`--top` ≤10；免费）|
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
- ✅ **partial 不算完整成功**：遇 `partial: true`、`failedPages`、`failedShards`、`truncatedShards` 或退出码 3，要标注部分结果并安排补拉（`truncatedShards` 给出具体日期区间，可定向缩窗）
- ✅ **贵档失败先判因、不盲目重跑**：v0.26 起 `one-pager` / `knowledge-batch` / `viewpoint-debate` 等贵档端点及 50 积分/篇下载不自动重放，每次手动重跑都计费；EDE `999999` = 无数据，改查询条件而不是重试
- ❌ 不串行等所有数据拉完再分析 · ❌ 不重复拉当日已缓存数据 · ❌ 不把知识库转述数字当财报披露
