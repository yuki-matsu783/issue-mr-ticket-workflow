#!/usr/bin/env bash
# block-direct-git.sh — git のコミット・push の直接実行を拒否して提供コマンドを案内する
# 仕様: .claude/docs/10_spec/hooks/20-PreToolUse/block-direct-git.md（判定・WF40x）。
#       コマンド位置の判定の正はこのフックで、規則はフック共通仕様 §7 に置く
# 登録: PreToolUse / matcher `Bash|PowerShell`
# 出力: deny（WF401 / WF402 / WF403 / WF409）または許可（無出力）
#
# 判定は純 bash（cmdpos.sh）で行い、外部プロセスを起動しない。jq は入力の読み取りの 1 回だけ。
set -euo pipefail

HOOK_DENY_ID="WF409"

# 共通ライブラリの読み込み行（20-common-step-shell-script 仕様「読み込み行」が正）。引数 <lib> <policy> だけを変え、中身を改変しない。
# shellcheck disable=SC1090,SC2317
__ss_load() { local lib="$1" pol="$2" d="${BASH_SOURCE[1]%/*}" r="" f=""; [ "$d" = "${BASH_SOURCE[1]}" ] && d="."; case "$d" in /*|[A-Za-z]:/*) ;; *) d="$PWD/$d" ;; esac; while [ -n "$d" ] && [ ! -d "$d/.claude" ]; do case "$d" in */*) d="${d%/*}" ;; *) d="" ;; esac; done; r="$d"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; if [ ! -f "$f" ] && [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then r="${CLAUDE_PROJECT_DIR//\\//}"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ ! -f "$f" ] && command -v git >/dev/null 2>&1; then r="$(git rev-parse --show-toplevel 2>/dev/null || true)"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ -n "$r" ] && [ -f "$f" ]; then LOGGER_ROOT="$r"; export LOGGER_ROOT; [ "$lib" = frontmatter ] && FM_AVAILABLE=1; . "$f"; return 0; fi; [ "$lib" = frontmatter ] && FM_AVAILABLE=0; case "$pol" in nop) LOGGER_ROOT="${r:-$PWD}"; export LOGGER_ROOT; log_debug() { :; }; log_info() { :; }; log_warn() { :; }; log_error() { :; }; fm_extract() { FM_BLOCK=""; return 2; }; fm_get() { return 2; }; fm_list() { return 2; }; fm_has() { return 2; } ;; deny) printf '%s\n' "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"${HOOK_DENY_ID:-WF009}: 機構の不調 — 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）\"}}"; exit 0 ;; *) printf '%s\n' "FATAL: 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）"; exit 2 ;; esac; }
__ss_load logger nop

__bg_dir="${BASH_SOURCE[0]%/*}"
case "$__bg_dir" in /*|[A-Za-z]:/*) ;; *) __bg_dir="$PWD/$__bg_dir" ;; esac
# shellcheck source=/dev/null
. "$__bg_dir/../lib/hook-common.sh"
# shellcheck source=/dev/null
. "$__bg_dir/../lib/cmdpos.sh"

hook_init block-direct-git deny WF409
hook_fail_closed

# 制御方式 1: 停止中なら何もしない（§4）
hook_enforce_enabled || hook_disabled

# 入力（jq 1 回。副入力は要らない）
hook_read_input || hook_fail "入力を読めない"

# コミットを生成するサブコマンド（commit 以外）。commit.sh の規約検査を迂回するので同じく拒否する。
# `merge` と `stash` は明示的に対象外（DDR i0004-07）
__BG_COMMIT_SUBCMDS=' revert cherry-pick am rebase commit-tree '
__BG_TARGET_WORDS=' commit push revert cherry-pick am rebase commit-tree '

__BG_CMD="${HOOK_COMMAND:-}"
[[ -n "$__BG_CMD" ]] || hook_allow

__bg_target() { # 記録用の対象（先頭 80 文字。redact は hook_record が掛ける）
  printf '%s' "${__BG_CMD:0:80}"
}

__BG_HOWTO_COMMIT="コミットは提供コマンドで行う: bash .claude/skills/20-common-step-commit-push/scripts/commit.sh -m \"<件名>\" <ファイル>...。手順は 20-common-step-commit-push に従う。"
__BG_HOWTO_PUSH="push は提供コマンドで行う: bash .claude/skills/20-common-step-commit-push/scripts/push.sh。push 前チェックを飛ばす必要があるなら wip/push-check-skip.md を置く（機構の緊急停止では飛ばせない）。"
__BG_NO_BYPASS="コマンドの分割・別の実行系（eval / PowerShell）・権限設定の変更・フックの登録解除で迂回しないこと。"

# 制御方式 2: コマンド列を得る（PowerShell は §7-6 の前処理）
cmdpos_parse "$__BG_CMD" "$([[ "$HOOK_TOOL" == PowerShell ]] && printf 'powershell' || printf 'bash')"

# 制御方式 4: 縮退（bash < 4.3 / 4096 文字超）は語の共起で拒否側に倒す
if (( CP_DEGRADED )); then
  if [[ "$CP_LOWER" == *git* ]] && { [[ "$CP_LOWER" == *commit* ]] || [[ "$CP_LOWER" == *push* ]]; }; then
    hook_deny WF403 "コマンドが長すぎる（または bash が古い）ため位置を判定できず、git と commit / push の語が共にあるので拒否側に倒した。$__BG_HOWTO_COMMIT $__BG_HOWTO_PUSH 実行が目的でないなら語を言い換える（.claude/rules/ai-command-style.md）。$__BG_NO_BYPASS" "$(__bg_target)"
  fi
  hook_allow
fi

# 制御方式 3: セグメントごとに判定する
__bg_i=0
for (( __bg_i = 0; __bg_i < CP_COUNT; __bg_i++ )); do
  # データだけの段（ヒアドキュメント本文・コメント）は実行位置ではない
  [[ "${CP_DATA[$__bg_i]:-0}" == 1 ]] && continue
  # 提供コマンド（§7-8）の内部処理は対象外
  [[ -n "${CP_PROVIDED[$__bg_i]:-}" ]] && continue

  # 文字列をコードとして受け取る実行系は中身を見られない。対象語があれば拒否側へ
  if [[ "${CP_OPAQUE[$__bg_i]:-0}" == 1 ]]; then
    if [[ "$CP_LOWER" == *commit* ]] || [[ "$CP_LOWER" == *push* ]]; then
      hook_deny WF403 "文字列をコードとして受け取る実行系（eval / bash -c / xargs / find -exec など）の中に commit / push の語があり、実行体を特定できないので拒否側に倒した。$__BG_HOWTO_COMMIT $__BG_HOWTO_PUSH $__BG_NO_BYPASS" "$(__bg_target)"
    fi
    continue
  fi

  __bg_exe="${CP_EXE[$__bg_i]:-}"
  __bg_sub="${CP_SUBCMD[$__bg_i]:-}"
  __bg_gitlike="${CP_GITLIKE[$__bg_i]:-0}"

  if [[ "$__bg_exe" != git && "$__bg_gitlike" != 1 ]]; then continue; fi

  # サブコマンドが 1 つも無い（`git` 単独、PowerShell のヒアストリングのようにデータごと潰れた段）は害が無い。
  # 「語はあるが読めない」（`_`）とは区別する — 前者は実行しても何も起きず、後者は何が走るか分からない
  [[ -z "$__bg_sub" ]] && continue

  # 第 1 サブコマンドが特定できない（クォートで語が割れた等）→ 拒否側（DDR i0009-01）
  if [[ "$__bg_sub" == "_" ]]; then
    hook_deny WF403 "git の第 1 サブコマンドを特定できない（クォートや展開で語が割れている）ため拒否側に倒した。サブコマンドはクォートで割らずに書く（git 'commit' ではなく git commit）。ただし実行が目的なら提供コマンドを使う。$__BG_HOWTO_COMMIT $__BG_HOWTO_PUSH $__BG_NO_BYPASS" "$(__bg_target)"
  fi

  case "$__bg_sub" in
    commit)
      hook_deny WF401 "git commit の直接実行は行わない。$__BG_HOWTO_COMMIT $__BG_NO_BYPASS" "$(__bg_target)" ;;
    push)
      hook_deny WF402 "git push の直接実行は行わない。$__BG_HOWTO_PUSH $__BG_NO_BYPASS" "$(__bg_target)" ;;
  esac
  if [[ "$__BG_COMMIT_SUBCMDS" == *" $__bg_sub "* ]]; then
    hook_deny WF401 "git $__bg_sub はコミットを生成するサブコマンドで、commit.sh の規約検査（件名の形式・除外パターン）を迂回するため拒否する。$__BG_HOWTO_COMMIT $__BG_NO_BYPASS" "$(__bg_target)"
  fi
  # PowerShell などで実行体を特定できない（CP_GITLIKE）場合、対象外のサブコマンドなら通す（§7-6）
done

# 制御方式 6: いずれにも該当しない（記録しない）
hook_allow
