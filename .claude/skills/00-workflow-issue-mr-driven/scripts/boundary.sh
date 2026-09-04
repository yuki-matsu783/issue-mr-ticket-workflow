#!/usr/bin/env bash
# boundary.sh — タスクの切れ目の判定・記録・レビュー依頼・完了確認（提供コマンド）
# 仕様: .claude/docs/10_spec/skills/00-workflow-issue-mr-driven.md「Script 処理」（判定順・エラー識別子の正）
# 使い方: bash .claude/skills/00-workflow-issue-mr-driven/scripts/boundary.sh <subcommand> [options]
#   status [--offline]
#   note    --body-file <path> [--usage-report <path>]
#   request --body-file <path> [--final] [--standalone] [--external --comment-url <url>] [--usage-report <path>]
#   skip    --reason <理由> [--final]
#   complete [--final] [--accept-unresolved] [--standalone] [--external --report-file <json>]
# 終了コード: 成功 0 / 前提・状態の未充足 1 / 引数や環境の誤り 2。最終行は `OK: ...` または `BD<番号>: ...`（status / complete の本体は JSON）
#
# --report-file / リモート取得の正規化スキーマ（--external はこの形で渡す）:
#   {"threads":[{"id","resolved","url","path","line","body","author","created_at"}],
#    "reviews":[{"state","url","author","submitted_at"}],
#    "comments":[{"url","body","author","created_at"}]}
set -euo pipefail
shopt -u patsub_replacement 2>/dev/null || true

# 共通ライブラリの読み込み行（20-common-step-shell-script 仕様「読み込み行」が正）。引数 <lib> <policy> だけを変え、中身を改変しない。
# shellcheck disable=SC1090,SC2317
__ss_load() { local lib="$1" pol="$2" d="${BASH_SOURCE[1]%/*}" r="" f=""; [ "$d" = "${BASH_SOURCE[1]}" ] && d="."; case "$d" in /*|[A-Za-z]:/*) ;; *) d="$PWD/$d" ;; esac; while [ -n "$d" ] && [ ! -d "$d/.claude" ]; do case "$d" in */*) d="${d%/*}" ;; *) d="" ;; esac; done; r="$d"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; if [ ! -f "$f" ] && [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then r="${CLAUDE_PROJECT_DIR//\\//}"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ ! -f "$f" ] && command -v git >/dev/null 2>&1; then r="$(git rev-parse --show-toplevel 2>/dev/null || true)"; f="$r/.claude/skills/20-common-step-shell-script/scripts/$lib.sh"; fi; if [ -n "$r" ] && [ -f "$f" ]; then LOGGER_ROOT="$r"; export LOGGER_ROOT; [ "$lib" = frontmatter ] && FM_AVAILABLE=1; . "$f"; return 0; fi; [ "$lib" = frontmatter ] && FM_AVAILABLE=0; case "$pol" in nop) LOGGER_ROOT="${r:-$PWD}"; export LOGGER_ROOT; log_debug() { :; }; log_info() { :; }; log_warn() { :; }; log_error() { :; }; fm_extract() { FM_BLOCK=""; return 2; }; fm_get() { return 2; }; fm_list() { return 2; }; fm_has() { return 2; } ;; deny) printf '%s\n' "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"${HOOK_DENY_ID:-WF009}: 機構の不調 — 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）\"}}"; exit 0 ;; *) printf '%s\n' "FATAL: 共通ライブラリ $lib を読み込めない（リポジトリルート未解決）"; exit 2 ;; esac; }
__ss_load logger nop
__ss_load frontmatter fatal

readonly SCRIPT_PREFIX="BD"
readonly TICKETS="wip/10_tickets"
readonly TODO="$TICKETS/00_todo" DOING="$TICKETS/10_doing" DONE="$TICKETS/20_done"
readonly MR_JSON="logs/mr.json"
readonly REVIEW_JSON="logs/review-state.json"
readonly HISTORY_JSONL="logs/review-history.jsonl"
readonly MERGE_JSON="logs/merge-state.json"
readonly TICKET_SH=".claude/skills/20-common-step-ticket/scripts/ticket.sh"
readonly FINAL_TYPE="overall-summary"

usage() {
  cat <<'USAGE'
使い方: bash .claude/skills/00-workflow-issue-mr-driven/scripts/boundary.sh <subcommand> [options]
  status   [--offline]                          切れ目の判定を JSON で返す
  note     --body-file <path> [--usage-report <path>]
                                                通常コメントを投稿する（レビュー状態は変えない）
  request  --body-file <path> [--final] [--standalone] [--external --comment-url <url>] [--usage-report <path>]
                                                レビューを依頼して requested にする
  skip     --reason <理由> [--final]             レビュー不要の切れ目を skipped にする
  complete [--final] [--accept-unresolved] [--standalone] [--external --report-file <json>]
                                                指摘を取得して completed にする
USAGE
}

result_ok() { log_info "OK: $1"; printf 'OK: %s\n' "$1"; exit 0; }
result_ng() { log_warn "${SCRIPT_PREFIX}$1: $2"; printf '%s%s: %s\n' "$SCRIPT_PREFIX" "$1" "$2"; exit "$3"; }
# 引数・環境の誤り（BD006・終了コード 2）。前提未充足（BD001〜BD005・終了コード 1）とは別に扱う
arg_ng() { result_ng 006 "引数・環境の誤り — $1" 2; }

now_iso() { local ts; printf -v ts '%(%Y-%m-%dT%H:%M:%S%z)T' -1; printf '%s:%s' "${ts:0:22}" "${ts:22}"; }
cur_branch() { git rev-parse --abbrev-ref HEAD 2>/dev/null || true; }
head_sha() { git rev-parse HEAD 2>/dev/null || true; }
first_sha() { git rev-list --max-parents=0 HEAD 2>/dev/null | tail -n 1 || true; }

detect_host() {
  local url; url="$(git remote get-url origin 2>/dev/null || true)"
  case "$url" in
    *github.com*) printf 'github' ;;
    *gitlab*) printf 'gitlab' ;;
    *) printf '' ;;
  esac
}

# ---------------------------------------------------------------- 切れ目の判定
# 出力変数: B_CURRENT B_NEXT B_NEXT_TYPE B_SKILL / B_TASK_TYPE B_LAST_DONE B_TASK_TICKETS B_REVIEW_REQUIRED
#           B_AT_BOUNDARY B_FINAL B_POSITION B_MR B_HOST / R_STATE R_VIA R_BASE R_HEAD R_URL R_REQ_AT R_DONE_AT
scan_tickets() {
  local nx f n t
  nx="$(bash "$TICKET_SH" next 2>/dev/null || true)"
  if [ -z "$nx" ] || ! printf '%s' "$nx" | jq -e . >/dev/null 2>&1; then
    arg_ng "ticket.sh next が JSON を返さない（$TICKET_SH）: ${nx:-（出力なし）}"
  fi
  # jq の起動を 1 回にまとめる（1 回の status で 4 回起動しない）。
  # 空の値が潰れないよう 1 行 1 値で受ける（IFS 区切りの read は空フィールドを畳んでしまう）
  local -a fv
  mapfile -t fv < <(printf '%s' "$nx" | jq -r '[.current // "", .next // "", .type // "", .skill // ""] | .[]' | tr -d '\r')
  B_CURRENT="${fv[0]:-}"; B_NEXT="${fv[1]:-}"; B_NEXT_TYPE="${fv[2]:-}"; B_SKILL="${fv[3]:-}"

  # 完了群の末尾から、同じ種類が続く範囲を最後のタスクとする
  B_TASK_TYPE=""; B_LAST_DONE=""; B_TASK_TICKETS=(); B_REVIEW_REQUIRED="false"
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    n="${f##*/}"; n="${n%%-*}"
    t="$(fm_get "$f" ticket_type 2>/dev/null || true)"
    if [ -z "$B_TASK_TYPE" ]; then B_TASK_TYPE="$t"; B_LAST_DONE="$n"; fi
    [ "$t" = "$B_TASK_TYPE" ] || break
    B_TASK_TICKETS+=("$n")
    if [ "$(fm_get "$f" human_review.required 2>/dev/null || true)" = "true" ]; then B_REVIEW_REQUIRED="true"; fi
  done < <(ls -1 "$DONE"/[0-9][0-9][0-9][0-9]-*.md 2>/dev/null | sort -r)

  # 全体まとめの切れ目（--final）: doing が overall-summary 1 枚
  shopt -s nullglob; local doing=("$DOING"/*.md); shopt -u nullglob
  B_FINAL="false"; B_FINAL_FILE=""
  if [ "${#doing[@]}" -eq 1 ] && [ "$(fm_get "${doing[0]}" ticket_type 2>/dev/null || true)" = "$FINAL_TYPE" ]; then
    B_FINAL="true"; B_FINAL_FILE="${doing[0]}"
  fi

  # at_boundary: doing が空 かつ（next が無い、または next の種類が最後のタスクと違う）
  B_AT_BOUNDARY="false"
  if [ "${#doing[@]}" -eq 0 ]; then
    if [ -z "$B_NEXT" ] || [ "$B_NEXT_TYPE" != "$B_TASK_TYPE" ]; then B_AT_BOUNDARY="true"; fi
  fi
}

# --final のときは、切れ目の鍵を作業中の全体まとめチケットに差し替える
apply_final_key() {
  local n
  n="${B_FINAL_FILE##*/}"; n="${n%%-*}"
  B_TASK_TYPE="$FINAL_TYPE"; B_LAST_DONE="$n"; B_TASK_TICKETS=("$n")
  B_REVIEW_REQUIRED="false"
  if [ "$(fm_get "$B_FINAL_FILE" human_review.required 2>/dev/null || true)" = "true" ]; then B_REVIEW_REQUIRED="true"; fi
  return 0
}

read_review() {
  R_STATE="none"; R_VIA=""; R_BASE=""; R_HEAD=""; R_URL=""; R_REQ_AT=""; R_DONE_AT=""; R_LAST_DONE=""; R_TASK_TYPE=""
  R_BROKEN="false"
  [ -f "$REVIEW_JSON" ] || return 0
  # jq の起動を 1 回にまとめる（読む項目の数だけ起動しない）。空の値が潰れないよう 1 行 1 値で受ける
  local -a fv
  mapfile -t fv < <(jq -r '[.state // "none", .via // "", .base_sha // "", .head_sha // "",
                            .request_comment_url // "", .requested_at // "", .completed_at // "",
                            .boundary.last_done // "", .boundary.task_type // ""] | .[]' "$REVIEW_JSON" 2>/dev/null | tr -d '\r')
  if [ "${#fv[@]}" -lt 9 ]; then R_BROKEN="true"; return 0; fi
  R_STATE="${fv[0]:-none}"; R_VIA="${fv[1]:-}"; R_BASE="${fv[2]:-}"; R_HEAD="${fv[3]:-}"
  R_URL="${fv[4]:-}"; R_REQ_AT="${fv[5]:-}"; R_DONE_AT="${fv[6]:-}"
  R_LAST_DONE="${fv[7]:-}"; R_TASK_TYPE="${fv[8]:-}"
  [ -n "$R_STATE" ] || R_STATE="none"
}

# 記録が現在の切れ目のものか。違えば none として扱う
review_valid() { [ -n "$R_LAST_DONE" ] && [ "$R_LAST_DONE" = "$B_LAST_DONE" ] && [ "$R_TASK_TYPE" = "$B_TASK_TYPE" ]; }

# マージ前作業の進行状態。logs/ はブランチに紐づかないローカルの記録なので、別の issue で ready まで
# 終えた記録がそのまま残る。現在の MR・ブランチと結びつかない記録は「無い」ものとして扱う
# （そうしないと、同じ clone で次の issue を始めた瞬間から status が毎回 BD005 で止まる）
merge_state() {
  [ -f "$MERGE_JSON" ] || return 0
  jq -r --argjson mr "${B_MR:-null}" --arg br "$(cur_branch)" '
    if ((.mr // null) != null and $mr != null and ((.mr | tostring) != ($mr | tostring))) then ""
    elif ((.branch // "") != "" and $br != "" and (.branch != $br)) then ""
    else (.state // "") end' "$MERGE_JSON" 2>/dev/null | tr -d '\r' || true
}

wip_has_artifacts() {
  shopt -s nullglob
  local a=(wip/30_reports/*.md wip/20_plans/*.md "$TODO"/*.md "$DOING"/*.md "$DONE"/*.md)
  shopt -u nullglob
  [ "${#a[@]}" -gt 0 ]
}

# 実態からの再導出で見つけた矛盾。見つかれば BD005 で止める。
# 一覧は先に出し、result_ng には 1 行だけ渡す（最終行を `BD005:` に保つ — 提供コマンドの契約）
check_conflicts() { # $1=依頼マーカーの一致件数（不明なら -1）
  local dup="$1" ms found="" n=0
  ms="$(merge_state)"
  case "$ms" in
    cleaned|pushed|ready)
      if wip_has_artifacts; then found+="- merge-state が $ms なのに wip/ に成果物が残っている"$'\n'; n=$((n + 1)); fi ;;
  esac
  if [ "$dup" -ge 2 ] 2>/dev/null; then
    found+="- 同じ切れ目（$B_TASK_TYPE:$B_LAST_DONE）の依頼コメントが $dup 件ある"$'\n'
    n=$((n + 1))
  fi
  if [ -n "$found" ]; then
    printf '%s' "$found"
    result_ng 005 "進行状態を実態から一意に決められない。矛盾 $n 件（上に列挙）。人間が確認すること" 1
  fi
}

# ---------------------------------------------------------------- 記録の書き込み
ensure_logs() { mkdir -p logs; }

archive_review() {
  [ -f "$REVIEW_JSON" ] || return 0
  ensure_logs
  jq -c --arg at "$(now_iso)" '. + {archived_at: $at}' "$REVIEW_JSON" 2>/dev/null >> "$HISTORY_JSONL" || true
}

append_history() { # $1=JSON 1 行
  ensure_logs
  printf '%s\n' "$1" >> "$HISTORY_JSONL"
}

write_review() { # $1=state $2=via $3=base $4=head $5=url $6=requested_at $7=completed_at $8=findings(JSON) $9=accepted(JSON) $10=skip_reason
  ensure_logs
  local tickets_json
  tickets_json="$(printf '%s\n' "${B_TASK_TICKETS[@]:-}" | jq -Rsc 'split("\n") | map(select(. != ""))')"
  jq -n --argjson mr "${B_MR:-null}" --arg tt "$B_TASK_TYPE" --argjson tk "$tickets_json" --arg ld "$B_LAST_DONE" \
        --arg st "$1" --arg via "$2" --arg base "$3" --arg head "$4" --arg url "$5" \
        --arg rat "$6" --arg cat "$7" --argjson fd "$8" --argjson ac "$9" --arg sr "${10}" \
    '{mr: $mr,
      boundary: {task_type: $tt, tickets: $tk, last_done: $ld},
      state: $st,
      via: (if $via == "" then null else $via end),
      base_sha: (if $base == "" then null else $base end),
      head_sha: (if $head == "" then null else $head end),
      request_comment_url: (if $url == "" then null else $url end),
      requested_at: (if $rat == "" then null else $rat end),
      completed_at: (if $cat == "" then null else $cat end),
      accepted_unresolved: $ac,
      findings: $fd,
      skip_reason: (if $sr == "" then null else $sr end)}' > "$REVIEW_JSON.tmp"
  mv "$REVIEW_JSON.tmp" "$REVIEW_JSON"
}

write_mr_json() { # $1=host $2=mr $3=url
  ensure_logs
  local issue=""
  if [ -f "$MR_JSON" ]; then issue="$(jq -r '.issue // ""' "$MR_JSON" 2>/dev/null | tr -d '\r' || true)"; fi
  jq -n --arg h "$1" --argjson m "$2" --arg u "$3" --arg i "$issue" \
    '{host: $h, issue: (if $i == "" then null else ($i|tonumber?) end), mr: $m, url: (if $u == "" then null else $u end)}' > "$MR_JSON.tmp"
  mv "$MR_JSON.tmp" "$MR_JSON"
}

# ---------------------------------------------------------------- リモート
marker_request() { printf '<!-- boundary:request %s:%s -->' "$B_TASK_TYPE" "$B_LAST_DONE"; }
marker_accept()  { printf '<!-- boundary:accept %s:%s -->' "$B_TASK_TYPE" "$B_LAST_DONE"; }

# MR を特定する（記録 → CLI）。B_MR / B_MR_URL / B_HOST を設定する
resolve_mr() { # $1=offline(0/1)
  B_MR="null"; B_MR_URL=""; B_HOST="$(detect_host)"
  if [ -f "$MR_JSON" ]; then
    local -a fv; local m h
    mapfile -t fv < <(jq -r '[(.mr // "" | tostring), .url // "", .host // ""] | .[]' "$MR_JSON" 2>/dev/null | tr -d '\r')
    m="${fv[0]:-}"; B_MR_URL="${fv[1]:-}"; h="${fv[2]:-}"
    if [ -n "$m" ]; then
      B_MR="$m"
      if [ -n "$h" ]; then B_HOST="$h"; fi
      return 0
    fi
  fi
  if [ "$1" -eq 1 ]; then return 0; fi
  local out=""
  case "$B_HOST" in
    github)
      command -v gh >/dev/null 2>&1 || return 0
      out="$(gh pr view --json number,url,state 2>/dev/null || true)"
      [ -n "$out" ] || return 0
      B_MR="$(printf '%s' "$out" | jq -r '.number // empty' | tr -d '\r')"
      B_MR_URL="$(printf '%s' "$out" | jq -r '.url // ""' | tr -d '\r')"
      ;;
    gitlab)
      command -v glab >/dev/null 2>&1 || return 0
      out="$(glab mr list --source-branch "$(cur_branch)" --output json 2>/dev/null || true)"
      [ -n "$out" ] || return 0
      B_MR="$(printf '%s' "$out" | jq -r '.[0].iid // empty' | tr -d '\r')"
      B_MR_URL="$(printf '%s' "$out" | jq -r '.[0].web_url // ""' | tr -d '\r')"
      ;;
  esac
  [ -n "$B_MR" ] || B_MR="null"
  [ "$B_MR" = "null" ] || write_mr_json "$B_HOST" "$B_MR" "$B_MR_URL"
}

# 通常コメントを投稿する。成功で URL を stdout に返す
post_comment() { # $1=本文ファイル
  case "$B_HOST" in
    github)
      command -v gh >/dev/null 2>&1 || return 1
      gh pr comment "$B_MR" --body-file "$1" 2>&1 | tr -d '\r' | tail -n 1
      ;;
    gitlab)
      command -v glab >/dev/null 2>&1 || return 1
      glab mr note "$B_MR" --message "$(cat "$1")" 2>&1 | tr -d '\r' | tail -n 1
      ;;
    *) return 1 ;;
  esac
}

# 指摘を正規化スキーマで取得して stdout に返す
fetch_review_data() {
  case "$B_HOST" in
    github)
      command -v gh >/dev/null 2>&1 || return 1
      local q threads comments
      q='query($o:String!,$r:String!,$n:Int!){repository(owner:$o,name:$r){pullRequest(number:$n){reviewThreads(first:100){nodes{id isResolved isOutdated comments(first:50){nodes{url path line body createdAt author{login}}}}} reviews(last:50){nodes{state submittedAt url author{login}}}}}}'
      threads="$(gh api graphql -f query="$q" -F o="$(gh repo view --json owner -q .owner.login)" -F r="$(gh repo view --json name -q .name)" -F n="$B_MR" 2>/dev/null)" || return 1
      comments="$(gh api --paginate "repos/{owner}/{repo}/issues/$B_MR/comments" 2>/dev/null)" || return 1
      printf '%s' "$threads" | jq --argjson c "$(printf '%s' "$comments" | jq -s 'add // []')" '
        .data.repository.pullRequest as $pr
        | {threads: [$pr.reviewThreads.nodes[] | {id: .id, resolved: .isResolved,
             url: (.comments.nodes[0].url // ""), path: (.comments.nodes[0].path // ""),
             line: (.comments.nodes[0].line // null), body: (.comments.nodes[0].body // ""),
             author: (.comments.nodes[0].author.login // ""), created_at: (.comments.nodes[0].createdAt // "")}],
           reviews: [$pr.reviews.nodes[] | {state: .state, url: .url, author: (.author.login // ""), submitted_at: .submittedAt}],
           comments: [$c[] | {url: .html_url, body: .body, author: (.user.login // ""), created_at: .created_at}]}' | tr -d '\r'
      ;;
    gitlab)
      command -v glab >/dev/null 2>&1 || return 1
      local disc
      disc="$(glab api --paginate "projects/:id/merge_requests/$B_MR/discussions" 2>/dev/null)" || return 1
      printf '%s' "$disc" | jq -s 'add // []' | jq '
        {threads: [.[] | select(.notes[0].resolvable == true)
           | {id: .id, resolved: (.notes[0].resolved // false), url: (.notes[0].position.new_path // ""),
              path: (.notes[0].position.new_path // ""), line: (.notes[0].position.new_line // null),
              body: (.notes[0].body // ""), author: (.notes[0].author.username // ""), created_at: (.notes[0].created_at // "")}],
         reviews: [],
         comments: [.[] | select(.notes[0].resolvable != true) | {url: "", body: (.notes[0].body // ""), author: (.notes[0].author.username // ""), created_at: (.notes[0].created_at // "")}]}' | tr -d '\r'
      ;;
    *) return 1 ;;
  esac
}

# ---------------------------------------------------------------- status
cmd_status() {
  local offline=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --offline) offline=1 ;;
      -h|--help) usage; exit 0 ;;
      *) arg_ng "status の不明な引数: $1" ;;
    esac
    shift
  done
  scan_tickets
  if [ "$B_FINAL" = "true" ]; then apply_final_key; fi
  resolve_mr "$offline"
  read_review

  local dup=-1
  # 記録が無い・壊れている場合は実態から再導出する
  if [ "$R_BROKEN" = "true" ] || [ ! -f "$REVIEW_JSON" ]; then
    if [ "$offline" -eq 0 ] && [ "$B_MR" != "null" ] && [ -n "$B_LAST_DONE" ]; then
      local data cnt
      if data="$(fetch_review_data 2>/dev/null)" && [ -n "$data" ]; then
        cnt="$(printf '%s' "$data" | jq --arg m "$(marker_request)" '[.comments[] | select(.body | contains($m))] | length')"
        dup="$cnt"
        if [ "$cnt" = "1" ]; then
          R_STATE="requested"; R_TASK_TYPE="$B_TASK_TYPE"; R_LAST_DONE="$B_LAST_DONE"; R_VIA="cli"
          R_URL="$(printf '%s' "$data" | jq -r --arg m "$(marker_request)" '[.comments[] | select(.body | contains($m))][0].url // ""')"
          R_REQ_AT="$(printf '%s' "$data" | jq -r --arg m "$(marker_request)" '[.comments[] | select(.body | contains($m))][0].created_at // ""')"
        fi
      fi
    fi
    check_conflicts "$dup"
    # --offline はリモートの依頼マーカーを見ないので、記録が壊れている・無いときの R_STATE は
    # 「不明」であって「none」ではない。書き戻すと不明が none として固まり、オンラインの status
    # からは再導出の対象に見えなくなる（requested のまま記録を失った切れ目が二重依頼になる）。
    # 書き戻すのはオンラインで実態を確かめたときだけにする
    if [ "$offline" -eq 0 ]; then
      write_review "$R_STATE" "$R_VIA" "$R_BASE" "$R_HEAD" "$R_URL" "$R_REQ_AT" "" "[]" "[]" ""
      log_info "review-state を実態から再導出した state=$R_STATE"
    else
      log_info "offline なので review-state を書き戻さない（state=$R_STATE は暫定）"
    fi
  else
    check_conflicts "$dup"
  fi

  local eff="none"
  if review_valid; then eff="$R_STATE"; fi

  local pos="none" ms merge_running=0
  ms="$(merge_state)"
  case "$ms" in started|recorded|linked|cleaned|pushed) merge_running=1 ;; esac
  if [ "$eff" = "requested" ]; then pos="requested"
  elif [ -n "$B_CURRENT" ]; then pos="in_task"
  elif [ "$B_AT_BOUNDARY" = "true" ] && [ "$eff" = "none" ] && [ -n "$B_LAST_DONE" ]; then pos="before_request"
  elif [ "$eff" = "completed" ] || [ "$eff" = "skipped" ]; then pos="completed"
  elif [ -z "$B_CURRENT" ] && [ -z "$B_NEXT" ] && [ "$merge_running" -eq 1 ]; then pos="merge_prep"
  fi

  # チケット一覧は --arg で渡して jq の中で分割する（jq の起動をもう 1 回増やさない）
  jq -nc --argjson ab "$B_AT_BOUNDARY" --arg pos "$pos" --arg cur "$B_CURRENT" --arg nx "$B_NEXT" \
        --arg ty "$B_NEXT_TYPE" --arg sk "$B_SKILL" --arg tt "$B_TASK_TYPE" \
        --arg tkraw "${B_TASK_TICKETS[*]:-}" \
        --arg ld "$B_LAST_DONE" --argjson rr "$B_REVIEW_REQUIRED" --arg st "$eff" --arg via "$R_VIA" \
        --arg base "$R_BASE" --arg head "$R_HEAD" --arg url "$R_URL" --arg rat "$R_REQ_AT" --arg cat "$R_DONE_AT" \
        --argjson mr "$B_MR" --arg host "$B_HOST" --argjson fin "$B_FINAL" \
    '{at_boundary: $ab, position: $pos, final: $fin,
      current: (if $cur == "" then null else $cur end),
      next: (if $nx == "" then null else $nx end),
      type: (if $ty == "" then null else $ty end),
      skill: (if $sk == "" then null else $sk end),
      last_task: {task_type: (if $tt == "" then null else $tt end),
                  tickets: ($tkraw | split(" ") | map(select(. != ""))),
                  last_done: (if $ld == "" then null else $ld end), review_required: $rr},
      review: {state: $st, via: (if $via == "" then null else $via end),
               base_sha: (if $base == "" then null else $base end),
               head_sha: (if $head == "" then null else $head end),
               request_comment_url: (if $url == "" then null else $url end),
               requested_at: (if $rat == "" then null else $rat end),
               completed_at: (if $cat == "" then null else $cat end)},
      mr: $mr, host: (if $host == "" then null else $host end)}' | tr -d '\r'
  exit 0
}

# ---------------------------------------------------------------- 対応工数レポートの投稿
post_usage_report() { # $1=path
  [ -f "$1" ] || { log_warn "usage-report が無い: $1"; return 0; }
  local tmp url
  tmp="$(mktemp)"
  { printf '<!-- boundary:usage -->\n\n'; cat "$1"; } > "$tmp"
  if url="$(post_comment "$tmp" 2>/dev/null)" && [ -n "$url" ]; then
    ensure_logs; mkdir -p logs/usage
    local f="logs/usage/$(cur_branch).json"
    jq -n --arg s "$(head_sha)" --arg u "$url" '{posted: true, since_sha: $s, url: $u}' > "$f"
    log_info "usage-report を投稿した $url"
  else
    log_warn "usage-report の投稿に失敗した（request 自体は成功とする）"
  fi
  rm -f "$tmp"
  return 0
}

# ---------------------------------------------------------------- note
cmd_note() {
  local body="" usage_report=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --body-file) [ $# -ge 2 ] || arg_ng "--body-file にパスを指定する"; body="$2"; shift ;;
      --usage-report) [ $# -ge 2 ] || arg_ng "--usage-report にパスを指定する"; usage_report="$2"; shift ;;
      -h|--help) usage; exit 0 ;;
      *) arg_ng "note の不明な引数: $1" ;;
    esac
    shift
  done
  [ -n "$body" ] && [ -f "$body" ] && [ -s "$body" ] || result_ng 001 "本文が空か存在しない（--body-file <path>）" 1
  scan_tickets
  if [ "$B_FINAL" = "true" ]; then apply_final_key; fi
  resolve_mr 0
  [ "$B_MR" != "null" ] || result_ng 001 "MR が無い（単独実行モードなら request --standalone を使う。note は MR が要る）" 1
  local tmp url
  tmp="$(mktemp)"
  { printf '<!-- boundary:note -->\n\n'; cat "$body"; } > "$tmp"
  if ! url="$(post_comment "$tmp")" || [ -z "$url" ]; then
    rm -f "$tmp"; result_ng 004 "コメントの投稿に失敗した（host=$B_HOST mr=$B_MR）。CLI が無い環境は呼び出し元が投稿し request --external を使う" 1
  fi
  rm -f "$tmp"
  append_history "$(jq -nc --arg u "$url" --arg at "$(now_iso)" --arg tt "$B_TASK_TYPE" '{kind: "note", url: $u, at: $at, task_type: $tt}')"
  if [ -n "$usage_report" ]; then post_usage_report "$usage_report"; fi
  result_ok "コメントを投稿した: $url"
}

# ---------------------------------------------------------------- request
cmd_request() {
  local body="" usage_report="" final=0 standalone=0 external=0 comment_url=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --body-file) [ $# -ge 2 ] || arg_ng "--body-file にパスを指定する"; body="$2"; shift ;;
      --usage-report) [ $# -ge 2 ] || arg_ng "--usage-report にパスを指定する"; usage_report="$2"; shift ;;
      --comment-url) [ $# -ge 2 ] || arg_ng "--comment-url に URL を指定する"; comment_url="$2"; shift ;;
      --final) final=1 ;;
      --standalone) standalone=1 ;;
      --external) external=1 ;;
      -h|--help) usage; exit 0 ;;
      *) arg_ng "request の不明な引数: $1" ;;
    esac
    shift
  done
  scan_tickets
  local ng=""
  if [ "$final" -eq 1 ]; then
    if [ "$B_FINAL" = "true" ]; then apply_final_key
    else ng+="- --final は作業中が全体まとめチケット 1 枚のときだけ使える"$'\n'; fi
  else
    if [ "$B_FINAL" = "true" ]; then ng+="- 全体まとめの切れ目は --final を付ける"$'\n'; fi
    [ "$B_AT_BOUNDARY" = "true" ] || ng+="- タスクの切れ目ではない（作業中のチケットか、同じ種類の未着手チケットが残っている）"$'\n'
  fi
  [ -n "$body" ] && [ -f "$body" ] && [ -s "$body" ] || ng+="- 本文が空か存在しない（--body-file <path>）"$'\n'
  [ -z "$(git status --porcelain 2>/dev/null)" ] || ng+="- 未コミットの変更がある（commit.sh でコミットする）"$'\n'
  local br unpushed
  br="$(cur_branch)"
  unpushed="$(git rev-list "origin/$br..HEAD" 2>/dev/null || printf 'unknown')"
  if [ "$unpushed" = "unknown" ]; then ng+="- 上流が無い（push.sh で push する）"$'\n'
  elif [ -n "$unpushed" ]; then ng+="- HEAD が push されていない（push.sh で push する）"$'\n'; fi

  resolve_mr 0
  [ "$standalone" -eq 1 ] || [ "$B_MR" != "null" ] || ng+="- MR が無い（--standalone を使うか MR を作る）"$'\n'
  read_review
  if review_valid && [ "$R_STATE" = "requested" ]; then ng+="- 現在の切れ目は既に requested（complete へ進む）"$'\n'; fi
  if [ -n "$ng" ]; then
    printf '%s' "$ng"
    result_ng 001 "レビュー依頼の前提を満たしていない。未充足 $(printf '%s' "$ng" | grep -c '^- ') 件（上に列挙）" 1
  fi

  local url="" via="cli" tmp
  tmp="$(mktemp)"
  { printf '%s\n\n' "$(marker_request)"; cat "$body"; } > "$tmp"
  if [ "$external" -eq 1 ]; then
    [ -n "$comment_url" ] || { rm -f "$tmp"; arg_ng "--external には --comment-url <url> が要る"; }
    url="$comment_url"; via="external"
  elif [ "$standalone" -eq 1 ]; then
    url=""; via="chat"
    append_history "$(jq -nc --arg b "$(cat "$body")" --arg at "$(now_iso)" '{kind: "request-standalone", body: $b, at: $at}')"
  else
    if ! url="$(post_comment "$tmp")" || [ -z "$url" ]; then
      rm -f "$tmp"; result_ng 004 "コメントの投稿に失敗した（host=$B_HOST mr=$B_MR）。CLI が無い環境は呼び出し元が投稿し --external --comment-url を使う" 1
    fi
  fi
  rm -f "$tmp"

  local base head at
  base="$R_HEAD"; [ -n "$base" ] || base="$(first_sha)"
  head="$(head_sha)"; at="$(now_iso)"
  archive_review
  write_review "requested" "$via" "$base" "$head" "$url" "$at" "" "[]" "[]" ""
  if [ -n "$usage_report" ] && [ "$standalone" -eq 0 ] && [ "$external" -eq 0 ]; then post_usage_report "$usage_report"; fi
  result_ok "レビューを依頼した（${url:-チャットで依頼}。対象 $B_TASK_TYPE / チケット ${B_TASK_TICKETS[*]:-なし} / 差分 ${base:0:7}..${head:0:7}）"
}

# ---------------------------------------------------------------- skip
cmd_skip() {
  local reason="" final=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --reason) [ $# -ge 2 ] || arg_ng "--reason に理由を指定する"; reason="$2"; shift ;;
      --final) final=1 ;;
      -h|--help) usage; exit 0 ;;
      *) arg_ng "skip の不明な引数: $1" ;;
    esac
    shift
  done
  scan_tickets
  local ng=""
  if [ "$final" -eq 1 ]; then
    if [ "$B_FINAL" = "true" ]; then apply_final_key
    else ng+="- --final は作業中が全体まとめチケット 1 枚のときだけ使える"$'\n'; fi
  else
    [ "$B_AT_BOUNDARY" = "true" ] || ng+="- タスクの切れ目ではない"$'\n'
  fi
  [ "$B_REVIEW_REQUIRED" = "false" ] || ng+="- 人間レビューが要の切れ目は省略できない（レビューを依頼すること）"$'\n'
  [ -n "$reason" ] || ng+="- 理由が空（--reason <理由>）"$'\n'
  if [ -n "$ng" ]; then
    printf '%s' "$ng"
    result_ng 001 "レビューの省略の前提を満たしていない。未充足 $(printf '%s' "$ng" | grep -c '^- ') 件（上に列挙）" 1
  fi
  resolve_mr 1
  archive_review
  write_review "skipped" "cli" "" "$(head_sha)" "" "" "$(now_iso)" "[]" "[]" "$reason"
  result_ok "レビューを省略した（$B_TASK_TYPE / $B_LAST_DONE。理由: $reason）"
}

# ---------------------------------------------------------------- complete
cmd_complete() {
  local final=0 accept=0 standalone=0 external=0 report=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --final) final=1 ;;
      --accept-unresolved) accept=1 ;;
      --standalone) standalone=1 ;;
      --external) external=1 ;;
      --report-file) [ $# -ge 2 ] || arg_ng "--report-file にパスを指定する"; report="$2"; shift ;;
      -h|--help) usage; exit 0 ;;
      *) arg_ng "complete の不明な引数: $1" ;;
    esac
    shift
  done
  scan_tickets
  if [ "$final" -eq 1 ]; then
    [ "$B_FINAL" = "true" ] || result_ng 001 "--final は作業中が全体まとめチケット 1 枚のときだけ使える" 1
    apply_final_key
  fi
  resolve_mr 1
  read_review
  review_valid && [ "$R_STATE" = "requested" ] || \
    result_ng 002 "現在の切れ目（$B_TASK_TYPE / $B_LAST_DONE）が requested でない（現在: ${R_STATE:-none}）。request からやり直すこと" 1

  local data=""
  if [ "$standalone" -eq 1 ]; then
    data='{"threads":[],"reviews":[],"comments":[]}'
  elif [ "$external" -eq 1 ]; then
    [ -n "$report" ] && [ -f "$report" ] || arg_ng "--external には --report-file <json> が要る"
    jq -e . "$report" >/dev/null 2>&1 || arg_ng "--report-file が JSON として読めない: $report"
    data="$(cat "$report")"
  else
    resolve_mr 0
    if ! data="$(fetch_review_data)" || [ -z "$data" ]; then
      result_ng 004 "指摘の取得に失敗した（host=$B_HOST mr=$B_MR）。CLI が無い環境は --external --report-file を使う" 1
    fi
  fi

  # 機構が投稿したコメント（固定マーカー付き）を除く。ログイン名では除外しない。
  # 時刻の比較は必ずエポック秒に直してから行う: requested_at はローカルのオフセット表記（+09:00）で
  # 記録され、ホストの created_at / submitted_at は UTC の Z 表記なので、ISO 文字列のまま辞書順で
  # 比べると依頼直後の指摘が「依頼より前」と判定されて黙って落ちる。ep はどちらの表記も受ける。
  # 変換に fromdateiso8601 を使わないのは、Windows の jq が strptime を持たず
  # 「strptime/1 not implemented on this platform」で落ちるため（civil_days で日数を自前に計算する）
  local findings unresolved changes_req
  findings="$(printf '%s' "$data" | jq --arg since "$R_REQ_AT" '
    def civil_days($y; $m; $d):
      ( if $m <= 2 then $y - 1 else $y end ) as $yy
      | ( ($yy / 400) | floor ) as $era
      | ( $yy - $era * 400 ) as $yoe
      | ( if $m > 2 then $m - 3 else $m + 9 end ) as $mp
      | ( (((153 * $mp) + 2) / 5) | floor ) as $doym
      | ( $doym + $d - 1 ) as $doy
      | ( ($yoe * 365) + (($yoe / 4) | floor) - (($yoe / 100) | floor) + $doy ) as $doe
      | ($era * 146097) + $doe - 719468;
    def ep: . as $s
      | if ($s == null or $s == "") then 0
        else ( $s | sub("\\.[0-9]+"; "") ) as $t
          | ( [$t | capture("^(?<y>[0-9]{4})-(?<mo>[0-9]{2})-(?<d>[0-9]{2})[T ](?<h>[0-9]{2}):(?<mi>[0-9]{2}):(?<se>[0-9]{2})(?<z>Z|[+-][0-9]{2}:?[0-9]{2})?$")] ) as $ms
          | if ($ms | length) == 0 then 0
            else ($ms[0]) as $m
              | ( civil_days(($m.y | tonumber); ($m.mo | tonumber); ($m.d | tonumber)) * 86400
                  + ($m.h | tonumber) * 3600 + ($m.mi | tonumber) * 60 + ($m.se | tonumber) ) as $base
              | if ($m.z == null or $m.z == "Z") then $base
                else ( $m.z | sub(":"; "") ) as $zz
                  | ( (($zz[1:3] | tonumber) * 3600) + (($zz[3:5] | tonumber) * 60) ) as $off
                  | if ($zz[0:1] == "+") then ($base - $off) else ($base + $off) end
                end
            end
        end;
    def after($se): ((. | ep) as $x | $se == 0 or $x == 0 or $x >= $se);
    ($since | ep) as $se
    | [ (.threads // [])[] | select((.body // "") | contains("<!-- boundary:") | not)
        | select((.created_at // "") | after($se))
        | {kind: "thread", url: .url, author: .author, path: .path, line: .line,
           summary: ((.body // "") | split("\n")[0]), resolved: (.resolved // false)} ]
    + [ (.reviews // [])[] | select((.submitted_at // "") | after($se))
        | {kind: "review", url: .url, author: .author, path: null, line: null,
           summary: .state, resolved: true} ]
    + [ (.comments // [])[] | select((.body // "") | contains("<!-- boundary:") | not)
        | select((.created_at // "") | after($se))
        | {kind: "comment", url: .url, author: .author, path: null, line: null,
           summary: ((.body // "") | split("\n")[0]), resolved: true} ]' | tr -d '\r')"
  unresolved="$(printf '%s' "$data" | jq -c '[(.threads // [])[] | select((.resolved // false) == false) | select((.body // "") | contains("<!-- boundary:") | not)]')"
  changes_req="$(printf '%s' "$data" | jq -r '[(.reviews // [])[] | select(.state == "CHANGES_REQUESTED")] | length')"

  if [ "$changes_req" != "0" ]; then
    printf '%s' "$data" | jq -r '(.reviews // [])[] | select(.state == "CHANGES_REQUESTED") | "- \(.author): \(.url)"'
    result_ng 003 "変更要求（CHANGES_REQUESTED）が $changes_req 件残っている（上に列挙）。--accept-unresolved では通せない。レビュアーが approve / dismiss するまで待つこと" 1
  fi
  local n_unres; n_unres="$(printf '%s' "$unresolved" | jq 'length')"
  if [ "$n_unres" != "0" ] && [ "$accept" -eq 0 ]; then
    printf '%s' "$unresolved" | jq -r '.[] | "- \(.url) \(.path):\(.line) \(.summary // .body)"'
    result_ng 003 "未解決のレビュースレッドが $n_unres 件ある（上に列挙）。解決してもらうか、確認済みなら --accept-unresolved を付ける（変更要求は不可）" 1
  fi

  local accepted="[]"
  if [ "$n_unres" != "0" ] && [ "$accept" -eq 1 ]; then
    accepted="$(printf '%s' "$unresolved" | jq -c '[.[] | {id: .id, url: .url, accepted_by: "boundary.sh --accept-unresolved"}]')"
    if [ "$standalone" -eq 0 ] && [ "$external" -eq 0 ] && [ "$B_MR" != "null" ]; then
      local tmp; tmp="$(mktemp)"
      { printf '%s\n\n' "$(marker_accept)"
        printf '未解決のまま受け入れたスレッド %s 件:\n\n' "$n_unres"
        printf '%s' "$unresolved" | jq -r '.[] | "- \(.url) \(.path):\(.line)"'
      } > "$tmp"
      post_comment "$tmp" >/dev/null 2>&1 || log_warn "受け入れコメントの投稿に失敗した"
      rm -f "$tmp"
    fi
  fi

  local via="cli"
  if [ "$external" -eq 1 ]; then via="external"; fi
  if [ "$standalone" -eq 1 ]; then via="chat"; fi
  archive_review
  write_review "completed" "$via" "$R_BASE" "$R_HEAD" "$R_URL" "$R_REQ_AT" "$(now_iso)" "$findings" "$accepted" ""
  printf '%s\n' "$findings"
  result_ok "レビュー完了を記録した（指摘 $(printf '%s' "$findings" | jq 'length') 件 / 受け入れた未解決 $(printf '%s' "$accepted" | jq 'length') 件）"
}

# ---------------------------------------------------------------- main
main() {
  local sub="${1:-}"; shift || true
  case "$sub" in
    -h|--help|"") usage; [ -n "$sub" ] && exit 0; arg_ng "サブコマンドを指定する（status / note / request / skip / complete）" ;;
  esac
  cd "$LOGGER_ROOT" || arg_ng "リポジトリルートに移動できない: $LOGGER_ROOT"
  command -v jq >/dev/null 2>&1 || arg_ng "jq が無い（status / complete は JSON を返す）"
  command -v git >/dev/null 2>&1 || arg_ng "git が無い"
  [ -f "$TICKET_SH" ] || arg_ng "ticket.sh が無い: $TICKET_SH"
  log_info "start subcommand=$sub args=$*"
  case "$sub" in
    status) cmd_status "$@" ;;
    note) cmd_note "$@" ;;
    request) cmd_request "$@" ;;
    skip) cmd_skip "$@" ;;
    complete) cmd_complete "$@" ;;
    *) arg_ng "不明なサブコマンド: $sub（status / note / request / skip / complete）" ;;
  esac
}

main "$@"
