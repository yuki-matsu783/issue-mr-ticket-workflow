#!/usr/bin/env bash
# finalize.sh — 全体まとめの完了検査から draft 解除まで（提供コマンド）
# 仕様: .claude/docs/10_spec/skills/10-task-overall-summary.md「Script 処理」（段階・state・エラー識別子の正）
# 使い方: bash .claude/skills/10-task-overall-summary/scripts/finalize.sh release [options]
#   release                                        8 段階を順に実行する（記録済みの段階は飛ばす。冪等）
#   release --external --pr <M> --body-file <path> 段階 4 の本文を <path> に書き出して止まる（linked にしない）
#   release --external --pr <M> --linked           呼び出し元が本文を更新した後に段階 4 を完了として再開する
#   release --external --pr <M>                    段階 7 の最終ゲートだけを検査して ready にする（draft 解除は呼び出し元）
# 終了コード: 成功 0 / 前提・検査の未充足 1 / 引数や環境の誤り 2。最終行は `OK: ...` または `FN<番号>: ...`
set -euo pipefail

# 共通ライブラリの読み込み行（20-common-step-shell-script 仕様「読み込み行」が正）。引数 <lib> <policy> だけを変え、中身を改変しない。
# shellcheck disable=SC1090,SC2317
__ss_load() { local lib="$1" pol="$2" d="${BASH_SOURCE[1]%/*}" r="" f=""; [ "$d" = "${BASH_SOURCE[1]}" ] && d="."; case "$d" in /*|[A-Za-z]:/*) ;; *) d="$PWD/$d" ;; esac; while [ -n "$d" ] && [ ! -d "$d/.claude" ]; do case "$d" in */*) d="${d%/*}" ;; *) d="" ;; esac; done; r="$d"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; if [ ! -f "$f" ] && [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then r="${CLAUDE_PROJECT_DIR//\\//}"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ ! -f "$f" ] && command -v git >/dev/null 2>&1; then r="$(git rev-parse --show-toplevel 2>/dev/null || true)"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ -n "$r" ] && [ -f "$f" ]; then LOGGER_ROOT="$r"; export LOGGER_ROOT; [ "$lib" = frontmatter ] && FM_AVAILABLE=1; . "$f"; return 0; fi; [ "$lib" = frontmatter ] && FM_AVAILABLE=0; case "$pol" in nop) LOGGER_ROOT="${r:-$PWD}"; export LOGGER_ROOT; log_debug() { :; }; log_info() { :; }; log_warn() { :; }; log_error() { :; }; fm_extract() { FM_BLOCK=""; return 2; }; fm_get() { return 2; }; fm_list() { return 2; }; fm_has() { return 2; } ;; deny) printf '%s\n' "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"${HOOK_DENY_ID:-WF009}: 機構の不調 — 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）\"}}"; exit 0 ;; *) printf '%s\n' "FATAL: 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）"; exit 2 ;; esac; }
__ss_load logger nop
__ss_load frontmatter fatal

readonly SCRIPT_PREFIX="FN"
readonly TICKETS="wip/10_tickets"
readonly TODO="$TICKETS/00_todo" DOING="$TICKETS/10_doing" DONE="$TICKETS/20_done"
readonly REPORTS="wip/30_reports"
readonly MR_JSON="logs/mr.json"
readonly REVIEW_JSON="logs/review-state.json"
readonly MERGE_JSON="logs/merge-state.json"
readonly COMMIT_SH=".claude/skills/20-common-step-commit-push/scripts/commit.sh"
readonly PUSH_SH=".claude/skills/20-common-step-commit-push/scripts/push.sh"
readonly CHECK_HTML=".claude/skills/20-common-step-report-view/scripts/check-html.sh"
readonly SUMMARY_HEADING="## 統括"
readonly CHECK_HEADING="## 完了検査"

usage() {
  cat <<'USAGE'
使い方: bash .claude/skills/10-task-overall-summary/scripts/finalize.sh release [options]
  release                                        8 段階を順に実行する（記録済みの段階は飛ばす。冪等）
  release --external --pr <M> --body-file <path> 段階 4 の本文を書き出して止まる
  release --external --pr <M> --linked           呼び出し元が本文を更新した後の再開
  release --external --pr <M>                    段階 7 の最終ゲートだけを検査する
USAGE
}

result_ok() { log_info "OK: $1"; printf 'OK: %s\n' "$1"; exit 0; }
result_ng() { log_warn "${SCRIPT_PREFIX}$1: $2"; printf '%s%s: %s\n' "$SCRIPT_PREFIX" "$1" "$2"; exit "$3"; }
# 引数・環境の誤り。仕様の識別子表に専用番号が無いため FN001 を終了コード 2 で使う（作業ログ「仕様からの逸脱」に記録）
arg_ng() { result_ng 001 "引数・環境の誤り — $1" 2; }

now_iso() { local ts; printf -v ts '%(%Y-%m-%dT%H:%M:%S%z)T' -1; printf '%s:%s' "${ts:0:22}" "${ts:22}"; }
cur_branch() { git rev-parse --abbrev-ref HEAD 2>/dev/null || true; }
head_sha() { git rev-parse HEAD 2>/dev/null || true; }

# ---------------------------------------------------------------- 環境の解決
resolve_context() {
  F_HOST=""; F_MR="${OPT_PR:-}"; F_ISSUE=""; F_OWNER=""; F_REPO=""; F_MR_URL=""
  if [ -f "$MR_JSON" ]; then
    local -a fv
    mapfile -t fv < <(jq -r '[.host // "", (.mr // "" | tostring), (.issue // "" | tostring), .url // ""] | .[]' "$MR_JSON" 2>/dev/null | tr -d '\r')
    F_HOST="${fv[0]:-}"; F_ISSUE="${fv[2]:-}"; F_MR_URL="${fv[3]:-}"
    if [ -z "$F_MR" ]; then F_MR="${fv[1]:-}"; fi
  fi
  # owner/repo は blob URL の組み立てに要る。MR の URL があればそちらを優先する（origin がローカルパスのこともある）
  local src="$F_MR_URL"
  if [ -z "$src" ]; then src="$(git remote get-url origin 2>/dev/null || true)"; fi
  if [ -z "$F_HOST" ]; then
    case "$src" in *github.com*) F_HOST="github" ;; *gitlab*) F_HOST="gitlab" ;; esac
  fi
  local path="${src#*://}"; path="${path#*/}"; path="${path%.git}"
  F_OWNER="${path%%/*}"
  local rest="${path#*/}"
  F_REPO="${rest%%/*}"
  if [ "$F_OWNER" = "$path" ]; then F_OWNER=""; F_REPO=""; fi
}

# 全体まとめチケット（作業中）。無ければ空
find_summary_ticket() {
  F_TICKET=""; F_TICKET_NO=""
  shopt -s nullglob; local d=("$DOING"/*.md); shopt -u nullglob
  local f
  for f in "${d[@]}"; do
    if [ "$(fm_get "$f" ticket_type 2>/dev/null || true)" = "overall-summary" ]; then
      F_TICKET="$f"; F_TICKET_NO="${f##*/}"; F_TICKET_NO="${F_TICKET_NO%%-*}"; return 0
    fi
  done
  return 1
}

# 統括レポート（md）。チケット番号で引き、無ければ種類名で探す
find_summary_report() {
  F_REPORT=""
  shopt -s nullglob
  local c=("$REPORTS/$F_TICKET_NO-overall-summary.md" "$REPORTS"/*-overall-summary.md)
  shopt -u nullglob
  [ "${#c[@]}" -gt 0 ] || return 1
  F_REPORT="${c[0]}"
  return 0
}

wip_artifacts() {
  find wip -type f ! -name .gitkeep 2>/dev/null | head -1
}

# ---------------------------------------------------------------- 進行状態
read_state() {
  F_STATE=""; F_VIA=""; F_PRE_SHA=""
  [ -f "$MERGE_JSON" ] || return 0
  local -a fv
  mapfile -t fv < <(jq -r '[.state // "", .via // "", .pre_cleanup_sha // ""] | .[]' "$MERGE_JSON" 2>/dev/null | tr -d '\r')
  [ "${#fv[@]}" -ge 3 ] || return 0
  F_STATE="${fv[0]:-}"; F_VIA="${fv[1]:-}"; F_PRE_SHA="${fv[2]:-}"
}

write_state() { # $1=state
  mkdir -p logs
  local now; now="$(now_iso)"
  local key=""
  case "$1" in
    started) key="started_at" ;; recorded) key="recorded_at" ;; linked) key="linked_at" ;;
    cleaned) key="cleaned_at" ;; pushed) key="pushed_at" ;; ready) key="ready_at" ;;
  esac
  local base='{}'
  if [ -f "$MERGE_JSON" ]; then base="$(cat "$MERGE_JSON" 2>/dev/null || printf '{}')"; fi
  if ! printf '%s' "$base" | jq -e . >/dev/null 2>&1; then base='{}'; fi
  printf '%s' "$base" | jq --arg st "$1" --arg via "${OPT_EXTERNAL:+external}" --arg now "$now" --arg key "$key" \
      --arg sha "$F_PRE_SHA" --arg mr "$F_MR" --arg iss "$F_ISSUE" '
      . + {state: $st,
           via: (if $via == "" then (.via // "cli") else $via end),
           mr: (if $mr == "" then .mr else ($mr | tonumber? // .mr) end),
           issue: (if $iss == "" then .issue else ($iss | tonumber? // .issue) end),
           pre_cleanup_sha: (if $sha == "" then .pre_cleanup_sha else $sha end)}
      | (if $key == "" then . else .[$key] = $now end)' > "$MERGE_JSON.tmp"
  mv "$MERGE_JSON.tmp" "$MERGE_JSON"
  F_STATE="$1"
  log_info "state -> $1"
}

# 記録が無い・壊れているときの再導出（linked の判定は固定マーカーだけを見る）
rederive_state() {
  local body="" marker=""
  if [ -n "$(wip_artifacts)" ]; then
    if [ -z "$F_REPORT" ] || ! grep -q "^$CHECK_HEADING" "$F_REPORT" 2>/dev/null; then
      F_STATE=""; log_info "再導出: 未実施（完了検査の節が無い）"; return 0
    fi
    body="$(fetch_body 2>/dev/null || true)"
    marker="$(printf '%s' "$body" | grep -o '<!-- finalize:linked [0-9a-f]\{7,40\} -->' | head -1 || true)"
    if [ -n "$marker" ]; then
      F_PRE_SHA="$(printf '%s' "$marker" | sed 's/<!-- finalize:linked //; s/ -->//')"
      F_STATE="linked"; log_info "再導出: linked（マーカーの sha=$F_PRE_SHA）"
    else
      F_STATE="recorded"; log_info "再導出: recorded（マーカー無し。空の表は linked と見なさない）"
    fi
    return 0
  fi
  # wip/ が空
  local br unpushed; br="$(cur_branch)"
  unpushed="$(git rev-list "origin/$br..HEAD" 2>/dev/null || printf 'unknown')"
  if [ -n "$unpushed" ] && [ "$unpushed" != "unknown" ]; then F_STATE="cleaned"; log_info "再導出: cleaned"; return 0; fi
  if is_draft; then F_STATE="pushed"; log_info "再導出: pushed"; else F_STATE="ready"; log_info "再導出: ready"; fi
  # 片付けコミットの親から pre_cleanup_sha を復元する（logs/ を唯一の正にしない）
  if [ -z "$F_PRE_SHA" ]; then
    local c; c="$(git log --format=%H --diff-filter=D -1 -- wip/30_reports 2>/dev/null || true)"
    if [ -n "$c" ]; then F_PRE_SHA="$(git rev-parse "$c^" 2>/dev/null || true)"; fi
  fi
}

# ---------------------------------------------------------------- リモート
fetch_body() {
  case "$F_HOST" in
    github) command -v gh >/dev/null 2>&1 || return 1; gh pr view "$F_MR" --json body -q .body 2>/dev/null | tr -d '\r' ;;
    gitlab) command -v glab >/dev/null 2>&1 || return 1; glab api "projects/:id/merge_requests/$F_MR" 2>/dev/null | jq -r '.description // ""' | tr -d '\r' ;;
    *) return 1 ;;
  esac
}
put_body() { # $1=本文ファイル
  case "$F_HOST" in
    github) command -v gh >/dev/null 2>&1 || return 1; gh pr edit "$F_MR" --body-file "$1" >/dev/null 2>&1 ;;
    gitlab) command -v glab >/dev/null 2>&1 || return 1; glab api -X PUT "projects/:id/merge_requests/$F_MR" --raw-field "description=@$1" >/dev/null 2>&1 ;;
    *) return 1 ;;
  esac
}
is_draft() {
  case "$F_HOST" in
    github) command -v gh >/dev/null 2>&1 || return 1; [ "$(gh pr view "$F_MR" --json isDraft -q .isDraft 2>/dev/null | tr -d '\r')" = "true" ] ;;
    gitlab) command -v glab >/dev/null 2>&1 || return 1; [ "$(glab api "projects/:id/merge_requests/$F_MR" 2>/dev/null | jq -r '.draft // false' | tr -d '\r')" = "true" ] ;;
    *) return 1 ;;
  esac
}
mark_ready() {
  case "$F_HOST" in
    github) gh pr ready "$F_MR" >/dev/null 2>&1 ;;
    gitlab) glab mr update "$F_MR" --ready >/dev/null 2>&1 ;;
    *) return 1 ;;
  esac
}
default_branch() {
  local d=""
  case "$F_HOST" in
    github) d="$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null | tr -d '\r' || true)" ;;
  esac
  [ -n "$d" ] || d="$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||' || true)"
  [ -n "$d" ] || d="main"
  printf '%s' "$d"
}

# ---------------------------------------------------------------- 段階 1: 前提検査
stage_precheck() {
  local unmet=()
  if ! find_summary_ticket; then unmet+=("全体まとめチケットが作業中でない（ticket.sh start で着手する）"); fi
  shopt -s nullglob
  local todo=("$TODO"/*.md) doing=("$DOING"/*.md)
  shopt -u nullglob
  [ "${#todo[@]}" -eq 0 ] || unmet+=("未着手のチケットが ${#todo[@]} 枚残っている（先に実施する）")
  [ "${#doing[@]}" -le 1 ] || unmet+=("作業中のチケットが ${#doing[@]} 枚ある（全体まとめ 1 枚だけにする）")

  if find_summary_report; then
    [ -f "${F_REPORT%.md}.html" ] || unmet+=("統括レポートの HTML が無い（${F_REPORT%.md}.html。report-view の手順で作る）")
  else
    unmet+=("統括レポートが無い（$REPORTS/<番号>-overall-summary.md）")
  fi

  local body=""
  if body="$(fetch_body)" && [ -n "$body" ]; then
    printf '%s\n' "$body" | grep -q "^$SUMMARY_HEADING" || unmet+=("MR 本文に見出し「$SUMMARY_HEADING」が無い（処理フロー 5 の本文最終化が済んでいない）")
  else
    unmet+=("MR 本文を取得できない（host=$F_HOST mr=$F_MR。CLI が無い環境は --external を使う）")
  fi

  local br unpushed; br="$(cur_branch)"
  unpushed="$(git rev-list "origin/$br..HEAD" 2>/dev/null || printf 'unknown')"
  if [ "$unpushed" = "unknown" ]; then unmet+=("上流が無い（push.sh で push する）")
  elif [ -n "$unpushed" ]; then unmet+=("HEAD が push されていない（統括レポートを履歴に載せてから片付ける）"); fi

  # レビューの記録（要なら completed、不要なら skipped）
  local need="true" rstate=""
  if [ -n "$F_TICKET" ] && [ "$(fm_get "$F_TICKET" human_review.required 2>/dev/null || true)" = "false" ]; then need="false"; fi
  if [ -f "$REVIEW_JSON" ]; then rstate="$(jq -r '.state // ""' "$REVIEW_JSON" 2>/dev/null | tr -d '\r' || true)"; fi
  if [ "$need" = "true" ]; then
    [ "$rstate" = "completed" ] || unmet+=("人間レビュー要の全体まとめだが logs/review-state.json が completed でない（現在: ${rstate:-記録なし}。boundary.sh complete --final）")
  else
    [ "$rstate" = "skipped" ] || [ "$rstate" = "completed" ] || unmet+=("人間レビュー不要の全体まとめだが省略が記録されていない（現在: ${rstate:-記録なし}。boundary.sh skip --final --reason ...）")
  fi

  if [ "${#unmet[@]}" -gt 0 ]; then
    printf '%s\n' "${unmet[@]/#/- }"
    result_ng 001 "release の前提を満たしていない。未充足 ${#unmet[@]} 件（上に列挙）" 1
  fi
}

# ---------------------------------------------------------------- 段階 2: 完了検査
stage_check() {
  if ! ticket_check_completion "$F_TICKET"; then
    printf '%s\n' "${TICKET_UNMET[@]/#/- }"
    result_ng 002 "全体まとめチケットの完了検査が通らない。未充足 ${#TICKET_UNMET[@]} 件（上に列挙）" 1
  fi
  # 検査の結果（DoD 1 件ごとの合否と根拠欄）を組み立てる
  F_CHECK_MD="$(
    printf '%s\n\n' "$CHECK_HEADING"
    printf 'チケット `%s` の完了検査（`finalize.sh release` の段階 2）。未充足 0 件。\n\n' "${F_TICKET##*/}"
    printf '| # | DoD | 合否 | 根拠 |\n|---|---|---|---|\n'
    ticket_section "$F_TICKET" '^## DoD' | grep -E '^- \[[ x]\]' | awk '
      { n++
        checked = ($0 ~ /^- \[x\]/) ? "◎ 済" : "✕ 未"
        line = $0; sub(/^- \[[ x]\] /, "", line)
        basis = ""
        if (match(line, /（根拠: /)) { basis = substr(line, RSTART + 6); sub(/）[[:space:]]*$/, "", basis); line = substr(line, 1, RSTART - 1) }
        gsub(/\|/, "\\|", line); gsub(/\|/, "\\|", basis)
        printf "| %d | %s | %s | %s |\n", n, line, checked, basis }'
    printf '\n検査の実装は `20-common-step-ticket` の `ticket_check_completion`（`ticket.sh complete` と同じもの）。\n'
  )"
}

# ---------------------------------------------------------------- 段階 3: 書き出しと push
stage_record() {
  local html="${F_REPORT%.md}.html"
  if ! grep -q "^$CHECK_HEADING" "$F_REPORT"; then
    printf '\n%s\n' "$F_CHECK_MD" >> "$F_REPORT"
  fi
  if ! grep -q 'id="completion-check"' "$html"; then
    local rows tmp
    rows="$(printf '%s' "$F_CHECK_MD" | grep -E '^\| [0-9]+ \|' | awk -F'|' '{
      printf "      <tr><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>\n", $2, $3, $4, $5 }')"
    tmp="$(mktemp)"
    awk -v rows="$rows" -v head="$CHECK_HEADING" '
      /<\/main>/ && !done {
        print "<section id=\"completion-check\">"
        print "  <h2>完了検査</h2>"
        print "  <p>全体まとめチケットの完了検査（<code>finalize.sh release</code> の段階 2）。未充足 0 件。</p>"
        print "  <div class=\"tablewrap\">"
        print "  <table>"
        print "    <thead><tr><th>#</th><th>DoD</th><th>合否</th><th>根拠</th></tr></thead>"
        print "    <tbody>"
        printf "%s", rows
        print "    </tbody>"
        print "  </table>"
        print "  </div>"
        print "</section>"
        print ""
        done = 1
      }
      { print }' "$html" > "$tmp"
    mv "$tmp" "$html"
  fi
  if [ -f "$CHECK_HTML" ]; then
    local out
    if ! out="$(bash "$CHECK_HTML" "$html" 2>&1)"; then
      printf '%s\n' "$out"
      result_ng 002 "統括レポートの HTML 検査が通らない（$html）。直してから release を再実行する" 1
    fi
  fi
  local out
  if ! out="$(bash "$COMMIT_SH" -m "chore: 全体まとめの完了検査を統括レポートに書き出す" "$F_REPORT" "$html" 2>&1)"; then
    printf '%s\n' "$out"; result_ng 002 "完了検査の書き出しをコミットできない（commit.sh の最終行を見ること）" 1
  fi
  if ! out="$(bash "$PUSH_SH" 2>&1)"; then
    printf '%s\n' "$out"
    result_ng 002 "完了検査の書き出しを push できない（全体まとめチケットの allow.ops に remote-write:push が要る）" 1
  fi
  write_state "recorded"
}

# ---------------------------------------------------------------- 段階 4: SHA の確定とリンク一覧
build_link_rows() { # $1=sha
  local f name
  shopt -s nullglob
  for f in "$REPORTS"/*.html; do
    name="${f##*/}"
    printf '| %s | %s | %s |\n' "${name%.html}" "$(report_desc "${f%.html}.md")" \
      "https://github.com/$F_OWNER/$F_REPO/blob/$1/$f"
  done
  shopt -u nullglob
}
report_desc() { # $1=md
  [ -f "$1" ] || { printf '成果物'; return 0; }
  local d; d="$(fm_get "$1" title 2>/dev/null || true)"
  [ -n "$d" ] || d="成果物"
  printf '%s' "${d//|/ }"
}

stage_link() {
  F_PRE_SHA="$(head_sha)"
  local body new rows tmp
  rows="$(build_link_rows "$F_PRE_SHA")"
  if ! body="$(fetch_body)" || [ -z "$body" ]; then
    result_ng 001 "MR 本文を取得できない（host=$F_HOST mr=$F_MR）。CLI が無い環境は --external --body-file を使う" 1
  fi
  tmp="$(mktemp)"
  # `## 統括` 配下のリンク一覧の表の中身だけを置き換える。他の節と人間が貼ったリンクには触れない
  printf '%s\n' "$body" | awk -v rows="$rows" -v marker="<!-- finalize:linked $F_PRE_SHA -->" '
    /^\| *レポート *\| *内容 *\| *リンク *\|/ { print; intable = 1; next }
    intable && /^\|[- :]*\|[- :]*\|[- :]*\|[[:space:]]*$/ { print; printf "%s", rows; skiprows = 1; intable = 0; next }
    skiprows && /^\|/ { next }
    skiprows { skiprows = 0 }
    /^<!-- finalize:linked / { next }
    { print }
    END { print ""; print marker }' > "$tmp"
  new="$tmp"
  if [ -n "${OPT_BODY_FILE:-}" ]; then
    cp "$new" "$OPT_BODY_FILE"
    rm -f "$tmp"
    result_ok "段階 4 の本文を書き出した（$OPT_BODY_FILE）。呼び出し元が MR 本文を更新したら release --external --pr $F_MR --linked で再開する"
  fi
  if ! put_body "$new"; then
    rm -f "$tmp"
    result_ng 001 "MR 本文を更新できない（host=$F_HOST mr=$F_MR）。CLI が無い環境は --external --body-file を使う" 1
  fi
  rm -f "$tmp"
  write_state "linked"
}

# ---------------------------------------------------------------- 段階 5: 片付け
stage_cleanup() {
  # commit.sh はディレクトリを受け取らないので、消す前にファイルの一覧を作って渡す
  local -a files=()
  mapfile -t files < <(find wip -type f ! -name .gitkeep 2>/dev/null | sed 's|\\|/|g')
  local n="${#files[@]}"
  if [ "$n" -eq 0 ]; then
    F_CLEANED=0
    write_state "cleaned"
    return 0
  fi
  local f
  for f in "${files[@]}"; do rm -f "$f"; done
  find wip -mindepth 1 -type d -empty -delete 2>/dev/null || true
  local out
  if ! out="$(bash "$COMMIT_SH" -m "chore: 作業領域を片付ける" "${files[@]}" 2>&1)"; then
    printf '%s\n' "$out"; result_ng 002 "片付けをコミットできない（commit.sh の最終行を見ること）" 1
  fi
  F_CLEANED="$n"
  write_state "cleaned"
}

# ---------------------------------------------------------------- 段階 6: push
stage_push() {
  local out
  if ! out="$(bash "$PUSH_SH" 2>&1)"; then
    printf '%s\n' "$out"; result_ng 002 "片付けを push できない（push.sh の最終行を見ること）" 1
  fi
  write_state "pushed"
}

# ---------------------------------------------------------------- 段階 7: 最終ゲートと draft 解除
stage_ready() {
  local base br behind conflict
  base="$(default_branch)"
  br="$(cur_branch)"
  git fetch origin >/dev/null 2>&1 || true
  behind="$(git rev-list --count "HEAD..origin/$base" 2>/dev/null || printf '0')"
  if [ "$behind" != "0" ]; then
    conflict="$(git merge-tree --write-tree HEAD "origin/$base" 2>/dev/null | grep -c 'CONFLICT' || true)"
    result_ng 003 "ベース（origin/$base）が $behind コミット進んでいる（衝突の兆候 ${conflict:-0} 件）。取り込んで解消してから release を再実行する。片付けは巻き戻さない" 1
  fi
  local unpushed; unpushed="$(git rev-list "origin/$br..HEAD" 2>/dev/null || printf '')"
  [ -z "$unpushed" ] || result_ng 003 "HEAD が push されていない（push.sh で push してから再実行する）" 1
  if [ -n "${OPT_EXTERNAL:-}" ]; then
    write_state "ready"
    return 0
  fi
  if ! mark_ready; then
    result_ng 003 "draft を解除できない（host=$F_HOST mr=$F_MR）。CLI が無い環境は呼び出し元が解除して --external で再実行する" 1
  fi
  write_state "ready"
}

# ---------------------------------------------------------------- release
cmd_release() {
  OPT_EXTERNAL=""; OPT_PR=""; OPT_BODY_FILE=""; OPT_LINKED=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --external) OPT_EXTERNAL=1 ;;
      --linked) OPT_LINKED=1 ;;
      --pr) [ $# -ge 2 ] || arg_ng "--pr には番号を指定する"; OPT_PR="$2"; shift ;;
      --body-file) [ $# -ge 2 ] || arg_ng "--body-file にはパスを指定する"; OPT_BODY_FILE="$2"; shift ;;
      -h|--help) usage; exit 0 ;;
      *) arg_ng "release の不明な引数: $1" ;;
    esac
    shift
  done
  resolve_context
  find_summary_ticket || true
  find_summary_report || true
  read_state
  [ -n "$F_STATE" ] || rederive_state

  # --linked は呼び出し元が本文を更新した後の再開（段階 4 を完了として記録する）
  if [ -n "$OPT_LINKED" ]; then
    [ -n "$F_PRE_SHA" ] || F_PRE_SHA="$(head_sha)"
    write_state "linked"
  fi

  case "$F_STATE" in
    ""|started|recorded|linked|cleaned|pushed|ready) ;;
    *) arg_ng "logs/merge-state.json の state が不正: $F_STATE" ;;
  esac
  # 記録済みの段階は飛ばして続きから行う（冪等）。write_state が F_STATE を進めるので順に落ちていく
  if [ -z "$F_STATE" ] || [ "$F_STATE" = "started" ]; then
    stage_precheck
    write_state "started"
    stage_check
    stage_record
  fi
  if [ "$F_STATE" = "recorded" ]; then stage_link; fi
  if [ "$F_STATE" = "linked" ]; then stage_cleanup; fi
  if [ "$F_STATE" = "cleaned" ]; then stage_push; fi
  if [ "$F_STATE" = "pushed" ]; then stage_ready; fi

  local url="$F_MR_URL"
  if [ -z "$url" ]; then url="https://github.com/$F_OWNER/$F_REPO/pull/$F_MR"; fi
  local tree="https://github.com/$F_OWNER/$F_REPO/tree/${F_PRE_SHA:-HEAD}/wip/30_reports"
  if [ "$F_HOST" = "gitlab" ]; then tree="https://gitlab.com/$F_OWNER/$F_REPO/-/tree/${F_PRE_SHA:-HEAD}/wip/30_reports"; fi
  result_ok "MR #$F_MR の draft を解除した（$url）。片付け ${F_CLEANED:-0} 件。成果物: $tree"
}

# ---------------------------------------------------------------- main
main() {
  local sub="${1:-}"; shift || true
  case "$sub" in
    -h|--help|"") usage; [ -n "$sub" ] && exit 0; arg_ng "サブコマンドを指定する（release）" ;;
  esac
  cd "$LOGGER_ROOT" || arg_ng "リポジトリルートに移動できない: $LOGGER_ROOT"
  command -v jq >/dev/null 2>&1 || arg_ng "jq が無い（進行状態は JSON で持つ）"
  command -v git >/dev/null 2>&1 || arg_ng "git が無い"
  # 完了検査は ticket.sh と共有する（二重実装しない）
  local tc=".claude/skills/20-common-step-ticket/scripts/ticket-check.sh"
  [ -f "$tc" ] || arg_ng "完了検査の共通関数が無い: $tc"
  # shellcheck disable=SC1090
  . "$tc"
  log_info "start subcommand=$sub args=$*"
  case "$sub" in
    release) cmd_release "$@" ;;
    *) arg_ng "不明なサブコマンド: $sub（release）" ;;
  esac
}

main "$@"
