#!/usr/bin/env bash
# test_worktree.sh — worktree.sh のテスト（仕様のテスト ID: WT-T01〜WT-T12）
# 使い方: bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --filter '*test_worktree*'
# テストは set -e を使わない（終了コードは run_cmd が取る）
set -uo pipefail

# 共通ライブラリの読み込み行（20-common-step-shell-script 仕様「読み込み行」が正）。引数 <lib> <policy> だけを変え、中身を改変しない。
# shellcheck disable=SC1090,SC2317
__ss_load() { local lib="$1" pol="$2" d="${BASH_SOURCE[1]%/*}" r="" f=""; [ "$d" = "${BASH_SOURCE[1]}" ] && d="."; case "$d" in /*|[A-Za-z]:/*) ;; *) d="$PWD/$d" ;; esac; while [ -n "$d" ] && [ ! -d "$d/.claude" ]; do case "$d" in */*) d="${d%/*}" ;; *) d="" ;; esac; done; r="$d"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; if [ ! -f "$f" ] && [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then r="${CLAUDE_PROJECT_DIR//\\//}"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ ! -f "$f" ] && command -v git >/dev/null 2>&1; then r="$(git rev-parse --show-toplevel 2>/dev/null || true)"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ -n "$r" ] && [ -f "$f" ]; then LOGGER_ROOT="$r"; export LOGGER_ROOT; [ "$lib" = frontmatter ] && FM_AVAILABLE=1; . "$f"; return 0; fi; [ "$lib" = frontmatter ] && FM_AVAILABLE=0; case "$pol" in nop) LOGGER_ROOT="${r:-$PWD}"; export LOGGER_ROOT; log_debug() { :; }; log_info() { :; }; log_warn() { :; }; log_error() { :; }; fm_extract() { FM_BLOCK=""; return 2; }; fm_get() { return 2; }; fm_list() { return 2; }; fm_has() { return 2; } ;; deny) printf '%s\n' "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"${HOOK_DENY_ID:-WF009}: 機構の不調 — 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）\"}}"; exit 0 ;; *) printf '%s\n' "FATAL: 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）"; exit 2 ;; esac; }
__ss_load test-lib fatal

# 検証対象（LOGGER_ROOT はリポジトリルート）
TARGET="$LOGGER_ROOT/.claude/skills/20-common-step-worktree/scripts/worktree.sh"

# ---- 足場 ----------------------------------------------------------------
make_tmp_repo
cd "$TMP_REPO" || exit 2
# add の既定の置き場（<リポジトリの親>/<リポジトリ名>-wt）。リポジトリの外なので trap の対象に足す
WT_BASE="${TMP_REPO}-wt"
_TL_TMPS+=("$WT_BASE")
MERGE_LOG="$TMP_REPO/logs/worktree-merges.jsonl"

setup_repo() {
  mkdir -p wip/10_tickets/00_todo wip/10_tickets/10_doing wip/10_tickets/20_done wip/30_reports wip/tmp
  printf 'logs/\n' > .gitignore
  : > wip/tmp/.gitkeep
  : > wip/10_tickets/00_todo/.gitkeep
  : > wip/10_tickets/10_doing/.gitkeep
  : > wip/10_tickets/20_done/.gitkeep
  printf -- '---\ntype: ticket\nticket_type: investigation\n---\n\n# 0018 調査\n' > wip/10_tickets/00_todo/0018-investigation.md
  printf '# レポート\n\n## sec-a\n\nBASE-A\n\n## sec-b\n\nBASE-B\n' > wip/30_reports/r.md
  git add -A
  git commit -qm "chore: init"
}
setup_repo

# 指定ディレクトリを作業ディレクトリにして run_cmd する
run_in() { # $1=dir $2..=コマンド
  local d="$1" prev="$PWD"
  shift
  cd "$d" || { R_EXIT=99; R_OUT=""; R_ERR="cd failed: $d"; return 0; }
  run_cmd "$@"
  cd "$prev" || true
  return 0
}

# git の呼び出し引数を記録する PATH を作る（「git merge を 1 回も実行しない」の検査用）
make_git_recorder() {
  local dir real
  dir="$(mktemp -d)"
  _TL_TMPS+=("$dir")
  real="$(command -v git)"
  GIT_ARGS_LOG="$dir/git-args.log"
  : > "$GIT_ARGS_LOG"
  {
    printf '#!/bin/bash\n'
    printf 'printf "%%s\\n" "$*" >> "%s"\n' "$GIT_ARGS_LOG"
    printf 'exec "%s" "$@"\n' "$real"
  } > "$dir/git"
  chmod +x "$dir/git" 2>/dev/null || true
  GIT_RECORDER_PATH="$dir"
  return 0
}
make_git_recorder

# 記録つきで worktree.sh を実行する（実行のたびに記録を空にする）
run_rec() {
  : > "$GIT_ARGS_LOG"
  run_cmd env "PATH=$GIT_RECORDER_PATH:$PATH" bash "$TARGET" "$@"
  return 0
}
merge_calls() { grep -c '^merge ' "$GIT_ARGS_LOG" 2>/dev/null || true; }

last_line() { printf '%s' "${R_OUT##*$'\n'}"; }
yn() { if [ -e "$1" ]; then printf 'yes'; else printf 'no'; fi; }

# 管理対象・外部の作業ツリーをすべて片付ける（テストの後始末。git worktree remove --force は使わない）
purge_worktrees() {
  local line p="" b=""
  while IFS= read -r line; do
    case "$line" in
      "worktree "*) p="${line#worktree }" ;;
      "branch refs/heads/"*)
        b="${line#branch refs/heads/}"
        case "$b" in
          main--wt-*|worktree-*|tmpwt*)
            rm -rf "$p"
            git branch -D "$b" >/dev/null 2>&1 || true
            ;;
        esac
        ;;
    esac
  done < <(git worktree list --porcelain)
  git worktree prune >/dev/null 2>&1 || true
  return 0
}

# ---- WT-T01: add の既定の置き場・ブランチ名・logs の初期化 -----------------
case_WT_T01() {
  run_cmd bash "$TARGET" add w1
  assert_exit "WT-T01" 0
  assert_contains "WT-T01" "OK:"
  assert_eq "WT-T01" "yes" "$(yn "$WT_BASE/w1")"
  # 置き場はリポジトリの外
  local inside="no"
  case "$WT_BASE/w1" in "$TMP_REPO"/*) inside="yes" ;; esac
  assert_eq "WT-T01" "no" "$inside"
  assert_eq "WT-T01" "main--wt-w1" "$(git -C "$WT_BASE/w1" rev-parse --abbrev-ref HEAD)"
  # logs/ には hooks と sh だけ
  assert_eq "WT-T01" "hooks sh" "$(ls "$WT_BASE/w1/logs" | tr '\n' ' ' | sed 's/ *$//')"
  # 進行状態 7 種（+ review-history.jsonl）が 1 つも作られていない
  local f present=""
  for f in mr.json review-state.json review-history.jsonl merge-state.json push-state.json locks usage sessions; do
    if [ -e "$WT_BASE/w1/logs/$f" ]; then present="$present $f"; fi
  done
  assert_eq "WT-T01" "" "$present"
  # wip/tmp/.gitkeep はチェックアウトで入る
  assert_eq "WT-T01" "yes" "$(yn "$WT_BASE/w1/wip/tmp/.gitkeep")"
}

# ---- WT-T11: 本流かどうかの判定（.git がディレクトリ / ファイル） ----------
case_WT_T11() {
  assert_eq "WT-T11" "dir" "$(if [ -d "$TMP_REPO/.git" ]; then printf 'dir'; else printf 'file'; fi)"
  assert_eq "WT-T11" "file" "$(if [ -f "$WT_BASE/w1/.git" ]; then printf 'file'; else printf 'dir'; fi)"
  # 作業ツリーでも list は動く
  run_in "$WT_BASE/w1" bash "$TARGET" list
  assert_exit "WT-T11" 0
  assert_eq "WT-T11" "2" "$(printf '%s' "$R_OUT" | tl_jq -r 'length')"
  # add / merge / remove は WT001
  run_in "$WT_BASE/w1" bash "$TARGET" add w9
  assert_exit "WT-T11" 1
  assert_eq "WT-T11" "WT001" "$(printf '%s' "$(last_line)" | cut -d: -f1)"
  run_in "$WT_BASE/w1" bash "$TARGET" merge w1
  assert_exit "WT-T11" 1
  assert_eq "WT-T11" "WT001" "$(printf '%s' "$(last_line)" | cut -d: -f1)"
  run_in "$WT_BASE/w1" bash "$TARGET" remove w1
  assert_exit "WT-T11" 1
  assert_eq "WT-T11" "WT001" "$(printf '%s' "$(last_line)" | cut -d: -f1)"
}

# ---- WT-T02: add の WT002 4 経路 と WT008 -------------------------------
case_WT_T02() {
  # (a) 置き場がリポジトリの配下
  run_cmd bash "$TARGET" add w2 "$TMP_REPO/sub"
  assert_exit "WT-T02" 1
  assert_contains "WT-T02" "WT002:"
  assert_contains "WT-T02" "リポジトリの配下"
  # (b) 置き場が既に存在する
  mkdir -p "$WT_BASE/w3"
  run_cmd bash "$TARGET" add w3
  assert_exit "WT-T02" 1
  assert_contains "WT-T02" "既に存在"
  rm -rf "$WT_BASE/w3"
  # (c) 同名のブランチが既にある
  git branch main--wt-w4 >/dev/null 2>&1
  run_cmd bash "$TARGET" add w4
  assert_exit "WT-T02" 1
  assert_contains "WT-T02" "同名のブランチ"
  git branch -D main--wt-w4 >/dev/null 2>&1
  # (d) 同名の作業ツリーが既に登録されている（実体だけ消した状態）
  git worktree add -q -b tmpwt5 "$WT_BASE/w5" >/dev/null 2>&1
  rm -rf "$WT_BASE/w5"
  run_cmd bash "$TARGET" add w5
  assert_exit "WT-T02" 1
  assert_contains "WT-T02" "作業ツリーが既に登録"
  git worktree prune >/dev/null 2>&1
  git branch -D tmpwt5 >/dev/null 2>&1
  # (d') 相対パスの <置き場> でも登録と照合できる。Git Bash では同じディレクトリが /tmp/x と C:/…/x の
  # 2 通りに綴られるので、$PWD 基準の綴りのままだと git worktree list 由来の登録と一致せず (d) を素通りする
  git worktree add -q -b tmpwt7 "$WT_BASE/w7" >/dev/null 2>&1
  rm -rf "$WT_BASE/w7"
  run_cmd bash "$TARGET" add w7 "../${TMP_REPO##*/}-wt/w7"
  assert_exit "WT-T02" 1
  assert_contains "WT-T02" "作業ツリーが既に登録"
  git worktree prune >/dev/null 2>&1
  git branch -D tmpwt7 >/dev/null 2>&1
  # <名前> の形式違反は WT008・終了 2
  run_cmd bash "$TARGET" add Bad_Name
  assert_exit "WT-T02" 2
  assert_eq "WT-T02" "WT008" "$(printf '%s' "$(last_line)" | cut -d: -f1)"
  # detached HEAD も WT008・終了 2
  git checkout -q --detach HEAD
  run_cmd bash "$TARGET" add w6
  assert_exit "WT-T02" 2
  assert_eq "WT-T02" "WT008" "$(printf '%s' "$(last_line)" | cut -d: -f1)"
  git checkout -q main
}

# ---- WT-T03: list の JSON ------------------------------------------------
case_WT_T03() {
  # 外部の仕組みが作った作業ツリー（worktree-<名前> ブランチ）
  git worktree add -q -b worktree-x "$WT_BASE/ext-x" >/dev/null 2>&1
  # w1 を作業中 1 枚 + 未コミットにする
  mv "$WT_BASE/w1/wip/10_tickets/00_todo/0018-investigation.md" "$WT_BASE/w1/wip/10_tickets/10_doing/0018-investigation.md"
  run_cmd bash "$TARGET" list
  assert_exit "WT-T03" 0
  local json="$R_OUT"
  mapfile -t v < <(printf '%s' "$json" | tl_jq -r '[
      (length|tostring),
      (.[0].main|tostring), (.[0].managed|tostring), (.[0].doing|length|tostring), (.[0].dirty|tostring),
      ((.[]|select(.branch=="main--wt-w1"))|.managed|tostring),
      ((.[]|select(.branch=="main--wt-w1"))|.dirty|tostring),
      ((.[]|select(.branch=="main--wt-w1"))|.doing[0].ticket),
      ((.[]|select(.branch=="main--wt-w1"))|.doing[0].type),
      ((.[]|select(.branch=="worktree-x"))|.managed|tostring),
      ((.[]|select(.branch=="worktree-x"))|.dirty|tostring)
    ] | .[]')
  assert_eq "WT-T03" "3" "${v[0]:-}"
  assert_eq "WT-T03" "true" "${v[1]:-}"      # 本流が先頭で main:true
  assert_eq "WT-T03" "false" "${v[2]:-}"     # 本流は managed:false
  assert_eq "WT-T03" "0" "${v[3]:-}"         # 本流の doing は空配列
  assert_eq "WT-T03" "false" "${v[4]:-}"     # 本流は dirty:false
  assert_eq "WT-T03" "true" "${v[5]:-}"      # w1 は managed:true
  assert_eq "WT-T03" "true" "${v[6]:-}"      # w1 は dirty:true
  assert_eq "WT-T03" "0018" "${v[7]:-}"
  assert_eq "WT-T03" "investigation" "${v[8]:-}"
  assert_eq "WT-T03" "false" "${v[9]:-}"     # 外部の worktree-x は managed:false
  assert_eq "WT-T03" "false" "${v[10]:-}"
}

# ---- WT-T09: 対象が見つからない / 管理対象外は WT005 ----------------------
case_WT_T09() {
  run_cmd bash "$TARGET" merge nosuch
  assert_exit "WT-T09" 1
  assert_eq "WT-T09" "WT005" "$(printf '%s' "$(last_line)" | cut -d: -f1)"
  run_cmd bash "$TARGET" merge worktree-x
  assert_exit "WT-T09" 1
  assert_eq "WT-T09" "WT005" "$(printf '%s' "$(last_line)" | cut -d: -f1)"
  assert_contains "WT-T09" "管理対象外"
  run_cmd bash "$TARGET" remove worktree-x
  assert_exit "WT-T09" 1
  assert_eq "WT-T09" "WT005" "$(printf '%s' "$(last_line)" | cut -d: -f1)"
  run_cmd bash "$TARGET" remove nosuch
  assert_exit "WT-T09" 1
  assert_eq "WT-T09" "WT005" "$(printf '%s' "$(last_line)" | cut -d: -f1)"
}

# ---- WT-T10: 引数・環境の誤りは WT008・終了 2 -----------------------------
case_WT_T10() {
  run_cmd bash "$TARGET" bogus
  assert_exit "WT-T10" 2
  assert_eq "WT-T10" "WT008" "$(printf '%s' "$(last_line)" | cut -d: -f1)"
  run_cmd bash "$TARGET" list --oops
  assert_exit "WT-T10" 2
  assert_eq "WT-T10" "WT008" "$(printf '%s' "$(last_line)" | cut -d: -f1)"
  run_cmd bash "$TARGET" merge w1 -m
  assert_exit "WT-T10" 2
  assert_eq "WT-T10" "WT008" "$(printf '%s' "$(last_line)" | cut -d: -f1)"
  run_cmd bash "$TARGET" merge w1 --all
  assert_exit "WT-T10" 2
  assert_eq "WT-T10" "WT008" "$(printf '%s' "$(last_line)" | cut -d: -f1)"
  assert_contains "WT-T10" "同時に指定"
  # jq 不在
  make_restricted_path bash git mkdir cat sed grep tr
  run_cmd env "PATH=$RESTRICTED_PATH" bash "$TARGET" list
  assert_exit "WT-T10" 2
  assert_eq "WT-T10" "WT008" "$(printf '%s' "$(last_line)" | cut -d: -f1)"
  assert_contains "WT-T10" "jq"
}

# ---- WT-T04: merge の成功と冪等 ------------------------------------------
case_WT_T04() {
  run_cmd bash "$TARGET" add m1
  assert_exit "WT-T04" 0
  # 作業ツリー側でチケットを 00_todo → 20_done に移し、レポートに追記してコミットする
  mv "$WT_BASE/m1/wip/10_tickets/00_todo/0018-investigation.md" "$WT_BASE/m1/wip/10_tickets/20_done/0018-investigation.md"
  printf '\n追記-m1\n' >> "$WT_BASE/m1/wip/30_reports/r.md"
  git -C "$WT_BASE/m1" add -A
  git -C "$WT_BASE/m1" commit -qm "chore: m1 の成果"
  local before
  before="$(git rev-parse HEAD)"
  run_cmd bash "$TARGET" merge m1
  assert_exit "WT-T04" 0
  assert_contains "WT-T04" "OK:"
  # --no-ff のマージコミット（親が 2 つ）で、件名は chore: で始まる
  assert_eq "WT-T04" "3" "$(git rev-list --parents -1 HEAD | wc -w | tr -d ' ')"
  assert_eq "WT-T04" "chore: 作業ツリー m1 の成果を合流する" "$(git log -1 --format=%s)"
  # チケットの移動とレポートの追記が両方入る
  assert_eq "WT-T04" "yes" "$(yn "$TMP_REPO/wip/10_tickets/20_done/0018-investigation.md")"
  assert_eq "WT-T04" "no" "$(yn "$TMP_REPO/wip/10_tickets/00_todo/0018-investigation.md")"
  assert_eq "WT-T04" "1" "$(grep -c '追記-m1' "$TMP_REPO/wip/30_reports/r.md" | tr -d ' ')"
  # 合流の記録が 1 行だけ増え、result / tickets が入る
  assert_eq "WT-T04" "1" "$(grep -c . "$MERGE_LOG" | tr -d ' ')"
  mapfile -t r < <(tl_jq -r '[.result, (.tickets|join(",")), .worktree, .into, (.merge_commit|length|tostring), (.conflicts|length|tostring)] | .[]' < "$MERGE_LOG")
  assert_eq "WT-T04" "merged" "${r[0]:-}"
  assert_eq "WT-T04" "0018" "${r[1]:-}"
  assert_eq "WT-T04" "m1" "${r[2]:-}"
  assert_eq "WT-T04" "main" "${r[3]:-}"
  assert_eq "WT-T04" "7" "${r[4]:-}"
  assert_eq "WT-T04" "0" "${r[5]:-}"
  # 二度目は up-to-date で成功（冪等）。HEAD は動かない
  local after1
  after1="$(git rev-parse HEAD)"
  run_cmd bash "$TARGET" merge m1
  assert_exit "WT-T04" 0
  assert_contains "WT-T04" "取り込み済み"
  assert_eq "WT-T04" "$after1" "$(git rev-parse HEAD)"
  assert_eq "WT-T04" "2" "$(grep -c . "$MERGE_LOG" | tr -d ' ')"
  assert_eq "WT-T04" "up-to-date" "$(tail -n 1 "$MERGE_LOG" | tl_jq -r '.result')"
  assert_eq "WT-T04" "$before" "$(git rev-parse 'HEAD^1')"
}

# ---- WT-T07: remove が作業ツリーとブランチを消す --------------------------
case_WT_T07() {
  run_cmd bash "$TARGET" remove m1
  assert_exit "WT-T07" 0
  assert_contains "WT-T07" "OK:"
  assert_eq "WT-T07" "no" "$(yn "$WT_BASE/m1")"
  assert_eq "WT-T07" "0" "$(git worktree list --porcelain | grep -c 'main--wt-m1' | tr -d ' ')"
  assert_eq "WT-T07" "0" "$(git branch --list 'main--wt-m1' | grep -c . | tr -d ' ')"
}

# ---- WT-T05: merge の前提検査（git merge を 1 回も実行しない） -------------
case_WT_T05() {
  run_cmd bash "$TARGET" add p1
  assert_exit "WT-T05" 0
  # 1) 本流に未コミットの変更（項目 2）
  printf 'dirty-main\n' >> "$TMP_REPO/wip/30_reports/r.md"
  run_rec merge p1
  assert_exit "WT-T05" 1
  assert_eq "WT-T05" "WT003" "$(printf '%s' "$(last_line)" | cut -d: -f1)"
  assert_contains "WT-T05" "本流に未コミット"
  assert_eq "WT-T05" "0" "$(merge_calls)"
  git checkout -q -- wip/30_reports/r.md
  # 2) 本流に作業中チケット（項目 3）
  printf -- '---\ntype: ticket\nticket_type: design\n---\n\n# 0099\n' > "$TMP_REPO/wip/10_tickets/10_doing/0099-design.md"
  git add -A && git commit -qm "chore: 0099 に着手"
  run_rec merge p1
  assert_exit "WT-T05" 1
  assert_eq "WT-T05" "WT003" "$(printf '%s' "$(last_line)" | cut -d: -f1)"
  assert_contains "WT-T05" "本流に作業中チケット"
  assert_contains "WT-T05" "0099"
  assert_eq "WT-T05" "0" "$(merge_calls)"
  git rm -q "$TMP_REPO/wip/10_tickets/10_doing/0099-design.md" && git commit -qm "chore: 0099 を完了"
  # 3) 対象に未コミットの変更（項目 4）
  printf 'dirty-p1\n' >> "$WT_BASE/p1/wip/30_reports/r.md"
  run_rec merge p1
  assert_exit "WT-T05" 1
  assert_eq "WT-T05" "WT003" "$(printf '%s' "$(last_line)" | cut -d: -f1)"
  assert_contains "WT-T05" "p1 に未コミット"
  assert_eq "WT-T05" "0" "$(merge_calls)"
  git -C "$WT_BASE/p1" checkout -q -- wip/30_reports/r.md
  # 4) 対象に作業中チケット（項目 5）
  printf -- '---\ntype: ticket\nticket_type: design\n---\n\n# 0098\n' > "$WT_BASE/p1/wip/10_tickets/10_doing/0098-design.md"
  git -C "$WT_BASE/p1" add -A && git -C "$WT_BASE/p1" commit -qm "chore: 0098 に着手"
  run_rec merge p1
  assert_exit "WT-T05" 1
  assert_eq "WT-T05" "WT003" "$(printf '%s' "$(last_line)" | cut -d: -f1)"
  assert_contains "WT-T05" "p1 に作業中チケット"
  assert_eq "WT-T05" "0" "$(merge_calls)"
  git -C "$WT_BASE/p1" rm -q wip/10_tickets/10_doing/0098-design.md
  git -C "$WT_BASE/p1" commit -qm "chore: 0098 を完了"
  # 5) 別 issue のブランチ（項目 6）— 管理対象外なので WT005
  run_rec merge worktree-x
  assert_exit "WT-T05" 1
  assert_eq "WT-T05" "WT005" "$(printf '%s' "$(last_line)" | cut -d: -f1)"
  assert_eq "WT-T05" "0" "$(merge_calls)"
  # 6) 作業ツリーからの実行（項目 1）は WT001
  local prev="$PWD"
  cd "$WT_BASE/p1" || exit 2
  : > "$GIT_ARGS_LOG"
  run_cmd env "PATH=$GIT_RECORDER_PATH:$PATH" bash "$TARGET" merge --all
  cd "$prev" || exit 2
  assert_exit "WT-T05" 1
  assert_eq "WT-T05" "WT001" "$(printf '%s' "$(last_line)" | cut -d: -f1)"
  assert_eq "WT-T05" "0" "$(merge_calls)"
  # 7) 複数が同時に未充足なら全件列挙され、--all で 1 つも合流しない
  printf 'dirty-main\n' >> "$TMP_REPO/wip/30_reports/r.md"
  printf 'dirty-p1\n' >> "$WT_BASE/p1/wip/30_reports/r.md"
  local head_before
  head_before="$(git rev-parse HEAD)"
  run_rec merge --all
  assert_exit "WT-T05" 1
  assert_eq "WT-T05" "WT003" "$(printf '%s' "$(last_line)" | cut -d: -f1)"
  assert_contains "WT-T05" "本流に未コミット"
  assert_contains "WT-T05" "p1 に未コミット"
  assert_eq "WT-T05" "0" "$(merge_calls)"
  assert_eq "WT-T05" "$head_before" "$(git rev-parse HEAD)"
  git checkout -q -- wip/30_reports/r.md
  git -C "$WT_BASE/p1" checkout -q -- wip/30_reports/r.md
  # 正のコントロール: 前提が揃えば git merge が実行される
  run_rec merge p1
  assert_exit "WT-T05" 0
  assert_eq "WT-T05" "1" "$(merge_calls)"
}

# ---- WT-T06: 衝突は WT004 で中断し合流前に戻る ----------------------------
case_WT_T06() {
  run_cmd bash "$TARGET" add c1
  assert_exit "WT-T06" 0
  # 同じ行を双方で書き換える
  sed -i 's/^BASE-A$/A-from-c1/' "$WT_BASE/c1/wip/30_reports/r.md"
  git -C "$WT_BASE/c1" add -A && git -C "$WT_BASE/c1" commit -qm "chore: c1"
  sed -i 's/^BASE-A$/A-from-main/' "$TMP_REPO/wip/30_reports/r.md"
  git add -A && git commit -qm "chore: main 側の変更"
  local head_before lines_before
  head_before="$(git rev-parse HEAD)"
  lines_before="$(grep -c . "$MERGE_LOG" | tr -d ' ')"
  run_cmd bash "$TARGET" merge c1
  assert_exit "WT-T06" 1
  assert_eq "WT-T06" "WT004" "$(printf '%s' "$(last_line)" | cut -d: -f1)"
  assert_contains "WT-T06" "wip/30_reports/r.md"
  # --abort 済みで本流が合流前と同一
  assert_eq "WT-T06" "$head_before" "$(git rev-parse HEAD)"
  assert_eq "WT-T06" "" "$(git status --porcelain)"
  # 記録に aborted が 1 行残る
  assert_eq "WT-T06" "$((lines_before + 1))" "$(grep -c . "$MERGE_LOG" | tr -d ' ')"
  mapfile -t a < <(tail -n 1 "$MERGE_LOG" | tl_jq -r '[.result, .merge_commit, (.conflicts|join(","))] | .[]')
  assert_eq "WT-T06" "aborted" "${a[0]:-}"
  assert_eq "WT-T06" "" "${a[1]:-}"
  assert_eq "WT-T06" "wip/30_reports/r.md" "${a[2]:-}"
  # 負のコントロール: 別の節の追記だけなら衝突せず成功する
  run_cmd bash "$TARGET" add c2
  assert_exit "WT-T06" 0
  printf '\nC2-ADD\n' >> "$WT_BASE/c2/wip/30_reports/r.md"
  git -C "$WT_BASE/c2" add -A && git -C "$WT_BASE/c2" commit -qm "chore: c2"
  run_cmd bash "$TARGET" merge c2
  assert_exit "WT-T06" 0
  assert_contains "WT-T06" "OK:"
  assert_eq "WT-T06" "1" "$(grep -c 'C2-ADD' "$TMP_REPO/wip/30_reports/r.md" | tr -d ' ')"
  # 記録の 1 行の上限は**バイト**（フック共通仕様 §5）。日本語のパスは 1 文字 3 バイトなので、
  # 文字数で見ていると 4096 文字未満のまま 4 KB を超える行が出る
  local i nm dir="wip/30_reports/衝突検査用の置き場" line bytes chars
  # 非 ASCII のパスを 8 進エスケープせずそのまま出す設定。既定（quotePath=true）だと
  # 記録の行が ASCII だけになり、バイト数と文字数が食い違わない
  git config core.quotePath false
  mkdir -p "$dir"
  for ((i = 1; i <= 40; i++)); do
    printf 'BASE\n' > "$dir/日本語の名前がとても長い衝突するレポートのファイル-$i.md"
  done
  git add -A && git commit -qm "chore: バイト長の検査の下ごしらえ"
  run_cmd bash "$TARGET" add c3
  assert_exit "WT-T06" 0
  for ((i = 1; i <= 40; i++)); do
    nm="$dir/日本語の名前がとても長い衝突するレポートのファイル-$i.md"
    printf 'C3\n' > "$WT_BASE/c3/$nm"
    printf 'MAIN\n' > "$TMP_REPO/$nm"
  done
  git -C "$WT_BASE/c3" add -A && git -C "$WT_BASE/c3" commit -qm "chore: c3"
  git add -A && git commit -qm "chore: 本流側の変更"
  # UTF-8 のロケールで走らせる。C ロケールでは bash の ${#x} がそもそもバイト数を返すので、
  # 文字数とバイト数の食い違いが起きず、この検査が空振りする（前提を下で assert する）
  assert_eq "WT-T06" "3" "$( export LC_ALL=C.UTF-8; y="あああ"; printf '%s' "${#y}" )"
  run_cmd env LC_ALL=C.UTF-8 bash "$TARGET" merge c3
  assert_exit "WT-T06" 1
  assert_eq "WT-T06" "WT004" "$(printf '%s' "$(last_line)" | cut -d: -f1)"
  line="$(tail -n 1 "$MERGE_LOG")"
  bytes="$(printf '%s' "$line" | LC_ALL=C wc -c | tr -d ' ')"
  chars="$( export LC_ALL=C.UTF-8; printf '%s' "${#line}" )"
  # 前提: 文字数では上限に達していない（バイトで見ないと切り詰めが起きない足場であること）
  assert_eq "WT-T06" "under" "$(if [ "$chars" -lt 4096 ]; then printf 'under'; else printf 'over'; fi)"
  assert_eq "WT-T06" "under" "$(if [ "$bytes" -lt 4096 ]; then printf 'under'; else printf 'over'; fi)"
  # 切り詰めた印が末尾に入る
  assert_eq "WT-T06" "…" "$(printf '%s' "$line" | tl_jq -r '.conflicts[-1]')"
}

# ---- WT-T08: remove の前提未充足 -----------------------------------------
case_WT_T08() {
  run_cmd bash "$TARGET" add r1
  assert_exit "WT-T08" 0
  # 未コミットの差分は --force でも消さない
  printf 'uncommitted\n' >> "$WT_BASE/r1/wip/30_reports/r.md"
  run_cmd bash "$TARGET" remove r1
  assert_exit "WT-T08" 1
  assert_eq "WT-T08" "WT006" "$(printf '%s' "$(last_line)" | cut -d: -f1)"
  assert_contains "WT-T08" "未コミット"
  run_cmd bash "$TARGET" remove r1 --force
  assert_exit "WT-T08" 1
  assert_eq "WT-T08" "WT006" "$(printf '%s' "$(last_line)" | cut -d: -f1)"
  assert_eq "WT-T08" "yes" "$(yn "$WT_BASE/r1")"
  # 未合流のコミットは --force のときだけ、失われるコミット数を出して消える
  git -C "$WT_BASE/r1" add -A && git -C "$WT_BASE/r1" commit -qm "chore: r1 未合流"
  run_cmd bash "$TARGET" remove r1
  assert_exit "WT-T08" 1
  assert_eq "WT-T08" "WT006" "$(printf '%s' "$(last_line)" | cut -d: -f1)"
  assert_contains "WT-T08" "合流していないコミット"
  run_cmd bash "$TARGET" remove r1 --force
  assert_exit "WT-T08" 0
  assert_contains "WT-T08" "1 件"
  assert_eq "WT-T08" "no" "$(yn "$WT_BASE/r1")"
  assert_eq "WT-T08" "0" "$(git branch --list 'main--wt-r1' | grep -c . | tr -d ' ')"
}

# ---- WT-T12: merge --all は順に合流し、衝突でそこで止める ------------------
case_WT_T12() {
  purge_worktrees
  run_cmd bash "$TARGET" add a1
  assert_exit "WT-T12" 0
  run_cmd bash "$TARGET" add a2
  assert_exit "WT-T12" 0
  sed -i 's/^BASE-B$/B-from-a1/' "$WT_BASE/a1/wip/30_reports/r.md"
  git -C "$WT_BASE/a1" add -A && git -C "$WT_BASE/a1" commit -qm "chore: a1"
  sed -i 's/^BASE-B$/B-from-a2/' "$WT_BASE/a2/wip/30_reports/r.md"
  git -C "$WT_BASE/a2" add -A && git -C "$WT_BASE/a2" commit -qm "chore: a2"
  local lines_before
  lines_before="$(grep -c . "$MERGE_LOG" | tr -d ' ')"
  run_cmd bash "$TARGET" merge --all
  assert_exit "WT-T12" 1
  assert_eq "WT-T12" "WT004" "$(printf '%s' "$(last_line)" | cut -d: -f1)"
  # 合流できた対象と残っている対象が分かれて出る
  assert_contains "WT-T12" "合流できた:"
  assert_contains "WT-T12" "未処理:"
  # 記録は 2 行増え、merged 1 件・aborted 1 件
  assert_eq "WT-T12" "$((lines_before + 2))" "$(grep -c . "$MERGE_LOG" | tr -d ' ')"
  assert_eq "WT-T12" "1" "$(tail -n 2 "$MERGE_LOG" | tl_jq -r '.result' | grep -c '^merged$' | tr -d ' ')"
  assert_eq "WT-T12" "1" "$(tail -n 2 "$MERGE_LOG" | tl_jq -r '.result' | grep -c '^aborted$' | tr -d ' ')"
  # 中断後、本流は片方だけ取り込んだ状態でクリーン
  assert_eq "WT-T12" "" "$(git status --porcelain)"
}

case_WT_T01
case_WT_T11
case_WT_T02
case_WT_T03
case_WT_T09
case_WT_T10
case_WT_T04
case_WT_T07
case_WT_T05
case_WT_T06
case_WT_T08
case_WT_T12
purge_worktrees
finish
