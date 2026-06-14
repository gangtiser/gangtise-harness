# Investor Harness · 多 Agent 研究流水线（编排指南）

> 本目录下的 5 个 `.md` 是 Claude Code subagent 定义（带 frontmatter，会被自动注册为 agent 类型）。
> 本 README 不是 agent，只是它们的"怎么协同"说明书。

---

## 为什么要分角色

单 agent 容易混淆三件事：

1. **取数** vs **分析** vs **决策**
2. **多头视角** vs **空头视角**
3. **研究员视角** vs **基金经理视角**

混在一起的结果：LLM 一会儿当数据员一会儿当 PM，证据等级松散，反方审视流于形式。把这些**显式拆成不同的 agent**、每个只负责一种职责、最后由协调员（主对话）汇总，结果显著更可靠。

---

## 5 个角色（流水线顺序）

| 顺序 | 角色 | 文件 | 职责 | 调用的主 skill / 工具 |
|---|---|---|---|---|
| 1 | **data-fetcher** | [data-fetcher.md](data-fetcher.md) | 取数员，只按 `core/adapters.md` 用 Gangtise OpenAPI(+Tavily) 拿数据、标证据等级，不分析 | `gangtise` CLI / Tavily |
| 2 | **thesis-builder** | [thesis-builder.md](thesis-builder.md) | 把数据收敛成可证伪命题 | sk-thesis / sk-company-deepdive / sk-industry-map |
| 3 | **red-teamer** | [red-teamer.md](red-teamer.md) | 强制空头审视，挑战必要条件 | sk-red-team（先读 biases.md） |
| 4 | **pm-voice** | [pm-voice.md](pm-voice.md) | 基金经理视角，压成可决策一页纸 | sk-pm-brief / sk-consensus-watch |
| 5 | **compliance-checker** | [compliance-checker.md](compliance-checker.md) | 合规终审，输出前最后一道关卡 | core/compliance.md 全量 |

---

## 协作流程

```
用户 → 主对话（协调员）
         │
         ├── 1. data-fetcher（取数 → Data Fetch Report）
         │        ↓ 输出喂给下一棒
         ├── 2. thesis-builder（建命题 → 必要条件 + 证伪阈值）
         │        ↓
         ├── 3. red-teamer（反方 → 攻击必要条件 + 查 biases.md）
         │        ↓
         ├── 4. pm-voice（压成一页纸 → Action/入场/卖出）
         │        ↓
         └── 5. compliance-checker（红线过审 → APPROVED/REJECTED）
                  ↓
            协调员汇总 + 双输出（对话贴全文 + 归档 coverage/{ticker}/）
```

**关键纪律**：5 棒**串行**（每棒依赖上一棒输出），不能并行。协调员负责把上一棒的产出原样喂给下一棒，并在最后按 `core/output-archive.md` 归档。

---

## 在本工作区怎么触发

直接对主对话说，例如：

- "**按研究流水线深度看 X**" / "跑一遍 5-agent 流水线看 X"
- 主对话（协调员）会用 Agent 工具依次派发 data-fetcher → thesis-builder → red-teamer → pm-voice → compliance-checker，每棒拿到上一棒的输出。

**适用场景**：有对抗性、需要独立反方 + 合规过审的**深度研究**（起 coverage、重大决策前、命题复核）。
**不适用**：日常轻量查询（直接用单个 sk-* skill 更省 token——一条流水线约烧 30-40 万 subagent token）。

> 实测：本流水线已端到端跑通——real Gangtise 取数 → red-teamer 读缓存交叉验证、抓出命题硬伤 → pm-voice 压一页纸 → 合规过审。产出按 `core/output-archive.md` 归档到 `coverage/{ticker}/`。

---

## 单 agent 降级模式

若不想起整条流水线，可让单个 agent（或主对话）在一次回答里**显式经过 5 个阶段**，每阶段一个 section：

```markdown
## 1. Data Fetched     [实际取到的数据 + 数据源]
## 2. Thesis           [基于数据的可证伪命题]
## 3. Red Team         [反方观点 + 最大风险 + biases 检查]
## 4. PM View          [决策结论 + 入场/卖出条件]
## 5. Compliance       [红线检查结论]
```

保留"职责分离"的结构纪律，省去多 agent 的 token 开销，但失去独立反方的对抗价值。
