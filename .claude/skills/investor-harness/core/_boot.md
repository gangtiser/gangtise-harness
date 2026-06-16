# Investor Harness · Boot

> 🚀 每次新会话第一个读的文件。**< 1k tokens**。其他 core/* 按需懒加载。

## What this is

Investor Harness v0.9.2（Gangtise 定制版）— 投研人的 AI 任务执行规范。
治三大痛点：**幻觉 / 健忘 / 不成体系**。数据源统一走 Gangtise OpenAPI（外部搜索保留 Tavily）。

## 28 skills (one-line each)

`sk-master`(7 模式总控) · `sk-autopilot`(自动路由) · `sk-thesis`(命题构建) · `sk-industry-map`(行业框架) · `sk-company-deepdive`(公司深度) · `sk-earnings-preview`(财报前瞻) · `sk-model-check`(模型审阅) · `sk-consensus-watch`(预期差) · `sk-catalyst-monitor`(事件跟踪) · `sk-roadshow-questions`(路演问题) · `sk-red-team`(反方审视) · `sk-pm-brief`(PM 一页纸) · `sk-briefing`(晨会晚报) · `sk-tape-review`(盘面 + 技术面复盘) · `sk-deck-builder`(PPT 生成 · UI 设计 + 研报包装) · `sk-batch-refresh`(批量刷新) · `sk-batch-earnings`(财报季批量) · `sk-catalyst-sweep`(催化剂扫描)

新增（v0.9.2）：`sk-stock-screen`(条件选股) · `sk-industry-database`(行业数据库) · `sk-close-recap`(收盘复盘) · `sk-hourly-watch`(盘中监控) · `sk-daily-feed`(日度信息流) · `sk-people-watch`(人物/社区跟踪) · `sk-question-list`(问题清单) · `sk-qa-archive`(Q&A 归档) · `sk-wiki-build`(研究 wiki 构建) · `sk-health-check`(覆盖池健康检查)

## Boot protocol (新会话/compact 后)

1. 读 `.task-pulse`（如存在）
2. 读 `CLAUDE.md`
3. 如 .task-pulse 有 in_progress 任务 → 主动告知用户 + 等选择，不要默认从头开始
4. 用户选了某 skill 才加载 SKILL.md
5. SKILL 内按需加载 core/preamble.md 等

## 三层加载（节省 token）

- **Tier 0** (always): _boot.md + .task-pulse + CLAUDE.md ≈ 4-5k
- **Tier 1** (on skill invoke): SKILL.md + preamble + postamble + adapters ≈ 6k
- **Tier 2** (on demand): evidence / compliance / output-archive / acceptance ≈ 5k

⛔ 不要在不需要时加载 Tier 2。

## Resume protocol (断点续跑)

```
1. 读 .task-pulse → 找 in_progress 任务 id
2. 读 .checkpoint/{task-id}.md → 知道做到哪段
3. 加载对应 SKILL.md
4. 从断点继续，不重复
5. 完成后写最终输出到归档路径，更新 .task-pulse 标 done
```

## Output discipline (v0.5.1 双输出)

- 输出**必须**同时**贴到对话**和**写入文件**（按 output-archive.md）
- 对话里贴完整内容（人类读），文件里存完整内容（归档 + 跨 skill 引用）
- 结尾追加 `📁 已归档：{path}` 提示 + 关键统计 + 下一步建议
- **不要**只回摘要——很多人在云端跑，打不开本地文件
- 例外：用户明确说"省 token 模式"才退回到摘要

## User customization (v0.7 新增)

**开始常规路由前**必须检查用户工作区是否有自定义：
- `{workspace}/user-templates/*.md` — 用户任务模板（日报 / 周报 / 月报等）
- `{workspace}/user-skills/*/SKILL.md` — 用户自定义 skill（L2 继承 / L3 自创）

命中 → 用用户定制，不用默认 sk-* 路由。
详见 core/user-templates.md + core/user-skills.md。

## Where to find more

| 需要时读 | 文件 |
|---|---|
| 完整开始前流程 | core/preamble.md |
| 完整结束后流程 | core/postamble.md |
| 数据源决策树 | core/adapters.md |
| 证据分级（完整中文标签） | core/evidence.md |
| 合规边界 | core/compliance.md |
| 归档命名规范 | core/output-archive.md |
| 验收抽查（默认不强制，仅 Librarian/重大交付） | core/acceptance.md |
| 入口菜单 | core/menu.md |
| 市场识别 | core/markets.md |
| 任务持久化格式 | core/task-pulse.md |
| 断点续跑细节 | core/checkpoint.md |
| 用户任务模板 (L1) | core/user-templates.md |
| 用户自定义 skill (L2+L3) | core/user-skills.md |
