# Gangtise Harness · 投研工作 harness

面向买方研究员 / 基金经理的 AI 投研任务执行规范。强制 LLM 在做投研时**不出现幻觉、不丢失上下文、不输出杂乱**。

基线源自 [investor-harness](https://github.com/joansongjr/investor-harness)（MIT），本仓库为 **Gangtise 定制版**：

- **命名**：统一 `sk-*`
- **数据源**：统一走 **Gangtise OpenAPI**（外部搜索保留 Tavily），见 `core/adapters.md`
- **证据分级**：完整中文标签（公开事实 / 财报披露 / 市场共识 / 合理推演 / 待核验假设），旧版 `F1/F2/M1/C1/H1` 已废弃

## 构成

| 模块 | 位置 | 说明 |
|---|---|---|
| 28 个 skill | `.claude/skills/investor-harness/skills/` | 公司深度 / 财报前瞻 / 反方 / 选股 / 复盘 / 数据库 / wiki 等 |
| 强制流程 core | `.claude/skills/investor-harness/core/` | preamble / postamble / adapters / evidence / compliance / acceptance 等 |
| 5 个研究流水线 subagent | `.claude/agents/` | data-fetcher → thesis-builder → red-teamer → pm-voice → compliance-checker |
| 套件清单 | `.claude/skills/investor-harness/manifest.yaml` | 机器可读的 skill / core / agent 注册表 |
| 用户定制层 | `user-templates/` `user-skills/` | L1 模板 / L2 继承 / L3 自创 示例 |

## 快速开始

1. 把本仓库放进你的工作区（或作为 `.claude/` 子集）
2. 从 `.claude/skills/investor-harness/setup/workspace/*.template` 生成你自己的 `coverage.md` / `watchlist.md` / `decision-log.md` / `biases.md` / `people-watch.md` 等 live 文件
3. 新会话先读 `CLAUDE.md`（身份 + 规则）和 `core/_boot.md`（启动协议）
4. 说"看一下 X"走 `sk-autopilot`，或"按研究流水线深度看 X"启动 5-agent 流水线

## 数据隐私

本仓库**只含框架**。真实研究产出（`coverage/` `themes/` `briefings/`）、个人决策记忆（`decision-log.md` `biases.md` `watchlist.md` 等）、运行缓存均通过 `.gitignore` 排除，**不入库**。
