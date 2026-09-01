#!/usr/bin/env bash
# test_ticket.sh — ticket.sh のテスト（仕様のテスト ID: TICKET-T01〜11）
# 使い方: bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --filter '*test_ticket*'
set -uo pipefail

# 共通ライブラリの読み込み行（20-common-step-shell-script 仕様「読み込み行」が正）。引数 <lib> <policy> だけを変え、中身を改変しない。
# shellcheck disable=SC1090,SC2317
__ss_load() { local lib="$1" pol="$2" d="${BASH_SOURCE[1]%/*}" r="" f=""; [ "$d" = "${BASH_SOURCE[1]}" ] && d="."; case "$d" in /*|[A-Za-z]:/*) ;; *) d="$PWD/$d" ;; esac; while [ -n "$d" ] && [ ! -d "$d/.claude" ]; do case "$d" in */*) d="${d%/*}" ;; *) d="" ;; esac; done; r="$d"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; if [ ! -f "$f" ] && [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then r="${CLAUDE_PROJECT_DIR//\\//}"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ ! -f "$f" ] && command -v git >/dev/null 2>&1; then r="$(git rev-parse --show-toplevel 2>/dev/null || true)"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ -n "$r" ] && [ -f "$f" ]; then LOGGER_ROOT="$r"; export LOGGER_ROOT; . "$f"; return 0; fi; case "$pol" in nop) LOGGER_ROOT="${r:-$PWD}"; export LOGGER_ROOT; log_debug() { :; }; log_info() { :; }; log_warn() { :; }; log_error() { :; }; fm_extract() { FM_BLOCK=""; return 1; }; fm_get() { return 1; }; fm_list() { return 1; }; fm_has() { return 1; } ;; deny) printf '%s\n' "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"${HOOK_DENY_ID:-WF009}: 機構の不調 — 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）\"}}"; exit 0 ;; *) printf '%s\n' "FATAL: 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）"; exit 2 ;; esac; }
__ss_load test-lib fatal

REAL="$LOGGER_ROOT/.claude"
make_tmp_repo
cd "$TMP_REPO" || exit 2
mkdir -p .claude/skills/20-common-step-shell-script/scripts .claude/skills/20-common-step-commit-push/scripts .claude/skills/20-common-step-commit-push/assets \
         .claude/skills/20-common-step-ticket/scripts .claude/skills/20-common-step-ticket/assets .claude/hooks/config
cp "$REAL"/skills/20-common-step-shell-script/scripts/*.sh .claude/skills/20-common-step-shell-script/scripts/
cp "$REAL"/skills/20-common-step-commit-push/scripts/*.sh .claude/skills/20-common-step-commit-push/scripts/
cp "$REAL"/skills/20-common-step-commit-push/assets/exclude-patterns.txt .claude/skills/20-common-step-commit-push/assets/
cp "$REAL"/skills/20-common-step-ticket/scripts/ticket.sh .claude/skills/20-common-step-ticket/scripts/
cp "$REAL"/skills/20-common-step-ticket/assets/ticket.template.md .claude/skills/20-common-step-ticket/assets/
cp "$REAL"/hooks/config/task-types.tsv .claude/hooks/config/
T=".claude/skills/20-common-step-ticket/scripts/ticket.sh"
echo "# t" > README.md; printf "logs/
" > .gitignore
git add -A && git commit -q -m "chore: init"
count_commits() { git rev-list --count HEAD; }
subject() { git log -1 --pretty=%s; }
# DoD を全部チェックして根拠を埋め、現在地を消込み、AI アセット欄を書く（完了検査を通す形にする）
fulfill() { # $1=file
  sed -i 's/^- \[ \] \(.*\)（根拠: ）$/- [x] \1（根拠: テストで確認）/; s/^- 未着手$/- 済: すべて完了/' "$1"
  sed -i 's/^### AI アセットに反映すべき内容$/### AI アセットに反映すべき内容\n\n- 無し（テスト用チケット）/' "$1"
}

# TICKET-T01 create → start → complete の遷移とファイルの移動・時刻/基準点の記録
run_cmd bash "$T" create investigation --title "調査 A" --purpose "確かめる" --dod "問い 1 に答える" --dod "根拠を添える" --work "読む" --allow-ops "read,remote-read"
assert_exit "TICKET-T01" 0
assert_contains "TICKET-T01" "OK: wip/10_tickets/00_todo/0001-investigation.md を作成した"
assert_eq "TICKET-T01" "chore: チケット 0001 を作成" "$(subject)"
if [ -f wip/10_tickets/00_todo/0001-investigation.md ] && ! grep -q '{{' wip/10_tickets/00_todo/0001-investigation.md; then pass "TICKET-T01"; else fail "TICKET-T01" "作成ファイルが無いかプレースホルダが残る"; fi
assert_eq "TICKET-T01" $'read\nremote-read' "$(bash -c 'source .claude/skills/20-common-step-shell-script/scripts/frontmatter.sh; fm_list wip/10_tickets/00_todo/0001-investigation.md allow.ops')"
run_cmd bash "$T" start 0001
assert_exit "TICKET-T01" 0
assert_contains "TICKET-T01" "OK: 0001-investigation.md を作業中にした（開始 "
assert_eq "TICKET-T01" "chore: チケット 0001 に着手" "$(subject)"
if [ -f wip/10_tickets/10_doing/0001-investigation.md ] && [ ! -e wip/10_tickets/00_todo/0001-investigation.md ]; then pass "TICKET-T01"; else fail "TICKET-T01" "doing へ移動していない"; fi
sha="$(git rev-parse --short HEAD~1)"
if grep -q "^base_sha: \"$sha\"" wip/10_tickets/10_doing/0001-investigation.md && grep -qE '^started_at: "[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}[+-][0-9]{2}:[0-9]{2}"' wip/10_tickets/10_doing/0001-investigation.md; then pass "TICKET-T01"; else fail "TICKET-T01" "base_sha / started_at が記録されていない: $(grep -E '^(base_sha|started_at)' wip/10_tickets/10_doing/0001-investigation.md)"; fi
fulfill wip/10_tickets/10_doing/0001-investigation.md
run_cmd bash "$T" complete 0001
assert_exit "TICKET-T01" 0
assert_contains "TICKET-T01" "OK: 0001-investigation.md を完了にした"
if [ -f wip/10_tickets/20_done/0001-investigation.md ] && grep -qE '^completed_at: "[0-9]{4}-' wip/10_tickets/20_done/0001-investigation.md; then pass "TICKET-T01"; else fail "TICKET-T01" "done へ移動・完了時刻が無い"; fi
assert_eq "TICKET-T01" "" "$(git status --porcelain)"

# TICKET-T02 作業中があるときの start が TK002
run_cmd bash "$T" create design-plan --title "設計計画" --purpose "p" --dod "d"
run_cmd bash "$T" create design --title "設計" --purpose "p" --dod "d" --predecessors "0002"
run_cmd bash "$T" start 0002
assert_exit "TICKET-T02" 0
run_cmd bash "$T" start 0003
assert_exit "TICKET-T02" 1
assert_contains "TICKET-T02" "TK002:"
assert_contains "TICKET-T02" "0002-design-plan.md"

# TICKET-T03 DoD 未チェック・根拠欄が空・作業ログ欠け・未コミットありの complete が TK003 で全件列挙
f=wip/10_tickets/10_doing/0002-design-plan.md
sed -i 's/^- \[ \] d（根拠: ）$/- [ ] d（根拠: ）\n- [x] e（根拠: ）\n- [x] g/' "$f"
sed -i '/^### 判断と根拠$/d' "$f"
echo x > stray.txt
run_cmd bash "$T" complete 0002
assert_exit "TICKET-T03" 1
assert_contains "TICKET-T03" "TK003:"
assert_contains "TICKET-T03" "未チェックの項目がある"
assert_contains "TICKET-T03" "根拠欄が空"
assert_contains "TICKET-T03" "見出し「判断と根拠」が無い"
assert_contains "TICKET-T03" "「現在地」に未完了の項目"
assert_contains "TICKET-T03" "「AI アセットに反映すべき内容」が空"
assert_contains "TICKET-T03" "未コミットの変更がある"
assert_contains "TICKET-T03" "根拠欄「（根拠: ）」そのものが無い"
assert_contains "TICKET-T03" "未充足 7 件"
if [ -f "$f" ]; then pass "TICKET-T03"; else fail "TICKET-T03" "拒否されたのに移動した"; fi
rm -f stray.txt
sed -i 's/^- \[ \] d（根拠: ）$/- [x] d（根拠: ok）/; s/^- \[x\] e（根拠: ）$/- [x] e（根拠: ok）/; s/^### 拒否・確認・迂回の記録$/### 判断と根拠\n\n### 拒否・確認・迂回の記録/' "$f"
sed -i 's/^- \[x\] g$/- [x] g（根拠: ok）/' "$f"
fulfill "$f"
run_cmd bash "$T" complete 0002
assert_exit "TICKET-T03" 0

# TICKET-T04 全体まとめの complete が TK005
run_cmd bash "$T" create overall-summary --title "まとめ" --purpose "p" --dod "d"
run_cmd bash "$T" start 0004
assert_exit "TICKET-T04" 0
fulfill wip/10_tickets/10_doing/0004-overall-summary.md
run_cmd bash "$T" complete 0004
assert_exit "TICKET-T04" 1
assert_contains "TICKET-T04" "TK005:"
run_cmd bash "$T" cancel 0004 --reason "テスト"
assert_exit "TICKET-T04" 0

# TICKET-T05 連番が取り消し済みを含めて重複しない（0004 は取り消し済み → 次は 0005）
run_cmd bash "$T" create investigation --title "調査 B" --purpose "p" --dod "d"
assert_contains "TICKET-T05" "0005-investigation.md を作成した"
run_cmd bash "$T" cancel 0005 --reason "不要 & 重複 | \"引用\" \\ 記号"
assert_exit "TICKET-T05" 0
if [ -f wip/10_tickets/30_cancelled/0005-investigation.md ] && grep -qF 'cancel_reason: "不要 & 重複 | \"引用\" \\ 記号"' wip/10_tickets/30_cancelled/0005-investigation.md; then pass "TICKET-T05"; else fail "TICKET-T05" "取り消しの記載が無い"; fi
run_cmd bash "$T" cancel 0005 --reason ""
assert_exit "TICKET-T05" 1
assert_contains "TICKET-T05" "TK007:"
run_cmd bash "$T" create investigation --title "調査 C" --purpose "p" --dod "d"
assert_contains "TICKET-T05" "0006-investigation.md を作成した"

# TICKET-T06 next の JSON（current / next / type / skill）と空のときの null
run_cmd bash "$T" next
assert_exit "TICKET-T06" 0
assert_eq "TICKET-T06" '{"current":null,"next":"0003","type":"design","skill":"10-task-design-exec"}' "$R_OUT"
run_cmd bash "$T" start 0003
run_cmd bash "$T" next
assert_eq "TICKET-T06" '{"current":"0003","next":null,"type":"design","skill":"10-task-design-exec"}' "$R_OUT"
fulfill wip/10_tickets/10_doing/0003-design.md
run_cmd bash "$T" complete 0003
run_cmd bash "$T" start 0006
fulfill wip/10_tickets/10_doing/0006-investigation.md
run_cmd bash "$T" complete 0006
run_cmd bash "$T" next
assert_eq "TICKET-T06" '{"current":null,"next":null}' "$R_OUT"

# TICKET-T07 先行チケット未完了の start が TK006
run_cmd bash "$T" create implementation-plan --title "実装計画" --purpose "p" --dod "d"            # 0007
run_cmd bash "$T" create implementation --title "実装" --purpose "p" --dod "d" --predecessors "0007,0099"   # 0008
run_cmd bash "$T" start 0008
assert_exit "TICKET-T07" 1
assert_contains "TICKET-T07" "TK006:"
assert_contains "TICKET-T07" "0007 0099"
if [ -f wip/10_tickets/00_todo/0008-implementation.md ]; then pass "TICKET-T07"; else fail "TICKET-T07" "拒否されたのに移動した"; fi

# TICKET-T08 先行が未完了の小さい連番を飛ばして着手できる最小連番を返す。全部が待ちなら next: null + blocked
run_cmd bash "$T" next
assert_eq "TICKET-T08" '{"current":null,"next":"0007","type":"implementation-plan","skill":"10-task-implementation-plan"}' "$R_OUT"
run_cmd bash "$T" cancel 0007 --reason "並べ替え"
run_cmd bash "$T" next
assert_eq "TICKET-T08" '{"current":null,"next":null,"blocked":["0008"]}' "$R_OUT"
run_cmd bash "$T" cancel 0008 --reason "片付け"

# TICKET-T09 overall-plan の create / start はコミットしない（他の種類はコミットする）
before="$(count_commits)"
run_cmd bash "$T" create overall-plan --title "全体計画" --purpose "p" --dod "d"
assert_exit "TICKET-T09" 0
assert_contains "TICKET-T09" "overall-plan はコミットしない"
assert_eq "TICKET-T09" "$before" "$(count_commits)"
run_cmd bash "$T" start 0009
assert_exit "TICKET-T09" 0
assert_eq "TICKET-T09" "$before" "$(count_commits)"
if [ -f wip/10_tickets/10_doing/0009-overall-plan.md ] && [ -n "$(git status --porcelain)" ]; then pass "TICKET-T09"; else fail "TICKET-T09" "未追跡のまま doing に無い"; fi
git add -A && git commit -q -m "chore: start #1 x"   # feature ブランチの開始コミット相当
fulfill wip/10_tickets/10_doing/0009-overall-plan.md
run_cmd bash "$T" complete 0009
assert_exit "TICKET-T09" 0
assert_eq "TICKET-T09" "chore: チケット 0009 を完了" "$(subject)"
before="$(count_commits)"
run_cmd bash "$T" create investigation --title "調査 D" --purpose "p" --dod "d"
assert_eq "TICKET-T09" "$((before + 1))" "$(count_commits)"

# TICKET-T10 commit.sh が拒否する状況で同じ最終行で失敗し、start / complete / cancel は元の置き場に記載事項も含めて戻り、create は作成ファイルが残らない
# commit.sh を拒否させる: コミット時の検査（pre-commit フック）を失敗させる
printf '#!/bin/sh\necho "pre-commit: blocked" >&2\nexit 1\n' > .git/hooks/pre-commit; chmod +x .git/hooks/pre-commit
before="$(count_commits)"
run_cmd bash "$T" create design --title "拒否" --purpose "p" --dod "d"
assert_exit "TICKET-T10" 1
assert_contains "TICKET-T10" "CP004:"
assert_eq "TICKET-T10" "CP004" "$(printf '%s' "${R_OUT##*$'\n'}" | cut -d: -f1)"
if ls wip/10_tickets/00_todo/0011-*.md >/dev/null 2>&1; then fail "TICKET-T10" "create の拒否でファイルが残った"; else pass "TICKET-T10"; fi
orig="$(cat wip/10_tickets/00_todo/0010-investigation.md)"
run_cmd bash "$T" start 0010
assert_exit "TICKET-T10" 1
assert_eq "TICKET-T10" "CP004" "$(printf '%s' "${R_OUT##*$'\n'}" | cut -d: -f1)"
if [ -f wip/10_tickets/00_todo/0010-investigation.md ] && [ "$(cat wip/10_tickets/00_todo/0010-investigation.md)" = "$orig" ] && [ ! -e wip/10_tickets/10_doing/0010-investigation.md ]; then pass "TICKET-T10"; else fail "TICKET-T10" "start の拒否で元に戻っていない"; fi
run_cmd bash "$T" cancel 0010 --reason "x"
assert_exit "TICKET-T10" 1
if [ -f wip/10_tickets/00_todo/0010-investigation.md ] && [ "$(cat wip/10_tickets/00_todo/0010-investigation.md)" = "$orig" ]; then pass "TICKET-T10"; else fail "TICKET-T10" "cancel の拒否で元に戻っていない"; fi
rm -f .git/hooks/pre-commit
run_cmd bash "$T" start 0010
assert_exit "TICKET-T10" 0
before="$(count_commits)"
fulfill wip/10_tickets/10_doing/0010-investigation.md
orig="$(cat wip/10_tickets/10_doing/0010-investigation.md)"
printf '#!/bin/sh\nexit 1\n' > .git/hooks/pre-commit; chmod +x .git/hooks/pre-commit
run_cmd bash "$T" complete 0010
assert_exit "TICKET-T10" 1
if [ -f wip/10_tickets/10_doing/0010-investigation.md ] && [ "$(cat wip/10_tickets/10_doing/0010-investigation.md)" = "$orig" ] && [ ! -e wip/10_tickets/20_done/0010-investigation.md ]; then pass "TICKET-T10"; else fail "TICKET-T10" "complete の拒否で元に戻っていない"; fi
rm -f .git/hooks/pre-commit
assert_eq "TICKET-T10" "$before" "$(count_commits)"
run_cmd bash "$T" complete 0010
assert_exit "TICKET-T10" 0

# TICKET-T11 ファイル名の種類と ticket_type が食い違うチケットで next / start が frontmatter の値を使う
run_cmd bash "$T" create investigation --title "食い違い" --purpose "p" --dod "d"   # 0011
git mv wip/10_tickets/00_todo/0011-investigation.md wip/10_tickets/00_todo/0011-design.md && git commit -q -m "chore: rename"
run_cmd bash "$T" next
assert_eq "TICKET-T11" '{"current":null,"next":"0011","type":"investigation","skill":"10-task-investigation-exec"}' "$R_OUT"
run_cmd bash "$T" start 0011
assert_exit "TICKET-T11" 0
assert_contains "TICKET-T11" "0011-design.md を作業中にした"
run_cmd bash "$T" next
assert_eq "TICKET-T11" '{"current":"0011","next":null,"type":"investigation","skill":"10-task-investigation-exec"}' "$R_OUT"
# overall-plan の判定も frontmatter（ファイル名 investigation・中身 overall-plan → コミットしない）
run_cmd bash "$T" cancel 0011 --reason "x"
before="$(count_commits)"
cat > wip/10_tickets/00_todo/0012-investigation.md <<'EOF'
---
type: ticket
ticket_type: overall-plan
predecessors: []
executor: main
human_review: {required: true, reason: "r"}
adversarial_review: {required: false, reason: "r"}
allow:
  write: ["wip/**"]
  ops: ["read"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0012 t

## 目的

p

## DoD

- [ ] d（根拠: ）

## 作業ログ

### 現在地

- 未着手
EOF
run_cmd bash "$T" start 0012
assert_exit "TICKET-T11" 0
assert_contains "TICKET-T11" "overall-plan はコミットしない"
assert_eq "TICKET-T11" "$before" "$(count_commits)"

finish
