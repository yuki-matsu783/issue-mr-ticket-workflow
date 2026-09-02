#!/usr/bin/env bash
# session-start.sh — セッションの開始・再開・クリア・compact のたびに現在地を注入する
# 仕様: .claude/docs/10_spec/hooks/00-SessionStart/session-start.md（注入の形式・識別子の正）
# 登録: SessionStart（matcher 無し。source は startup / resume / clear / compact のすべて）
# 出力: stdout の注入テキスト（WF701〜704）または無出力
#
# 現在地の判定そのものは `boundary.sh status --offline` に委ねる（独自の判定を持たない）。
# **`boundary.sh` は 3/3（issue #10）で実装するので、この時点では常に不在**。仕様の制御方式 3 の
# とおり「失敗したら何も出さずに終了 0」に落ちる。整形（制御方式 4〜11）は判定の結果が無ければ
# 書きようがないので、偽の判定を置かず 3/3 へ送る（DDR i0009-09 と同じ扱い）。
set -euo pipefail

# 案内側なので判定不能でも通す。読み込み行の deny ポリシーは使わない
HOOK_DENY_ID="WF709"

# 共通ライブラリの読み込み行（20-common-step-shell-script 仕様「読み込み行」が正）。引数 <lib> <policy> だけを変え、中身を改変しない。
# shellcheck disable=SC1090,SC2317
__ss_load() { local lib="$1" pol="$2" d="${BASH_SOURCE[1]%/*}" r="" f=""; [ "$d" = "${BASH_SOURCE[1]}" ] && d="."; case "$d" in /*|[A-Za-z]:/*) ;; *) d="$PWD/$d" ;; esac; while [ -n "$d" ] && [ ! -d "$d/.claude" ]; do case "$d" in */*) d="${d%/*}" ;; *) d="" ;; esac; done; r="$d"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; if [ ! -f "$f" ] && [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then r="${CLAUDE_PROJECT_DIR//\\//}"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ ! -f "$f" ] && command -v git >/dev/null 2>&1; then r="$(git rev-parse --show-toplevel 2>/dev/null || true)"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ -n "$r" ] && [ -f "$f" ]; then LOGGER_ROOT="$r"; export LOGGER_ROOT; [ "$lib" = frontmatter ] && FM_AVAILABLE=1; . "$f"; return 0; fi; [ "$lib" = frontmatter ] && FM_AVAILABLE=0; case "$pol" in nop) LOGGER_ROOT="${r:-$PWD}"; export LOGGER_ROOT; log_debug() { :; }; log_info() { :; }; log_warn() { :; }; log_error() { :; }; fm_extract() { FM_BLOCK=""; return 2; }; fm_get() { return 2; }; fm_list() { return 2; }; fm_has() { return 2; } ;; deny) printf '%s\n' "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"${HOOK_DENY_ID:-WF009}: 機構の不調 — 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）\"}}"; exit 0 ;; *) printf '%s\n' "FATAL: 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）"; exit 2 ;; esac; }
__ss_load logger nop

__se_dir="${BASH_SOURCE[0]%/*}"
case "$__se_dir" in /*|[A-Za-z]:/*) ;; *) __se_dir="$PWD/$__se_dir" ;; esac
# shellcheck source=/dev/null
. "$__se_dir/../lib/hook-common.sh"
# shellcheck source=/dev/null
. "$__se_dir/../lib/probe-4c.sh"

hook_init session-start notify WF709

# 入力（jq 1 回）。読めなくても案内側なので通す
hook_read_input || hook_fail "入力を読めない"

# 4c プローブ（既定では何もしない）。**早期 return より前**に置く。
# 後ろに置くと boundary.sh 不在で黙って抜ける経路の source が 1 行も残らない
probe_4c

# 制御方式 1: 停止中は 1 行だけ出して記録する（現在地は出さない）
if ! hook_enforce_enabled; then
  printf '%s\n' "[WF701] 機構は停止中（WORKFLOW_ENFORCE=0 / WORKFLOW_SESSION_START_ENFORCE=0）"
  hook_disabled
fi

# 呼出条件: サブエージェントのセッションには注入しない。
# 判別できなければ出す（メインで欠けるほうが副作用が大きい）
if [[ -n "${HOOK_AGENT_ID:-}" || -n "${CLAUDE_AGENT_ID:-}" ]]; then
  hook_record skip "" "" "サブエージェントの開始（agent_id あり）"
  exit 0
fi

# 制御方式 2: logs/sessions/ の古いディレクトリを片付ける（失敗は無視）。
# frontmatter 索引の機構は未導入なので何もしない
__se_prune_sessions() {
  local base="$HOOK_WORKTREE/logs/sessions" d
  [[ -d "$base" ]] || return 0
  local ng=0
  shopt -q nullglob && ng=1
  shopt -s nullglob
  for d in "$base"/*/; do
    # 7 日 = 10080 分。find の -mmin なら stat の移植性に悩まなくて済む（hc_lock と同じ方針）
    if [[ -n "$(find "$d" -maxdepth 0 -mmin +10080 2>/dev/null)" ]]; then rm -rf "$d" 2>/dev/null || true; fi
  done
  (( ng )) || shopt -u nullglob
  return 0
}
__se_prune_sessions || true

# 制御方式 3: boundary.sh status --offline に判定を委ねる。
# 不在・失敗（jq / git 不在を含む）は何も出さずに終了 0
__se_boundary="$HOOK_WORKTREE/.claude/hooks/boundary.sh"
if [[ ! -f "$__se_boundary" ]]; then
  log_info "boundary.sh が無いので現在地を導出しない（3/3 で実装）"
  hook_record skip "" "" "boundary.sh 不在（3/3 で実装）"
  exit 0
fi
if ! command -v jq >/dev/null 2>&1; then
  log_info "jq が無いので現在地を導出しない"
  hook_record skip "" "" "jq 不在"
  exit 0
fi

__se_status=""
if ! __se_status="$(bash "$__se_boundary" status --offline 2>/dev/null)" || [[ -z "$__se_status" ]]; then
  log_info "boundary.sh status --offline が失敗したので何も出さない"
  hook_record skip "" "" "boundary.sh status --offline が失敗"
  exit 0
fi

# 制御方式 4〜11（注入テキストの組み立て）は boundary.sh の出力の形が確定してから書く。
# ここに偽の整形を置くと、SE-T08（本物と同じ position を伝える）が偽実装同士の比較になって観点を失う
log_warn "boundary.sh status --offline を取得したが、注入の整形は 3/3 で実装する"
hook_record skip "" "" "注入の整形は 3/3 で実装（boundary.sh の出力あり）"
exit 0
