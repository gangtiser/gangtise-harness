# Repository Guidelines

## Project Structure & Module Organization

This repository is a research workspace, not an application codebase. Root Markdown files hold operating context: `CLAUDE.md` defines agent behavior, while `coverage.md`, `watchlist.md`, `decision-log.md`, `biases.md`, `active-tasks.md`, `people-watch.md`, `memory.md`, and `research-queue.md` track workflow state.

Research output lives under `coverage/<ticker>_<name>/`, grouped by workstream such as `deepdive/`, `red-team/`, `pm-brief/`, `earnings/`, `decks/`, or the newer `sk-*` workstream names. Theme research lives under `themes/<theme>/`, and briefing output from `sk-briefing` is archived under `briefings/`. Presentation projects, when needed, live under `projects/<ticker>_<topic>_<format>_<date>/` with `sources/`, `templates/`, `images/`, `notes/`, `svg_output/`, `svg_final/`, and `exports/`.

Reusable workflows live in `.claude/skills/investor-harness/skills/`, with shared mandatory process files in `.claude/skills/investor-harness/core/`, subagent prompts in `.claude/agents/`, and the machine-readable suite registry in `.claude/skills/investor-harness/manifest.yaml`. User overrides and examples live in `user-templates/` and `user-skills/`. Treat `.cache/`, `.checkpoint/`, `.task-pulse`, and `.claude/skills/investor-harness.bak-*` as generated session or backup state.

## Build, Test, and Development Commands

There is no package manifest, build system, or automated test runner. Use inspection commands before and after edits:

- `rg --files -g '*.md'` lists Markdown documents.
- `find coverage themes briefings -maxdepth 3 -type f | sort` reviews current research artifacts.
- `find .claude/skills/investor-harness -maxdepth 2 -type f | sort` reviews harness skill and core files.
- `git diff -- <path>` reviews local changes when inside a Git checkout.

For deck projects, keep source Markdown in `sources/` and generated `.pptx` in `coverage/<ticker>/decks/`. `projects/` (gitignored) is only scratch space for active deck generation; once a deck is final, file its source project under `coverage/<ticker>/decks/_project/` so all material for a ticker stays in one place.

## Coding Style & Naming Conventions

Prefer concise Markdown with clear headings, short paragraphs, and tables only when they improve scanability. Name dated research files as `YYYY-MM-DD-topic.md` or `YYYY-MM-DD-sk-name.md`, for example `2026-04-28-deepdive.md` or `2026-06-10-sk-red-team.md`. Keep coverage folders in the `ticker_中文名` pattern, such as `300502_新易盛`.

For investment claims, separate facts, expectations, inferences, and conclusions. Use the full Chinese evidence labels from `CLAUDE.md` where relevant: `公开事实`, `财报披露`, `市场共识`, `合理推演`, and `待核验假设`. Do not use letter-code abbreviations for evidence grades. Do not invent figures, channel checks, order data, ratings, or target prices.

## Testing Guidelines

Validation is manual. Before submitting changes, skim edited Markdown, confirm links and referenced files exist, and ensure generated PDFs/PPTX files have matching source material. For workflow state changes, update the relevant tracker: `coverage.md`, `watchlist.md`, `active-tasks.md`, `.task-pulse`, `people-watch.md`, or `decision-log.md`.

## Commit & Pull Request Guidelines

Use `git status --short` before editing and before wrapping up. Commit messages should use a simple imperative style with a scope, for example `docs: update 300502 deepdive notes` or `assets: add AI capex red-team deck`. Pull requests should describe the artifact changed, list source files or data used, call out generated outputs, and note assumptions requiring human review.

## Security & Configuration Tips

Do not commit API keys, private notes, raw non-public information, or real research output excluded by `.gitignore` (`coverage/`, `themes/`, `briefings/`, `projects/`, and live tracker Markdown files). Follow the data protocol and compliance limits in `CLAUDE.md`: no promised returns, no unsupported numerical claims, and no blending of facts with inference.
