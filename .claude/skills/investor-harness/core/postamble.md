# Postamble · 强制结束后流程

> 所有 sk-* skill 在产生分析输出**之后**，按本文件完成。
> **v0.5 改动**：合并步骤、去掉 acceptance 强制检查、inline 证据标注。

---

## Step 1 · 归档 + 更新任务状态（合并）

**一句话执行**：
1. 写文件到归档路径（按 [output-archive.md](output-archive.md) 目录结构 + 命名 + 产物 frontmatter）：`{coverage_root}/{ticker}_{name}/{目录名}/{YYYY-MM-DD}-{skill-short}.md`（目录名如 `deepdive/` `red-team/` `pm-brief/`，文件短名如 `deepdive`/`redteam`/`pmbrief`，二者不一定相同，均见 output-archive.md）；文件头部带 frontmatter（target_type / target_id / as_of / skill / status 必填），刷新替代旧文且旧文已有 frontmatter 时把旧文 `status` 改 `stale`（2026-07-12 前的历史文件不回填、不改动）
2. 更新 `.task-pulse`：状态 done，删除 checkpoint
3. 更新 `{coverage_root}/{ticker}_{name}/INDEX.md`：last_updated、latest_outputs

**不做的事**：
- ❌ 不写 `active-tasks.md`（.task-pulse 已足够）
- ❌ 不跑 acceptance.md 清单（改为抽查）

---

## Step 2 · Dual Output（保留）

**必须同时**：
1. **对话贴完整输出**（含证据等级、仍需补的资料、合规声明）
2. **文件写完整副本**（先写文件，再贴对话）

**标准结尾**：
```markdown
📁 **已归档**：{path}
📊 证据：公开事实×{N} 财报披露×{N} 市场共识×{N} 合理推演×{N} 待核验假设×{N}
🆔 Task ID：{id} · 状态：done

⚠️ 本输出不构成投资建议。
🔄 建议下一步：{skill-1} | {skill-2}
```

---

## Step 3 · 简化合规声明

**一句话模板**：
```markdown
**合规声明**：本分析基于公开信息，不构成投资建议。涉及评级/目标价需人工复核。
```

---

## 原 Step 0-1-6 的处置

| 原步骤 | 新处置 | 原因 |
|---|---|---|
| Step 0 增量 checkpoint | **去掉** | 每次输出都写 checkpoint 太频繁，改为只在 context < 10k 时写 |
| Step 1 证据自检 | **改为 inline** | 输出时每条事实直接标等级，不再事后检查 |
| Step 2 仍需补的资料 | **保留** | 但只列真正缺失的，不写"建议"和"不确定"子分类 |
| Step 3 合规声明 | **简化** | 一句话模板 |
| Step 4 归档 | **保留，与 task 更新合并** | 见 Step 1 |
| Step 5 更新 active-tasks | **去掉** | .task-pulse 已承载任务状态 |
| Step 6 验收清单 | **去掉** | 改为抽查，默认不跑 |
