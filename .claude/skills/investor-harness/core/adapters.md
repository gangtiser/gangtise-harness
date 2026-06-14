# Data Adapters · 优化版 v0.5

> 数据源优先级 + 并行取数策略。

---

## 核心原则

1. **并行优先**：无依赖的数据源同时拉取，不要串行等待
2. **缓存复用**：同一天内同一标的的财务/估值数据直接读 `.cache/`，不再重复调用 API
3. **知识库优先**：先用 gangtise knowledge-batch，搜捕不到再用 Tavily/WebSearch
4. **精简字段**：`--field` 只选需要的字段，减少传输和解析时间

---

## 缓存规则

**位置**：`{workspace_root}/.cache/`

**命名**：`{ticker}_{data_type}_{YYYY-MM-DD}.{json|md}`

| 数据类型 | 缓存文件名示例 | TTL |
|---|---|---|
| 利润表 | `002384_income_2026-04-28.json` | 当日有效 |
| 资产负债表 | `002384_balance_2026-04-28.json` | 当日有效 |
| 主营业务 | `002384_business_2026-04-28.json` | 当日有效 |
| 一致预期 | `002384_consensus_2026-04-28.json` | 当日有效 |
| 估值 | `002384_valuation_2026-04-28.json` | 当日有效 |
| 知识库搜索 | `002384_kb_关键词hash_2026-04-28.json` | 当日有效 |

**使用流程**：
1. 调用前先检查 `.cache/` 是否存在当日缓存
2. 存在 → 直接读取，跳过 API 调用
3. 不存在 → 调用 API → 写入缓存 → 返回数据

**清理**：缓存文件 7 天后自动过期，可手动 `rm -rf .cache/` 清理。

---

## 并行取数策略

> **⚠️ 证券代码格式（实测 CLI v0.16.0）**：下文所有 `{code}` 必须带交易所后缀——A股沪市 `.SH`（如 `688256.SH`）、深市 `.SZ`（如 `002384.SZ`）。裸代码 `688256` 在 `fundamental` 接口会报 `API error (430009): 非有效A股`，在 `quote` 接口返回空。
>
> **已知能力缺口（v0.16.0）**：`fundamental` 三表接口（income/balance/cash-flow）当前**只返回最新一期**，`--fiscal-year`/`--period`/`--report-type`/`--start-date` 均无法取多年历史序列。需要年报历史趋势时，走知识库（标市场共识）或让用户贴年报（标财报披露），**不要**把知识库转述的历史数字当财报披露。

### 公司深度研究（sk-company-deepdive）

**Batch 1 — 财务核心（并行）**：
```bash
# P1a: 利润表（年报+季报）
gangtise fundamental income-statement --security-code {code} --fiscal-year {y1} --fiscal-year {y2} --period annual --field totalOpRev --field netProfitAttrParent --field basicEPS

# P1b: 资产负债表
gangtise fundamental balance-sheet --security-code {code} --fiscal-year {y1} --fiscal-year {y2} --period annual --field totalAssets --field totalParentEq --field monetaryAssets --field inventory

# P1c: 现金流量表
gangtise fundamental cash-flow --security-code {code} --fiscal-year {y1} --fiscal-year {y2} --period annual --field netOpCashFlows
```

**Batch 2 — 估值与市场（并行，在 Batch 1 执行时同时发起）**：
```bash
# P2a: 一致预期
gangtise fundamental earning-forecast --security-code {code} --consensus netIncome --consensus eps --consensus pe

# P2b: 估值分析
gangtise fundamental valuation-analysis --security-code {code} --indicator peTtm --limit 5

# P2c: K线（最近5日）
gangtise quote day-kline --security {code} --limit 5 --field close --field pctChange
```

**Batch 3 — 业务与股东（在 Batch 1-2 返回后执行）**：
```bash
# P3a: 主营业务拆分
gangtise fundamental main-business --security-code {code} --breakdown product --period annual

# P3b: 前十大股东
gangtise fundamental top-holders --security-code {code} --holder-type top10 --fiscal-year {latest}
```

**Batch 4 — 知识库搜索（与前序批次并行）**：
```bash
# P4: 知识库批量搜索
gangtise ai knowledge-batch --query "{公司名} {业务关键词}" --resource-type 10 --resource-type 60 --top 15
```

**Batch 5 — 外部搜索（知识库结果不足时）**：
```bash
# P5: Tavily 外部搜索
curl -s "https://api.tavily.com/search" -H "Content-Type: application/json" -d '{...}'
```

---

## 数据源优先级

### §A — A 股 / 公募基金

| 优先级 | 数据源 | 说明 |
|---|---|---|
| P1 | Gangtise OpenAPI | 财务/行情/一致预期/估值 |
| P2 | **缓存读取** | 当日已拉取的数据直接复用 |
| P3 | Gangtise 知识库（knowledge-batch） | 研报/纪要/公告 |
| P4 | Tavily MCP | 外部搜索兜底 |
| P5 | WebSearch / WebFetch | Tavily 不可用时降级 |
| P6 | 用户贴材料 | 兜底 |

### §H — 港股 / §U — 美股

同上，优先 Gangtise OpenAPI + 缓存 + 知识库，再 Tavily。

---

## 精简字段速查

**利润表**：`totalOpRev` `netProfitAttrParent` `basicEPS` `grossProfit` `rdExp`
**资产负债表**：`totalAssets` `totalParentEq` `monetaryAssets` `inventory` `shortTermLoans` `longTermLoans`
**现金流量表**：`netOpCashFlows` `netInvCashFlows` `netFinCashFlows`
**估值**：`peTtm` `pbMrq`
**K线**：`close` `pctChange` `volume` `amount`

---

## 对 LLM 的行为要求

- ✅ **并行**：无依赖的数据源同时调用
- ✅ **缓存**：先检查 `.cache/`，再调 API
- ✅ **精简**：`--field` 只选需要的字段
- ✅ **批量**：能用一次 `knowledge-batch` 查到的，不要分多次
- ❌ **禁止**：串行等待所有数据拉完再开始分析
- ❌ **禁止**：重复拉取当日已缓存的数据
