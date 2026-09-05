#!/usr/bin/env bash
# worktree.sh — 作業ツリーの作成・一覧・合流・片付け（提供コマンド）
# 仕様: .claude/docs/10_spec/skills/20-common-step-worktree.md「Script 処理」（判定順・エラー識別子の正）
# 使い方: bash .claude/skills/20-common-step-worktree/scripts/worktree.sh <add|list|merge|remove> [args]
#   add <名前> [<置き場>] / list / merge <名前>|<サブブランチ名>|--all [-m <件名>] / remove <名前>|<置き場> [--force]
# 終了コード: 成功 0 / 前提・状態の未充足 1 / 引数や環境の誤り 2。最終行は `OK: ...` または `WT<番号>: ...`（list は JSON）
set -euo pipefail

# 共通ライブラリの読み込み行（20-common-step-shell-script 仕様「読み込み行」が正）。引数 <lib> <policy> だけを変え、中身を改変しない。
# shellcheck disable=SC1090,SC2317
__ss_load() { local lib="$1" pol="$2" d="${BASH_SOURCE[1]%/*}" r="" f=""; [ "$d" = "${BASH_SOURCE[1]}" ] && d="."; case "$d" in /*|[A-Za-z]:/*) ;; *) d="$PWD/$d" ;; esac; while [ -n "$d" ] && [ ! -d "$d/.claude" ]; do case "$d" in */*) d="${d%/*}" ;; *) d="" ;; esac; done; r="$d"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; if [ ! -f "$f" ] && [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then r="${CLAUDE_PROJECT_DIR//\\//}"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ ! -f "$f" ] && command -v git >/dev/null 2>&1; then r="$(git rev-parse --show-toplevel 2>/dev/null || true)"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ -n "$r" ] && [ -f "$f" ]; then LOGGER_ROOT="$r"; export LOGGER_ROOT; [ "$lib" = frontmatter ] && FM_AVAILABLE=1; . "$f"; return 0; fi; [ "$lib" = frontmatter ] && FM_AVAILABLE=0; case "$pol" in nop) LOGGER_ROOT="${r:-$PWD}"; export LOGGER_ROOT; log_debug() { :; }; log_info() { :; }; log_warn() { :; }; log_error() { :; }; fm_extract() { FM_BLOCK=""; return 2; }; fm_get() { return 2; }; fm_list() { return 2; }; fm_has() { return 2; } ;; deny) printf '%s\n' "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"${HOOK_DENY_ID:-WF009}: 機構の不調 — 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）\"}}"; exit 0 ;; *) printf '%s\n' "FATAL: 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）"; exit 2 ;; esac; }
__ss_load logger nop
__ss_load frontmatter fatal

readonly SCRIPT_PREFIX="WT"
readonly DOING_REL="wip/10_tickets/10_doing"
readonly MERGE_LOG_REL="logs/worktree-merges.jsonl"
readonly MERGE_LOG_MAX=4096        # 1 行の上限（フック共通仕様 §5 の並行書き込みの規則）
readonly WT_MARK="--wt-"           # サブブランチの区切り（feature ブランチ名に現れない）

# 解決結果（共通の入口）
WT_ROOT=""       # 現在のチェックアウトのルート
MAIN_ROOT=""     # 本流（共有ルート）のルート
MAIN_BRANCH=""   # 本流の現在ブランチ（detached なら空）
PREFIX_BRANCH="" # <本流の現在ブランチ>--wt-
IS_MAIN=0

usage() {
  cat <<'USAGE'
使い方: bash .claude/skills/20-common-step-worktree/scripts/worktree.sh <subcommand> [args]
  add <名前> [<置き場>]                          作業ツリーを切る（本流でのみ）
  list                                            全作業ツリーを JSON 配列で返す（本流・作業ツリーのどちらでも）
  merge <名前>|<サブブランチ名>|--all [-m <件名>]  成果を本流へ合流する（本流でのみ）
  remove <名前>|<置き場> [--force]                作業ツリーとサブブランチを片付ける（本流でのみ）
USAGE
}

result_ok() { log_info "OK: $1"; printf 'OK: %s\n' "$1"; exit 0; }
result_ng() { log_warn "${SCRIPT_PREFIX}$1: $2"; printf '%s%s: %s\n' "$SCRIPT_PREFIX" "$1" "$2"; exit "$3"; }

now_iso() { local ts; printf -v ts '%(%Y-%m-%dT%H:%M:%S%z)T' -1; printf '%s:%s' "${ts:0:22}" "${ts:22}"; }

# パスを正規化した絶対パスにする（存在しなくてよい。. と .. を畳む）
abs_path() { # $1=path
  local p="$1" prefix="" out="" seg
  case "$p" in
    [A-Za-z]:/*) prefix="${p:0:2}"; p="${p:2}" ;;
    /*) ;;
    *) p="$PWD/$p" ;;
  esac
  while [ -n "$p" ]; do
    seg="${p%%/*}"
    if [ "$seg" = "$p" ]; then p=""; else p="${p#*/}"; fi
    case "$seg" in
      ''|'.') continue ;;
      '..') out="${out%/*}" ;;
      *) out="$out/$seg" ;;
    esac
  done
  printf '%s%s' "$prefix" "${out:-/}"
}

is_under() { # $1=path $2=base（同一も配下とみなす）
  case "$1" in "$2") return 0 ;; "$2"/*) return 0 ;; *) return 1 ;; esac
}

# 与えられたパスがこのリポジトリ（本流または同じリポジトリの作業ツリー）の配下かを判定する。
# 文字列の前方一致では見分けられない（Windows の Git Bash では同じディレクトリが /tmp/x と /c/Users/.../x の
# 2 通りに綴られる）ので、存在する最深の祖先を git 自身に解決させて綴りを揃えてから比べる。
is_under_repo() { # $1=絶対パス（存在しなくてよい）
  local d="$1" top i
  while [ -n "$d" ] && [ "$d" != "/" ] && [ ! -d "$d" ]; do
    d="${d%/*}"
    [ -n "$d" ] || d="/"
  done
  [ -d "$d" ] || return 1
  top="$(git -C "$d" rev-parse --show-toplevel 2>/dev/null || true)"
  [ -n "$top" ] || return 1
  top="$(abs_path "$top")"
  [ "$top" = "$MAIN_ROOT" ] && return 0
  [ "$top" = "$WT_ROOT" ] && return 0
  for ((i = 0; i < ${#WL_PATHS[@]}; i++)); do
    if [ "$top" = "${WL_PATHS[$i]}" ]; then return 0; fi
  done
  return 1
}

# ユーザーが与えたパスを git 目線の綴りに揃える（存在しなければそのまま）
canon_worktree_path() { # $1=パス
  local p top
  p="$(abs_path "$1")"
  [ -d "$p" ] || { printf '%s' "$p"; return 0; }
  top="$(git -C "$p" rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -n "$top" ]; then abs_path "$top"; else printf '%s' "$p"; fi
}

join_by() { # $1=区切り $2..=要素
  local sep="$1" out="" e
  shift
  for e in "$@"; do
    if [ -z "$out" ]; then out="$e"; else out="$out$sep$e"; fi
  done
  printf '%s' "$out"
}

# ---- 共通の入口 -----------------------------------------------------------

require_env() {
  command -v git >/dev/null 2>&1 || result_ng "008" "git が見つからない。git を PATH に置いてから実行すること" 2
  command -v jq >/dev/null 2>&1 || result_ng "008" "jq が見つからない。jq を PATH に置いてから実行すること" 2
}

# 本流かどうかの判定（この節が仕様の正）: リポジトリルート直下の .git がディレクトリなら本流、ファイルなら作業ツリー。
# ticket.sh / push.sh もこの判定を使い、各コマンドで作り直さない。
wt_is_main_root() { # $1=リポジトリルート
  [ -d "$1/.git" ]
}

resolve_roots() {
  local top common
  top="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  [ -n "$top" ] || result_ng "008" "リポジトリルートへ移れない。git リポジトリの中で実行すること" 2
  WT_ROOT="$(abs_path "$top")"
  cd "$WT_ROOT" || result_ng "008" "リポジトリルートへ移れない: $WT_ROOT" 2
  if wt_is_main_root "$WT_ROOT"; then IS_MAIN=1; else IS_MAIN=0; fi
  common="$(git rev-parse --git-common-dir 2>/dev/null || true)"
  [ -n "$common" ] || common=".git"
  case "$common" in /*|[A-Za-z]:/*) ;; *) common="$WT_ROOT/$common" ;; esac
  common="$(abs_path "$common")"
  MAIN_ROOT="${common%/.git}"
  [ -n "$MAIN_ROOT" ] || MAIN_ROOT="$WT_ROOT"
  MAIN_BRANCH="$(git -C "$MAIN_ROOT" symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
  PREFIX_BRANCH="${MAIN_BRANCH}${WT_MARK}"
  log_debug "roots wt=$WT_ROOT main=$MAIN_ROOT branch=${MAIN_BRANCH:-<detached>} is_main=$IS_MAIN"
}

require_main() { # $1=サブコマンド名
  [ "$IS_MAIN" = 1 ] && return 0
  result_ng "001" "$1 は本流でのみ実行できる（現在: $WT_ROOT / 本流: $MAIN_ROOT）。本流を作業ディレクトリにして実行し直すこと" 1
}

require_branch() {
  [ -n "$MAIN_BRANCH" ] && return 0
  result_ng "008" "本流が detached HEAD でブランチ名を決められない。feature ブランチをチェックアウトしてから実行すること" 2
}

# ---- 作業ツリーの一覧（生データ） ------------------------------------------

WL_PATHS=()
WL_BRANCHES=()

load_worktrees() {
  local line
  WL_PATHS=()
  WL_BRANCHES=()
  while IFS= read -r line; do
    case "$line" in
      "worktree "*)
        WL_PATHS+=("$(abs_path "${line#worktree }")")
        WL_BRANCHES+=("")
        ;;
      "branch refs/heads/"*)
        if [ "${#WL_BRANCHES[@]}" -gt 0 ]; then
          WL_BRANCHES[$(( ${#WL_BRANCHES[@]} - 1 ))]="${line#branch refs/heads/}"
        fi
        ;;
    esac
  done < <(git worktree list --porcelain)
  return 0
}

is_managed_branch() { # $1=ブランチ名
  [ -n "$MAIN_BRANCH" ] || return 1
  [ -n "$1" ] || return 1
  case "$1" in "$PREFIX_BRANCH"*) return 0 ;; *) return 1 ;; esac
}

wt_name_of() { # $1=ブランチ名 → --wt- の後ろ
  printf '%s' "${1#"$PREFIX_BRANCH"}"
}

worktree_index_by_path() { # $1=絶対パス → 見つかれば添字を出力して 0
  local i
  for ((i = 0; i < ${#WL_PATHS[@]}; i++)); do
    if [ "${WL_PATHS[$i]}" = "$1" ]; then printf '%s' "$i"; return 0; fi
  done
  return 1
}

worktree_index_by_branch() { # $1=ブランチ名 → 見つかれば添字を出力して 0
  local i
  [ -n "$1" ] || return 1
  for ((i = 0; i < ${#WL_BRANCHES[@]}; i++)); do
    if [ "${WL_BRANCHES[$i]}" = "$1" ]; then printf '%s' "$i"; return 0; fi
  done
  return 1
}

# <path>/wip/10_tickets/10_doing/ の作業中チケットを "0018:investigation,0019:design" の形で返す
doing_pairs() { # $1=作業ツリーのルート
  local d="$1/$DOING_REL" f base num type out=""
  [ -d "$d" ] || { printf ''; return 0; }
  shopt -s nullglob
  for f in "$d"/*.md; do
    base="${f##*/}"
    num="${base:0:4}"
    case "$num" in [0-9][0-9][0-9][0-9]) ;; *) continue ;; esac
    type="$(fm_get "$f" ticket_type 2>/dev/null || true)"
    out="$out,$num:$type"
  done
  shopt -u nullglob
  printf '%s' "${out#,}"
}

doing_numbers() { # $1=作業ツリーのルート → "0018 0019"
  local pairs p out=""
  pairs="$(doing_pairs "$1")"
  [ -n "$pairs" ] || { printf ''; return 0; }
  local IFS=','
  for p in $pairs; do out="$out ${p%%:*}"; done
  printf '%s' "${out# }"
}

dirty_files() { # $1=作業ツリーのルート → "a.md b.md"（空なら空）
  local st
  st="$(git -C "$1" status --porcelain 2>/dev/null || true)"
  [ -n "$st" ] || { printf ''; return 0; }
  printf '%s' "$(printf '%s\n' "$st" | cut -c4- | tr '\n' ' ')"
}

# ---- add ------------------------------------------------------------------

cmd_add() {
  local positional=() name dest default_dest branch parent out
  while [ $# -gt 0 ]; do
    case "$1" in
      -*) result_ng "008" "不明なオプション: $1（使い方: add <名前> [<置き場>]）" 2 ;;
      *) positional+=("$1") ;;
    esac
    shift
  done
  [ "${#positional[@]}" -ge 1 ] || result_ng "008" "add には <名前> が要る（使い方: add <名前> [<置き場>]）" 2
  [ "${#positional[@]}" -le 2 ] || result_ng "008" "add の引数が多い: ${positional[*]:-}（使い方: add <名前> [<置き場>]）" 2
  name="${positional[0]}"
  dest="${positional[1]:-}"
  case "$name" in
    [a-z0-9]*) ;;
    *) result_ng "008" "<名前> の形式違反: $name（[a-z0-9][a-z0-9-]* で書くこと）" 2 ;;
  esac
  case "$name" in
    *[!a-z0-9-]*) result_ng "008" "<名前> の形式違反: $name（[a-z0-9][a-z0-9-]* で書くこと）" 2 ;;
  esac
  require_branch

  default_dest="${MAIN_ROOT%/*}/${MAIN_ROOT##*/}-wt/$name"
  [ -n "$dest" ] || dest="$default_dest"
  dest="$(abs_path "$dest")"
  load_worktrees

  if is_under_repo "$dest"; then
    result_ng "002" "置き場がリポジトリの配下にある: $dest。既定の置き場は $default_dest（リポジトリの外）。別の置き場を指すこと" 1
  fi
  if [ -e "$dest" ]; then
    result_ng "002" "置き場が既に存在する: $dest。既定の置き場は $default_dest。別の名前か置き場を指すか、既存の作業ツリーをそのまま使うこと" 1
  fi
  branch="${PREFIX_BRANCH}${name}"
  if git show-ref --verify --quiet "refs/heads/$branch"; then
    result_ng "002" "同名のブランチが既にある: $branch。別の名前を指すか、既存の作業ツリーをそのまま使うこと" 1
  fi
  if worktree_index_by_path "$dest" >/dev/null; then
    result_ng "002" "同名の作業ツリーが既に登録されている: $dest（実体が無いなら git worktree prune で整理する）。別の名前か置き場を指すこと" 1
  fi
  parent="${dest%/*}"
  mkdir -p "$parent" 2>/dev/null || true
  if [ ! -d "$parent" ]; then
    result_ng "002" "置き場の親ディレクトリを作れない: $parent。書ける場所を <置き場> で指すこと" 1
  fi
  if ! out="$(git worktree add -b "$branch" "$dest" HEAD 2>&1)"; then
    result_ng "007" "git worktree add が失敗した: $out（--force / --ignore-other-worktrees で押し通さないこと）" 1
  fi
  # 記録と実行ログの置き場だけを作る。進行状態（mr.json / review-state.json / merge-state.json /
  # push-state.json / locks/ / usage/ / sessions/）は共有ルートのものを参照するので作らない。
  mkdir -p "$dest/logs/hooks" "$dest/logs/sh"
  result_ok "作業ツリーを切った（$dest / ブランチ $branch）。このパスをツールの作業ディレクトリにして始めること（cd は使えない）"
}

# ---- list -----------------------------------------------------------------

cmd_list() {
  [ $# -eq 0 ] || result_ng "008" "list は引数を取らない: $*（使い方: list）" 2
  load_worktrees
  local i path branch main managed dirty tsv=""
  for ((i = 0; i < ${#WL_PATHS[@]}; i++)); do
    path="${WL_PATHS[$i]}"
    branch="${WL_BRANCHES[$i]}"
    if wt_is_main_root "$path"; then main=1; else main=0; fi
    if is_managed_branch "$branch"; then managed=1; else managed=0; fi
    if [ -n "$(dirty_files "$path")" ]; then dirty=1; else dirty=0; fi
    tsv+="$path"$'\t'"$branch"$'\t'"$main"$'\t'"$managed"$'\t'"$dirty"$'\t'"$(doing_pairs "$path")"$'\n'
  done
  printf '%s' "$tsv" | jq -R -s -c '
    split("\n") | map(select(length > 0)) | map(split("\t")) | map({
      path: .[0],
      branch: (if .[1] == "" then null else .[1] end),
      main: (.[2] == "1"),
      managed: (.[3] == "1"),
      doing: (if ((.[5] // "") == "") then [] else (.[5] | split(",") | map(split(":") | {ticket: .[0], type: .[1]})) end),
      dirty: (.[4] == "1")
    })' | tr -d '\r'
  log_info "list ${#WL_PATHS[@]} 件"
  exit 0
}

# ---- 合流の記録 -----------------------------------------------------------

build_merge_line() { # $1=ts $2=名前 $3=置き場 $4=ブランチ $5=result $6=merge_commit $7=tickets(改行) $8=conflicts(改行) [$9=切り詰めた]
  jq -nc \
    --arg ts "$1" --arg w "$2" --arg p "$3" --arg b "$4" --arg into "$MAIN_BRANCH" \
    --arg r "$5" --arg mc "$6" --arg t "$7" --arg c "$8" --argjson tr "${9:-0}" \
    '{ts: $ts, worktree: $w, path: $p, branch: $b, into: $into, result: $r, merge_commit: $mc,
      tickets: ($t | split("\n") | map(select(length > 0))),
      conflicts: (($c | split("\n") | map(select(length > 0))) + (if $tr == 1 then ["…"] else [] end))}' | tr -d '\r'
}

record_merge() { # $1=名前 $2=置き場 $3=ブランチ $4=result $5=merge_commit $6=tickets(改行) $7=conflicts(改行)
  local ts line log n
  ts="$(now_iso)"
  log="$MAIN_ROOT/$MERGE_LOG_REL"
  mkdir -p "${log%/*}" 2>/dev/null || true
  line="$(build_merge_line "$ts" "$1" "$2" "$3" "$4" "$5" "$6" "$7" 0)"
  n="$(printf '%s' "$7" | grep -c . 2>/dev/null || true)"
  [ -n "$n" ] || n=0
  # 1 行を 4 KB 未満に保つ。超える分は conflicts を切り詰め、末尾に … を付ける
  while [ "${#line}" -ge "$MERGE_LOG_MAX" ] && [ "$n" -gt 0 ]; do
    n=$((n - 1))
    line="$(build_merge_line "$ts" "$1" "$2" "$3" "$4" "$5" "$6" "$(printf '%s' "$7" | head -n "$n")" 1)"
  done
  printf '%s\n' "$line" >> "$log" 2>/dev/null || log_warn "合流の記録を書けない: $log"
  return 0
}

tickets_between() { # $1=合流前の HEAD
  git diff --name-only "$1..HEAD" -- wip/10_tickets/ 2>/dev/null \
    | sed -n 's#.*/\([0-9][0-9][0-9][0-9]\)-[^/]*$#\1#p' | sort -u
}

# ---- merge ----------------------------------------------------------------

cmd_merge() {
  local all=0 subject="" target="" i idx
  while [ $# -gt 0 ]; do
    case "$1" in
      --all) all=1 ;;
      -m)
        shift
        [ $# -gt 0 ] || result_ng "008" "-m に値が無い（使い方: merge <名前>|<サブブランチ名>|--all [-m <件名>]）" 2
        subject="$1"
        ;;
      -*) result_ng "008" "不明なオプション: $1（使い方: merge <名前>|<サブブランチ名>|--all [-m <件名>]）" 2 ;;
      *)
        [ -z "$target" ] || result_ng "008" "対象を 2 つ以上指定した: $target $1（対象は 1 つか --all）" 2
        target="$1"
        ;;
    esac
    shift
  done
  if [ "$all" = 1 ] && [ -n "$target" ]; then
    result_ng "008" "対象と --all は同時に指定できない: $target --all" 2
  fi
  if [ "$all" = 0 ] && [ -z "$target" ]; then
    result_ng "008" "merge には対象が要る（使い方: merge <名前>|<サブブランチ名>|--all [-m <件名>]）" 2
  fi
  require_branch
  load_worktrees

  local t_idx=()
  if [ "$all" = 1 ]; then
    for ((i = 0; i < ${#WL_PATHS[@]}; i++)); do
      if is_managed_branch "${WL_BRANCHES[$i]}"; then t_idx+=("$i"); fi
    done
    if [ "${#t_idx[@]}" -eq 0 ]; then
      result_ok "合流の対象が無い（管理対象の作業ツリーは 0 件）。記録: $MERGE_LOG_REL"
    fi
  else
    if idx="$(worktree_index_by_branch "${PREFIX_BRANCH}${target}")"; then
      t_idx+=("$idx")
    elif idx="$(worktree_index_by_branch "$target")"; then
      if is_managed_branch "${WL_BRANCHES[$idx]}"; then
        t_idx+=("$idx")
      fi
      if [ "${#t_idx[@]}" -eq 0 ]; then
        result_ng "005" "対象が管理対象外の作業ツリー: $target（ブランチ ${WL_BRANCHES[$idx]} が ${PREFIX_BRANCH} で始まらない）。list で管理対象を確かめて正しい対象を指すこと" 1
      fi
    else
      result_ng "005" "対象の作業ツリーが見つからない: $target。list で管理対象の一覧を確かめて正しい対象を指すこと" 1
    fi
  fi

  # 前提検査を全対象についてまとめて先に行い、未充足を全件列挙する（1 件目で止めない）
  local fails=() f nm p br
  f="$(dirty_files "$MAIN_ROOT")"
  [ -z "$f" ] || fails+=("本流に未コミットの変更がある（$f）")
  f="$(doing_numbers "$MAIN_ROOT")"
  [ -z "$f" ] || fails+=("本流に作業中チケットが残っている（$f）")
  for i in "${t_idx[@]}"; do
    p="${WL_PATHS[$i]}"; br="${WL_BRANCHES[$i]}"; nm="$(wt_name_of "$br")"
    f="$(dirty_files "$p")"
    [ -z "$f" ] || fails+=("$nm に未コミットの変更がある（$f）")
    f="$(doing_numbers "$p")"
    [ -z "$f" ] || fails+=("$nm に作業中チケットが残っている（$f）")
    if ! is_managed_branch "$br"; then
      fails+=("$nm のブランチが同じ issue に属さない（$br）")
    fi
  done
  if [ "${#fails[@]}" -gt 0 ]; then
    result_ng "003" "合流できない。未充足: $(join_by " / " "${fails[@]}")。タスクの切れ目まで進めるか、コミットしてから再実行すること" 1
  fi

  local merged=() uptodate=() remaining=() before after rc out subj tickets conflicts unmerged short j
  for ((j = 0; j < ${#t_idx[@]}; j++)); do
    i="${t_idx[$j]}"
    p="${WL_PATHS[$i]}"; br="${WL_BRANCHES[$i]}"; nm="$(wt_name_of "$br")"
    before="$(git rev-parse HEAD)"
    subj="${subject:-chore: 作業ツリー $nm の成果を合流する}"
    rc=0
    out="$(git merge --no-ff -m "$subj" "$br" 2>&1)" || rc=$?
    if [ "$rc" -eq 0 ]; then
      after="$(git rev-parse HEAD)"
      if [ "$after" = "$before" ]; then
        record_merge "$nm" "$p" "$br" "up-to-date" "" "" ""
        uptodate+=("$nm")
      else
        short="$(git rev-parse --short HEAD)"
        tickets="$(tickets_between "$before")"
        record_merge "$nm" "$p" "$br" "merged" "$short" "$tickets" ""
        if [ -n "$tickets" ]; then
          merged+=("$nm → $short / チケット $(printf '%s' "$tickets" | tr '\n' ' ' | sed 's/ *$//')")
        else
          merged+=("$nm → $short")
        fi
      fi
      continue
    fi
    unmerged="$(git ls-files --unmerged 2>/dev/null || true)"
    if [ -n "$unmerged" ]; then
      conflicts="$(git diff --name-only --diff-filter=U 2>/dev/null || true)"
      git merge --abort >/dev/null 2>&1 || true
      record_merge "$nm" "$p" "$br" "aborted" "" "" "$conflicts"
      local k
      for ((k = j; k < ${#t_idx[@]}; k++)); do remaining+=("$(wt_name_of "${WL_BRANCHES[${t_idx[$k]}]}")"); done
      result_ng "004" "合流で自動的に解けない衝突が出たので中断し、合流前に戻した（$nm）。衝突: $(printf '%s' "$conflicts" | tr '\n' ' ' | sed 's/ *$//') / 合流できた: $(join_by ", " "${merged[@]:-}" ) / 未処理: $(join_by ", " "${remaining[@]}") / 記録: $MERGE_LOG_REL。衝突の解消は人が行う（AI は一方に寄せない）" 1
    fi
    git merge --abort >/dev/null 2>&1 || true
    result_ng "007" "git merge が失敗した（$nm）: $out（安全装置を外して押し通さないこと）" 1
  done

  local msg="$(( ${#merged[@]} + ${#uptodate[@]} )) 件を合流した"
  if [ "${#merged[@]}" -gt 0 ]; then msg="$msg（$(join_by ", " "${merged[@]}")）"; fi
  if [ "${#uptodate[@]}" -gt 0 ]; then msg="$msg。取り込み済み: $(join_by ", " "${uptodate[@]}")"; fi
  result_ok "$msg。残っている対象: なし。記録: $MERGE_LOG_REL"
}

# ---- remove ---------------------------------------------------------------

cmd_remove() {
  local force=0 target="" idx="" p br nm ahead=0 out
  while [ $# -gt 0 ]; do
    case "$1" in
      --force) force=1 ;;
      -*) result_ng "008" "不明なオプション: $1（使い方: remove <名前>|<置き場> [--force]）" 2 ;;
      *)
        [ -z "$target" ] || result_ng "008" "対象を 2 つ以上指定した: $target $1（対象は 1 つ）" 2
        target="$1"
        ;;
    esac
    shift
  done
  [ -n "$target" ] || result_ng "008" "remove には対象が要る（使い方: remove <名前>|<置き場> [--force]）" 2
  require_branch
  load_worktrees

  if idx="$(worktree_index_by_branch "${PREFIX_BRANCH}${target}")"; then
    :
  elif idx="$(worktree_index_by_path "$(canon_worktree_path "$target")")"; then
    :
  elif idx="$(worktree_index_by_branch "$target")"; then
    :
  else
    result_ng "005" "対象の作業ツリーが見つからない: $target。list で管理対象の一覧を確かめて正しい対象を指すこと" 1
  fi
  p="${WL_PATHS[$idx]}"; br="${WL_BRANCHES[$idx]}"
  if ! is_managed_branch "$br"; then
    result_ng "005" "対象が管理対象外の作業ツリー: $target（ブランチ ${br:-<detached>} が ${PREFIX_BRANCH} で始まらない）。list で管理対象を確かめて正しい対象を指すこと" 1
  fi
  nm="$(wt_name_of "$br")"

  local fails=() f
  f="$(dirty_files "$p")"
  [ -z "$f" ] || fails+=("未コミットの変更が残っている（$f）— --force でも消さない")
  ahead="$(git rev-list --count "$MAIN_BRANCH..$br" 2>/dev/null || printf '0')"
  if [ "$ahead" != "0" ] && [ "$force" = 0 ]; then
    fails+=("本流へ合流していないコミットが $ahead 件ある")
  fi
  if [ "${#fails[@]}" -gt 0 ]; then
    result_ng "006" "片付けできない（$nm）。残っている: $(join_by " / " "${fails[@]}")。コミットするか合流してから片付けること" 1
  fi
  if [ "$ahead" != "0" ]; then
    printf '注意: --force により未合流のコミット %s 件を捨てる（%s）\n' "$ahead" "$br"
  fi
  if ! out="$(git worktree remove "$p" 2>&1)"; then
    result_ng "007" "git worktree remove が失敗した: $out（--force で押し通さないこと）" 1
  fi
  if [ "$force" = 1 ]; then
    out="$(git branch -D "$br" 2>&1)" || result_ng "007" "git branch -D が失敗した: $out" 1
  else
    out="$(git branch -d "$br" 2>&1)" || result_ng "007" "git branch -d が失敗した: $out" 1
  fi
  out="$(git worktree prune 2>&1)" || result_ng "007" "git worktree prune が失敗した: $out" 1
  result_ok "作業ツリー $p とブランチ $br を削除した"
}

# ---- 入口 -----------------------------------------------------------------

main() {
  local sub="${1:-}"
  [ $# -eq 0 ] || shift
  case "$sub" in
    -h|--help) usage; exit 0 ;;
    add|list|merge|remove) ;;
    "") usage; result_ng "008" "サブコマンドが無い（add / list / merge / remove のいずれか）" 2 ;;
    *) usage; result_ng "008" "不明なサブコマンド: $sub（add / list / merge / remove のいずれか）" 2 ;;
  esac
  require_env
  resolve_roots
  log_info "start subcommand=$sub args=${*:-}"
  case "$sub" in
    add) require_main add; cmd_add "$@" ;;
    list) cmd_list "$@" ;;
    merge) require_main merge; cmd_merge "$@" ;;
    remove) require_main remove; cmd_remove "$@" ;;
  esac
}

main "$@"
