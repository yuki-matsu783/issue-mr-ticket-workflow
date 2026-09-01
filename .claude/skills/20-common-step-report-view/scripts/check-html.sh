#!/usr/bin/env bash
# check-html.sh — HTML ビューの機械検査（提供コマンド）
# 仕様: .claude/docs/10_spec/skills/20-common-step-report-view.md「check-html.sh」
# 使い方: bash .claude/skills/20-common-step-report-view/scripts/check-html.sh <file.html>
#   検査 1〜7（RV001〜RV007）を全項目実行し、未充足を全件列挙する。必須節はテンプレート（<body data-template="report|plan">
#   で特定。無ければ置き場のディレクトリで推定）の data-required 要素から導出する。
# 終了コード: 成功 0 / 検査不合格 1 / 引数・ファイル不正 2。最終行は `OK: ...` または `RV<番号>: ...`
set -euo pipefail

# 共通ライブラリの読み込み行（20-common-step-shell-script 仕様「読み込み行」が正）。引数 <lib> <policy> だけを変え、中身を改変しない。
# shellcheck disable=SC1090,SC2317
__ss_load() { local lib="$1" pol="$2" d="${BASH_SOURCE[1]%/*}" r="" f=""; [ "$d" = "${BASH_SOURCE[1]}" ] && d="."; case "$d" in /*|[A-Za-z]:/*) ;; *) d="$PWD/$d" ;; esac; while [ -n "$d" ] && [ ! -d "$d/.claude" ]; do case "$d" in */*) d="${d%/*}" ;; *) d="" ;; esac; done; r="$d"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; if [ ! -f "$f" ] && [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then r="${CLAUDE_PROJECT_DIR//\\//}"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ ! -f "$f" ] && command -v git >/dev/null 2>&1; then r="$(git rev-parse --show-toplevel 2>/dev/null || true)"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ -n "$r" ] && [ -f "$f" ]; then LOGGER_ROOT="$r"; export LOGGER_ROOT; . "$f"; return 0; fi; case "$pol" in nop) log_debug() { :; }; log_info() { :; }; log_warn() { :; }; log_error() { :; }; fm_extract() { FM_BLOCK=""; return 1; }; fm_get() { return 1; }; fm_list() { return 1; }; fm_has() { return 1; } ;; deny) printf '%s\n' "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"${HOOK_DENY_ID:-WF009}: 機構の不調 — 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）\"}}"; exit 0 ;; *) printf '%s\n' "FATAL: 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）"; exit 2 ;; esac; }
__ss_load logger nop

readonly SCRIPT_PREFIX="RV"
readonly TEMPLATE_DIR=".claude/skills/20-common-step-report-view/assets"

usage() {
  cat <<'USAGE'
使い方: bash .claude/skills/20-common-step-report-view/scripts/check-html.sh <file.html>
  1 プレースホルダ {{名前}} 0 件 / 2 外部リソース 0 件 / 3 id の重複なし / 4 ページ内リンクの参照先あり /
  5 <style> がちょうど 1 つ / 6 テンプレートの必須節（data-required）がすべて存在 / 7 id・リンクが 0 件なら不合格（負のコントロール）
USAGE
}

result_ng2() { log_warn "${SCRIPT_PREFIX}: $1"; printf '%s\n' "$1"; exit 2; }

# HTML コメントを除く（純 bash。地の文で <style> や id="…" に触れるコメントを数えないため）
strip_comments() { # $1=内容 → REPLY
  local s="$1" pre rest
  while [[ "$s" == *"<!--"* ]]; do
    pre="${s%%<!--*}"
    rest="${s#*<!--}"
    if [[ "$rest" == *"-->"* ]]; then rest="${rest#*-->}"; else rest=""; fi
    s="$pre$rest"
  done
  REPLY="$s"
}

# 開きタグ内の id 属性だけを抽出する
extract_ids() { printf '%s' "$1" | grep -oE '<[A-Za-z][^>]*[[:space:]]id="[^"]+"' | sed 's/.*id="//; s/"$//' || true; }
# data-required 要素の識別子（id があれば id、無ければ tag@出現順）
extract_required() {
  local tags tag id line n=0
  { printf '%s' "$1" | grep -oE '<[A-Za-z][^>]*[[:space:]]data-required([[:space:]>]|=)[^>]*>?' || true; } | while IFS= read -r line; do
    tag="$(printf '%s' "$line" | sed -E 's/^<([A-Za-z0-9]+).*/\1/')"
    id="$(printf '%s' "$line" | grep -oE '[[:space:]]id="[^"]+"' | head -1 | sed 's/.*id="//; s/"$//' || true)"
    n=$((n + 1))
    if [ -n "$id" ]; then printf '%s#%s\n' "$tag" "$id"; else printf '%s@%d\n' "$tag" "$n"; fi
  done
}

main() {
  [ $# -eq 1 ] || { usage; result_ng2 "RV: 引数は HTML ファイル 1 つ"; }
  case "$1" in -h|--help) usage; exit 0 ;; esac
  local file="$1"
  cd "$LOGGER_ROOT" || result_ng2 "RV: リポジトリルートに移動できない: $LOGGER_ROOT"
  [ -f "$file" ] || result_ng2 "RV: ファイルが無い: $file"
  case "$file" in *.html) ;; *) result_ng2 "RV: .html 以外は検査しない: $file" ;; esac
  log_info "start $file"

  local raw body
  raw="$(cat "$file")"
  raw="${raw//$'\r'/}"
  strip_comments "$raw"; body="$REPLY"
  local fails=()

  # 1. プレースホルダ（コメント内も含めて数える — 雛形の痕跡）
  local ph
  ph="$(printf '%s' "$raw" | grep -oE '\{\{[^{}]*\}\}' | sort | uniq -c | awk '{ n=$1; $1=""; sub(/^ /, ""); printf "%s×%d ", $0, n }' || true)"
  [ -z "$ph" ] || fails+=("RV001: プレースホルダが残っている: ${ph}")

  # 2. 外部リソース（src 属性・<link href>・CSS url()・@import。data: URI と <a href> は対象外）
  local ext=()
  while IFS= read -r line; do [ -n "$line" ] && ext+=("$line"); done < <(printf '%s' "$body" | grep -oE '<(img|script|iframe|video|audio|source|embed|object|track)[^>]*[[:space:]]src="[^"]*"' | grep -vE 'src="data:' || true)
  while IFS= read -r line; do [ -n "$line" ] && ext+=("$line"); done < <(printf '%s' "$body" | grep -oE '<link[^>]*[[:space:]]href="[^"]*"' || true)
  # url() は @import 文の中のものを二重に数えない
  local body_no_import; body_no_import="$(printf '%s' "$body" | sed -E 's/@import[[:space:]]+[^;]+;?//g')"
  while IFS= read -r line; do [ -n "$line" ] && ext+=("$line"); done < <(printf '%s' "$body_no_import" | grep -oE 'url\([^)]*\)' | grep -vE '^url\(["'"'"']?data:' || true)
  while IFS= read -r line; do [ -n "$line" ] && ext+=("$line"); done < <(printf '%s' "$body" | grep -oE '@import[[:space:]]+[^;]+' || true)
  [ "${#ext[@]}" -eq 0 ] || fails+=("RV002: 外部リソースの読み込みがある（${#ext[@]} 件）: $(printf '%s | ' "${ext[@]}" | cut -c1-300)")

  # 3. id の重複
  local ids dup
  ids="$(extract_ids "$body")"
  dup="$(printf '%s\n' "$ids" | sed '/^$/d' | sort | uniq -d | tr '\n' ' ')"
  [ -z "$dup" ] || fails+=("RV003: id が重複している: ${dup}")

  # 4. ページ内リンクの参照先
  local hrefs broken
  hrefs="$(printf '%s' "$body" | grep -oE 'href="#[^"]+"' | sed 's/^href="#//; s/"$//' | sort -u || true)"
  broken="$(comm -23 <(printf '%s\n' "$hrefs" | sed '/^$/d') <(printf '%s\n' "$ids" | sed '/^$/d' | sort -u) | tr '\n' ' ')"
  [ -z "$broken" ] || fails+=("RV004: 参照先の無いページ内リンク: ${broken}")

  # 5. <style> がちょうど 1 つ
  local styles
  styles="$(printf '%s' "$body" | grep -oE '<style([[:space:]][^>]*)?>' | wc -l | tr -d ' ')"
  [ "$styles" -eq 1 ] || fails+=("RV005: <style> 要素が ${styles} 個（ちょうど 1 つにする）")

  # 6. テンプレートの必須節
  local kind template treq missing="" req
  kind="$(printf '%s' "$body" | grep -oE '<body[^>]*data-template="[^"]+"' | sed 's/.*data-template="//; s/"$//' | head -1 || true)"
  if [ -z "$kind" ]; then
    case "$file" in */wip/30_reports/*|wip/30_reports/*) kind="report" ;; */wip/20_plans/*|wip/20_plans/*) kind="plan" ;; esac
  fi
  template="$TEMPLATE_DIR/$kind.template.html"
  if [ -z "$kind" ] || [ ! -f "$template" ]; then
    fails+=("RV006: テンプレートを特定できない（<body data-template=\"report|plan\"> が無く、置き場からも推定できない）")
  else
    local traw tbody
    traw="$(cat "$template")"; traw="${traw//$'\r'/}"
    strip_comments "$traw"; tbody="$REPLY"
    treq="$(extract_required "$tbody")"
    local have_req_tags; have_req_tags="$(extract_required "$body")"
    while IFS= read -r req; do
      [ -z "$req" ] && continue
      case "$req" in
        *#*) printf '%s\n' "$ids" | grep -qx -- "${req#*#}" || missing+=" ${req#*#}" ;;
        *@*) # id 無し: 同じタグの data-required 要素の数で比べる
          local tag="${req%@*}" need have
          need="$(printf '%s\n' "$treq" | grep -c "^$tag@" || true)"
          have="$(printf '%s\n' "$have_req_tags" | grep -c "^$tag@" || true)"
          [ "$have" -ge "$need" ] || missing+=" <$tag data-required>" ;;
      esac
    done <<<"$treq"
    [ -z "$missing" ] || fails+=("RV006: テンプレート（$kind）の必須節が無い:${missing}")
  fi

  # 7. 負のコントロール
  local nid nlink
  nid="$(printf '%s\n' "$ids" | sed '/^$/d' | wc -l | tr -d ' ')"
  nlink="$(printf '%s\n' "$hrefs" | sed '/^$/d' | wc -l | tr -d ' ')"
  if [ "$nid" -eq 0 ] || [ "$nlink" -eq 0 ]; then fails+=("RV007: id ${nid} 件 / ページ内リンク ${nlink} 件（0 件は抽出の故障を疑い、合格にしない）"); fi

  if [ "${#fails[@]}" -eq 0 ]; then
    log_info "OK $file ids=$nid links=$nlink"
    printf 'OK: 検査 7 項目すべて通過（id %s 件 / リンク %s 件を確認。テンプレート: %s）\n' "$nid" "$nlink" "$kind"
    exit 0
  fi
  log_warn "NG $file: ${#fails[@]} 件"
  printf '%s\n' "${fails[@]}"
  exit 1
}

main "$@"
