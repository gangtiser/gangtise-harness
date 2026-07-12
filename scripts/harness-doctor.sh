#!/usr/bin/env bash
# harness doctor · gangtise-harness 静态自检
# 用法：bash scripts/harness-doctor.sh
# 退出码：0 = 通过（允许 ⚠️ 警告）；1 = 有 ❌ 失败
# 检查面：注册对齐(含重复注册) / 版本戳+对齐日期一致 / 证据标签 / 覆盖池状态 / 运行态文件(双向) / 私密数据隔离(含 .gitignore 策略) / 归档命名 / 产物 frontmatter / 内部链接
# 设计约束：bash 3.2（macOS 自带）可跑；除 git / python3（仅 JSON 校验，缺失则跳过）外无依赖

set -u
cd "$(dirname "$0")/.." || exit 1

HARNESS=".claude/skills/investor-harness"
PASS=0; WARN=0; FAIL=0

ok()   { PASS=$((PASS+1)); printf '✅ %s\n' "$1"; }
warn() { WARN=$((WARN+1)); printf '⚠️  %s\n' "$1"; }
fail() { FAIL=$((FAIL+1)); printf '❌ %s\n' "$1"; }

# YYYY-MM-DD 真实日历校验（纯 shell，含闰年，不依赖 date 的跨平台差异）；退出码 0 = 合法
valid_ymd() {
  echo "$1" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' || return 1
  local y m d dim
  y=$((10#${1%%-*})); m=$((10#$(echo "$1" | cut -d- -f2))); d=$((10#$(echo "$1" | cut -d- -f3)))
  [ "$m" -ge 1 ] && [ "$m" -le 12 ] && [ "$d" -ge 1 ] || return 1
  dim=31
  case $m in
    4|6|9|11) dim=30 ;;
    2) if [ $((y%4)) -eq 0 ] && { [ $((y%100)) -ne 0 ] || [ $((y%400)) -eq 0 ]; }; then dim=29; else dim=28; fi ;;
  esac
  [ "$d" -le "$dim" ]
}

printf 'harness doctor · %s\n' "$(pwd)"
printf '%s\n' '—————————————————————————————————————'

# ---------- 1. skill 注册对齐（manifest ↔ skills/ 目录，双向） ----------
man_skills=$(grep -oE 'id: sk-[a-z0-9-]+' "$HARNESS/manifest.yaml" | sed 's/id: //' | sort -u)
man_dup=$(grep -oE 'id: sk-[a-z0-9-]+' "$HARNESS/manifest.yaml" | sed 's/id: //' | sort | uniq -d)
dir_skills=$(ls -d "$HARNESS/skills/"sk-*/ 2>/dev/null | sed 's|.*/\(sk-[^/]*\)/|\1|' | sort -u)
miss_dir=$(comm -23 <(echo "$man_skills") <(echo "$dir_skills"))
miss_man=$(comm -13 <(echo "$man_skills") <(echo "$dir_skills"))
n_man=$(echo "$man_skills" | grep -c .); n_dir=$(echo "$dir_skills" | grep -c .)
if [ -z "$miss_dir" ] && [ -z "$miss_man" ] && [ -z "$man_dup" ]; then
  ok "skill 注册对齐（manifest ${n_man} ↔ 目录 ${n_dir}，无重复注册）"
else
  [ -n "$miss_dir" ] && fail "manifest 注册但目录缺失：$(echo $miss_dir)"
  [ -n "$miss_man" ] && fail "目录存在但 manifest 未注册：$(echo $miss_man)"
  [ -n "$man_dup" ] && fail "manifest 重复注册同一 skill id：$(echo $man_dup)"
fi

# ---------- 2. SKILL.md frontmatter（name 与目录一致 + description 存在） ----------
fm_bad=""
for d in "$HARNESS/skills/"sk-*/; do
  s="${d}SKILL.md"; sk=$(basename "$d")
  if [ ! -f "$s" ]; then fm_bad="$fm_bad $sk(无SKILL.md)"; continue; fi
  head -20 "$s" | grep -q "^name: *$sk *$" || fm_bad="$fm_bad $sk(name不符)"
  head -20 "$s" | grep -q "^description:" || fm_bad="$fm_bad $sk(缺description)"
done
if [ -z "$fm_bad" ]; then ok "SKILL.md frontmatter 完整（name/description）"; else fail "SKILL frontmatter 问题：$fm_bad"; fi

# ---------- 3. 流水线 agent 注册对齐（manifest pipeline ↔ .claude/agents/*.md） ----------
man_agents=$(grep -oE 'pipeline: \[[^]]+\]' "$HARNESS/manifest.yaml" | sed 's/pipeline: \[//;s/\]//;s/, /\n/g' | sort -u)
dir_agents=$(ls .claude/agents/*.md 2>/dev/null | sed 's|.*/||;s|\.md$||' | grep -iv '^README$' | sort -u)
if [ "$man_agents" = "$dir_agents" ]; then
  ok "流水线 agent 注册对齐（$(echo "$man_agents" | grep -c .) 个）"
else
  fail "agent 注册不一致：manifest=[$(echo $man_agents)] 目录=[$(echo $dir_agents)]"
fi

# ---------- 4. 版本戳一致（VERSION / manifest / adapters / README） ----------
v_version=$(head -1 "$HARNESS/VERSION" | tr -d ' ')
v_manifest=$(grep -m1 '^version:' "$HARNESS/manifest.yaml" | awk '{print $2}')
up_version=$(grep -oE '上游末次同步：[0-9]{4}-[0-9]{2}-[0-9]{2}' "$HARNESS/VERSION" | grep -oE '[0-9-]+$')
up_manifest=$(grep -m1 '^upstream_synced:' "$HARNESS/manifest.yaml" | awk '{print $2}')
cli_adapters=$(grep -m1 -oE '本文件基于 \*\*v[0-9.]+\*\*' "$HARNESS/core/adapters.md" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
cli_manifest=$(grep -m1 '^cli_aligned:' "$HARNESS/manifest.yaml" | awk '{print $2}')
cli_readme=$(grep -m1 -oE '基于 v[0-9.]+ 验证' README.md | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
cli_versionf=$(grep -oE '文档对齐：v[0-9.]+' "$HARNESS/VERSION" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
d_manifest=$(grep -m1 '^cli_aligned_date:' "$HARNESS/manifest.yaml" | awk '{print $2}')
d_versionf=$(grep -oE '文档对齐：v[0-9.]+ / [0-9]{4}-[0-9]{2}-[0-9]{2}' "$HARNESS/VERSION" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}')
d_readme=$(grep -m1 -oE '基于 v[0-9.]+ 验证，[0-9]{4}-[0-9]{2}-[0-9]{2}' README.md | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}')
if [ "$v_version" = "$v_manifest" ] && [ "$up_version" = "$up_manifest" ] \
   && [ -n "$cli_adapters" ] && [ "$cli_adapters" = "$cli_manifest" ] \
   && [ "$cli_adapters" = "$cli_readme" ] && [ "$cli_adapters" = "$cli_versionf" ] \
   && [ -n "$d_manifest" ] && [ "$d_manifest" = "$d_versionf" ] && [ "$d_manifest" = "$d_readme" ]; then
  ok "版本戳一致（harness $v_version · 上游同步 $up_version · CLI 对齐 v$cli_adapters × 4 处 · 对齐日期 $d_manifest × 3 处）"
else
  fail "版本戳漂移：harness[VERSION=$v_version manifest=$v_manifest] 上游[VERSION=$up_version manifest=$up_manifest] CLI[adapters=$cli_adapters manifest=$cli_manifest README=$cli_readme VERSION=$cli_versionf] 对齐日期[manifest=$d_manifest VERSION=$d_versionf README=$d_readme]"
fi

# ---------- 5. 本机 CLI 版本 vs 文档基线（仅提醒） ----------
if command -v gangtise >/dev/null 2>&1; then
  cli_local=$(gangtise --version 2>/dev/null | head -1 | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+')
  if [ "$cli_local" = "$cli_adapters" ]; then
    ok "本机 gangtise CLI $cli_local 与文档基线一致"
  else
    warn "本机 gangtise CLI $cli_local ≠ 文档基线 v$cli_adapters —— 需要跑一次版本对齐（改 adapters/README/manifest/VERSION）"
  fi
else
  warn "本机未安装 gangtise CLI（npm install -g gangtise-openapi-cli）"
fi

# ---------- 6. 字母证据缩写残留（框架文件；旧标签 F1/F2/M1/C1/H1 已于 v0.9.2 弃用） ----------
letters=$(grep -rEn '证据(等级)?[：: ]*[FMCH][12]\b|[FMCH][12]x[0-9]+' \
  "$HARNESS/core" "$HARNESS/skills" "$HARNESS/setup" .claude/agents README.md CLAUDE.md 2>/dev/null \
  | grep -v '弃用\|旧版\|不使用\|对应现行\|deprecated' || true)
if [ -z "$letters" ]; then ok "无字母证据缩写残留（框架文件）"; else fail "字母证据缩写残留：$(echo "$letters" | head -3)"; fi

# ---------- 7. 覆盖池互斥（coverage.md 当前覆盖 ∩ watchlist.md） ----------
cov_codes=""
[ -f coverage.md ] && cov_codes=$(sed -n '/^## 当前覆盖/,/^## /p' coverage.md | grep -oE '\| *[0-9]{6} *\|' | grep -oE '[0-9]{6}' | sort -u)
if [ -f coverage.md ] && [ -f watchlist.md ]; then
  # 只扫「当前观察」区——「已转 coverage」「已退场」是历史档案，与覆盖池重叠属正常
  wl_section=$(sed -n '/^## 当前观察/,/^## /p' watchlist.md)
  wl_codes=$(echo "$wl_section" | grep -oE '[0-9]{6}' | sort -u)
  overlap=$(comm -12 <(echo "$cov_codes") <(echo "$wl_codes") | grep . || true)
  if [ -z "$overlap" ]; then
    ok "覆盖池与观察池无重叠"
  else
    for c in $overlap; do
      # 待确认标注也只认「当前观察」区内该行——历史区的标注不能替当前行背书
      if echo "$wl_section" | grep "$c" | grep -q '⚠️\|待.*确认\|待定'; then
        warn "标的 $c 同时在 coverage.md 与 watchlist.md（已标注待确认——到验证节点后记得二选一）"
      else
        fail "标的 $c 同时在 coverage.md 与 watchlist.md 当前观察区且无待确认标注"
      fi
    done
  fi
else
  warn "coverage.md 或 watchlist.md 不存在，跳过互斥检查"
fi

# ---------- 8. coverage/ 目录归属（每个目录应在当前覆盖表，或 INDEX 声明未纳入） ----------
if [ -f coverage.md ]; then
  orphan=""
  for d in coverage/*/; do
    [ -d "$d" ] || continue
    t=$(basename "$d" | cut -d_ -f1)
    if ! echo "$cov_codes" | grep -q "^$t$"; then
      if grep -q '未纳入' "${d}INDEX.md" 2>/dev/null; then :; else orphan="$orphan $(basename "$d")"; fi
    fi
  done
  if [ -z "$orphan" ]; then ok "coverage/ 目录归属清晰（在覆盖表或 INDEX 声明未纳入）"; else fail "coverage/ 目录不在当前覆盖表且 INDEX 无「未纳入」声明：$orphan"; fi
else
  warn "coverage.md 不存在，跳过 coverage/ 目录归属检查"
fi

# ---------- 9. .task-pulse 合法 JSON ----------
if [ -f .task-pulse ]; then
  if command -v python3 >/dev/null 2>&1; then
    if python3 -m json.tool .task-pulse >/dev/null 2>&1; then ok ".task-pulse 是合法 JSON"; else fail ".task-pulse 不是合法 JSON"; fi
  else
    warn "无 python3，跳过 .task-pulse JSON 校验"
  fi
else
  warn ".task-pulse 不存在"
fi

# ---------- 10. checkpoint ↔ .task-pulse 双向（孤儿 checkpoint / pulse 指向缺失文件） ----------
cp_orphan=""
for f in .checkpoint/*.md; do
  [ -f "$f" ] || continue
  id=$(basename "$f" .md)
  grep -q "$id" .task-pulse 2>/dev/null || cp_orphan="$cp_orphan $id"
done
pulse_missing=""
if [ -f .task-pulse ]; then
  for p in $(grep -oE '\.checkpoint/[A-Za-z0-9._-]+\.md' .task-pulse 2>/dev/null | sort -u); do
    [ -f "$p" ] || pulse_missing="$pulse_missing $p"
  done
fi
if [ -z "$cp_orphan" ] && [ -z "$pulse_missing" ]; then
  ok "checkpoint ↔ .task-pulse 双向一致"
else
  [ -n "$cp_orphan" ] && warn "checkpoint 孤儿（.task-pulse 中无此任务，done 后应删）：$cp_orphan"
  [ -n "$pulse_missing" ] && warn ".task-pulse 引用的 checkpoint 文件不存在（续跑会失败，按 checkpoint.md 边界场景处理）：$pulse_missing"
fi

# ---------- 11. 状态文件结构占位符（coverage/watchlist 必须具体化） ----------
ph=$(grep -n '\[请填\|N 家公司\|\[覆盖池公司\|\[相关公司\]' coverage.md watchlist.md memory.md 2>/dev/null || true)
if [ -z "$ph" ]; then ok "状态文件无模板占位符残留"; else warn "模板占位符残留（该填的还没填）：$(echo "$ph" | head -3)"; fi

# ---------- 12. 私密数据不入库（git 索引 + .gitignore 策略双检） ----------
tracked=$(git ls-files -- coverage themes briefings projects archive .cache .checkpoint \
  coverage.md decision-log.md biases.md watchlist.md research-queue.md active-tasks.md \
  memory.md people-watch.md selection-pipeline.md knowledge-index.md .task-pulse AGENTS.md 2>/dev/null || true)
unignored=""
for p in coverage/.probe themes/.probe briefings/.probe projects/.probe archive/.probe .cache/.probe .checkpoint/.probe \
  coverage.md decision-log.md biases.md watchlist.md research-queue.md active-tasks.md \
  memory.md people-watch.md selection-pipeline.md knowledge-index.md .task-pulse AGENTS.md; do
  git check-ignore -q "$p" 2>/dev/null || unignored="$unignored ${p%/.probe}"
done
if [ -z "$tracked" ] && [ -z "$unignored" ]; then
  ok "私密数据全部隔离在 git 之外（.gitignore 策略完整）"
else
  [ -n "$tracked" ] && fail "私密文件被 git 追踪（立即 git rm --cached）：$(echo "$tracked" | head -5)"
  [ -n "$unignored" ] && fail ".gitignore 缺少私密路径保护（下次 git add 会泄漏）：$unignored"
fi

# ---------- 13. 归档命名（coverage 一级子目录下 .md 须 YYYY-MM-DD- 前缀；data/notes/decks 除外） ----------
badname=$(find coverage -mindepth 3 -maxdepth 3 -name '*.md' 2>/dev/null \
  | grep -v '/data/\|/notes/\|/decks/' \
  | grep -vE '/[0-9]{4}-[0-9]{2}-[0-9]{2}-[^/]+\.md$' || true)
if [ -z "$badname" ]; then ok "归档命名符合 {YYYY-MM-DD}-{short}.md 规范"; else warn "归档命名不合规范：$(echo "$badname" | head -5)"; fi

# ---------- 14. 产物 frontmatter（2026-07-12 起新增产物必填 5 项 + 值合法；含周报/月报/健康检查等非日期前缀产物，见 output-archive.md） ----------
FM_SINCE="2026-07-12"; FM_SINCE_YM="2026-07"; FM_SINCE_WEEK="2026-W28"   # 2026-07-12 属 ISO 2026-W28
fm_miss=""
while IFS= read -r f; do
  [ -n "$f" ] || continue
  b=$(basename "$f")
  # 日期门槛：完整 YYYY-MM-DD（个股前缀 / health-check- 后缀）→ 按日；ISO 周 YYYY-Www（周报）→ 按周（周数两位补零，字典序 == 时间序）；仅 YYYY-MM（月报）→ 按年月。三者早于契约起点均视为历史，不回填
  fd=$(echo "$b" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1)
  if [ -n "$fd" ]; then
    [ "$fd" \< "$FM_SINCE" ] && continue
  else
    fw=$(echo "$b" | grep -oE '[0-9]{4}-W[0-9]{2}' | head -1)
    if [ -n "$fw" ]; then
      [ "$fw" \< "$FM_SINCE_WEEK" ] && continue
    else
      fym=$(echo "$b" | grep -oE '[0-9]{4}-[0-9]{2}' | head -1)
      { [ -n "$fym" ] && [ "$fym" \< "$FM_SINCE_YM" ]; } && continue
    fi
  fi
  # 起始围栏
  if ! head -1 "$f" | grep -q '^---$'; then fm_miss="$fm_miss $f(无frontmatter)"; continue; fi
  # 闭合围栏：2-30 行内须有第二个 ---（否则正文被当 frontmatter）。用 sed 不用 awk——awk 的 exit 会触发 END 覆盖退出码
  if [ "$(sed -n '2,30{/^---$/p;}' "$f" | head -1)" != "---" ]; then fm_miss="$fm_miss $f(frontmatter未闭合)"; continue; fi
  block=$(sed -n '2,30{/^---$/q;p;}' "$f")
  # 必填 5 项：键存在、不重复、值非空且非 YAML 占位（""/''/null/~）；再按键做枚举/日历校验
  #（${k} 带花括号——中文紧跟变量名会被 UTF-8 locale 吞进变量名）
  for k in target_type target_id as_of skill status; do
    line=$(echo "$block" | grep "^$k:" | head -1)
    if [ -z "$line" ]; then fm_miss="$fm_miss $f(缺${k})"; continue; fi
    [ "$(echo "$block" | grep -c "^$k:")" -le 1 ] || fm_miss="$fm_miss $f(${k}重复)"
    val=$(echo "$line" | sed "s/^$k:[[:space:]]*//;s/[[:space:]]*#.*\$//;s/[[:space:]]*\$//")
    case "$val" in ''|'""'|"''"|null|Null|NULL|'~') fm_miss="$fm_miss $f(${k}空/占位)"; continue ;; esac
    case "$k" in
      target_type) case "$val" in ticker|theme|market|portfolio|workspace) : ;; *) fm_miss="$fm_miss $f(target_type非法:$val)" ;; esac ;;
      status)      case "$val" in final|draft|stale) : ;; *) fm_miss="$fm_miss $f(status非法:$val)" ;; esac ;;
      as_of)       valid_ymd "$val" || fm_miss="$fm_miss $f(as_of非法日期:$val)" ;;
    esac
  done
done < <( { find coverage themes briefings \( \
      -name '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-*.md' -o \
      -name '[0-9][0-9][0-9][0-9]-W[0-9][0-9]*.md' -o \
      -name '[0-9][0-9][0-9][0-9]-[0-9][0-9]-*.md' -o \
      -name 'health-check-*.md' \) 2>/dev/null
    # 健康检查 canonical 归档在 briefings/，但根目录若有 health-check-*.md 也纳入，防逃逸
    find . -maxdepth 1 -name 'health-check-*.md' 2>/dev/null; } \
    | grep -v '/data/\|/notes/\|/decks/' | sort -u || true)
if [ -z "$fm_miss" ]; then ok "产物 frontmatter 完整（$FM_SINCE 起新增产物必填 5 项 + 值合法，含周报/月报/健康检查）"; else fail "产物 frontmatter 缺失/不完整：$(echo $fm_miss | tr ' ' '\n' | head -5)"; fi

# ---------- 15. core/skills 内部相对链接存在性（警告级，历史上有误报） ----------
deadlink=""
for f in "$HARNESS/core/"*.md "$HARNESS/skills/"*/SKILL.md .claude/agents/*.md; do
  [ -f "$f" ] || continue
  base=$(dirname "$f")
  links=$(grep -oE '\]\([^)#]+\.md\)' "$f" 2>/dev/null | sed 's/](//;s/)$//' | grep -v '^http\|{\|\*' | sort -u)
  for l in $links; do
    case "$l" in /*) tgt="$l" ;; *) tgt="$base/$l" ;; esac
    [ -e "$tgt" ] || deadlink="$deadlink ${f}→${l}"
  done
done
if [ -z "$deadlink" ]; then ok "core/skills/agents 内部 .md 链接全部可达"; else warn "疑似失效链接（人工核对，可能是模板路径）：$(echo $deadlink | tr ' ' '\n' | head -5)"; fi

printf '%s\n' '—————————————————————————————————————'
printf '结果：%d 通过 / %d 警告 / %d 失败\n' "$PASS" "$WARN" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
