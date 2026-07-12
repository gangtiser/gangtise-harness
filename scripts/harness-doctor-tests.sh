#!/usr/bin/env bash
# harness doctor · 固定反例回归测试
# 用法：bash scripts/harness-doctor-tests.sh（改过 harness-doctor.sh 后必跑）
# 机制：把整个工作区复制到临时目录，逐例注入一种异常，断言 doctor 报 fail/warn 而不是漏报
# 依赖私密 live 文件的用例（coverage.md / watchlist.md）在文件缺失时 SKIP，不判失败
set -u
SRC="$(cd "$(dirname "$0")/.." && pwd)"
BASE="$(mktemp -d "${TMPDIR:-/tmp}/harness-doctor-tests.XXXXXX")" || { printf 'mktemp -d 失败，中止\n' >&2; exit 1; }
[ -n "$BASE" ] && [ -d "$BASE" ] || { printf '临时目录无效，中止\n' >&2; exit 1; }
trap 'rm -rf "${BASE:?}"' EXIT
PASS=0; FAIL=0; SKIP=0

mk()  { rm -rf "${BASE:?}/$1"; cp -R "$SRC" "${BASE:?}/$1"; }
run() { bash "$BASE/$1/scripts/harness-doctor.sh" > "$BASE/$1.out" 2>&1; echo $?; }
skip() { SKIP=$((SKIP+1)); printf 'SKIP  %s（%s）\n' "$1" "$2"; }
# 跨平台就地编辑：BSD(macOS) 的 sed -i 需空串参数、GNU 不接受，改用临时文件 + mv 规避
inplace() { local f="$1"; shift; sed "$@" "$f" > "$f.__doctest" && mv "$f.__doctest" "$f"; }

assert() { # name / want_exit / got_exit / must_grep / out
  if [ "$3" = "$2" ] && grep -q "$4" "$5"; then
    PASS=$((PASS+1)); printf 'PASS  %s\n' "$1"
  else
    FAIL=$((FAIL+1)); printf 'FAIL  %s（exit=%s 期望=%s，模式「%s」%s）\n' "$1" "$3" "$2" "$4" "$(grep -q "$4" "$5" && echo 命中 || echo 未命中)"
  fi
}
assert_absent() { # name / out / must_not_grep
  if grep -q "$3" "$2"; then
    FAIL=$((FAIL+1)); printf 'FAIL  %s（不应出现「%s」但出现了）\n' "$1" "$3"
  else
    PASS=$((PASS+1)); printf 'PASS  %s\n' "$1"
  fi
}

# T1 README 的 CLI 对齐日期漂移 → 应 FAIL
mk t1
inplace "$BASE/t1/README.md" -e 's/验证，[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}/验证，2099-01-01/'
e=$(run t1); assert "T1 README 对齐日期漂移被拦截" 1 "$e" "版本戳漂移" "$BASE/t1.out"

# T2 watchlist「已转 coverage」历史区出现当前覆盖代码 → 不应误报
if [ -f "$SRC/coverage.md" ] && [ -f "$SRC/watchlist.md" ] && grep -q '^## 已转 coverage' "$SRC/watchlist.md"; then
  code=$(sed -n '/^## 当前覆盖/,/^## /p' "$SRC/coverage.md" | grep -oE '\| *[0-9]{6} *\|' | grep -oE '[0-9]{6}' | head -1)
  if [ -n "$code" ]; then
    mk t2
    awk -v c="$code" '{print} /^## 已转 coverage/{s=1} s&&/^\|---\|/{print "| 测试标的 (" c ") | 2026-04-01 | 2026-05-01 | 反例注入 |"; s=0}' \
      "$BASE/t2/watchlist.md" > "$BASE/t2/watchlist.md.new" && mv "$BASE/t2/watchlist.md.new" "$BASE/t2/watchlist.md"
    e=$(run t2)
    assert "T2 已转 coverage 历史区不误报（exit 仍 0）" 0 "$e" "覆盖池与观察池\|同时在 coverage.md" "$BASE/t2.out"
    assert_absent "T2 历史区代码 $code 未被误判" "$BASE/t2.out" "标的 $code"
  else
    skip "T2" "coverage.md 当前覆盖表无 6 位代码"
  fi
else
  skip "T2" "缺 coverage.md / watchlist.md / 已转 coverage 区"
fi

# T2b 当前观察区未标待确认、但历史区同代码已标 → 历史标注不能替当前行背书，应 FAIL
if [ -f "$SRC/coverage.md" ]; then
  code=$(sed -n '/^## 当前覆盖/,/^## /p' "$SRC/coverage.md" | grep -oE '\| *[0-9]{6} *\|' | grep -oE '[0-9]{6}' | head -1)
  if [ -n "$code" ]; then
    mk t2b
    cat > "$BASE/t2b/watchlist.md" <<EOF
# 观察池

## 当前观察

| # | 标的 | 类型 | 进观察池日期 | 关注原因 | 转 coverage 触发条件 |
|---|---|---|---|---|---|
| 1 | 测试标的 ($code) | 测试 | 2026-04-01 | 当前行无任何标注（反例注入） | 到验证节点二选一 |

## 已转 coverage（archive）

| 标的 | 进观察日期 | 转 coverage 日期 | 触发事件 |
|---|---|---|---|
| 测试标的 ($code) | 2026-04-01 | 2026-05-01 | ⚠️ 待确认（历史行，不应替当前行背书） |
EOF
    e=$(run t2b)
    assert "T2b 历史区标注不替当前行背书（应 FAIL）" 1 "$e" "当前观察区且无待确认标注" "$BASE/t2b.out"
  else
    skip "T2b" "coverage.md 当前覆盖表无 6 位代码"
  fi
else
  skip "T2b" "缺 coverage.md"
fi

# T3 删除 watchlist.md → 无 unbound、coverage 归属检查不受污染
if [ -f "$SRC/watchlist.md" ] && [ -f "$SRC/coverage.md" ]; then
  mk t3
  rm "$BASE/t3/watchlist.md"
  e=$(run t3)
  assert "T3 缺 watchlist 时跳过互斥检查" 0 "$e" "跳过互斥检查" "$BASE/t3.out"
  assert_absent "T3 无 unbound variable" "$BASE/t3.out" "unbound"
  assert "T3 coverage 归属检查仍正常" 0 "$e" "coverage/ 目录归属清晰" "$BASE/t3.out"
else
  skip "T3" "缺 watchlist.md / coverage.md"
fi

# T4 manifest 重复注册同一 skill id → 应 FAIL
mk t4
printf '\n# 反例注入\nx_dup_test:\n  - id: sk-thesis\n' >> "$BASE/t4/.claude/skills/investor-harness/manifest.yaml"
e=$(run t4); assert "T4 manifest 重复注册被拦截" 1 "$e" "重复注册同一 skill id" "$BASE/t4.out"

# T5 .task-pulse 指向不存在的 checkpoint → 应 WARN（不拦截但要报）
mk t5
cat > "$BASE/t5/.task-pulse" <<'EOF'
{
  "v": "0.4",
  "ts": "2026-07-12T00:00:00Z",
  "tasks": [{"id": "t-099", "skill": "sk-company-deepdive", "target": "测试", "status": "in_progress", "step": "6/9", "ckpt": ".checkpoint/t-099.md"}],
  "compacted": false,
  "warn": null
}
EOF
e=$(run t5); assert "T5 pulse 指向缺失 checkpoint 出警告" 0 "$e" "引用的 checkpoint 文件不存在" "$BASE/t5.out"

# T6a 当日新增产物无 frontmatter → 应 FAIL（用 themes/ 免受 coverage 归属检查干扰）
mk t6a
mkdir -p "$BASE/t6a/themes/doctor-fm-test"
printf '# 测试产物\n正文\n' > "$BASE/t6a/themes/doctor-fm-test/2026-07-12-test.md"
e=$(run t6a); assert "T6a 新产物缺 frontmatter 被拦截" 1 "$e" "产物 frontmatter 缺失" "$BASE/t6a.out"

# T6b 当日新增产物带完整 5 项 frontmatter → 应通过
mk t6b
mkdir -p "$BASE/t6b/themes/doctor-fm-test"
cat > "$BASE/t6b/themes/doctor-fm-test/2026-07-12-test.md" <<'EOF'
---
target_type: theme
target_id: doctor-fm-test
as_of: 2026-07-12
skill: sk-thesis
status: draft
---
# 测试产物
EOF
e=$(run t6b); assert "T6b 合规 frontmatter 通过" 0 "$e" "产物 frontmatter 完整" "$BASE/t6b.out"

# T6c 当日产物 frontmatter 键齐全但值全空 → 应 FAIL（防「假通过」）
mk t6c
mkdir -p "$BASE/t6c/themes/doctor-fm-test"
cat > "$BASE/t6c/themes/doctor-fm-test/2026-07-12-test.md" <<'EOF'
---
target_type:
target_id:
as_of:
skill:
status:
---
# 测试产物
EOF
e=$(run t6c); assert "T6c frontmatter 空值被拦截" 1 "$e" "空/占位" "$BASE/t6c.out"

# T6d 当日产物 frontmatter 无闭合围栏（正文被吞进 frontmatter）→ 应 FAIL
mk t6d
mkdir -p "$BASE/t6d/themes/doctor-fm-test"
cat > "$BASE/t6d/themes/doctor-fm-test/2026-07-12-test.md" <<'EOF'
---
target_type: theme
target_id: doctor-fm-test
as_of: 2026-07-12
skill: sk-thesis
status: draft
# 忘了写第二个 --- 围栏
正文开始
EOF
e=$(run t6d); assert "T6d frontmatter 未闭合被拦截" 1 "$e" "未闭合" "$BASE/t6d.out"

# T6e 当日产物 target_type 非枚举值 → 应 FAIL
mk t6e
mkdir -p "$BASE/t6e/themes/doctor-fm-test"
cat > "$BASE/t6e/themes/doctor-fm-test/2026-07-12-test.md" <<'EOF'
---
target_type: stock
target_id: doctor-fm-test
as_of: 2026-07-12
skill: sk-thesis
status: draft
---
# 测试产物
EOF
e=$(run t6e); assert "T6e frontmatter 非法枚举被拦截" 1 "$e" "target_type非法" "$BASE/t6e.out"

# T9a 周报（YYYY-Www 前缀，非 YYYY-MM-DD）缺 frontmatter → 应 FAIL（扩展扫描覆盖）
mk t9a
mkdir -p "$BASE/t9a/briefings/weekly"
printf '# 周度覆盖池复盘\n正文无 frontmatter\n' > "$BASE/t9a/briefings/weekly/2026-W29-coverage-review.md"
e=$(run t9a); assert "T9a 周报缺 frontmatter 被拦截" 1 "$e" "无frontmatter" "$BASE/t9a.out"

# T9b 月报（YYYY-MM 前缀，非 YYYY-MM-DD）缺 frontmatter → 应 FAIL
mk t9b
mkdir -p "$BASE/t9b/briefings/monthly"
printf '# 月度 PM 汇报\n正文\n' > "$BASE/t9b/briefings/monthly/2026-07-pm-report.md"
e=$(run t9b); assert "T9b 月报缺 frontmatter 被拦截" 1 "$e" "无frontmatter" "$BASE/t9b.out"

# T9c 健康检查（health-check- 前缀，日期在后缀）缺 frontmatter → 应 FAIL
mk t9c
printf '# 健康检查\n正文\n' > "$BASE/t9c/briefings/health-check-2026-07-12.md"
e=$(run t9c); assert "T9c 健康检查缺 frontmatter 被拦截" 1 "$e" "无frontmatter" "$BASE/t9c.out"

# T9d 周报带合规 frontmatter → 应通过（证明扩展扫描不误伤合规非日期前缀产物）
mk t9d
mkdir -p "$BASE/t9d/briefings/weekly"
cat > "$BASE/t9d/briefings/weekly/2026-W29-coverage-review.md" <<'EOF'
---
target_type: portfolio
target_id: coverage-pool
as_of: 2026-07-24
skill: sk-batch-refresh
status: final
---
# 周度覆盖池复盘
EOF
e=$(run t9d); assert "T9d 周报合规 frontmatter 通过" 0 "$e" "产物 frontmatter 完整" "$BASE/t9d.out"

# T9e 历史周报（2026-W14 早于契约周 2026-W28）无 frontmatter → 应跳过（历史不回填）
mk t9e
mkdir -p "$BASE/t9e/briefings/weekly"
printf '# 历史周报\n无 frontmatter\n' > "$BASE/t9e/briefings/weekly/2026-W14-coverage-review.md"
e=$(run t9e); assert "T9e 历史周报(W14<W28)无 frontmatter 应跳过" 0 "$e" "产物 frontmatter 完整" "$BASE/t9e.out"

# T9f 根目录 health-check（canonical 应在 briefings/，但根目录逃逸也要抓）缺 frontmatter → 应 FAIL
mk t9f
printf '# 根目录健康检查\n无 frontmatter\n' > "$BASE/t9f/health-check-2026-07-12.md"
e=$(run t9f); assert "T9f 根目录 health-check 缺 frontmatter 被抓" 1 "$e" "无frontmatter" "$BASE/t9f.out"

# T9g 边界周（2026-W28 == 契约起始周，非 <）无 frontmatter → 应 FAIL（等值边界须纳入校验，不被跳过）
mk t9g
mkdir -p "$BASE/t9g/briefings/weekly"
printf '# 契约起始周周报\n无 frontmatter\n' > "$BASE/t9g/briefings/weekly/2026-W28-coverage-review.md"
e=$(run t9g); assert "T9g 边界周(W28==门槛)须校验非跳过" 1 "$e" "无frontmatter" "$BASE/t9g.out"

# T10a as_of 格式对但非真实日历（2026-99-99）→ 应 FAIL
mk t10a
mkdir -p "$BASE/t10a/themes/doctor-fm-test"
cat > "$BASE/t10a/themes/doctor-fm-test/2026-07-12-test.md" <<'EOF'
---
target_type: theme
target_id: doctor-fm-test
as_of: 2026-99-99
skill: sk-thesis
status: draft
---
# 测试产物
EOF
e=$(run t10a); assert "T10a as_of 非法日历被拦截" 1 "$e" "as_of非法日期" "$BASE/t10a.out"

# T10b target_id 为 YAML 空标量 ""（shell 看是非空字符串）→ 应 FAIL
mk t10b
mkdir -p "$BASE/t10b/themes/doctor-fm-test"
cat > "$BASE/t10b/themes/doctor-fm-test/2026-07-12-test.md" <<'EOF'
---
target_type: theme
target_id: ""
as_of: 2026-07-12
skill: sk-thesis
status: draft
---
# 测试产物
EOF
e=$(run t10b); assert "T10b target_id 引号空串被拦截" 1 "$e" "target_id空/占位" "$BASE/t10b.out"

# T10c skill 为 YAML null → 应 FAIL
mk t10c
mkdir -p "$BASE/t10c/themes/doctor-fm-test"
cat > "$BASE/t10c/themes/doctor-fm-test/2026-07-12-test.md" <<'EOF'
---
target_type: theme
target_id: doctor-fm-test
as_of: 2026-07-12
skill: null
status: draft
---
# 测试产物
EOF
e=$(run t10c); assert "T10c skill null 被拦截" 1 "$e" "skill空/占位" "$BASE/t10c.out"

# T10d 必填键重复（status 两次）→ 应 FAIL
mk t10d
mkdir -p "$BASE/t10d/themes/doctor-fm-test"
cat > "$BASE/t10d/themes/doctor-fm-test/2026-07-12-test.md" <<'EOF'
---
target_type: theme
target_id: doctor-fm-test
as_of: 2026-07-12
skill: sk-thesis
status: draft
status: final
---
# 测试产物
EOF
e=$(run t10d); assert "T10d 必填键重复被拦截" 1 "$e" "status重复" "$BASE/t10d.out"

# T7 .gitignore 删掉 coverage/ 保护 → 应 FAIL
mk t7
inplace "$BASE/t7/.gitignore" -e '/^coverage\/$/d'
e=$(run t7); assert "T7 .gitignore 保护缺失被拦截" 1 "$e" "缺少私密路径保护" "$BASE/t7.out"

# T8 删除 coverage.md → 无 unbound，归属检查降级为提示
if [ -f "$SRC/coverage.md" ]; then
  mk t8
  rm "$BASE/t8/coverage.md"
  e=$(run t8)
  assert "T8 缺 coverage.md 跳过归属检查" 0 "$e" "跳过 coverage/ 目录归属检查" "$BASE/t8.out"
  assert_absent "T8 无 unbound variable" "$BASE/t8.out" "unbound"
else
  skip "T8" "缺 coverage.md"
fi

printf -- '—————————————————————————————————————\n'
printf '结果：%d PASS / %d FAIL / %d SKIP\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ]
