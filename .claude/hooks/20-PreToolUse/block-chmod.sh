#!/usr/bin/env bash
# block-chmod.sh — 禁止コマンド（既定は chmod）の実行を拒否する
# 仕様: .claude/docs/10_spec/hooks/20-PreToolUse/block-chmod.md（判定順・エラー識別子の正）
# 登録: PreToolUse / matcher `Bash|PowerShell`（フック共通仕様 §1 の PreToolUse 4 行目。位置であって実行順ではない）
# 出力: deny（WF501 / WF509）または無出力の許可
set -euo pipefail

# 判定不能で拒否側に倒すときの識別子。読み込み行より前に置く（読み込み行の deny ポリシーが参照する）
HOOK_DENY_ID="WF509"

# 共通ライブラリの読み込み行（20-common-step-shell-script 仕様「読み込み行」が正）。引数 <lib> <policy> だけを変え、中身を改変しない。
# shellcheck disable=SC1090,SC2317
__ss_load() { local lib="$1" pol="$2" d="${BASH_SOURCE[1]%/*}" r="" f=""; [ "$d" = "${BASH_SOURCE[1]}" ] && d="."; case "$d" in /*|[A-Za-z]:/*) ;; *) d="$PWD/$d" ;; esac; while [ -n "$d" ] && [ ! -d "$d/.claude" ]; do case "$d" in */*) d="${d%/*}" ;; *) d="" ;; esac; done; r="$d"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; if [ ! -f "$f" ] && [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then r="${CLAUDE_PROJECT_DIR//\\//}"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ ! -f "$f" ] && command -v git >/dev/null 2>&1; then r="$(git rev-parse --show-toplevel 2>/dev/null || true)"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ -n "$r" ] && [ -f "$f" ]; then LOGGER_ROOT="$r"; export LOGGER_ROOT; [ "$lib" = frontmatter ] && FM_AVAILABLE=1; . "$f"; return 0; fi; [ "$lib" = frontmatter ] && FM_AVAILABLE=0; case "$pol" in nop) LOGGER_ROOT="${r:-$PWD}"; export LOGGER_ROOT; log_debug() { :; }; log_info() { :; }; log_warn() { :; }; log_error() { :; }; fm_extract() { FM_BLOCK=""; return 2; }; fm_get() { return 2; }; fm_list() { return 2; }; fm_has() { return 2; } ;; deny) printf '%s\n' "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"${HOOK_DENY_ID:-WF009}: 機構の不調 — 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）\"}}"; exit 0 ;; *) printf '%s\n' "FATAL: 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）"; exit 2 ;; esac; }
__ss_load logger nop

__bc_dir="${BASH_SOURCE[0]%/*}"
case "$__bc_dir" in /*|[A-Za-z]:/*) ;; *) __bc_dir="$PWD/$__bc_dir" ;; esac
# shellcheck source=/dev/null
. "$__bc_dir/../lib/hook-common.sh"

hook_init block-chmod deny WF509
hook_fail_closed

# 制御方式 1: 停止中なら何もしない（§4）
hook_enforce_enabled || hook_disabled

# 入力（jq 1 回。副入力は要らない）
hook_read_input || hook_fail "入力を読めない"

# 禁止コマンドの一覧（1 行 1 コマンド。`#` はコメント。一覧をコードに埋めない）
_bc_blocked=()
_bc_load_blocked() {
  local f="$HOOK_ROOT/.claude/hooks/config/blocked-commands.txt" line
  _bc_blocked=()
  [[ -f "$f" ]] || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line//$'\r'/}"
    line="${line%%#*}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -n "$line" ]] && _bc_blocked+=("${line,,}")
  done < "$f"
  return 0
}
_bc_load_blocked

# 一覧が空なら拒否するものが無い
(( ${#_bc_blocked[@]} > 0 )) || hook_allow

# 難読化を取り除いた複製（語の照合にだけ使う。これで再解析はしない —
# 再解析すると文字列の中の `;` `|` `(` `)` が本物の区切りに昇格して過剰拒否になる）。
# 落とすのは空のクォート対と、中身の見えない展開。
# 文字単位の走査なので長さに上限を掛ける（超えたら空を返し、他の複製で判定する）
__BC_DEOB_MAX=4096
_bc_deobfuscate() { # $1=コマンド文字列 → REPLY
  local str="$1" out="" i=0 n c nx depth
  n=${#str}
  if (( n > __BC_DEOB_MAX )); then REPLY=""; return 0; fi
  while (( i < n )); do
    c="${str:i:1}"
    case "$c" in
      '$')
        nx="${str:i+1:1}"
        case "$nx" in
          '(')  depth=0; i=$(( i + 1 ))
                while (( i < n )); do
                  case "${str:i:1}" in
                    '(') depth=$(( depth + 1 )) ;;
                    ')') depth=$(( depth - 1 )); (( depth == 0 )) && { i=$(( i + 1 )); break; } ;;
                  esac
                  i=$(( i + 1 ))
                done ;;
          '{')  i=$(( i + 2 ))
                while (( i < n )) && [[ "${str:i:1}" != '}' ]]; do i=$(( i + 1 )); done
                i=$(( i + 1 )) ;;
          "'"|'"') i=$(( i + 1 )) ;;          # $'…' / $"…" のクォートは次の反復で見る
          *)    i=$(( i + 1 ))
                while (( i < n )) && [[ "${str:i:1}" == [A-Za-z0-9_@*#?] ]]; do i=$(( i + 1 )); done ;;
        esac ;;
      "'"|'"'|'`')
        if [[ "${str:i+1:1}" == "$c" ]]; then i=$(( i + 2 ))   # 空の対だけ落とす
        else out+="$c"; i=$(( i + 1 )); fi ;;
      *) out+="$c"; i=$(( i + 1 )) ;;
    esac
  done
  REPLY="$out"
}

# 制御方式 2: 高速前置判定（外部プロセスなし・cmdpos.sh も読まない）。
# 生の文字列だけを見ると `c\hmod` `ch""mod` `ch$()mod` のように実行体を割って隠せるので、
# 難読化に使える記号と空白を落とした複製にも当てる（パラメータ展開だけ。走査もループもしない）。
# 空白まで落とすのは `ch$( )mod` のように展開の中身の空白が残る形を拾うため。
# 下の難読化除去の複製と重なるが、あちらは長さの上限で縮退して空になるので、
# 長いコマンドに隠した同じ形はこちらでしか拾えない
# ここは絞り込みなので、多少通しすぎても後段（制御方式 3〜5）が正しく判定する
_bc_lower="${HOOK_COMMAND,,}"
_bc_bare="${_bc_lower//[\$\\\"\'()\{\}\`]/}"
_bc_bare="${_bc_bare//[[:space:]]/}"
_bc_deob=""
_bc_hit=0
for _bc_c in "${_bc_blocked[@]}"; do
  if [[ "$_bc_lower" == *"$_bc_c"* || "$_bc_bare" == *"$_bc_c"* ]]; then _bc_hit=1; break; fi
done
# 記号を落とすだけでは `ch$( : )mod` `ch${x:-}mod` のように展開の中身が残って語が繋がらない。
# `$` かバッククォートがあるときだけ、展開を丸ごと落とした複製も作って当てる
# （難読化に `$` もバッククォートも使わない形は上の 2 つの複製で足りる）
if (( ! _bc_hit )) && [[ "$_bc_lower" == *\$* || "$_bc_lower" == *'`'* ]]; then
  _bc_deobfuscate "$HOOK_COMMAND"
  _bc_deob="${REPLY,,}"
  for _bc_c in "${_bc_blocked[@]}"; do
    if [[ "$_bc_deob" == *"$_bc_c"* ]]; then _bc_hit=1; break; fi
  done
fi
(( _bc_hit )) || hook_allow

# ここから先だけ cmdpos.sh を読む（前置判定で落ちる大多数は読み込まない）
# shellcheck source=/dev/null
. "$__bc_dir/../lib/cmdpos.sh"

_bc_deny() { # $1=コマンド名 $2=判定不能か
  local name="$1" degraded="$2" msg
  if (( degraded )); then
    # 実際に走るのが '$name' とは限らない。読み手が「文書に書いただけなのに拒否された」ときに
    # 何をすればよいか分かるよう、権限変更の案内だけを出さず、何が判定を妨げたかを添える
    msg="コマンドの中に禁止コマンド '$name' の語があり、"
    msg+="実行体を特定できない箇所（変数展開・コード文字列など）があるため拒否側に倒した。"
    msg+="実際に '$name' を実行するつもりなら、実行権限の変更は不要で、スクリプトは 'bash <パス>' で実行する。"
    msg+="実行するつもりが無い（文書・コメント・検索語として書いただけ）なら、"
    msg+="その語を含む部分を Write / Edit で書くか、シェルに渡さない形に変える。"
    msg+="迂回（環境変数での無効化・語の分割・言い換え）はしないこと"
  else
    msg="禁止コマンド '$name' の実行。実行権限の変更は不要で、スクリプトは 'bash <パス>' で実行する。"
    msg+="権限変更が本当に必要なら、迂回せずユーザーに提案すること"
  fi
  hook_deny WF501 "$msg" "$name: ${HOOK_COMMAND:0:120}"
}

# 制御方式 3: 実行位置の実行体（basename）が一覧に一致したら拒否。提供コマンドは対象外
_bc_check_exes() { # 解析済みの CP_* を見て、実行位置が一覧に一致したら拒否（戻らない）
  local i c
  for (( i = 0; i < CP_COUNT; i++ )); do
    [[ -n "${CP_PROVIDED[$i]:-}" ]] && continue
    for c in "${_bc_blocked[@]}"; do
      [[ "${CP_EXE[$i]:-}" == "$c" ]] && _bc_deny "$c" 0
    done
  done
  return 0
}
cmdpos_parse "$HOOK_COMMAND"
_bc_check_exes

# 制御方式 4: 判定不能な位置（opaque / 縮退）で一覧の語が現れたら拒否側に倒す。
#   (a) opaque な段の引数に一覧の語がそのまま出る（`ls | xargs chmod +x`）→ その語で拒否
#   (b) 中身が見えない形（クォートが `_` に潰れている / 実行体が変数 / 解析が縮退）→ コマンド全体を見る
#   コマンド全体を見るのは (b) だけにする。全段で見ると `grep chmod f | xargs echo` のように
#   別の段のデータとして現れただけの語で拒否してしまう（過剰拒否）
_bc_seg_unknown() { # $1=段 → 中身が見えないなら 0
  local i="$1" t
  [[ "${CP_EXE[$i]:-}" == *\$* ]] && return 0
  local IFS=$'\x1e'
  for t in ${CP_ARGS[$i]:-}; do [[ "$t" == "_" ]] && return 0; done
  return 1
}
if (( CP_DEGRADED )); then _bc_deny "${_bc_blocked[0]}" 1; fi
for (( _bc_i = 0; _bc_i < CP_COUNT; _bc_i++ )); do
  if [[ "${CP_OPAQUE[$_bc_i]:-0}" == 1 ]]; then
    _bc_seg=" ${CP_EXE[$_bc_i]:-} ${CP_ARGS[$_bc_i]//$'\x1e'/ } "
    for _bc_c in "${_bc_blocked[@]}"; do
      [[ "$_bc_seg" == *" $_bc_c "* ]] && _bc_deny "$_bc_c" 1
    done
  fi
  if [[ "${CP_OPAQUE[$_bc_i]:-0}" == 1 ]] && _bc_seg_unknown "$_bc_i"; then
    for _bc_c in "${_bc_blocked[@]}"; do
      [[ "${CP_LOWER}" == *"$_bc_c"* || "$_bc_bare" == *"$_bc_c"* ]] && _bc_deny "$_bc_c" 1
    done
  fi
  :
done

# 制御方式 5: 実行位置に難読化の痕跡があれば「実行体を特定できない」として拒否側に倒す。
#   `"chmod"` `c"h"mod` `ch$( )mod` `ch${x:-}mod` はいずれも bash が chmod として実行するが、
#   文字列を操作して「何が実行されるか」を復元する方針では、シェルの表記を列挙し切れない
#   （取りこぼし → 過剰拒否 → 取りこぼしの再発、と往復した）。復元をやめ、
#   **実行体を特定できたかどうか**だけを見る。特定できない段が 1 つでもあれば、
#   一覧の語がコマンドのどこかに現れる時点で拒否する。
#
#   代償は過剰拒否で、「実行体に難読化があり、かつコマンドが禁止語に言及する」形を
#   誤って拒否すること。取りこぼし（実際に chmod が走る）より軽い交換として受け入れる。
#   対照（実行体が清けていて本文だけが禁止語に言及する形）は BC-T02 に同数置く。
#
#   cmdpos の正規化はクォートの範囲を `_` に潰し、`$` はそのまま残す。したがって
#   - 実行体に `$` かバッククォートがある → 特定できない
#   - 実行体がすべて `_` → 特定できない（`"chmod"` `'chmod'` `"/usr/bin/chmod"`）
#   - 実行体に `_` があり、生のコマンド文字列にその実行体がそのまま現れない
#     → 潰れたクォート由来（`c"h"mod` → `c_mod`）。元から `_` を含む `my_tool.sh` は現れるので通る
_bc_exe_unknown() { # $1=段 → 実行体を特定できないなら 0
  local exe="${CP_EXE[$1]:-}"
  [[ -z "$exe" ]] && return 0
  [[ "$exe" == *\$* || "$exe" == *'`'* ]] && return 0
  if [[ "$exe" == *_* ]]; then
    [[ "$exe" == *[!_]* ]] || return 0
    [[ "$_bc_lower" == *"$exe"* ]] || return 0
  fi
  return 1
}

for (( _bc_i = 0; _bc_i < CP_COUNT; _bc_i++ )); do
  [[ -n "${CP_PROVIDED[$_bc_i]:-}" ]] && continue
  # ヒアドキュメント本文とコメント行は実行位置ではない（bash は決して実行しない）。
  # 正規化はこれらも潰れたクォートも同じ `_` にするので、CP_DATA でしか区別できない。
  # ここを外すと「本文に禁止語を書いただけ」で拒否側に倒れる（0028 の実測で登録から 3 回目に踏んだ）
  [[ "${CP_DATA[$_bc_i]:-0}" == 1 ]] && continue
  if _bc_exe_unknown "$_bc_i"; then
    for _bc_c in "${_bc_blocked[@]}"; do
      if [[ "$_bc_lower" == *"$_bc_c"* || "$_bc_bare" == *"$_bc_c"* || "$_bc_deob" == *"$_bc_c"* ]]; then
        _bc_deny "$_bc_c" 1
      fi
    done
  fi
  :
done

# 制御方式 6: それ以外は許可（記録しない）
hook_allow
