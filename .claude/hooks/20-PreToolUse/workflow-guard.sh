#!/usr/bin/env bash
# workflow-guard.sh — 作業中チケットの宣言と上限設定だけを材料に、書き込み・コマンド・プランモードを判定する
# 仕様: .claude/docs/10_spec/hooks/20-PreToolUse/workflow-guard.md（判定順・WF20x）。
#       許可範囲の規則そのものはフック共通仕様 §8（scope.sh）が正で、このフックは規則を持たない
# 登録: PreToolUse / matcher 書き込み・実行・プランモード・起動
# 出力: deny（WF201 / WF204〜WF213）/ ask（WF202 / WF203）/ 許可（無出力）
#
# 作業中チケットが 1 枚あるときだけ働く。判定材料はチケットの frontmatter と scope-limits.json だけで、
# 会話・チケット本文の散文は見ない。jq は入力の 1 回と承認の記憶の 1 回（書き込み判定のときだけ）。
set -euo pipefail

HOOK_DENY_ID="WF209"

# 共通ライブラリの読み込み行（20-common-step-shell-script 仕様「読み込み行」が正）。引数 <lib> <policy> だけを変え、中身を改変しない。
# shellcheck disable=SC1090,SC2317
__ss_load() { local lib="$1" pol="$2" d="${BASH_SOURCE[1]%/*}" r="" f=""; [ "$d" = "${BASH_SOURCE[1]}" ] && d="."; case "$d" in /*|[A-Za-z]:/*) ;; *) d="$PWD/$d" ;; esac; while [ -n "$d" ] && [ ! -d "$d/.claude" ]; do case "$d" in */*) d="${d%/*}" ;; *) d="" ;; esac; done; r="$d"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; if [ ! -f "$f" ] && [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then r="${CLAUDE_PROJECT_DIR//\\//}"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ ! -f "$f" ] && command -v git >/dev/null 2>&1; then r="$(git rev-parse --show-toplevel 2>/dev/null || true)"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ -n "$r" ] && [ -f "$f" ]; then LOGGER_ROOT="$r"; export LOGGER_ROOT; [ "$lib" = frontmatter ] && FM_AVAILABLE=1; . "$f"; return 0; fi; [ "$lib" = frontmatter ] && FM_AVAILABLE=0; case "$pol" in nop) LOGGER_ROOT="${r:-$PWD}"; export LOGGER_ROOT; log_debug() { :; }; log_info() { :; }; log_warn() { :; }; log_error() { :; }; fm_extract() { FM_BLOCK=""; return 2; }; fm_get() { return 2; }; fm_list() { return 2; }; fm_has() { return 2; } ;; deny) printf '%s\n' "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"${HOOK_DENY_ID:-WF009}: 機構の不調 — 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）\"}}"; exit 0 ;; *) printf '%s\n' "FATAL: 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）"; exit 2 ;; esac; }
__ss_load logger nop

__wg_dir="${BASH_SOURCE[0]%/*}"
case "$__wg_dir" in /*|[A-Za-z]:/*) ;; *) __wg_dir="$PWD/$__wg_dir" ;; esac
# shellcheck source=/dev/null
. "$__wg_dir/../lib/hook-common.sh"
# shellcheck source=/dev/null
. "$__wg_dir/../lib/cmdpos.sh"
# shellcheck source=/dev/null
. "$__wg_dir/../lib/scope.sh"

hook_init workflow-guard deny WF209
hook_fail_closed

# 制御方式 1: 停止中なら何もしない（§4）
hook_enforce_enabled || hook_disabled

# 入力（jq 1 回目。副入力として scope-limits.json も読む）
hook_read_input limits || hook_fail "入力を読めない"

__WG_US=$'\x1e'                                   # SC_TARGETS / CP_REDIRECTS の区切り
__WG_DOING_DIR="wip/10_tickets/10_doing"
__WG_LIMITS_PATH=".claude/hooks/config/scope-limits.json"
# コマンドが書いてよい置き場（仕様 制御方式 6）。ここ以外への書き込みは Edit / Write に寄せる
__WG_CMD_WRITE_OK=('wip/tmp/**' 'logs/**')
# 提供コマンドの引数のうち、値がパスではないもの（メッセージ・宣言・理由）。次の語を読み飛ばす
__WG_VALUE_OPTS=' -m --message --reason --dod --title --body --note --label --type --allow-write --allow-ops --issue --pr '

__WG_NO_BYPASS="拒否されたら迂回せず、宣言の範囲内で進めること。範囲を広げる必要があるなら作業を止めてユーザーに提案する（未着手チケットの見直しか計画の追加チケット）。"

# ---- 制御方式 1: 作業中チケットが無ければ何もしない（記録もしない）----
hook_doing_ticket
__WG_NAME="$REPLY"
[[ -n "$__WG_NAME" ]] || exit 0

__WG_CLASS="$(tool_class "$HOOK_TOOL" "${HOOK_SKILL:-}")"

# 起動（Agent / Workflow）は常に許可（制御方式 8）。実行者の不一致は subagent-start-check が伝える。
# 読み取りは matcher の外だが、届いても判定材料が無いので通す
case "$__WG_CLASS" in
  spawn|read|declare) hook_allow ;;
esac

# ---- 共通の補助 ----
# ルート相対に直したうえで `.` と `..` を畳む。畳んでも作業ツリーの外に出るパスは判定できないので拒否側に倒す
# （`wip/../.claude/settings.json` のような書き方で保護範囲の glob をすり抜けられるため。プローブで確認した）
__wg_rel() { # $1=パス → REPLY にルート相対（末尾の / を落とす）
  local raw p seg out=""
  raw="$1"
  hook_rel_path "$raw" >/dev/null
  p="${REPLY%/}"
  if [[ "$p" == *"/../"* || "$p" == "../"* || "$p" == *"/.." || "$p" == ".."      || "$p" == *"/./"* || "$p" == "./"* || "$p" == *"/." ]]; then
    while [[ -n "$p" ]]; do
      if [[ "$p" == */* ]]; then seg="${p%%/*}"; p="${p#*/}"; else seg="$p"; p=""; fi
      case "$seg" in
        ""|".") ;;
        "..")
          if [[ -z "$out" || "$out" == ".." || "$out" == *"/.." ]]; then out="${out:+$out/}.."
          elif [[ "$out" == */* ]]; then out="${out%/*}"
          else out=""; fi ;;
        *) out="${out:+$out/}$seg" ;;
      esac
    done
    p="$out"
  fi
  # 作業ツリーの外（絶対パス・先頭の ..）は、どの範囲にも属さないので承認単位にもしない
  if [[ -z "$p" || "$p" == ".." || "$p" == "../"* || "$p" == /* || "$p" =~ ^[A-Za-z]:/ ]]; then
    hook_deny WF209 "$raw は作業ツリー（$HOOK_WORKTREE）の外を指すので、やってよいことの内側か判定できない。作業はリポジトリの中で行い、外に出す必要があるならユーザーに報告すること。$__WG_NO_BYPASS" "$raw"
  fi
  REPLY="$p"
  return 0
}

__wg_split_us() { # $1=US 区切り → REPLY_LIST
  REPLY_LIST=()
  local s="${1:-}" x
  while [[ -n "$s" ]]; do
    if [[ "$s" == *"$__WG_US"* ]]; then x="${s%%"$__WG_US"*}"; s="${s#*"$__WG_US"}"; else x="$s"; s=""; fi
    [[ -n "$x" ]] && REPLY_LIST+=("$x")
  done
  return 0
}

__wg_cmd_head() { printf '%s' "${HOOK_COMMAND:0:80}"; }

__wg_ticket_line() { printf '作業中チケット %s（種類 %s）' "$__WG_NAME" "${SC_TICKET_TYPE:-不明}"; }

# 実行位置のセグメントを 1 度だけ解析する（縮退・提供コマンドの有無を先に知りたい場面がある）
__WG_PARSED=0
__wg_parse() {
  (( __WG_PARSED )) && return 0
  cmdpos_parse "${HOOK_COMMAND:-}" "$([[ "$HOOK_TOOL" == PowerShell ]] && printf 'powershell' || printf 'bash')"
  __WG_PARSED=1
  return 0
}

# 実行位置のすべての段が提供コマンド（またはデータ）か。復旧経路と WF207 の例外に使う
__wg_all_provided() {
  local i
  [[ "$__WG_CLASS" == exec ]] || return 1
  __wg_parse
  (( CP_DEGRADED )) && return 1
  (( CP_COUNT > 0 )) || return 1
  for (( i = 0; i < CP_COUNT; i++ )); do
    [[ "${CP_DATA[$i]:-0}" == 1 ]] && continue
    [[ -n "${CP_PROVIDED[$i]:-}" ]] || return 1
  done
  return 0
}

# ---- 制御方式 2: 作業中が 2 枚以上（機構の異常）----
if (( HOOK_DOING_COUNT > 1 )); then
  __wg_list() {
    local f out="" ng=0
    shopt -q nullglob && ng=1
    shopt -s nullglob
    for f in "$HOOK_WORKTREE/$__WG_DOING_DIR"/*.md; do out+="${out:+, }${f##*/}"; done
    (( ng )) || shopt -u nullglob
    printf '%s' "$out"
  }
  if ! __wg_all_provided; then
    hook_deny WF207 "作業中チケットが $HOOK_DOING_COUNT 枚ある（$(__wg_list)）。1 枚だけの状態でしか判定できないので、bash .claude/skills/20-common-step-ticket/scripts/ticket.sh で 1 枚を残して他を未着手に戻すこと。$__WG_NO_BYPASS" "$HOOK_TOOL"
  fi
  hook_record allow "" "$HOOK_TOOL" "作業中 $HOOK_DOING_COUNT 枚だが提供コマンドなので通す"
  exit 0
fi

__WG_TICKET_REL="$__WG_DOING_DIR/$__WG_NAME"
__WG_TICKET_FILE="$HOOK_WORKTREE/$__WG_TICKET_REL"

# ---- 制御方式 3: 上限設定が無い・壊れている ----
# 設定 1 ファイルの破損が完全なロックアウトにならないよう、復旧経路だけを開けておく（DDR i0009-29）
if [[ "${HC_LIMITS_STATE:-missing}" != "ok" ]]; then
  __WG_LIMITS_WHY="${HC_LIMITS_ERROR:-設定ファイルが無い}"
  __WG_LIMITS_HOWTO="復旧経路は 3 つだけ開いている: 提供コマンドの実行 / $__WG_DOING_DIR 以下への書き込み / $__WG_LIMITS_PATH 自身の修正（確認あり）。"
  if __wg_all_provided; then
    hook_record allow "WF210" "$(__wg_cmd_head)" "設定を読めないが提供コマンドなので通す"
    exit 0
  fi
  if [[ "$__WG_CLASS" == write && -n "${HOOK_FILE_PATH:-}" ]]; then
    __wg_rel "$HOOK_FILE_PATH"; __WG_P="$REPLY"
    if [[ "$__WG_P" == "$__WG_LIMITS_PATH" ]]; then
      hook_ask WF203 "上限設定（$__WG_LIMITS_PATH）を読めない（$__WG_LIMITS_WHY）。設定ファイル自身の書き換えは、設定が読めない間も AI の裁量にしない。内容を確認して承認すること。" "$__WG_P" WF213
    fi
    if [[ "$__WG_P" == "$__WG_DOING_DIR"/* ]]; then
      hook_record allow "WF210" "$__WG_P" "設定を読めないがチケットの置き場なので通す"
      exit 0
    fi
  fi
  hook_deny WF210 "上限設定 $__WG_LIMITS_PATH を使えない（$__WG_LIMITS_WHY）ので、$HOOK_TOOL の対象（${HOOK_FILE_PATH:-$(__wg_cmd_head)}）がやってよいことの内側か判定できない。$__WG_LIMITS_HOWTO" "${HOOK_FILE_PATH:-$(__wg_cmd_head)}"
fi

# ---- 制御方式 4: チケットの記載 ----
__WG_RC=0
scope_load_ticket "$__WG_TICKET_FILE" || __WG_RC=$?
if (( __WG_RC == 2 )); then
  hook_fail "frontmatter.sh を読み込めていない（${SC_ERROR:-}）"
fi
__WG_TICKET_HOWTO="復旧経路は 2 つ: 提供コマンドの実行 / このチケット（$__WG_TICKET_REL）自身の修正。直せないなら bash .claude/skills/20-common-step-ticket/scripts/ticket.sh cancel <番号> --reason で取り消す。"
if (( __WG_RC == 0 )); then
  scope_load "$SC_TICKET_TYPE" || __WG_RC=$?
fi
if (( __WG_RC != 0 )); then
  if __wg_all_provided; then
    hook_record allow "WF211" "$(__wg_cmd_head)" "チケットを読めないが提供コマンドなので通す"
    exit 0
  fi
  if [[ "$__WG_CLASS" == write && -n "${HOOK_FILE_PATH:-}" ]]; then
    __wg_rel "$HOOK_FILE_PATH"; __WG_P="$REPLY"
    if [[ "$__WG_P" == "$__WG_TICKET_REL" ]]; then
      hook_record allow "WF211" "$__WG_P" "チケットを読めないがチケット自身の修正なので通す"
      exit 0
    fi
  fi
  hook_deny WF211 "$__WG_TICKET_REL の記載を判定に使えない（${SC_ERROR:-記載不正}）ので、やってよいことが決まらない。$__WG_TICKET_HOWTO" "$__WG_TICKET_REL"
fi

# ---- パス 1 本の判定（制御方式 5。コマンドの引数にも同じものを当てる）----
__WG_APPROVALS_READ=0
__wg_load_approvals() {
  (( __WG_APPROVALS_READ )) && return 0
  __WG_APPROVALS_READ=1
  hook_read_state approvals || log_warn "承認の記憶を読めない（jq 不在）"   # jq 2 回目
  scope_load_approvals || log_warn "承認の記憶が壊れている（空として扱う）"
  return 0
}

__wg_judge_path() { # $1=ルート相対パス $2=記録・文面に出す対象
  local p="$1" target="$2"
  __wg_load_approvals
  scope_resolve "$p"
  case "$SC_DECISION" in
    skip|allow) return 0 ;;
    deny)
      hook_deny WF201 "$p は $(__wg_ticket_line)では書き換えられない範囲（判定 $SC_STAGE: 共通の保護範囲または種類の禁止範囲）。$__WG_NO_BYPASS" "$target"
      ;;
    ask)
      if [[ "$SC_ID" == "WF203" ]]; then
        hook_ask WF203 "$p は変更のたびに確認する範囲。$(__wg_ticket_line)の作業として書き換えてよいか確認すること。" "$target" WF213
      fi
      hook_ask WF202 "$p は上限設定にもチケットの宣言にも無い、想定していないパス。$(__wg_ticket_line)。承認するとこのセッションの間は $SC_ASK_SCOPE 以下が同じ扱いになる。" "$target" WF213
      ;;
  esac
  return 0
}

# ---- 制御方式 5: 書き込みツール ----
if [[ "$__WG_CLASS" == write ]]; then
  if [[ -z "${HOOK_FILE_PATH:-}" ]]; then
    hook_deny WF209 "書き込みの対象パスを読み取れないので、やってよいことの内側か判定できない。$__WG_NO_BYPASS" "$HOOK_TOOL"
  fi
  __wg_rel "$HOOK_FILE_PATH"; __WG_P="$REPLY"
  # 作業中チケット自身の機械可読項目（種類・宣言・実行者・レビュー要否・先行）の改変は拒否。本文（DoD・作業ログ）は通す
  if [[ "$__WG_P" == "$__WG_TICKET_REL" && "${HOOK_FM_KEYS_TOUCHED:-0}" == "1" ]]; then
    hook_deny WF208 "着手済みのチケット（$__WG_TICKET_REL）の ticket_type / allow / executor / human_review / adversarial_review / predecessors は変えない。見直しは未着手チケットか計画の追加チケットで行う。作業ログ・DoD の追記なら機械可読項目に触れずに書くこと。" "$__WG_P"
  fi
  __wg_judge_path "$__WG_P" "$__WG_P"
  hook_record allow "" "$__WG_P" "判定 $SC_STAGE / 種類 $SC_TICKET_TYPE"
  exit 0
fi

# ---- 制御方式 7: プランモード ----
if [[ "$__WG_CLASS" == plan ]]; then
  if [[ "${SC_TYPE_PLAN_MODE:-false}" == "true" ]]; then
    hook_record allow "" "$HOOK_TOOL" "種類 $SC_TICKET_TYPE は plan_mode: true"
    exit 0
  fi
  hook_deny WF212 "$(__wg_ticket_line)ではプランモードに入れない。プランモードを使うのは全体計画のタスクだけで、他の種類はチケットの手順どおりに進める。" "$HOOK_TOOL"
fi

# ---- 制御方式 6: 実行ツール ----
[[ "$__WG_CLASS" == exec ]] || hook_allow

if [[ -z "${HOOK_COMMAND:-}" ]]; then
  hook_deny WF209 "実行するコマンドを読み取れないので分類できない。$__WG_NO_BYPASS" "$HOOK_TOOL"
fi

__wg_parse
if (( CP_DEGRADED )); then
  hook_deny WF209 "コマンドが長すぎる（または bash が古い）ため実行位置を判定できなかった。短い単位に分けて実行するか、判定できない旨をユーザーに報告すること。$__WG_NO_BYPASS" "$(__wg_cmd_head)"
fi

# コマンドが書いてよい置き場か（wip/tmp/** と logs/** だけ）
__wg_cmd_write_ok() { # $1=ルート相対パス
  local p="$1" g
  for g in "${__WG_CMD_WRITE_OK[@]}"; do scope_match "$g" "$p" && return 0; done
  return 1
}

__wg_check_write_targets() { # $1=US 区切りの宛先
  local t p
  __wg_split_us "${1:-}"
  for t in ${REPLY_LIST[@]+"${REPLY_LIST[@]}"}; do
    if [[ "$t" == "_" ]]; then
      hook_deny WF205 "コマンドがファイルを書こうとしているが、宛先を読み取れなかった。ファイルの作成・更新は Edit / Write で行うこと（コマンドで書いてよいのは wip/tmp/** と logs/** だけ）。" "$(__wg_cmd_head)"
    fi
    __wg_rel "$t"; p="$REPLY"
    if ! __wg_cmd_write_ok "$p"; then
      hook_deny WF205 "コマンドで $p を書き換えようとしている。ファイルの作成・更新は Edit / Write で行うこと（コマンドで書いてよいのは wip/tmp/** と logs/** だけ）。" "$(__wg_cmd_head)"
    fi
  done
  return 0
}

# 削除だけを行う段か（`rm` / `git rm`）。ファイルの中身を作らないので、対象がチケットの
# allow.write に収まっていれば通す（Edit / Write にファイルを消す手段が無く、これが無いと
# AI は自分が作ったアセットを片付けられない。仕様 制御方式 6 との差分は 0036 の作業ログ）
__wg_is_delete_seg() { # $1=セグメント番号
  case "${CP_EXE[$1]:-}" in
    rm)  return 0 ;;
    git) [[ "${CP_SUBCMD[$1]:-}" == rm ]] && return 0 ;;
  esac
  return 1
}

__wg_delete_targets() { # $1=セグメント番号 → 削除対象を REPLY_LIST に置く。読み取れなければ 1
  local i="$1" a seen_sub=0
  if [[ "${CP_EXE[$i]:-}" == rm ]]; then
    # cmdpos が抜いた書き込み先をそのまま使う（オプションの規則を複製しない）
    __wg_split_us "${CP_WRITE_TARGETS[$i]:-}"
    (( ${#REPLY_LIST[@]} )) || return 1
    return 0
  fi
  # git rm はサブコマンドより後ろの非オプション語が対象（cmdpos は git の書き込み先を抜かない）
  REPLY_LIST=()
  cmdpos_args "$i"
  for a in ${REPLY_ARGS[@]+"${REPLY_ARGS[@]}"}; do
    if (( seen_sub == 0 )); then [[ "$a" == rm ]] && seen_sub=1; continue; fi
    [[ "$a" == --pathspec-from-file* ]] && return 1   # 対象が別ファイルにあり読み取れない
    [[ "$a" == -* ]] && continue
    REPLY_LIST+=("$a")
  done
  (( ${#REPLY_LIST[@]} )) || return 1
  return 0
}

# 対象の配下に「消してはいけない範囲」が入り得るか（ディレクトリごとの削除で子孫を巻き込ませない）。
# glob は展開せず、文字列として `<対象>/` で始まるかだけを見る（判定できないものは拒否側に倒す）
__wg_delete_covers_guarded() { # $1=ルート相対パス
  local p="$1" g
  for g in ${SC_COMMON_PROTECTED[@]+"${SC_COMMON_PROTECTED[@]}"} \
           ${SC_COMMON_CONFIRM[@]+"${SC_COMMON_CONFIRM[@]}"} \
           ${SC_COMMON_STATE_FILES[@]+"${SC_COMMON_STATE_FILES[@]}"} \
           ${SC_TYPE_DENY[@]+"${SC_TYPE_DENY[@]}"} \
           ${SC_TYPE_CONFIRM[@]+"${SC_TYPE_CONFIRM[@]}"}; do
    [[ "$g" == "$p/"* ]] && return 0
  done
  return 1
}

# 削除してよいか。置き場（wip/tmp/** と logs/**）か、チケットが宣言した allow.write の内側だけを通す。
# 宣言を必須にするのは、共通の許可範囲（計画書・レポート・未着手チケット）を削除に開かないため
__wg_delete_ok() { # $1=ルート相対パス
  local p="$1" g
  # 進行状態のファイルは logs/ の中にあってもコマンドで消させない（書き換えと同じ扱い）
  for g in ${SC_COMMON_STATE_FILES[@]+"${SC_COMMON_STATE_FILES[@]}"}; do scope_match "$g" "$p" && return 1; done
  for g in "${__WG_CMD_WRITE_OK[@]}"; do scope_match "$g" "$p" && return 0; done
  scope_resolve "$p"
  [[ "$SC_DECISION" == allow ]] || return 1
  (( ${#SC_DECL_WRITE[@]} )) || return 1
  for g in "${SC_DECL_WRITE[@]}"; do scope_match "$g" "$p" && return 0; done
  return 1
}

__wg_check_delete_targets() { # $1=セグメント番号
  local i="$1" t p
  if ! __wg_delete_targets "$i"; then
    hook_deny WF205 "削除するコマンドだが、消す対象を読み取れなかった。消すファイルをパスで 1 つずつ指定すること（コマンドで消してよいのはチケットの allow.write の内側だけ）。" "$(__wg_cmd_head)"
  fi
  __wg_load_approvals
  for t in ${REPLY_LIST[@]+"${REPLY_LIST[@]}"}; do
    if [[ "$t" == "_" ]]; then
      hook_deny WF205 "削除の対象を読み取れなかった（クォート等で潰れている）。消すファイルをパスでそのまま指定すること。" "$(__wg_cmd_head)"
    fi
    # 展開前の文字列は、どのパスになるか決まらない（`.claude/hooks/*` が glob として宣言に一致してしまう）
    if [[ "$t" == *'*'* || "$t" == *'?'* || "$t" == *'['* || "$t" == *'{'* \
       || "$t" == *'$'* || "$t" == *'`'* || "$t" == *'~'* || "$t" == *','* ]]; then
      hook_deny WF205 "削除の対象 $t は展開してからでないとパスが決まらない（glob・ブレース・変数・コンマ区切り）。消すファイルを 1 つずつ書くこと。$__WG_NO_BYPASS" "$(__wg_cmd_head)"
    fi
    __wg_rel "$t"; p="$REPLY"
    if __wg_delete_covers_guarded "$p"; then
      hook_deny WF205 "$p を丸ごと消すと、配下の保護範囲・毎回確認の範囲・進行状態のファイルまで巻き込む。中のファイルを 1 つずつ消すこと。$__WG_NO_BYPASS" "$(__wg_cmd_head)"
    fi
    if ! __wg_delete_ok "$p"; then
      hook_deny WF205 "$p を消そうとしているが、$(__wg_ticket_line)が宣言した allow.write の外（判定 $SC_STAGE）。コマンドで消せるのは wip/tmp/** と logs/**、それに宣言した範囲だけ。$__WG_NO_BYPASS" "$(__wg_cmd_head)"
    fi
  done
  return 0
}

# 提供コマンドの引数に現れるパスにも、書き込みと同じ判定を当てる（仕様 制御方式 6・WG-T14）
__wg_check_provided_args() { # $1=セグメント番号
  local i="$1" a skip=0 first=1 p
  cmdpos_args "$i"
  for a in ${REPLY_ARGS[@]+"${REPLY_ARGS[@]}"}; do
    if (( first )); then first=0; continue; fi          # 第 1 引数は提供コマンド自身
    if (( skip )); then skip=0; continue; fi
    if [[ "$__WG_VALUE_OPTS" == *" $a "* ]]; then skip=1; continue; fi
    [[ "$a" == -* ]] && continue
    # パスらしい語だけを見る（メッセージ・番号・部分文字列を対象にしない）
    [[ "$a" == *[[:space:]]* ]] && continue
    if [[ "$a" == */* ]] || [[ "$a" =~ ^[A-Za-z0-9_.@-]+\.[A-Za-z0-9]+$ ]]; then
      __wg_rel "$a"; p="$REPLY"
      __wg_judge_path "$p" "$(__wg_cmd_head)"
    fi
  done
  return 0
}

__wg_i=0
for (( __wg_i = 0; __wg_i < CP_COUNT; __wg_i++ )); do
  # データだけの段（ヒアドキュメント本文・コメント）は実行位置ではない
  [[ "${CP_DATA[$__wg_i]:-0}" == 1 ]] && continue

  # scope_classify は SC_CLASS / SC_TARGETS にも置く。コマンド置換で呼ぶと副作用が子シェルに閉じるので、
  # 標準出力は捨てて変数から受け取る
  scope_classify "$__wg_i" >/dev/null
  __WG_SEG_CLASS="$SC_CLASS"
  # 分類が何であれ、シェルのリダイレクト先は書き込みとして見る（web の出力先は SC_TARGETS に入る）
  __WG_TARGETS="${SC_TARGETS:-}"
  if [[ -n "${CP_REDIRECTS[$__wg_i]:-}" ]]; then
    __WG_TARGETS="${__WG_TARGETS}${__WG_TARGETS:+$__WG_US}${CP_REDIRECTS[$__wg_i]}"
  fi

  # 削除だけの段は allow.write で判定する（作成・更新は従来どおり Edit / Write に寄せる）。
  # リダイレクト先は削除ではなく書き込みなので、置き場の判定を当てる
  if __wg_is_delete_seg "$__wg_i"; then
    __wg_check_delete_targets "$__wg_i"
    __wg_check_write_targets "${CP_REDIRECTS[$__wg_i]:-}"
    continue
  fi

  case "$__WG_SEG_CLASS" in
    provided)
      __wg_check_provided_args "$__wg_i"
      __wg_check_write_targets "$__WG_TARGETS"
      continue
      ;;
    opaque)
      hook_deny WF209 "文字列をコードとして受け取る実行系（eval 等）は中身を判定できない。実行するコマンドをそのまま書くか、判定できない旨をユーザーに報告すること。$__WG_NO_BYPASS" "$(__wg_cmd_head)"
      ;;
    write)
      __wg_check_write_targets "$__WG_TARGETS"
      continue
      ;;
    read|remote-read)
      __wg_check_write_targets "$__WG_TARGETS"
      continue
      ;;
    remote-write:upload)
      hook_deny WF206 "本文やファイルを送る形のリモート操作（curl / wget の送信側）は、宣言があっても行わない。取得だけなら送信のオプションを外すこと。" "$(__wg_cmd_head)"
      ;;
    remote-write:*)
      __wg_check_write_targets "$__WG_TARGETS"
      if scope_op_declared "$__WG_SEG_CLASS"; then continue; fi
      hook_deny WF206 "リモートへの書き込み（${__WG_SEG_CLASS#remote-write:}）は $(__wg_ticket_line)の allow.ops に無い。リモート書き込みはワークの切れ目の処理か、宣言した種別だけで行う。$__WG_NO_BYPASS" "$(__wg_cmd_head)"
      ;;
    hook-test|build-test|merge-base|web)
      __wg_check_write_targets "$__WG_TARGETS"
      if scope_op_declared "$__WG_SEG_CLASS"; then continue; fi
      hook_deny WF204 "${CP_EXE[$__wg_i]:-このコマンド} は $__WG_SEG_CLASS に当たるが、$(__wg_ticket_line)の allow.ops に無い。許可されるのは読み取り系のコマンド・宣言した ops・提供コマンドだけ。$__WG_NO_BYPASS" "$(__wg_cmd_head)"
      ;;
    *)
      hook_deny WF204 "${CP_EXE[$__wg_i]:-このコマンド} はどの分類にも当たらない（既定拒否）。読み取り系の一覧に足すか、チケットの allow.ops で分類を宣言すること。$__WG_NO_BYPASS" "$(__wg_cmd_head)"
      ;;
  esac
done

hook_record allow "" "$(__wg_cmd_head)" "種類 $SC_TICKET_TYPE / $CP_COUNT 段"
exit 0
