#!/usr/bin/env bash
# test_workflow_guard.sh — workflow-guard.sh のテスト（仕様のテスト ID: WG-T01〜WG-T21）
# 使い方: bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --filter '*workflow_guard*'
# テストは set -e を使わない（終了コードは judge が取る）
set -uo pipefail

# 共通ライブラリの読み込み行（20-common-step-shell-script 仕様「読み込み行」が正）。引数 <lib> <policy> だけを変え、中身を改変しない。
# shellcheck disable=SC1090,SC2317
__ss_load() { local lib="$1" pol="$2" d="${BASH_SOURCE[1]%/*}" r="" f=""; [ "$d" = "${BASH_SOURCE[1]}" ] && d="."; case "$d" in /*|[A-Za-z]:/*) ;; *) d="$PWD/$d" ;; esac; while [ -n "$d" ] && [ ! -d "$d/.claude" ]; do case "$d" in */*) d="${d%/*}" ;; *) d="" ;; esac; done; r="$d"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; if [ ! -f "$f" ] && [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then r="${CLAUDE_PROJECT_DIR//\\//}"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ ! -f "$f" ] && command -v git >/dev/null 2>&1; then r="$(git rev-parse --show-toplevel 2>/dev/null || true)"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ -n "$r" ] && [ -f "$f" ]; then LOGGER_ROOT="$r"; export LOGGER_ROOT; [ "$lib" = frontmatter ] && FM_AVAILABLE=1; . "$f"; return 0; fi; [ "$lib" = frontmatter ] && FM_AVAILABLE=0; case "$pol" in nop) LOGGER_ROOT="${r:-$PWD}"; export LOGGER_ROOT; log_debug() { :; }; log_info() { :; }; log_warn() { :; }; log_error() { :; }; fm_extract() { FM_BLOCK=""; return 2; }; fm_get() { return 2; }; fm_list() { return 2; }; fm_has() { return 2; } ;; deny) printf '%s\n' "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"${HOOK_DENY_ID:-WF009}: 機構の不調 — 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）\"}}"; exit 0 ;; *) printf '%s\n' "FATAL: 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）"; exit 2 ;; esac; }
__ss_load test-lib fatal

SRC="$LOGGER_ROOT/.claude/hooks"
SK="$LOGGER_ROOT/.claude/skills/20-common-step-shell-script/scripts"

make_tmp_repo
mkdir -p "$TMP_REPO/.claude/hooks/20-PreToolUse" "$TMP_REPO/.claude/hooks/lib" "$TMP_REPO/.claude/hooks/config" \
         "$TMP_REPO/.claude/skills/20-common-step-shell-script/scripts" "$TMP_REPO/.claude/docs" \
         "$TMP_REPO/wip/10_tickets/00_todo" "$TMP_REPO/wip/10_tickets/10_doing" "$TMP_REPO/wip/10_tickets/20_done" \
         "$TMP_REPO/wip/30_reports" "$TMP_REPO/wip/tmp" "$TMP_REPO/logs" "$TMP_REPO/fixtures" \
         "$TMP_REPO/apl/app/src/api" "$TMP_REPO/apl/app/src/other" "$TMP_REPO/apl/app/docs" \
         "$TMP_REPO/tools" "$TMP_REPO/tests"
cp "$SRC/20-PreToolUse/workflow-guard.sh" "$TMP_REPO/.claude/hooks/20-PreToolUse/"
cp "$SRC/lib/hook-common.sh" "$SRC/lib/cmdpos.sh" "$SRC/lib/scope.sh" "$TMP_REPO/.claude/hooks/lib/"
cp "$SK/logger.sh" "$SK/frontmatter.sh" "$TMP_REPO/.claude/skills/20-common-step-shell-script/scripts/"
TMP_HOOK="$TMP_REPO/.claude/hooks/20-PreToolUse/workflow-guard.sh"
LIMITS="$TMP_REPO/.claude/hooks/config/scope-limits.json"
DEC="$TMP_REPO/logs/hooks/decisions.jsonl"
APPROVALS="$TMP_REPO/logs/sessions/s1/approvals.json"

# 上限設定は本番の設定をそのまま使う。ただし commands.build-test は本番が空なので、
# 「宣言があれば通る / 無ければ WF204」を試せるようにテスト用の 1 行だけ足す（WG-T06）
tl_jq '.commands["build-test"] = ["npm test"]' "$SRC/config/scope-limits.json" > "$LIMITS"
LIMITS_JSON="$(cat "$LIMITS")"

# ---- チケットの雛形 ----
mk_ticket() { # $1=ファイル名（拡張子なし） $2=ticket_type $3=allow.write（JSON 配列） $4=allow.ops（JSON 配列）
  cat > "$TMP_REPO/fixtures/$1.md" <<EOF
---
type: ticket
ticket_type: $2
executor: main
human_review: {required: true, reason: "テスト"}
adversarial_review: {required: false, reason: "テスト"}
allow:
  write: $3
  ops: $4
---

# $1

## 作業ログ
EOF
}
mk_ticket 0003-implementation      implementation           '["apl/app/src/api/**", "apl/app/docs/**"]'                   '["read"]'
mk_ticket 0004-implementation      implementation           '["apl/app/src/api/**"]'                                              '["read", "build-test"]'
mk_ticket 0005-overall-plan        overall-plan             '[]'                                                          '["read", "remote-write:issue-create"]'
mk_ticket 0006-ai-asset-design     ai-asset-design          '[".claude/docs/**"]'                                         '["read"]'
mk_ticket 0007-ai-asset-impl       ai-asset-implementation  '[".claude/hooks/**", ".claude/settings.json", "CLAUDE.md"]'  '["read", "hook-test"]'
mk_ticket 0008-investigation       investigation            '[]'                                                          '["read", "web"]'
mk_ticket 0009-design              design                   '["apl/app/docs/**"]'                                         '["read"]'
mk_ticket 0010-bogus               no-such-type             '[]'                                                          '["read"]'

set_ticket() { # $1... = fixtures の名前（0 個なら作業中なし）
  local n
  rm -f "$TMP_REPO"/wip/10_tickets/10_doing/*.md
  for n in "$@"; do cp "$TMP_REPO/fixtures/$n.md" "$TMP_REPO/wip/10_tickets/10_doing/$n.md"; done
  return 0
}
reset_logs() { rm -rf "$TMP_REPO/logs"; mkdir -p "$TMP_REPO/logs"; }
set_approvals() { # $1... = 承認済みの範囲（省略で削除）
  local s j=""
  if (( $# == 0 )); then rm -f "$APPROVALS"; return 0; fi
  mkdir -p "${APPROVALS%/*}"
  for s in "$@"; do j+="${j:+,}{\"scope\":\"$s\"}"; done
  printf '[%s]\n' "$j" > "$APPROVALS"
  return 0
}

lab() { # $1=フックの出力 → 1 語
  case "$1" in
    *WF201*) printf 'WF201\n' ;; *WF202*) printf 'WF202\n' ;; *WF203*) printf 'WF203\n' ;;
    *WF204*) printf 'WF204\n' ;; *WF205*) printf 'WF205\n' ;; *WF206*) printf 'WF206\n' ;;
    *WF207*) printf 'WF207\n' ;; *WF208*) printf 'WF208\n' ;; *WF209*) printf 'WF209\n' ;;
    *WF210*) printf 'WF210\n' ;; *WF211*) printf 'WF211\n' ;; *WF212*) printf 'WF212\n' ;;
    *WF213*) printf 'WF213\n' ;;
    "")      printf 'allow\n' ;; *) printf 'other:%s\n' "$1" ;;
  esac
}

payload() { # $1=tool_name、以降は tool_input の <キー> <値> の並び
  local tool="$1"; shift
  MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL="*" jq -nc --arg t "$tool" --arg cwd "$TMP_REPO" '
    {hook_event_name: "PreToolUse", tool_name: $t, session_id: "s1", cwd: $cwd, tool_input: {}}
    | reduce range(0; ($ARGS.positional | length); 2) as $i
        (.; .tool_input[$ARGS.positional[$i]] = $ARGS.positional[$i + 1])' --args "$@" | tr -d '\r'
}
run() { lab "$(payload "$@" | bash "$TMP_HOOK" 2>/dev/null)"; }
run_env() { local e="$1"; shift; lab "$(payload "$@" | env "$e" bash "$TMP_HOOK" 2>/dev/null)"; }
raw() { payload "$@" | bash "$TMP_HOOK" 2>/dev/null; }

tf() { run "${2:-Write}" file_path "$TMP_REPO/$1"; }                       # 書き込み（内容なし）
tfc() { run Write file_path "$TMP_REPO/$1" content "$2"; }                  # 書き込み（内容あり）
te() { run Edit file_path "$TMP_REPO/$1" old_string "$2" new_string "$3"; } # 編集
tc() { run "${2:-Bash}" command "$1"; }                                     # 実行
tp() { run EnterPlanMode; }

# ---- 作業ツリーをまたぐ判定の足場（WG-T19 / WG-T20 / WG-T21）----
# cwd を差し替えた入力を組む。MSYS のパス変換を止めないと /tmp/... が Windows パスに化け、
# 作業ツリーの照合が常に外れる（payload と同じ回避）
payload_at() { # $1=cwd $2=tool_name、以降は tool_input の <キー> <値> の並び
  local cwd="$1" tool="$2"; shift 2
  MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL="*" jq -nc --arg t "$tool" --arg cwd "$cwd" '
    {hook_event_name: "PreToolUse", tool_name: $t, session_id: "s1", cwd: $cwd, tool_input: {}}
    | reduce range(0; ($ARGS.positional | length); 2) as $i
        (.; .tool_input[$ARGS.positional[$i]] = $ARGS.positional[$i + 1])' --args "$@" | tr -d '\r'
}
run_at() { lab "$(payload_at "$@" | bash "$TMP_HOOK" 2>/dev/null)"; }
raw_at() { payload_at "$@" | bash "$TMP_HOOK" 2>/dev/null; }

# 本流（TMP_REPO）とそこから切った作業ツリーを相互参照付きで用意する。git worktree add は呼ばない
# （フックは <作業ツリー>/.git と <本流>/.git/worktrees/<名前>/gitdir の相互参照だけを見る）
wt_fixture() { # $1=作業ツリーの置き場 $2=登録名
  mkdir -p "$1/.claude" "$1/wip/10_tickets/00_todo" "$1/wip/10_tickets/10_doing" \
           "$1/wip/10_tickets/20_done" "$1/wip/tmp" "$1/logs" "$1/apl/app/src/api" "$1/tools" \
           "$TMP_REPO/.git/worktrees/$2"
  printf 'gitdir: %s/.git/worktrees/%s\n' "$TMP_REPO" "$2" > "$1/.git"
  printf '%s\n' "$1/.git" > "$TMP_REPO/.git/worktrees/$2/gitdir"
  return 0
}
# 作業中チケットの枚数を数える（負のコントロールの前提をテスト自身が確かめるため。0004 の e48）
doing_count() { # $1=作業ツリーのルート
  local f n=0 ng=0
  shopt -q nullglob && ng=1
  shopt -s nullglob
  for f in "$1"/wip/10_tickets/10_doing/*.md; do n=$(( n + 1 )); done
  (( ng )) || shopt -u nullglob
  printf '%s' "$n"
}
set_wt_ticket() { # $1=作業ツリー、以降 fixtures の名前（0 個なら作業中なし）
  local wt="$1" n
  shift
  rm -f "$wt"/wip/10_tickets/10_doing/*.md
  for n in "$@"; do cp "$TMP_REPO/fixtures/$n.md" "$wt/wip/10_tickets/10_doing/$n.md"; done
  return 0
}

# ---- WG-T01: 作業中 0 枚 ----
case_no_ticket() {
  set_ticket
  reset_logs
  assert_eq "WG-T01" "allow" "$(tf 'apl/app/src/api/a.ts')"
  assert_eq "WG-T01" "allow" "$(tf '.claude/settings.json')"
  assert_eq "WG-T01" "allow" "$(tc 'rm -rf src')"
  assert_eq "WG-T01" "allow" "$(tp)"
  assert_eq "WG-T01" "allow" "$(run Agent subagent_type opus)"
  # 記録もしない
  if [[ -s "$DEC" ]]; then fail "WG-T01" "作業中 0 枚で記録が残る: $(cat "$DEC")"; else pass "WG-T01"; fi
}

# ---- WG-T02: 許可範囲と宣言 ----
case_allow() {
  set_ticket 0003-implementation
  reset_logs; set_approvals
  assert_eq "WG-T02" "allow" "$(tf 'wip/30_reports/a.md')"        # common.allow
  assert_eq "WG-T02" "allow" "$(tf 'wip/tmp/x.txt')"
  assert_eq "WG-T02" "allow" "$(tf 'apl/app/src/api/a.ts')"               # 宣言 ∩ types.allow
  assert_eq "WG-T02" "WF202" "$(tf 'apl/app/src/other/b.ts')"             # 上限内だが宣言外 → 未記載扱い
  assert_eq "WG-T02" "WF201" "$(tf 'apl/app/docs/x.md')"          # 宣言にあるが上限外（types.deny）→ 無視される
  # 作業中チケットの本文（作業ログ）は宣言によらず通る
  assert_eq "WG-T02" "allow" "$(te 'wip/10_tickets/10_doing/0003-implementation.md' '## 作業ログ' '## 作業ログ
- 追記')"
  # 記録は残る
  if [[ -s "$DEC" ]]; then pass "WG-T02"; else fail "WG-T02" "判定が記録されない"; fi
  # 宣言が空なら types.allow がそのまま効く
  set_ticket 0004-implementation
  assert_eq "WG-T02" "allow" "$(tf 'apl/app/src/api/a.ts')"
  assert_eq "WG-T02" "WF202" "$(tf 'apl/app/src/other/b.ts')"
}

# ---- WG-T03: 保護範囲と種類ごとの明示許可 ----
case_protected() {
  set_ticket 0003-implementation
  assert_eq "WG-T03" "WF201" "$(tf '.claude/hooks/lib/x.sh')"
  assert_eq "WG-T03" "WF201" "$(tf '.claude/docs/10_spec/x.md')"
  assert_eq "WG-T03" "WF201" "$(tf '.gitignore')"
  # `.` や `..` を挟んだ書き方で保護範囲の glob をすり抜けられない
  assert_eq "WG-T03" "WF201" "$(tf './.claude/settings.json')"
  assert_eq "WG-T03" "WF201" "$(tf 'wip/../.claude/settings.json')"
  assert_eq "WG-T03" "WF201" "$(tf 'apl/app/src/api/../../../../.claude/hooks/x.sh')"
  assert_eq "WG-T03" "WF205" "$(tc 'echo x > wip/tmp/../../.claude/settings.json')"
  set_ticket 0006-ai-asset-design
  assert_eq "WG-T03" "allow" "$(tf '.claude/docs/10_spec/x.md')"   # types.allow で保護範囲を上書き
  assert_eq "WG-T03" "WF201" "$(tf '.claude/hooks/lib/x.sh')"
  assert_eq "WG-T03" "WF201" "$(tf '.claude/settings.json')"
}

# ---- WG-T04: 未記載パスと承認の記憶 ----
case_unlisted() {
  set_ticket 0003-implementation
  set_approvals
  assert_eq "WG-T04" "WF202" "$(tf 'tools/gen.py')"
  # 承認単位（親ディレクトリ）が案内に出る
  case "$(raw Write file_path "$TMP_REPO/tools/gen.py")" in
    *tools*) pass "WG-T04" ;; *) fail "WG-T04" "承認単位が案内に無い" ;;
  esac
  set_approvals tools
  assert_eq "WG-T04" "allow" "$(tf 'tools/gen.py')"
  assert_eq "WG-T04" "allow" "$(tf 'tools/sub/x.py')"
  assert_eq "WG-T04" "WF202" "$(tf 'other/x.py')"
  # file_granular はファイル単位（親 = ルートで承認されない）
  set_approvals
  assert_eq "WG-T04" "WF202" "$(tf 'CLAUDE.md')"
  case "$(raw Write file_path "$TMP_REPO/CLAUDE.md")" in
    *CLAUDE.md*) pass "WG-T04" ;; *) fail "WG-T04" "ファイル単位の承認単位が案内に無い" ;;
  esac
  set_approvals .
  assert_eq "WG-T04" "WF202" "$(tf 'CLAUDE.md')"                   # 承認単位 "." は効かない
  set_approvals CLAUDE.md
  assert_eq "WG-T04" "allow" "$(tf 'CLAUDE.md')"
  set_approvals
}

# ---- WG-T05: 毎回確認の範囲 ----
case_confirm() {
  set_ticket 0003-implementation
  set_approvals apl/app/package.json .claude/hooks/config
  assert_eq "WG-T05" "WF203" "$(tf 'apl/app/package.json')"        # types.confirm（承認済みでも毎回）
  # implementation では .claude/** が保護範囲（判定 2）で止まるので、confirm（判定 4）には届かない。
  # common.confirm が効くのは、その種類の allow に明示されている .claude/** の中だけ（下の ai-asset-implementation）
  assert_eq "WG-T05" "WF201" "$(tf '.claude/hooks/config/scope-limits.json')"
  set_ticket 0007-ai-asset-impl
  assert_eq "WG-T05" "WF203" "$(tf '.claude/hooks/config/scope-limits.json')"
  assert_eq "WG-T05" "WF203" "$(tf '.claude/settings.json')"
  set_approvals
}

# ---- WG-T06: コマンドの分類 ----
case_commands() {
  set_ticket 0003-implementation
  assert_eq "WG-T06" "allow" "$(tc 'ls -la src')"
  assert_eq "WG-T06" "allow" "$(tc 'cat apl/app/src/api/a.ts | grep x')"
  assert_eq "WG-T06" "allow" "$(tc 'git status --short')"
  assert_eq "WG-T06" "allow" "$(tc 'gh pr view 3 --json number')"          # remote-read
  assert_eq "WG-T06" "allow" "$(tc 'bash .claude/skills/20-common-step-ticket/scripts/ticket.sh next')"
  assert_eq "WG-T06" "WF205" "$(tc 'echo x > apl/app/src/api/a.ts')"
  assert_eq "WG-T06" "WF205" "$(tc 'cp a.md apl/app/src/api/a.md')"
  assert_eq "WG-T06" "WF205" "$(tc 'rm -rf src/api')"
  assert_eq "WG-T06" "allow" "$(tc 'echo x > wip/tmp/a.txt')"              # 書いてよい置き場
  assert_eq "WG-T06" "allow" "$(tc 'echo x >> logs/sh/a.log')"
  # シェルのキーワードだけの段（for / done / fi / esac）を分類外にしない。リダイレクト付きは書き込みとして拾う
  assert_eq "WG-T06" "allow" "$(tc 'for f in a b; do echo $f; done')"
  assert_eq "WG-T06" "allow" "$(tc 'if true; then ls; fi')"
  assert_eq "WG-T06" "allow" "$(tc 'case $x in a) ls;; esac')"
  assert_eq "WG-T06" "WF205" "$(tc 'for f in a; do echo x; done > apl/app/src/api/a.ts')"
  assert_eq "WG-T06" "allow" "$(tc 'for f in a; do echo x; done > wip/tmp/a.txt')"
  assert_eq "WG-T06" "WF204" "$(tc 'npm test')"                            # build-test の宣言が無い
  set_ticket 0004-implementation
  assert_eq "WG-T06" "allow" "$(tc 'npm test')"
  assert_eq "WG-T06" "allow" "$(tc 'bash tests/run.sh')"
  # hook-test は ai-asset-implementation の宣言でだけ通る
  assert_eq "WG-T06" "WF204" "$(tc 'bash .claude/hooks/lib/tests/test_scope.sh')"
  set_ticket 0007-ai-asset-impl
  assert_eq "WG-T06" "allow" "$(tc 'bash .claude/hooks/lib/tests/test_scope.sh')"
}

# ---- WG-T07: リモート書き込み ----
case_remote() {
  set_ticket 0003-implementation
  assert_eq "WG-T07" "WF206" "$(tc 'gh issue create --title x --body y')"
  assert_eq "WG-T07" "WF206" "$(tc 'gh pr comment 3 --body x')"
  set_ticket 0005-overall-plan
  assert_eq "WG-T07" "allow" "$(tc 'gh issue create --title x --body y')"
  assert_eq "WG-T07" "WF206" "$(tc 'gh pr comment 3 --body x')"            # 宣言に無い種別
}

# ---- WG-T08: 作業中が 2 枚以上 ----
case_two_doing() {
  set_ticket 0003-implementation 0004-implementation
  assert_eq "WG-T08" "WF207" "$(tc 'ls -la')"
  assert_eq "WG-T08" "WF207" "$(tf 'wip/30_reports/a.md')"
  assert_eq "WG-T08" "WF207" "$(tp)"
  # 提供コマンドは通る（1 枚に戻す経路）
  assert_eq "WG-T08" "allow" "$(tc 'bash .claude/skills/20-common-step-ticket/scripts/ticket.sh cancel 0004 --reason x')"
  # 番号の一覧が出る
  case "$(raw Bash command 'ls -la')" in
    *0003*0004*) pass "WG-T08" ;; *) fail "WG-T08" "チケット番号の一覧が出ない" ;;
  esac
  # どの作業ツリーで数えたかが出る（枚数は 1 作業ツリーあたりの話なので、書かないと戻す先が決まらない）
  case "$(raw Bash command 'ls -la')" in
    *"$TMP_REPO"*) pass "WG-T08" ;; *) fail "WG-T08" "どの作業ツリーで数えたかが出ない" ;;
  esac
}

# ---- WG-T09: 作業中チケット自身の改変 ----
case_self_edit() {
  set_ticket 0003-implementation
  local t='wip/10_tickets/10_doing/0003-implementation.md'
  assert_eq "WG-T09" "WF208" "$(te "$t" 'ticket_type: implementation' 'ticket_type: design')"
  assert_eq "WG-T09" "WF208" "$(te "$t" 'adversarial_review: {required: false, reason: "テスト"}' 'adversarial_review: {required: true, reason: "テスト"}')"
  # 入れ子の write / ops 行だけを差し替える形も検知する（allow: 行に触れずに宣言を広げられないこと）
  assert_eq "WG-T09" "WF208" "$(te "$t" '  write: ["apl/app/src/api/**", "apl/app/docs/**"]' '  write: [".claude/**"]')"
  assert_eq "WG-T09" "WF208" "$(te "$t" '  ops: ["read"]' '  ops: ["read", "remote-write:push"]')"
  assert_eq "WG-T09" "WF208" "$(te "$t" 'executor: main' 'executor: sub')"
  assert_eq "WG-T09" "allow" "$(te "$t" '## 作業ログ' '## 作業ログ
- 15:00 着手')"
  assert_eq "WG-T09" "allow" "$(te "$t" '- [ ] DoD' '- [x] DoD')"
  # 箇条書きの中の ops / write は作業ログなので巻き込まない
  assert_eq "WG-T09" "allow" "$(te "$t" '## 作業ログ' '## 作業ログ
- ops: read だけで足りた')"
  # 他のチケット（未着手）の書き換えは WF208 の対象外
  assert_eq "WG-T09" "allow" "$(te 'wip/10_tickets/00_todo/0011-x.md' 'ticket_type: implementation' 'ticket_type: design')"
}

# ---- WG-T10: 判定不能 ----
case_undecidable() {
  set_ticket 0003-implementation
  assert_eq "WG-T10" "WF209" "$(tc 'eval "rm -rf src"')"
  assert_eq "WG-T10" "WF209" "$(tc 'xargs rm < list.txt')"
  local long; long="ls $(printf 'x%.0s' $(seq 1 4200))"
  assert_eq "WG-T10" "WF209" "$(tc "$long")"
  assert_eq "WG-T10" "WF209" "$(run Bash file_path x)"                      # command が無い
  assert_eq "WG-T10" "WF209" "$(run Write command x)"                       # file_path が無い
  # 作業ツリーの外は、どの範囲にも属さないので承認単位にもしない（拒否側に倒す）
  assert_eq "WG-T10" "WF209" "$(tf '../outside.txt')"
  assert_eq "WG-T10" "WF209" "$(tf 'wip/../../outside.txt')"
}

# ---- WG-T11: 設定・種類の異常 ----
case_config() {
  set_ticket 0003-implementation
  # 設定なし
  rm -f "$LIMITS"
  assert_eq "WG-T11" "WF210" "$(tf 'apl/app/src/api/a.ts')"
  assert_eq "WG-T11" "WF203" "$(tf '.claude/hooks/config/scope-limits.json')"
  assert_eq "WG-T11" "allow" "$(tf 'wip/10_tickets/10_doing/0003-implementation.md')"
  assert_eq "WG-T11" "allow" "$(tc 'bash .claude/skills/20-common-step-ticket/scripts/ticket.sh next')"
  assert_eq "WG-T11" "WF210" "$(tc 'ls -la')"
  printf '%s' "$LIMITS_JSON" > "$LIMITS"
  # 種類が設定に無い
  set_ticket 0010-bogus
  assert_eq "WG-T11" "WF211" "$(tf 'apl/app/src/api/a.ts')"
  assert_eq "WG-T11" "allow" "$(tf 'wip/10_tickets/10_doing/0010-bogus.md')"
  assert_eq "WG-T11" "allow" "$(tc 'bash .claude/skills/20-common-step-ticket/scripts/ticket.sh next')"
  # frontmatter が無いチケットも WF211
  printf 'ticket without frontmatter\n' > "$TMP_REPO/wip/10_tickets/10_doing/0010-bogus.md"
  assert_eq "WG-T11" "WF211" "$(tf 'apl/app/src/api/a.ts')"
  # 設定ありのときの毎回確認（ai-asset-implementation でも）
  set_ticket 0007-ai-asset-impl
  assert_eq "WG-T11" "WF203" "$(tf '.claude/hooks/config/scope-limits.json')"
  assert_eq "WG-T11" "WF203" "$(tf '.claude/settings.json')"
  assert_eq "WG-T11" "allow" "$(tf '.claude/hooks/20-PreToolUse/x.sh')"
}

# ---- WG-T12: プランモード ----
case_plan() {
  set_ticket 0005-overall-plan
  assert_eq "WG-T12" "allow" "$(tp)"
  set_ticket 0003-implementation
  assert_eq "WG-T12" "WF212" "$(tp)"
}

# ---- WG-T13: ヘッドレスでは確認が拒否になる ----
case_headless() {
  set_ticket 0003-implementation
  set_approvals
  assert_eq "WG-T13" "WF213" "$(run_env WORKFLOW_HEADLESS=1 Write file_path "$TMP_REPO/tools/gen.py")"
  assert_eq "WG-T13" "WF213" "$(run_env WORKFLOW_HEADLESS=1 Write file_path "$TMP_REPO/apl/app/package.json")"
  assert_eq "WG-T13" "allow" "$(run_env WORKFLOW_HEADLESS=1 Write file_path "$TMP_REPO/apl/app/src/api/a.ts")"
  assert_eq "WG-T13" "WF201" "$(run_env WORKFLOW_HEADLESS=1 Write file_path "$TMP_REPO/.claude/settings.json")"
  # 停止中は何もしない
  assert_eq "WG-T13" "allow" "$(run_env WORKFLOW_ENFORCE=0 Write file_path "$TMP_REPO/.claude/settings.json")"
  assert_eq "WG-T13" "allow" "$(run_env WORKFLOW_GUARD_ENFORCE=0 Write file_path "$TMP_REPO/.claude/settings.json")"

  # ホットパス: jq は入力の 1 回と承認の記憶の 1 回まで。git / date / sed / find は呼ばない（HK-T19）
  local bash_bin; bash_bin="$(command -v bash)"
  make_counting_path jq git date sed find awk grep cat tr cut head tail wc sort uniq
  run_cmd env PATH="$COUNTING_PATH" "$bash_bin" -c     "printf '%s' '$(payload Write file_path "$TMP_REPO/apl/app/src/api/a.ts")' | '$bash_bin' '$TMP_HOOK'"
  assert_eq "WG-T13" "2" "$(counted_calls jq)"
  assert_eq "WG-T13" "0" "$(counted_calls git)"
  assert_eq "WG-T13" "0" "$(counted_calls date)"
  assert_eq "WG-T13" "0" "$(counted_calls sed)"
  assert_eq "WG-T13" "0" "$(counted_calls find)"
  # 承認の記憶を見ない経路（コマンドの判定）は 1 回で済む
  make_counting_path jq git date sed find awk grep cat tr cut head tail wc sort uniq
  run_cmd env PATH="$COUNTING_PATH" "$bash_bin" -c     "printf '%s' '$(payload Bash command 'ls -la')' | '$bash_bin' '$TMP_HOOK'"
  assert_eq "WG-T13" "1" "$(counted_calls jq)"
}

# ---- WG-T14: 提供コマンドの引数のパス ----
case_provided_args() {
  set_ticket 0003-implementation
  local cp=".claude/skills/20-common-step-commit-push/scripts/commit.sh"
  assert_eq "WG-T14" "WF201" "$(tc "bash $cp -m 'chore: x' .claude/settings.json")"
  assert_eq "WG-T14" "allow" "$(tc "bash $cp -m 'chore: x' wip/30_reports/a.md apl/app/src/api/a.ts")"
  assert_eq "WG-T14" "WF202" "$(tc "bash $cp -m 'chore: x' tools/gen.py")"
  # メッセージ・オプションの値をパスとして扱わない
  assert_eq "WG-T14" "allow" "$(tc "bash $cp -m 'fix: a.md を直す' wip/tmp/a.txt")"
  assert_eq "WG-T14" "allow" "$(tc 'bash .claude/skills/20-common-step-ticket/scripts/ticket.sh create --type implementation --allow-write "apl/*/src/**"')"
}

# ---- WG-T15: web の分類と出力先 ----
case_web() {
  set_ticket 0008-investigation
  assert_eq "WG-T15" "allow" "$(tc 'curl https://example.com/x')"
  assert_eq "WG-T15" "allow" "$(tc 'curl -s https://example.com/x')"
  assert_eq "WG-T15" "allow" "$(tc 'curl -o wip/tmp/x.md https://example.com/x')"
  assert_eq "WG-T15" "WF205" "$(tc 'curl -o .claude/settings.json https://example.com/x')"
  assert_eq "WG-T15" "WF205" "$(tc 'curl -O https://example.com/x')"
  assert_eq "WG-T15" "WF205" "$(tc 'curl https://example.com/x > apl/app/src/api/a.ts')"
  assert_eq "WG-T15" "allow" "$(tc 'curl https://example.com/x > wip/tmp/a.txt')"
  assert_eq "WG-T15" "WF205" "$(tc 'wget https://example.com/x')"
  assert_eq "WG-T15" "allow" "$(tc 'wget -O - https://example.com/x')"
  set_ticket 0009-design
  assert_eq "WG-T15" "WF204" "$(tc 'curl https://example.com/x')"           # web の宣言が無い
}

# ---- WG-T17: 送信側は宣言があっても通らない ----
case_web_upload() {
  set_ticket 0008-investigation                                            # web を宣言している
  assert_eq "WG-T17" "WF206" "$(tc 'curl -T a.md https://example.com/x')"
  assert_eq "WG-T17" "WF206" "$(tc 'curl -d @a.md https://example.com/x')"
  assert_eq "WG-T17" "WF206" "$(tc 'curl --data-binary @a.md https://example.com/x')"
  assert_eq "WG-T17" "WF206" "$(tc 'curl -F file=@a.md https://example.com/x')"
  assert_eq "WG-T17" "WF206" "$(tc 'curl -X POST https://example.com/x')"
  assert_eq "WG-T17" "WF206" "$(tc 'curl --request PUT https://example.com/x')"
  assert_eq "WG-T17" "WF206" "$(tc 'wget --post-file=a.md https://example.com/x')"
  assert_eq "WG-T17" "WF206" "$(tc 'wget --method=PUT https://example.com/x')"
  assert_eq "WG-T17" "allow" "$(tc 'curl -X GET https://example.com/x')"
  # wget は既定で URL の basename に書くので、送信側でなくても出力先の判定に落ちる（WG-T15 と同じ扱い）。
  # 仕様の WG-T17 は「WF206 にならない」ことを言っており、`-O -` を付けなければ WF205 になる
  assert_eq "WG-T17" "WF205" "$(tc 'wget --method=GET https://example.com/x')"
  assert_eq "WG-T17" "allow" "$(tc 'wget --method=GET -O - https://example.com/x')"
  # 出力先と URL を取り違えない
  assert_eq "WG-T17" "allow" "$(tc 'curl https://example.com/x -o wip/tmp/a')"
  assert_eq "WG-T17" "allow" "$(tc 'curl -o wip/tmp/a https://example.com/x')"
}

# ---- WG-T16: 設定・承認の記憶が壊れていても判定が続く ----
case_broken() {
  set_ticket 0003-implementation
  printf '%s' '{ not json' > "$LIMITS"
  local out; out="$(raw Write file_path "$TMP_REPO/apl/app/src/api/a.ts")"
  assert_eq "WG-T16" "WF210" "$(lab "$out")"
  case "$out" in *Write*) pass "WG-T16" ;; *) fail "WG-T16" "tool_name が案内に無い" ;; esac
  case "$out" in *apl/app/src/api/a.ts*) pass "WG-T16" ;; *) fail "WG-T16" "対象パスが案内に無い" ;; esac
  # 復旧経路
  assert_eq "WG-T16" "allow" "$(tc 'bash .claude/skills/20-common-step-commit-push/scripts/commit.sh -m x wip/tmp/a')"
  assert_eq "WG-T16" "allow" "$(tf 'wip/10_tickets/10_doing/0003-implementation.md')"
  assert_eq "WG-T16" "WF203" "$(tf '.claude/hooks/config/scope-limits.json')"
  # 検証に落ちる設定（キー不足）も同じ扱い
  printf '%s' '{"common":{"allow":[]},"types":{}}' > "$LIMITS"
  assert_eq "WG-T16" "WF210" "$(tf 'apl/app/src/api/a.ts')"
  printf '%s' "$LIMITS_JSON" > "$LIMITS"
  # 承認の記憶が壊れているときは、承認済み判定だけが効かなくなる
  mkdir -p "${APPROVALS%/*}"; printf '%s' '{ not json' > "$APPROVALS"
  assert_eq "WG-T16" "WF202" "$(tf 'tools/gen.py')"
  assert_eq "WG-T16" "allow" "$(tf 'apl/app/src/api/a.ts')"
  assert_eq "WG-T16" "WF201" "$(tf '.claude/settings.json')"
  set_approvals
}

# ---- WG-T18: 削除だけのコマンドは allow.write の内側なら通る ----
case_delete() {
  set_ticket 0007-ai-asset-impl
  reset_logs; set_approvals
  assert_eq "WG-T18" "allow" "$(tc 'rm .claude/hooks/20-PreToolUse/x.sh')"
  assert_eq "WG-T18" "allow" "$(tc 'rm -f .claude/hooks/20-PreToolUse/x.sh .claude/hooks/lib/y.sh')"
  assert_eq "WG-T18" "allow" "$(tc 'git rm .claude/hooks/20-PreToolUse/x.sh')"
  assert_eq "WG-T18" "allow" "$(tc 'git rm -r --cached .claude/hooks/old/')"
  assert_eq "WG-T18" "allow" "$(tc 'rm wip/tmp/x')"                        # 従来から通っていた置き場
  # 許可範囲の外は今までどおり WF205（負のコントロール）
  assert_eq "WG-T18" "WF205" "$(tc 'rm apl/app/src/api/a.ts')"
  assert_eq "WG-T18" "WF205" "$(tc 'git rm apl/app/src/api/a.ts')"
  assert_eq "WG-T18" "WF205" "$(tc 'rm .claude/settings.json')"            # 毎回確認の範囲は消させない
  assert_eq "WG-T18" "WF205" "$(tc 'rm -rf .claude')"
  # 作成・更新の扱いは変えない
  assert_eq "WG-T18" "WF205" "$(tc 'echo x > .claude/hooks/20-PreToolUse/x.sh')"
  assert_eq "WG-T18" "WF205" "$(tc 'mv .claude/hooks/20-PreToolUse/x.sh .claude/hooks/20-PreToolUse/y.sh')"
  assert_eq "WG-T18" "WF205" "$(tc 'cp wip/tmp/x .claude/hooks/20-PreToolUse/x.sh')"
  # 対象を読み取れない形は拒否
  assert_eq "WG-T18" "WF205" "$(tc 'rm -f')"
  assert_eq "WG-T18" "WF205" "$(tc 'git rm --pathspec-from-file wip/tmp/list.txt')"
  # 削除の対象が通っても、リダイレクト先は従来どおり置き場で見る
  assert_eq "WG-T18" "WF205" "$(tc 'rm .claude/hooks/20-PreToolUse/x.sh > .claude/hooks/out.txt')"
  assert_eq "WG-T18" "allow" "$(tc 'rm .claude/hooks/20-PreToolUse/x.sh > wip/tmp/out.txt')"
  # ディレクトリごとの削除は、配下に保護範囲・毎回確認・進行状態が入り得るなら通さない
  assert_eq "WG-T18" "WF205" "$(tc 'rm -rf .claude/hooks/config')"
  assert_eq "WG-T18" "WF205" "$(tc 'rm -rf .claude/hooks/config/')"
  assert_eq "WG-T18" "WF205" "$(tc 'git rm -r .claude/hooks')"
  assert_eq "WG-T18" "WF205" "$(tc 'rm -rf logs')"
  # 展開してからでないとパスが決まらない語は通さない
  assert_eq "WG-T18" "WF205" "$(tc 'rm -rf .claude/hooks/*')"
  assert_eq "WG-T18" "WF205" "$(tc 'rm -rf .claude/hooks/{x.sh,../settings.json}')"
  assert_eq "WG-T18" "WF205" "$(tc 'rm -rf .claude/hooks/$X')"
  assert_eq "WG-T18" "WF205" "$(tc 'rm .claude/hooks/20-PreToolUse/x.sh,.claude/settings.json')"
  assert_eq "WG-T18" "WF205" "$(tc 'rm ~/x.sh')"
  # 進行状態のファイルは logs/ の中でも消せない（置き場の許可より優先）
  assert_eq "WG-T18" "WF205" "$(tc 'rm logs/review-state.json')"
  assert_eq "WG-T18" "WF205" "$(tc 'rm logs/mr.json')"
  assert_eq "WG-T18" "allow" "$(tc 'rm logs/sh/ticket.log')"
  # 宣言に無いパスは、上限（types.allow）の内側でも共通の許可範囲でも消せない
  set_ticket 0003-implementation
  assert_eq "WG-T18" "allow" "$(tc 'rm apl/app/src/api/a.ts')"
  assert_eq "WG-T18" "WF205" "$(tc 'rm apl/app/src/other/b.ts')"
  assert_eq "WG-T18" "WF205" "$(tc 'rm wip/10_tickets/00_todo/0011-x.md')"
  assert_eq "WG-T18" "WF205" "$(tc 'rm wip/30_reports/a.md')"
  assert_eq "WG-T18" "allow" "$(tc 'rm wip/tmp/a.txt')"
  # 宣言が空のチケットは、置き場の外を消せない
  set_ticket 0005-overall-plan
  assert_eq "WG-T18" "WF205" "$(tc 'rm wip/30_reports/a.md')"
  assert_eq "WG-T18" "allow" "$(tc 'rm wip/tmp/a.txt')"
  # 作業中チケットが無ければこのフックは何もしない（WG-T01 と同じ。削除の可否は入口ガードが見る）
  set_ticket
  assert_eq "WG-T18" "allow" "$(tc 'rm .claude/hooks/20-PreToolUse/x.sh')"
}

# ---- WG-T19: 宣言範囲の強制が worktree 側のチケットで判定される（A1-6 / A5）----
WG_WT=""
case_worktree_scope() {
  make_tmp_dir
  WG_WT="$TMP_DIR/wt"
  wt_fixture "$WG_WT" w1
  set_ticket                                    # 本流 0 枚
  set_wt_ticket "$WG_WT" 0003-implementation    # worktree 1 枚
  set_approvals
  # 前提を assert してから判定を呼ぶ（既存のリポジトリの状態に依存させない）
  assert_eq "WG-T19" "0" "$(doing_count "$TMP_REPO")"
  assert_eq "WG-T19" "1" "$(doing_count "$WG_WT")"
  # worktree 側チケット（0003-implementation: allow.write は apl/app/src/api/** と apl/app/docs/**）で判定される
  assert_eq "WG-T19" "allow" "$(run_at "$WG_WT" Write file_path "$WG_WT/apl/app/src/api/a.ts")"
  assert_eq "WG-T19" "WF201" "$(run_at "$WG_WT" Write file_path "$WG_WT/.claude/settings.json")"
  assert_eq "WG-T19" "WF202" "$(run_at "$WG_WT" Write file_path "$WG_WT/tools/gen.py")"
  # WF207 は出ない（本流にも 1 枚あって合計 2 枚でも、数えるのは作業ツリーの中だけ）
  set_ticket 0005-overall-plan
  assert_eq "WG-T19" "1" "$(doing_count "$TMP_REPO")"
  assert_eq "WG-T19" "1" "$(doing_count "$WG_WT")"
  assert_eq "WG-T19" "allow" "$(run_at "$WG_WT" Write file_path "$WG_WT/apl/app/src/api/a.ts")"
  assert_eq "WG-T19" "WF201" "$(run_at "$WG_WT" Write file_path "$WG_WT/.claude/settings.json")"
  # 本流側のチケット（overall-plan: 宣言は空）は worktree 側の判定に使われない。
  # 同じパスが cwd=本流 では WF202（未記載）、cwd=worktree では allow になる（材料が別のチケットである証拠）
  assert_eq "WG-T19" "WF202" "$(run_at "$TMP_REPO" Write file_path "$TMP_REPO/apl/app/src/api/a.ts")"
}

# ---- WG-T20: WG-T19 の負のコントロール（本流 1 枚・worktree 0 枚）----
case_worktree_negative() {
  local out rc
  set_ticket 0003-implementation      # 本流 1 枚
  set_wt_ticket "$WG_WT"              # worktree 0 枚
  assert_eq "WG-T20" "1" "$(doing_count "$TMP_REPO")"
  assert_eq "WG-T20" "0" "$(doing_count "$WG_WT")"
  # cwd=worktree では判定に入らない（無出力・終了 0）。本流のチケットの宣言は一切使われない
  out="$(raw_at "$WG_WT" Write file_path "$TMP_REPO/.claude/settings.json")"; rc=$?
  assert_eq "WG-T20" "" "$out"
  assert_eq "WG-T20" "0" "$rc"
  out="$(raw_at "$WG_WT" Write file_path "$WG_WT/.claude/settings.json")"; rc=$?
  assert_eq "WG-T20" "" "$out"
  assert_eq "WG-T20" "0" "$rc"
  assert_eq "WG-T20" "allow" "$(run_at "$WG_WT" Bash command 'rm .claude/settings.json')"
  # 正のコントロール: 同じ入力を cwd=本流 で流すと拒否される（無音は判定の不在であって故障ではない）
  assert_eq "WG-T20" "WF201" "$(run_at "$TMP_REPO" Write file_path "$TMP_REPO/.claude/settings.json")"
  assert_eq "WG-T20" "WF205" "$(run_at "$TMP_REPO" Bash command 'rm .claude/settings.json')"
  # 作業ツリーだと自称しているのに相互参照を確かめられない cwd からの操作は、
  # 本流の枚数で判定せず WF209 で止める（本流に倒すと、その中の全操作が本流 0 枚で素通りする）
  set_ticket                          # 本流 0 枚
  set_wt_ticket "$WG_WT" 0003-implementation
  mv "$TMP_REPO/.git/worktrees" "$TMP_REPO/.git/worktrees-off"
  printf 'x\n' > "$TMP_REPO/.git/worktrees"
  assert_eq "WG-T20" "0" "$(doing_count "$TMP_REPO")"
  assert_eq "WG-T20" "WF209" "$(run_at "$WG_WT" Write file_path "$WG_WT/apl/app/src/api/a.ts")"
  assert_eq "WG-T20" "WF209" "$(run_at "$WG_WT" Bash command 'rm .claude/settings.json')"
  # 読み取り・起動は止めない（判定材料が無くても害が無い側）
  assert_eq "WG-T20" "allow" "$(run_at "$WG_WT" Read file_path "$WG_WT/apl/app/src/api/a.ts")"
  # 対照: 相互参照を戻せば作業ツリー側のチケットで判定される（WF209 が「確かめられない状態」に由来する証拠）
  rm -f "$TMP_REPO/.git/worktrees"
  mv "$TMP_REPO/.git/worktrees-off" "$TMP_REPO/.git/worktrees"
  assert_eq "WG-T20" "allow" "$(run_at "$WG_WT" Write file_path "$WG_WT/apl/app/src/api/a.ts")"
}

# ---- WG-T21: worktree.sh の置き場を指す引数の例外 ----
case_worktree_args() {
  local wtc=".claude/skills/20-common-step-worktree/scripts/worktree.sh"
  local cp=".claude/skills/20-common-step-commit-push/scripts/commit.sh"
  set_ticket 0003-implementation
  set_approvals
  # 置き場はリポジトリの外が既定。判定を当てると必ず WF209 になるので当てない（妥当性は worktree.sh が検査する）
  assert_eq "WG-T21" "allow" "$(tc "bash $wtc add w1 ../repo-wt/w1")"
  assert_eq "WG-T21" "allow" "$(tc "bash $wtc add w1")"
  assert_eq "WG-T21" "allow" "$(tc "bash $wtc remove ../repo-wt/w1")"
  assert_eq "WG-T21" "allow" "$(tc "bash $wtc remove w1")"
  assert_eq "WG-T21" "allow" "$(tc "bash $wtc list")"
  assert_eq "WG-T21" "allow" "$(tc "bash $wtc merge --all")"
  # 例外は引数の位置で決まる。名前の位置に外のパスを書けば従来どおり WF209（負のコントロール）
  assert_eq "WG-T21" "WF209" "$(tc "bash $wtc add ../repo-wt/w1")"
  # 同じ行の他のパス引数・他の提供コマンドの引数は従来どおり判定する（WG-T14 の正のコントロール）
  assert_eq "WG-T21" "WF201" "$(tc "bash $wtc add w1 ../repo-wt/w1 && bash $cp -m 'chore: x' .claude/settings.json")"
  assert_eq "WG-T21" "WF201" "$(tc "bash $cp -m 'chore: x' .claude/settings.json")"
  assert_eq "WG-T21" "WF209" "$(tc "bash $cp -m 'chore: x' ../repo-wt/w1/a.md")"
  # 提供コマンドでない git の作業ツリー操作は分類外、一覧は読み取り、cd は分類外
  assert_eq "WG-T21" "WF204" "$(tc 'git worktree add ../repo-wt/w1')"
  assert_eq "WG-T21" "WF204" "$(tc 'git worktree remove ../repo-wt/w1')"
  assert_eq "WG-T21" "allow" "$(tc 'git worktree list')"
  assert_eq "WG-T21" "WF204" "$(tc 'cd ../repo-wt/w1')"
}

printf 'ticket_type: implementation\n' > "$TMP_REPO/wip/10_tickets/00_todo/0011-x.md"

case_no_ticket
case_allow
case_protected
case_unlisted
case_confirm
case_commands
case_remote
case_two_doing
case_self_edit
case_undecidable
case_config
case_plan
case_headless
case_provided_args
case_web
case_web_upload
case_delete
case_broken
# 作業ツリーの fixture は本流に .git/worktrees/<名前> を足すので、他のケースの後に置く
case_worktree_scope
case_worktree_negative
case_worktree_args

finish
