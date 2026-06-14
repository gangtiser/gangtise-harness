# Repository Guidelines

## Project Structure & Module Organization

This repository is a research workspace, not an application codebase. Root Markdown files hold operating context: `CLAUDE.md` defines agent behavior, while `coverage.md`, `watchlist.md`, `decision-log.md`, `biases.md`, `active-tasks.md`, and `research-queue.md` track workflow state.

Research output lives under `coverage/<ticker>_<name>/`, grouped by workstream such as `deepdive/`, `red-team/`, `pm-brief/`, `earnings/`, or `decks/`. Presentation projects live under `projects/<ticker>_<topic>_<format>_<date>/` with `sources/`, `templates/`, `images/`, `notes/`, `svg_output/`, `svg_final/`, and `exports/`. Reusable prompts and workflows are in `user-templates/`, `user-skills/`, and `.claude/skills/`. Treat `.cache/` and `.checkpoint/` as generated session state.

## Build, Test, and Development Commands

There is no package manifest, build system, or automated test runner. Use inspection commands before and after edits:

- `rg --files -g '*.md'` lists Markdown documents.
- `find coverage projects themes -maxdepth 3 -type f | sort` reviews research artifacts.
- `git diff -- <path>` reviews local changes when inside a Git checkout.

For deck projects, keep source Markdown in `sources/` and generated files in `exports/` or `coverage/*/decks/`.

## Coding Style & Naming Conventions

Prefer concise Markdown with clear headings, short paragraphs, and tables only when they improve scanability. Name dated research files as `YYYY-MM-DD-topic.md`, for example `2026-04-28-deepdive.md`. Keep coverage folders in the `ticker_中文名` pattern, such as `300502_新易盛`.

For investment claims, separate facts, expectations, inferences, and conclusions. Use the full Chinese evidence labels from `CLAUDE.md` where relevant: `公开事实`, `财报披露`, `市场共识`, `合理推演`, and `待核验假设` (the old `F1/F2/M1/C1/H1` letter codes are deprecated as of v0.9.2). Do not invent figures, channel checks, order data, ratings, or target prices.

## Testing Guidelines

Validation is manual. Before submitting changes, skim edited Markdown, confirm links and referenced files exist, and ensure generated PDFs/PPTX files have matching source material. For workflow state changes, update the relevant tracker: `coverage.md`, `watchlist.md`, `active-tasks.md`, or `decision-log.md`.

## Commit & Pull Request Guidelines

Git history is not available in this checkout, so use a simple imperative style with a scope, for example `docs: update 300502 deepdive notes` or `assets: add AI capex red-team deck`. Pull requests should describe the artifact changed, list source files or data used, call out generated outputs, and note assumptions requiring human review.

## Security & Configuration Tips

Do not commit API keys, private notes, or raw non-public information. Follow the data protocol and compliance limits in `CLAUDE.md`: no promised returns, no unsupported numerical claims, and no blending of facts with inference.
