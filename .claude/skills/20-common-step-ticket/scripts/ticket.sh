#!/usr/bin/env bash
# ticket.sh — チケットの作成・着手・完了・取り消し・次の提示（提供コマンド）
# 仕様: .claude/docs/10_spec/skills/20-common-step-ticket.md「Script 処理」
# 使い方: bash .claude/skills/20-common-step-ticket/scripts/ticket.sh <create|start|complete|cancel|next> [args]
#   create <種類> --title <見出し> --purpose <目的> --dod <項目> [--dod ...] [--work <手順>]... [--predecessors "0001,0002"]
#          [--executor <main|モデル>] [--human-review true|false] [--human-review-reason <理由>]
#          [--adversarial-review true|false] [--adversarial-review-reason <理由>] [--allow-write "a/**,b/**"] [--allow-ops "read,build-test"]
#   start <番号> / complete <番号> / cancel <番号> --reason <理由> / next
# 状態変更のコミットは commit.sh 経由（overall-plan の create / start はコミットしない）。commit.sh が拒否したら作業ツリーを戻し、その最終行で失敗する。
# 終了コード: 成功 0 / 検査・前提未充足 1 / 引数や環境の誤り 2。最終行は `OK: ...` または `TK<番号>: ...`（next は JSON）
set -euo pipefail
shopt -u patsub_replacement 2>/dev/null || true

# 共通ライブラリの読み込み行（20-common-step-shell-script 仕様「読み込み行」が正）。引数 <lib> <policy> だけを変え、中身を改変しない。
# shellcheck disable=SC1090,SC2317
__ss_load() { local lib="$1" pol="$2" d="${BASH_SOURCE[1]%/*}" r="" f=""; [ "$d" = "${BASH_SOURCE[1]}" ] && d="."; case "$d" in /*|[A-Za-z]:/*) ;; *) d="$PWD/$d" ;; esac; while [ -n "$d" ] && [ ! -d "$d/.claude" ]; do case "$d" in */*) d="${d%/*}" ;; *) d="" ;; esac; done; r="$d"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; if [ ! -f "$f" ] && [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then r="${CLAUDE_PROJECT_DIR//\\//}"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ ! -f "$f" ] && command -v git >/dev/null 2>&1; then r="$(git rev-parse --show-toplevel 2>/dev/null || true)"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ -n "$r" ] && [ -f "$f" ]; then LOGGER_ROOT="$r"; export LOGGER_ROOT; . "$f"; return 0; fi; case "$pol" in nop) LOGGER_ROOT="${r:-$PWD}"; export LOGGER_ROOT; log_debug() { :; }; log_info() { :; }; log_warn() { :; }; log_error() { :; }; fm_extract() { FM_BLOCK=""; return 1; }; fm_get() { return 1; }; fm_list() { return 1; }; fm_has() { return 1; } ;; deny) printf '%s\n' "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"${HOOK_DENY_ID:-WF009}: 機構の不調 — 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）\"}}"; exit 0 ;; *) printf '%s\n' "FATAL: 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）"; exit 2 ;; esac; }
__ss_load logger nop
__ss_load frontmatter fatal

readonly SCRIPT_PREFIX="TK"
readonly TICKETS="wip/10_tickets"
readonly TODO="$TICKETS/00_todo" DOING="$TICKETS/10_doing" DONE="$TICKETS/20_done" CANCELLED="$TICKETS/30_cancelled"
readonly TEMPLATE=".claude/skills/20-common-step-ticket/assets/ticket.template.md"
readonly COMMIT=".claude/skills/20-common-step-commit-push/scripts/commit.sh"
readonly TASK_TYPES=".claude/hooks/config/task-types.tsv"
readonly LOG_HEADINGS=("現在地" "うまくいったこと" "うまくいかなかったこと" "仕様からの逸脱" "判断と根拠" "拒否・確認・迂回の記録" "使った AI アセットと効き目" "スコープ外で見つけたこと" "AI アセットに反映すべき内容" "備考")

usage() {
  cat <<'USAGE'
使い方: bash .claude/skills/20-common-step-ticket/scripts/ticket.sh <subcommand> [args]
  create <種類> --title <見出し> --purpose <目的> --dod <項目> [--dod ...] [--work <手順>]...
         [--predecessors "0001,0002"] [--executor main] [--human-review true|false] [--human-review-reason <理由>]
         [--adversarial-review true|false] [--adversarial-review-reason <理由>] [--allow-write "wip/**"] [--allow-ops "read"]
  start <番号>                  未着手 → 作業中（開始時刻・差分基準点を記録）
  complete <番号>               作業中 → 完了（DoD・作業ログ・未コミットの検査）
  cancel <番号> --reason <理由>  未着手/作業中 → 取り消し
  next                          次に着手するチケットを JSON で返す
USAGE
}

result_ok() { log_info "OK: $1"; printf 'OK: %s\n' "$1"; exit 0; }
result_ng() { log_warn "${SCRIPT_PREFIX}$1: $2"; printf '%s%s: %s\n' "$SCRIPT_PREFIX" "$1" "$2"; exit "$3"; }

now_iso() { local ts; printf -v ts '%(%Y-%m-%dT%H:%M:%S%z)T' -1; printf '%s:%s' "${ts:0:22}" "${ts:22}"; }
head_sha() { git rev-parse --short HEAD 2>/dev/null || true; }

# 番号からチケットを探す → T_PATH / T_STATE（todo|doing|done|cancelled|""）
find_ticket() {
  local n="$1" d f
  T_PATH=""; T_STATE=""
  for d in "$TODO:todo" "$DOING:doing" "$DONE:done" "$CANCELLED:cancelled"; do
    shopt -s nullglob
    for f in "${d%%:*}/$n-"*.md; do T_PATH="$f"; T_STATE="${d##*:}"; shopt -u nullglob; return 0; done
    shopt -u nullglob
  done
  return 1
}
doing_files() { shopt -s nullglob; DOING_FILES=("$DOING"/*.md); shopt -u nullglob; }
type_of() { fm_get "$1" ticket_type 2>/dev/null || true; }
skill_of() { # $1=type → tsv の 5 列目
  [ -f "$TASK_TYPES" ] || return 1
  awk -F'\t' -v t="$1" '$1 !~ /^#/ && $2 == t { sub(/\r$/, "", $5); print $5; found=1 } END { exit found ? 0 : 1 }' "$TASK_TYPES"
}
type_known() { skill_of "$1" >/dev/null 2>&1; }

# commit.sh を呼ぶ。失敗なら出力を表示し、最終行を COMMIT_LAST に入れて 1
do_commit() { # $1=件名 $2..=パス
  local msg="$1" out; shift
  local paths=() p
  for p in "$@"; do
    # 旧パスが未追跡（削除済みで index にも無い）なら渡さない
    if [ ! -e "$p" ] && ! git ls-files --error-unmatch -- "$p" >/dev/null 2>&1; then continue; fi
    paths+=("$p")
  done
  if out="$(bash "$COMMIT" -m "$msg" "${paths[@]}" 2>&1)"; then
    COMMIT_LAST="${out##*$'\n'}"
    return 0
  fi
  printf '%s\n' "$out"
  COMMIT_LAST="${out##*$'\n'}"
  # commit.sh がステージしたまま失敗した分を index から戻す（作業ツリーの復元は呼び手が行う）
  if [ "${#paths[@]}" -gt 0 ]; then git reset -q -- "${paths[@]}" >/dev/null 2>&1 || true; fi
  return 1
}

# 状態変更後のコミット失敗を、ticket.sh の失敗として返す（最終行は commit.sh のもの）
fail_with_commit_last() { log_warn "commit.sh の拒否: $COMMIT_LAST"; printf '%s\n' "$COMMIT_LAST"; exit 1; }

# frontmatter の二重引用符付きの値として書けるよう、sed の置換文字列に直す（改行は空白に。\ と " は YAML のエスケープ、| と & は sed の特殊文字）
# sed は置換文字列の `\\` を `\`、`\&` を `&`、`\|` を `|` にするので、ファイルには `\\`（\）と `\"`（"）が残る
sed_escape() { # $1=値 → REPLY
  local v="${1//$'\n'/ }"
  v="${v//\\/\\\\\\\\}"; v="${v//\"/\\\\\"}"; v="${v//&/\\&}"; v="${v//|/\\|}"
  REPLY="$v"
}
set_field() { # $1=file $2=key $3=value（frontmatter の `key: ""` 行を置き換える）
  sed_escape "$3"
  sed -i "s|^$2: \"\"|$2: \"$REPLY\"|" "$1"
}

# ---------------------------------------------------------------- create
cmd_create() {
  [ $# -ge 1 ] || result_ng 004 "create には種類を指定する（task-types.tsv の type）" 2
  local type="$1"; shift
  local title="" purpose="" preds="" executor="main" hr="true" hr_reason="既定（rules/work-defaults.md）" ar="false" ar_reason="既定（rules/work-defaults.md）" aw="wip/**" ao="read"
  local dod=() work=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --title) title="${2:-}"; shift ;;
      --purpose) purpose="${2:-}"; shift ;;
      --dod) dod+=("${2:-}"); shift ;;
      --work) work+=("${2:-}"); shift ;;
      --predecessors) preds="${2:-}"; shift ;;
      --executor) executor="${2:-}"; shift ;;
      --human-review) hr="${2:-}"; shift ;;
      --human-review-reason) hr_reason="${2:-}"; shift ;;
      --adversarial-review) ar="${2:-}"; shift ;;
      --adversarial-review-reason) ar_reason="${2:-}"; shift ;;
      --allow-write) aw="${2:-}"; shift ;;
      --allow-ops) ao="${2:-}"; shift ;;
      *) result_ng 004 "create の不明な引数: $1" 2 ;;
    esac
    shift
  done
  type_known "$type" || result_ng 004 "種類 '$type' は $TASK_TYPES に無い" 2
  [ -n "$title" ] && [ -n "$purpose" ] && [ "${#dod[@]}" -gt 0 ] || result_ng 001 "--title / --purpose / --dod（1 つ以上）は必須" 2
  case "$hr" in true|false) ;; *) result_ng 004 "--human-review は true か false" 2 ;; esac
  case "$ar" in true|false) ;; *) result_ng 004 "--adversarial-review は true か false" 2 ;; esac
  [ -f "$TEMPLATE" ] || result_ng 004 "テンプレートが無い: $TEMPLATE" 2

  # 1. 置き場
  mkdir -p "$TODO" "$DOING" "$DONE" "$CANCELLED"
  # 2. 連番（取り消し済みを含む全チケットの最大 + 1）
  local max=0 f n
  shopt -s nullglob
  for f in "$TICKETS"/*/[0-9][0-9][0-9][0-9]-*.md; do
    n="${f##*/}"; n="${n%%-*}"; n=$((10#$n))
    [ "$n" -gt "$max" ] && max=$n
  done
  shopt -u nullglob
  local num; printf -v num '%04d' $((max + 1))

  # 3. テンプレートを埋める
  json_list() { # "a,b" → ["a", "b"]
    local s="$1" out="" item; [ -z "$s" ] && { printf '[]'; return; }
    IFS=',' read -r -a arr <<<"$s"
    for item in "${arr[@]}"; do item="${item#"${item%%[![:space:]]*}"}"; item="${item%"${item##*[![:space:]]}"}"; [ -z "$item" ] && continue; out+="${out:+, }\"$item\""; done
    printf '[%s]' "$out"
  }
  local dod_text="" work_text="" item
  for item in "${dod[@]}"; do dod_text+="- [ ] ${item}（根拠: ）"$'\n'; done
  dod_text="${dod_text%$'\n'}"
  if [ "${#work[@]}" -eq 0 ]; then work_text="- DoD の各項目を順に満たす"; else for item in "${work[@]}"; do work_text+="- ${item}"$'\n'; done; work_text="${work_text%$'\n'}"; fi
  local content
  content="$(cat "$TEMPLATE")"
  content="${content//"{{TICKET_TYPE}}"/$type}"
  content="${content//"{{PREDECESSORS}}"/$(json_list "$preds")}"
  content="${content//"{{EXECUTOR}}"/$executor}"
  content="${content//"{{HUMAN_REVIEW_REQUIRED}}"/$hr}"
  content="${content//"{{HUMAN_REVIEW_REASON}}"/$hr_reason}"
  content="${content//"{{ADVERSARIAL_REVIEW_REQUIRED}}"/$ar}"
  content="${content//"{{ADVERSARIAL_REVIEW_REASON}}"/$ar_reason}"
  content="${content//"{{ALLOW_WRITE}}"/$(json_list "$aw")}"
  content="${content//"{{ALLOW_OPS}}"/$(json_list "$ao")}"
  content="${content//"{{NUMBER}}"/$num}"
  content="${content//"{{TITLE}}"/$title}"
  content="${content//"{{PURPOSE}}"/$purpose}"
  content="${content//"{{DOD}}"/$dod_text}"
  content="${content//"{{WORK}}"/$work_text}"
  local path="$TODO/$num-$type.md"
  printf '%s\n' "$content" > "$path"
  local left
  left="$(grep -o '{{[A-Z_]*}}' "$path" | sort -u | tr '\n' ' ' || true)"
  if [ -n "$left" ]; then rm -f "$path"; result_ng 001 "プレースホルダが残った: ${left}（テンプレートと引数を確認）" 1; fi
  log_info "create $path type=$type"

  # 4. コミット（overall-plan は行わない）
  if [ "$type" = "overall-plan" ]; then
    result_ok "$path を作成した（未着手。overall-plan はコミットしない — feature ブランチの開始コミットに載る）"
  fi
  if ! do_commit "chore: チケット $num を作成" "$path"; then
    rm -f "$path"
    fail_with_commit_last
  fi
  result_ok "$path を作成した（未着手。$COMMIT_LAST）"
}

# ---------------------------------------------------------------- start
cmd_start() {
  local n="${1:-}"; [[ "$n" =~ ^[0-9]{4}$ ]] || result_ng 004 "start には 4 桁の番号を指定する" 2
  doing_files
  if [ "${#DOING_FILES[@]}" -gt 0 ]; then
    result_ng 002 "作業中のチケットが既にある（${DOING_FILES[*]##*/}）。先に complete か cancel する" 1
  fi
  find_ticket "$n" || result_ng 004 "チケット $n が見つからない。手動で動かさず ticket.sh で扱う" 1
  [ "$T_STATE" = "todo" ] || result_ng 004 "チケット $n は未着手ではない（実際の置き場: $T_STATE = $T_PATH）。手動で動かさない" 1
  local type; type="$(type_of "$T_PATH")"
  # 先行チケット
  local missing="" p
  while IFS= read -r p; do
    [ -z "$p" ] && continue
    shopt -s nullglob; local hit=("$DONE/$p-"*.md); shopt -u nullglob
    [ "${#hit[@]}" -gt 0 ] || missing+=" $p"
  done < <(fm_list "$T_PATH" predecessors 2>/dev/null || true)
  [ -z "$missing" ] || result_ng 006 "先行チケットが未完了:${missing}（チケット $n）" 1

  local orig ts sha new
  orig="$(cat "$T_PATH")"
  ts="$(now_iso)"; sha="$(head_sha)"
  set_field "$T_PATH" started_at "$ts"
  set_field "$T_PATH" base_sha "$sha"
  new="$DOING/${T_PATH##*/}"
  mv "$T_PATH" "$new"
  log_info "start $n -> $new started_at=$ts base_sha=$sha"
  if [ "$type" = "overall-plan" ]; then
    result_ok "${new##*/} を作業中にした（開始 $ts / 基準点 ${sha:-なし}。overall-plan はコミットしない）"
  fi
  if ! do_commit "chore: チケット $n に着手" "$T_PATH" "$new"; then
    mv "$new" "$T_PATH"; printf '%s\n' "$orig" > "$T_PATH"
    fail_with_commit_last
  fi
  result_ok "${new##*/} を作業中にした（開始 $ts / 基準点 ${sha:-なし}。$COMMIT_LAST）"
}

# ---------------------------------------------------------------- complete
section() { # $1=file $2=見出し行の正規表現 → その節の本文（次の同レベル以上の見出しまで）
  awk -v re="$2" '
    $0 ~ re { f=1; lvl=match($0, /^#+/) ? RLENGTH : 0; next }
    f && /^#+ / { l=match($0, /^#+/) ? RLENGTH : 0; if (l <= lvl) { f=0 } }
    f { print }' "$1"
}
cmd_complete() {
  local n="${1:-}"; [[ "$n" =~ ^[0-9]{4}$ ]] || result_ng 004 "complete には 4 桁の番号を指定する" 2
  find_ticket "$n" || result_ng 004 "チケット $n が見つからない" 1
  [ "$T_STATE" = "doing" ] || result_ng 004 "チケット $n は作業中ではない（実際の置き場: $T_STATE = $T_PATH）。手動で動かさない" 1
  local type; type="$(type_of "$T_PATH")"
  [ "$type" != "overall-summary" ] || result_ng 005 "全体まとめは complete しない。片付けの提供コマンド（finalize.sh release）が完了を内包する" 1

  local unmet=() dod unchecked noroot cur ai h st
  dod="$(section "$T_PATH" '^## DoD')"
  unchecked="$(printf '%s\n' "$dod" | grep -n '^- \[ \]' | cut -d: -f1 | tr '\n' ' ' || true)"
  [ -z "$unchecked" ] || unmet+=("DoD に未チェックの項目がある（DoD 節の行 ${unchecked}）")
  noroot="$(printf '%s\n' "$dod" | grep -E '^- \[x\]' | grep -nE '（根拠:[[:space:]]*）|（根拠:[[:space:]]*$' | cut -d: -f1 | tr '\n' ' ' || true)"
  [ -z "$noroot" ] || unmet+=("チェック済み DoD の根拠欄が空（チェック済み項目の ${noroot}番目）")
  local noroot2
  noroot2="$(printf '%s\n' "$dod" | grep -E '^- \[x\]' | grep -nv '（根拠:' | cut -d: -f1 | tr '\n' ' ' || true)"
  [ -z "$noroot2" ] || unmet+=("チェック済み DoD に根拠欄「（根拠: ）」そのものが無い（チェック済み項目の ${noroot2}番目）。欄を消して通さない")
  for h in "${LOG_HEADINGS[@]}"; do grep -q "^### $h" "$T_PATH" || unmet+=("作業ログの見出し「$h」が無い"); done
  cur="$(section "$T_PATH" '^### 現在地')"
  if printf '%s\n' "$cur" | grep -qE '^- *(次|未着手)|未着手|^- *次[:：]'; then unmet+=("作業ログ「現在地」に未完了の項目が残っている（「次:」「未着手」）"); fi
  ai="$(section "$T_PATH" '^### AI アセットに反映すべき内容' | sed '/^[[:space:]]*$/d')"
  [ -n "$ai" ] || unmet+=("作業ログ「AI アセットに反映すべき内容」が空（0 件なら 0 件である根拠を書く）")
  st="$(git status --porcelain 2>/dev/null | tr -d '\r' | awk -v p="${T_PATH#./}" 'substr($0, 4) != p' | sed '/^$/d' || true)"
  if [ -n "$st" ]; then unmet+=("チケット以外に未コミットの変更がある（$(printf '%s\n' "$st" | wc -l | tr -d ' ') 件: $(printf '%s\n' "$st" | head -5 | sed 's/^...//' | tr '\n' ' ')）→ commit.sh で先にコミットする"); fi
  if [ "${#unmet[@]}" -gt 0 ]; then
    printf '%s\n' "${unmet[@]/#/- }"
    result_ng 003 "完了できない。未充足 ${#unmet[@]} 件（上に列挙）。形だけの記入で通さず、実態を満たしてから再実行する" 1
  fi

  local orig ts new
  orig="$(cat "$T_PATH")"
  ts="$(now_iso)"
  set_field "$T_PATH" completed_at "$ts"
  new="$DONE/${T_PATH##*/}"
  mv "$T_PATH" "$new"
  log_info "complete $n -> $new completed_at=$ts"
  if ! do_commit "chore: チケット $n を完了" "$T_PATH" "$new"; then
    mv "$new" "$T_PATH"; printf '%s\n' "$orig" > "$T_PATH"
    fail_with_commit_last
  fi
  result_ok "${new##*/} を完了にした（完了 $ts。$COMMIT_LAST）"
}

# ---------------------------------------------------------------- cancel
cmd_cancel() {
  local n="${1:-}" reason=""; shift || true
  while [ $# -gt 0 ]; do case "$1" in --reason) reason="${2:-}"; shift ;; *) result_ng 004 "cancel の不明な引数: $1" 2 ;; esac; shift; done
  [[ "$n" =~ ^[0-9]{4}$ ]] || result_ng 004 "cancel には 4 桁の番号を指定する" 2
  [ -n "$reason" ] || result_ng 007 "取り消し理由が空。--reason <理由> を指定する" 1
  find_ticket "$n" || result_ng 004 "チケット $n が見つからない" 1
  case "$T_STATE" in todo|doing) ;; *) result_ng 004 "チケット $n は未着手でも作業中でもない（実際の置き場: $T_STATE = $T_PATH）" 1 ;; esac
  mkdir -p "$CANCELLED"
  local orig ts new esc
  orig="$(cat "$T_PATH")"
  ts="$(now_iso)"
  sed_escape "$reason"; esc="$REPLY"
  sed -i "s|^base_sha: \(.*\)$|base_sha: \1\ncancelled_at: \"$ts\"\ncancel_reason: \"$esc\"|" "$T_PATH"
  new="$CANCELLED/${T_PATH##*/}"
  mv "$T_PATH" "$new"
  log_info "cancel $n -> $new reason=$reason"
  if ! do_commit "chore: チケット $n を取り消し" "$T_PATH" "$new"; then
    mv "$new" "$T_PATH"; printf '%s\n' "$orig" > "$T_PATH"
    fail_with_commit_last
  fi
  result_ok "${new##*/} を取り消した（$ts: $reason。$COMMIT_LAST）"
}

# ---------------------------------------------------------------- next
emit_json() { # $1=current $2=next $3=type $4=skill $5=blocked(空白区切り)
  local blocked_json="null"
  if [ -n "${5:-}" ]; then blocked_json="$(printf '%s\n' $5 | jq -R . | jq -sc .)"; fi
  jq -nc --arg c "$1" --arg n "$2" --arg t "$3" --arg s "$4" --argjson b "$blocked_json" \
    '{current: (if $c == "" then null else $c end), next: (if $n == "" then null else $n end)}
     + (if $t == "" then {} else {type: $t, skill: (if $s == "" then null else $s end)} end)
     + (if $b == null then {} else {blocked: $b} end)' | tr -d '\r'
}
cmd_next() {
  command -v jq >/dev/null 2>&1 || result_ng 004 "jq が無い（next は JSON を返す）" 2
  doing_files
  if [ "${#DOING_FILES[@]}" -gt 0 ]; then
    local cur="${DOING_FILES[0]##*/}" t
    t="$(type_of "${DOING_FILES[0]}")"
    emit_json "${cur%%-*}" "" "$t" "$(skill_of "$t" || true)" ""
    exit 0
  fi
  shopt -s nullglob; local todo=("$TODO"/[0-9][0-9][0-9][0-9]-*.md); shopt -u nullglob
  if [ "${#todo[@]}" -eq 0 ]; then emit_json "" "" "" "" ""; exit 0; fi
  local f p ok blocked="" num t
  for f in "${todo[@]}"; do
    num="${f##*/}"; num="${num%%-*}"
    ok=1
    while IFS= read -r p; do
      [ -z "$p" ] && continue
      shopt -s nullglob; local hit=("$DONE/$p-"*.md); shopt -u nullglob
      [ "${#hit[@]}" -gt 0 ] || { ok=0; break; }
    done < <(fm_list "$f" predecessors 2>/dev/null || true)
    if [ "$ok" -eq 1 ]; then
      t="$(type_of "$f")"
      log_info "next -> $num type=$t"
      emit_json "" "$num" "$t" "$(skill_of "$t" || true)" ""
      exit 0
    fi
    blocked+="$num "
  done
  emit_json "" "" "" "" "$blocked"
  exit 0
}

main() {
  local sub="${1:-}"; shift || true
  case "$sub" in
    -h|--help|"") usage; [ -n "$sub" ] && exit 0; result_ng 004 "サブコマンドを指定する（create / start / complete / cancel / next）" 2 ;;
  esac
  cd "$LOGGER_ROOT" || result_ng 004 "リポジトリルートに移動できない: $LOGGER_ROOT" 2
  [ -f "$COMMIT" ] || result_ng 004 "commit.sh が無い: $COMMIT" 2
  case "$sub" in
    create) cmd_create "$@" ;;
    start) cmd_start "$@" ;;
    complete) cmd_complete "$@" ;;
    cancel) cmd_cancel "$@" ;;
    next) cmd_next "$@" ;;
    *) result_ng 004 "不明なサブコマンド: $sub（create / start / complete / cancel / next）" 2 ;;
  esac
}

main "$@"
