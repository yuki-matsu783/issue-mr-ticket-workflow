#!/usr/bin/env bash
# test_scope.sh — scope.sh のテスト（仕様のテスト ID: HK-T11。判定順・宣言の絞り込み・ops の分類も同 ID に付ける）
# 使い方: bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --filter '*scope*'
# テストは set -e を使わない（終了コードは run_cmd が取る）
set -uo pipefail

# 共通ライブラリの読み込み行（20-common-step-shell-script 仕様「読み込み行」が正）。引数 <lib> <policy> だけを変え、中身を改変しない。
# shellcheck disable=SC1090,SC2317
__ss_load() { local lib="$1" pol="$2" d="${BASH_SOURCE[1]%/*}" r="" f=""; [ "$d" = "${BASH_SOURCE[1]}" ] && d="."; case "$d" in /*|[A-Za-z]:/*) ;; *) d="$PWD/$d" ;; esac; while [ -n "$d" ] && [ ! -d "$d/.claude" ]; do case "$d" in */*) d="${d%/*}" ;; *) d="" ;; esac; done; r="$d"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; if [ ! -f "$f" ] && [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then r="${CLAUDE_PROJECT_DIR//\\//}"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ ! -f "$f" ] && command -v git >/dev/null 2>&1; then r="$(git rev-parse --show-toplevel 2>/dev/null || true)"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ -n "$r" ] && [ -f "$f" ]; then LOGGER_ROOT="$r"; export LOGGER_ROOT; . "$f"; return 0; fi; case "$pol" in nop) LOGGER_ROOT="${r:-$PWD}"; export LOGGER_ROOT; log_debug() { :; }; log_info() { :; }; log_warn() { :; }; log_error() { :; }; fm_extract() { FM_BLOCK=""; return 1; }; fm_get() { return 1; }; fm_list() { return 1; }; fm_has() { return 1; } ;; deny) printf '%s\n' "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"${HOOK_DENY_ID:-WF009}: 機構の不調 — 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）\"}}"; exit 0 ;; *) printf '%s\n' "FATAL: 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）"; exit 2 ;; esac; }
__ss_load test-lib fatal

# shellcheck disable=SC1091
. "$LOGGER_ROOT/.claude/hooks/lib/cmdpos.sh"
# shellcheck disable=SC1091
. "$LOGGER_ROOT/.claude/hooks/lib/scope.sh"

make_tmp_dir
CFG="$TMP_DIR/scope-limits.json"
cat > "$CFG" <<'JSON'
{
  "common": {
    "allow": ["wip/10_tickets/**", "wip/20_plans/**", "wip/30_reports/**", "wip/tmp/**", "wip/00_overall_plan/**", "wip/push-check-skip.md"],
    "protected": [".claude/**", ".gitignore", ".gitattributes"],
    "confirm": [".claude/hooks/config/**", ".claude/settings.json"],
    "file_granular": ["CLAUDE.md"],
    "state_files": ["logs/mr.json", "logs/review-state.json", "logs/review-history.jsonl", "logs/merge-state.json"]
  },
  "types": {
    "implementation": {"allow": ["src/**", "tests/**"], "deny": [".claude/**", "docs/**"], "confirm": ["package.json"], "ops": ["read", "build-test", "remote-read"], "plan_mode": false},
    "design": {"allow": ["docs/**"], "deny": ["src/**", ".claude/**"], "ops": ["read", "remote-read"]},
    "ai-asset-implementation": {"allow": [".claude/skills/**", ".claude/hooks/**", ".claude/rules/**", ".claude/agents/**", ".claude/settings.json", ".claude/evals/**", "CLAUDE.md", ".gitattributes"], "deny": [".claude/docs/**", "src/**"], "ops": ["read", "build-test", "hook-test", "remote-read"]},
    "overall-plan": {"ops": ["read", "remote-read", "remote-write:issue-create", "remote-write:issue-append", "remote-write:mr-create", "remote-write:push"], "plan_mode": true}
  },
  "commands": {"build-test": ["npm test", "npm run build"]}
}
JSON

mk_ticket() { # $1=path $2=type $3=allow.write(JSON 配列) $4=allow.ops(JSON 配列)
  printf -- '---\ntype: ticket\nticket_type: %s\npredecessors: []\nexecutor: main\nhuman_review: {required: false, reason: "x"}\nadversarial_review: {required: false, reason: "x"}\nallow:\n  write: %s\n  ops: %s\nstarted_at: ""\ncompleted_at: ""\nbase_sha: ""\n---\n\n# t\n' "$2" "$3" "$4" > "$1"
}

# 判定を 1 行にする: <decision> <id> <stage> <askscope>
resolve() { # $1=type $2=ticket(- で無し) $3=approvals(- で無し) $4=path
  scope_load "$CFG" "$1" || { echo "load-error rc=$? $SC_ERROR"; return; }
  if [[ "$2" != "-" ]]; then scope_load_ticket "$2" || { echo "ticket-error"; return; }; else SC_DECL_WRITE=(); SC_DECL_OPS=(); fi
  if [[ "$3" != "-" ]]; then scope_load_approvals "$3"; else SC_APPROVED=(); fi
  scope_resolve "$4"
  printf '%s %s %s %s\n' "$SC_DECISION" "${SC_ID:--}" "$SC_STAGE" "${SC_ASK_SCOPE:--}"
}
match() { if scope_match "$1" "$2"; then echo yes; else echo no; fi; }
classify_all() { # $1=command → 分類を空白区切りで
  local i out=""
  cmdpos_parse "$1"
  for ((i = 0; i < CP_COUNT; i++)); do scope_classify "$i" >/dev/null; out+="${out:+ }$SC_CLASS"; done
  printf '%s\n' "$out"
}

# ---- glob: * は / を跨がず ** は跨ぐ ----
case_glob() {
  assert_eq "HK-T11" "yes" "$(match '.claude/*' '.claude/settings.json')"
  assert_eq "HK-T11" "no"  "$(match '.claude/*' '.claude/hooks/config/x')"
  assert_eq "HK-T11" "yes" "$(match '.claude/**' '.claude/settings.json')"
  assert_eq "HK-T11" "yes" "$(match '.claude/**' '.claude/hooks/config/x')"
  assert_eq "HK-T11" "no"  "$(match '.claude/**' 'src/.claude/x')"
  assert_eq "HK-T11" "yes" "$(match 'src/**' 'src/a/b/c.ts')"
  assert_eq "HK-T11" "yes" "$(match 'src/**' 'src/a.ts')"
  assert_eq "HK-T11" "no"  "$(match 'src/**' 'src')"
  assert_eq "HK-T11" "yes" "$(match '**/x.sh' 'a/b/x.sh')"
  assert_eq "HK-T11" "yes" "$(match '**/x.sh' 'x.sh')"
  assert_eq "HK-T11" "yes" "$(match 'package.json' 'package.json')"
  assert_eq "HK-T11" "no"  "$(match 'package.json' 'a/package.json')"
  assert_eq "HK-T11" "yes" "$(match '*.md' 'a.md')"
  assert_eq "HK-T11" "no"  "$(match '*.md' 'd/a.md')"
  assert_eq "HK-T11" "no"  "$(match 'a.md' 'aXmd')"
  assert_eq "HK-T11" "yes" "$(match '.claude/hooks/**/*.sh' '.claude/hooks/a.sh')"
  assert_eq "HK-T11" "yes" "$(match '.claude/hooks/**/*.sh' '.claude/hooks/lib/tests/t.sh')"
  assert_eq "HK-T11" "yes" "$(match 'wip/10_tickets/**' 'wip/10_tickets/10_doing/0001-x.md')"
  assert_eq "HK-T11" "yes" "$(match 'a?c' 'abc')"
  assert_eq "HK-T11" "no"  "$(match 'a?c' 'a/c')"
}

# ---- 判定順 (1)〜(7) と common.confirm の優先 ----
case_order() {
  # (4) common.confirm はどの type の allow より優先
  assert_eq "HK-T11" "ask WF203 4 -" "$(resolve ai-asset-implementation - - .claude/settings.json)"
  assert_eq "HK-T11" "ask WF203 4 -" "$(resolve ai-asset-implementation - - .claude/hooks/config/scope-limits.json)"
  assert_eq "HK-T11" "ask WF203 4 -" "$(resolve implementation - - package.json)"
  # (2) 共通保護範囲: type の allow に明示されていなければ deny、明示されていれば通る
  assert_eq "HK-T11" "deny WF201 2 -" "$(resolve implementation - - .claude/skills/x/SKILL.md)"
  assert_eq "HK-T11" "allow - 5 -" "$(resolve ai-asset-implementation - - .claude/skills/x/SKILL.md)"
  assert_eq "HK-T11" "deny WF201 2 -" "$(resolve ai-asset-implementation - - .claude/docs/10_spec/x.md)"
  assert_eq "HK-T11" "deny WF201 2 -" "$(resolve implementation - - .gitignore)"
  assert_eq "HK-T11" "allow - 5 -" "$(resolve ai-asset-implementation - - .gitattributes)"
  # (3) type の禁止範囲
  assert_eq "HK-T11" "deny WF201 3 -" "$(resolve design - - src/a.ts)"
  assert_eq "HK-T11" "deny WF201 3 -" "$(resolve implementation - - docs/a.md)"
  # (1) logs/** は対象外。state_files は対象外にならない
  assert_eq "HK-T11" "skip - 1 -" "$(resolve implementation - - logs/sh/x.log)"
  assert_eq "HK-T11" "ask WF202 7 logs" "$(resolve implementation - - logs/mr.json)"
  # (5) common.allow はどの type でも書ける
  assert_eq "HK-T11" "allow - 5 -" "$(resolve design - - wip/20_plans/0001-x.md)"
  assert_eq "HK-T11" "allow - 5 -" "$(resolve overall-plan - - wip/push-check-skip.md)"
  assert_eq "HK-T11" "allow - 5 -" "$(resolve implementation - - src/a/b.ts)"
  # (7) 未記載 → ask WF202。承認単位は親ディレクトリ、file_granular はファイル
  assert_eq "HK-T11" "ask WF202 7 README" "$(resolve implementation - - README/x.md)"
  assert_eq "HK-T11" "ask WF202 7 README.md" "$(resolve implementation - - README.md)"
  # 承認済み範囲: 親ディレクトリの承認はその配下だけ。"." が混ざっても他のパスは allow にならず、ルート直下はファイル単位
  local ap="$TMP_DIR/approved.json"
  printf '[{"scope":"."},{"scope":"README.md"},{"scope":"logs"}]\n' > "$ap"
  assert_eq "HK-T11" "allow - 6 -" "$(resolve implementation - "$ap" README.md)"
  assert_eq "HK-T11" "allow - 6 -" "$(resolve implementation - "$ap" logs/mr.json)"
  assert_eq "HK-T11" "ask WF202 7 LICENSE" "$(resolve implementation - "$ap" LICENSE)"
  assert_eq "HK-T11" "ask WF202 7 other" "$(resolve implementation - "$ap" other/x.txt)"
  assert_eq "HK-T11" "ask WF202 7 README.md" "$(resolve implementation - - README.md)"
  assert_eq "HK-T11" "ask WF202 7 CLAUDE.md" "$(resolve implementation - - CLAUDE.md)"
  assert_eq "HK-T11" "allow - 5 -" "$(resolve ai-asset-implementation - - CLAUDE.md)"
}

# ---- 宣言は上限の内側で絞る（広げられない）----
case_declaration() {
  local t1="$TMP_DIR/t1.md" t2="$TMP_DIR/t2.md" t3="$TMP_DIR/t3.md"
  mk_ticket "$t1" ai-asset-implementation '[".claude/skills/20-common-step-ticket/**", "wip/**"]' '["read", "build-test"]'
  assert_eq "HK-T11" "allow - 5 -" "$(resolve ai-asset-implementation "$t1" - .claude/skills/20-common-step-ticket/SKILL.md)"
  assert_eq "HK-T11" "ask WF202 7 .claude/skills/other" "$(resolve ai-asset-implementation "$t1" - .claude/skills/other/SKILL.md)"
  # 上限外の宣言は無視される（src/** は ai-asset-implementation の deny）
  mk_ticket "$t2" ai-asset-implementation '["src/**"]' '["read"]'
  assert_eq "HK-T11" "deny WF201 3 -" "$(resolve ai-asset-implementation "$t2" - src/a.ts)"
  mk_ticket "$t3" implementation '["docs/api/**"]' '["read"]'
  assert_eq "HK-T11" "deny WF201 3 -" "$(resolve implementation "$t3" - docs/api/x.md)"
  # 宣言なし（空）なら type の allow 全体
  mk_ticket "$t3" implementation '[]' '["read"]'
  assert_eq "HK-T11" "allow - 5 -" "$(resolve implementation "$t3" - tests/a.test.ts)"
  # (6) 承認済み範囲
  printf '[{"scope":"docs/api","ticket":"0001","at":"x"}]\n' > "$TMP_DIR/approvals.json"
  assert_eq "HK-T11" "allow - 6 -" "$(resolve overall-plan - "$TMP_DIR/approvals.json" docs/api/x.md)"
  assert_eq "HK-T11" "ask WF202 7 docs/other" "$(resolve overall-plan - "$TMP_DIR/approvals.json" docs/other/x.md)"
  # ticket の読み取り
  scope_load_ticket "$t1"
  assert_eq "HK-T11" "ai-asset-implementation 2 2" "$SC_TICKET_TYPE ${#SC_DECL_WRITE[@]} ${#SC_DECL_OPS[@]}"
  assert_eq "HK-T11" ".claude/skills/20-common-step-ticket/**" "${SC_DECL_WRITE[0]}"
}

# ---- ops の宣言 ----
case_ops() {
  local t="$TMP_DIR/t-ops.md"
  mk_ticket "$t" ai-asset-implementation '[]' '["read", "build-test"]'
  scope_load "$CFG" ai-asset-implementation; scope_load_ticket "$t"
  assert_eq "HK-T11" "0" "$(scope_op_declared build-test; echo $?)"
  assert_eq "HK-T11" "1" "$(scope_op_declared hook-test; echo $?)"
  assert_eq "HK-T11" "0" "$(scope_op_declared read; echo $?)"
  assert_eq "HK-T11" "0" "$(scope_op_declared remote-read; echo $?)"
  assert_eq "HK-T11" "1" "$(scope_op_declared remote-write:push; echo $?)"
  mk_ticket "$t" overall-plan '[]' '["read", "remote-write:push", "hook-test"]'
  scope_load "$CFG" overall-plan; scope_load_ticket "$t"
  assert_eq "HK-T11" "0" "$(scope_op_declared remote-write:push; echo $?)"
  assert_eq "HK-T11" "1" "$(scope_op_declared hook-test; echo $?)"   # 宣言しても上限に無ければ不可
  assert_eq "HK-T11" "true" "$SC_TYPE_PLAN_MODE"
}

# ---- コマンドの分類 ----
case_classify() {
  scope_load "$CFG" implementation
  assert_eq "HK-T11" "read" "$(classify_all 'ls -la')"
  assert_eq "HK-T11" "read read" "$(classify_all 'cat x | head')"
  assert_eq "HK-T11" "write" "$(classify_all 'cat x > y.txt')"
  cmdpos_parse 'cat x > y.txt'; scope_classify 0 >/dev/null; assert_eq "HK-T11" "y.txt" "$SC_TARGETS"
  cmdpos_parse 'cp a b > log.txt'; scope_classify 0 >/dev/null; assert_eq "HK-T11" "b${_SC_US}log.txt" "$SC_TARGETS"
  assert_eq "HK-T11" "provided" "$(classify_all 'bash .claude/skills/20-common-step-commit-push/scripts/commit.sh -m "docs: x" a.md')"
  # 一覧に載っている語彙は全要素を踏む（表形式の実装は表形式で検査する）
  local w pair
  for w in $_SC_READ_ONLY_CMDS; do
    case "$w" in '['|'[[') continue ;; esac
    assert_eq "HK-T11" "read" "$(classify_all "$w x")"
  done
  for w in $_SC_GIT_READ_SUBCMDS; do assert_eq "HK-T11" "read" "$(classify_all "git $w")"; done
  for pair in 'git remote -v=read' 'git remote add o u=unknown' 'git config --get user.name=read' 'git config user.name x=unknown' \
              'git merge origin/main=merge-base' 'git merge feat=unknown' 'git push=remote-write:push' 'git commit -m x=unknown' \
              'gh repo view=remote-read' 'gh run list=remote-read' 'gh workflow view x=remote-read' 'gh release download v1=remote-read' \
              'gh release upload v1 a.html=remote-write:attach' 'gh label create x=remote-write:other' 'gh project list=remote-read' \
              'glab ci view=remote-read' 'glab pipeline list=remote-read' 'gh auth status=remote-read' 'gh auth login=remote-write:other' \
              'gh version=remote-read' 'gh api repos/o/r=remote-read' 'gh api -X DELETE repos/o/r=remote-write:other' \
              'gh api -X POST repos/o/r/issues/1/comments -f body=x=remote-write:mr-comment' 'gh api repos/o/r/pulls -f title=x=remote-write:mr-create' \
              'gh api -X PATCH repos/o/r/pulls/7 -f body=x=remote-write:mr-edit' 'gh api repos/o/r/issues -f title=x=remote-write:issue-create' \
              'glab api projects/1/uploads -F file=@a=remote-write:attach' 'gh issue view 1=remote-read' 'gh issue create=remote-write:issue-create' \
              'gh issue edit 1=remote-write:issue-append' 'gh pr view 7=remote-read' 'gh pr checks 7=remote-read' 'gh pr create=remote-write:mr-create' \
              'gh pr edit 7=remote-write:mr-edit' 'glab mr note 7=remote-write:mr-comment' 'gh pr comment 7=remote-write:mr-comment' 'gh pr merge 7=remote-write:other' \
              'find . -name x=read' 'find . -delete=write' 'bash -n x.sh=read' 'bash tests/x.sh=build-test' 'npm test=build-test' 'npm run build=build-test' 'npm install=unknown'; do
    assert_eq "HK-T11" "${pair##*=}" "$(classify_all "${pair%=*}")"
  done
  assert_eq "HK-T11" "hook-test" "$(classify_all 'bash .claude/hooks/lib/tests/test_x.sh')"
  assert_eq "HK-T11" "hook-test" "$(classify_all 'bash .claude/skills/x/scripts/tests/test_y.sh')"
  assert_eq "HK-T11" "build-test" "$(classify_all 'bash tests/run.sh')"
  assert_eq "HK-T11" "build-test" "$(classify_all 'npm test')"
  assert_eq "HK-T11" "build-test" "$(classify_all 'npm run build')"
  assert_eq "HK-T11" "unknown" "$(classify_all 'npm install')"
  assert_eq "HK-T11" "remote-read" "$(classify_all 'gh pr view 7 --json body')"
  assert_eq "HK-T11" "remote-read" "$(classify_all 'gh auth status')"
  assert_eq "HK-T11" "remote-write:mr-create" "$(classify_all 'gh pr create --draft --title x --body-file f')"
  assert_eq "HK-T11" "remote-write:issue-append" "$(classify_all 'gh issue edit 3 --body-file f')"
  assert_eq "HK-T11" "remote-write:issue-create" "$(classify_all 'gh api repos/o/r/issues -f title=t')"
  assert_eq "HK-T11" "remote-read" "$(classify_all 'gh api repos/o/r/pulls/7/comments --paginate')"
  assert_eq "HK-T11" "remote-write:mr-comment" "$(classify_all 'gh pr comment 7 --body-file f')"
  assert_eq "HK-T11" "remote-write:draft-ready" "$(classify_all 'gh pr ready 7')"
  assert_eq "HK-T11" "remote-write:issue-create" "$(classify_all 'glab api projects/:id/issues -X POST --raw-field title=t')"
  assert_eq "HK-T11" "remote-write:push" "$(classify_all 'git push')"
  assert_eq "HK-T11" "merge-base" "$(classify_all 'git merge origin/main')"
  assert_eq "HK-T11" "unknown" "$(classify_all 'git merge feature')"
  assert_eq "HK-T11" "read read" "$(classify_all 'git status && git diff --stat')"
  assert_eq "HK-T11" "unknown" "$(classify_all 'git commit -m x')"
  assert_eq "HK-T11" "read" "$(classify_all 'git config --get user.name')"
  assert_eq "HK-T11" "unknown" "$(classify_all 'git config user.name x')"
  assert_eq "HK-T11" "opaque" "$(classify_all 'eval "$x"')"
  assert_eq "HK-T11" "unknown" "$(classify_all 'curl http://example.com')"
  assert_eq "HK-T11" "write" "$(classify_all "sed -i 's/a/b/' f")"
  assert_eq "HK-T11" "read" "$(classify_all "sed 's/a/b/' f")"
  assert_eq "HK-T11" "read" "$(classify_all 'bash -n x.sh')"
  assert_eq "HK-T11" "write" "$(classify_all 'find . -name x -delete')"
  assert_eq "HK-T11" "read" "$(classify_all 'find . -name x')"
  assert_eq "HK-T11" "read" "$(classify_all 'command -v jq')"
  assert_eq "HK-T11" "write" "$(classify_all 'mkdir -p wip/tmp/x')"
  cmdpos_parse 'mkdir -p wip/tmp/x'; scope_classify 0 >/dev/null; assert_eq "HK-T11" "wip/tmp/x" "$SC_TARGETS"
}

# ---- 設定の検査（WF210 / WF211 の材料）----
case_load_errors() {
  local bad="$TMP_DIR/bad.json" rc
  tl_jq 'del(.common.state_files)' "$CFG" > "$bad"
  scope_load "$bad" implementation; rc=$?
  assert_eq "HK-T11" "1" "$rc"
  assert_contains_var() { [[ "$SC_ERROR" == *"$1"* ]] && pass "HK-T11" || fail "HK-T11" "SC_ERROR='$SC_ERROR' に '$1' が無い"; }
  assert_contains_var "state_files"
  tl_jq 'del(.types.design.ops)' "$CFG" > "$bad"
  scope_load "$bad" implementation; rc=$?
  assert_eq "HK-T11" "1" "$rc"
  assert_contains_var "ops"
  tl_jq '.types.design.extra = 1' "$CFG" > "$bad"
  scope_load "$bad" implementation; rc=$?
  assert_eq "HK-T11" "1" "$rc"
  tl_jq '.common.bogus = []' "$CFG" > "$bad"
  scope_load "$bad" implementation; rc=$?
  assert_eq "HK-T11" "1" "$rc"
  printf 'not json' > "$bad"
  scope_load "$bad" implementation; rc=$?
  assert_eq "HK-T11" "1" "$rc"
  scope_load "$CFG" no-such-type; rc=$?
  assert_eq "HK-T11" "2" "$rc"
  scope_load "$TMP_DIR/missing.json" implementation; rc=$?
  assert_eq "HK-T11" "1" "$rc"
  scope_load "$CFG" implementation; rc=$?
  assert_eq "HK-T11" "0" "$rc"
  assert_eq "HK-T11" "4" "${#SC_TYPES[@]}"
}

case_glob
case_order
case_declaration
case_ops
case_classify
case_load_errors
finish
