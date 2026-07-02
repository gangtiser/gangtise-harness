# Preamble · 强制开始前流程

> 所有 sk-* skill 在产生任何分析输出**之前**，按本文件完成流程。
> **v0.5 改动**：并行取数 + 缓存优先 + 简化 Preflight。

---

## Step 0 · 任务断点检查

1. **读 `.task-pulse`**
   - 无 in_progress 任务 → 继续
   - 有匹配任务 → 询问是否继续
   - 用户说"继续 t-XXX" → 读 checkpoint 续跑

2. **创建 task 条目**（一次写入）
   ```
   .task-pulse: {id, skill, target, step:"0/N", ckpt:".checkpoint/{id}.md"}
   .checkpoint/{id}.md: 创建空文件
   ```

3. **Context budget 检查**（口径对齐 CLAUDE.md §1.6 / checkpoint.md，按"剩余"预算判断，不按绝对已用量——以适配不同 context 窗口的模型）
   - 剩余 < 30k tokens → 警告"建议本任务完后开新会话"，可继续
   - 剩余 < 10k → 强制写 checkpoint，停止

**时间**：< 10 秒

---

## Step 1 · 识别市场 + 检查历史输出（合并）

**市场识别**（1 秒）：
- 按代码格式判断：6位数字→CN-A，字母→US，4-5位数字→HK（取数时不足 5 位前补 0，如 700→00700.HK）
- 6 位且带"基金/ETF/LOF"字样（或 0/1/5 开头的基金代码）→ CN-FUND
- 输出：`市场：{CN-A | CN-FUND | HK | US | GLOBAL}`

**历史输出检查**（并行）：
- 读 `coverage/{ticker}/INDEX.md`（如有）
- 读最近一份同 skill 输出（如有）
- 输出：`历史状态：首次研究` 或 `更新（上次 YYYY-MM-DD）`

---

## Step 2 · 简化 Preflight

**一句话格式**：
```
[Preflight] 标的：X | 市场：Y | 历史：Z | 数据源：gangtise openapi + knowledge-batch [+ tavily]
```

**不做的事**：
- ❌ 不写完整的"数据源优先级链"段落
- ❌ 不写"预期缺失项"（这些留在末尾"仍需补的资料"段）

---

## Step 3 · 并行取数（核心优化）

**先检查缓存**：`{workspace}/.cache/{ticker}_{type}_{date}.{json|md}`（结构化数据存 `.json`，知识库/AI 文本类存 `.md`）
- 存在 → 直接读取，跳过 API 调用
- 不存在 → 走下面并行批次

**Batch 1 — 财务核心（并行，必须）**：
```bash
gangtise fundamental income-statement --security-code {code} ...
gangtise fundamental balance-sheet --security-code {code} ...
gangtise fundamental cash-flow --security-code {code} ...
```

**Batch 2 — 估值与市场（并行，必须）**：
```bash
gangtise fundamental earning-forecast --security-code {code} ...
gangtise fundamental valuation-analysis --security-code {code} ...
gangtise quote day-kline --security {code} --start-date {start_date} --end-date {end_date} ...
```
港股用 `day-kline-hk`，美股用 `day-kline-us`。最近 N 条 K 线必须先拉日期窗口，再按 `tradeDate` 取尾部；盘中当前价用 `gangtise quote realtime`。

**Batch 3 — 业务与股东（在 Batch 1-2 返回后并行）**：
```bash
gangtise fundamental main-business --security-code {code} ...
gangtise fundamental top-holders --security-code {code} ...
```

**Batch 4 — 知识库搜索（与前序并行）**：
```bash
gangtise ai knowledge-batch --query "{target}" --top 15 ...
```

**Batch 5 — 外部搜索（知识库不足时）**：
```bash
# Tavily API 或 WebSearch
```

**数据写入缓存**：所有 API 返回数据同时写入 `.cache/`

**证据等级标注**：每条数据拿到后**立即**标等级（公开事实/财报披露/市场共识/合理推演/待核验假设）

**时间目标**：从 Preflight 到拿到全部数据 → **< 3 分钟**

---

## 完成 Preamble 之后

进入对应 skill 的具体分析流程。输出结尾按 [postamble.md](postamble.md) 走。

---

## 例外

- 用户说"不需要取数，我直接贴材料" → Preflight 写"用户提供材料"
- 用户说"快速看一下" → 只走 Batch 1-2，跳过 Batch 3-5
