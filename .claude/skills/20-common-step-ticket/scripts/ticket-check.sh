#!/usr/bin/env bash
# ticket-check.sh — チケットの完了検査（source 専用）
# 仕様: .claude/docs/10_spec/skills/20-common-step-ticket.md「Script 処理」complete の検査
# 提供: ticket_check_completion <ticket ファイル> [--skip-worktree]
#       → 未充足を TICKET_UNMET 配列に入れる。充足なら 0、未充足なら 1
#       ticket_section <file> <見出しの正規表現> → その節の本文を標準出力へ
# 使い手: ticket.sh の complete と、finalize.sh release の段階 2（全体まとめチケットの完了検査）。
#         全体まとめは ticket.sh complete を通れない（TK005 が必ず拒否する）ので、検査だけをここで共有し、
#         2 か所に同じ判定を書かない（10-task-overall-summary 仕様「release」段階 2）。
# 前提: 呼び手が frontmatter.sh を読み込んでいること（fm_get を使う）。logger は呼び手のものを使う。

# 直接実行されたら何もしない
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then exit 0; fi

# 作業ログの固定見出し（正は 00_requirement/skills/20-common-step-ticket.md）
TICKET_LOG_HEADINGS=("現在地" "うまくいったこと" "うまくいかなかったこと" "仕様からの逸脱" "判断と根拠" "拒否・確認・迂回の記録" "使った AI アセットと効き目" "スコープ外で見つけたこと" "AI アセットに反映すべき内容" "備考")

ticket_section() { # $1=file $2=見出し行の正規表現 → その節の本文（次の同レベル以上の見出しまで）
  awk -v re="$2" '
    $0 ~ re { f=1; lvl=match($0, /^#+/) ? RLENGTH : 0; next }
    f && /^#+ / { l=match($0, /^#+/) ? RLENGTH : 0; if (l <= lvl) { f=0 } }
    f { print }' "$1"
}

# 完了検査。未充足を TICKET_UNMET に入れて 1 を返す（充足なら空にして 0）
ticket_check_completion() { # $1=ticket ファイル [--skip-worktree]
  local path="$1" skip_wt=0
  shift || true
  while [ $# -gt 0 ]; do
    case "$1" in --skip-worktree) skip_wt=1 ;; esac
    shift
  done
  TICKET_UNMET=()
  local dod unchecked noroot noroot2 cur ai h hc st

  dod="$(ticket_section "$path" '^## DoD')"
  unchecked="$(printf '%s\n' "$dod" | grep -n '^- \[ \]' | cut -d: -f1 | tr '\n' ' ' || true)"
  [ -z "$unchecked" ] || TICKET_UNMET+=("DoD に未チェックの項目がある（DoD 節の行 ${unchecked}）")
  noroot="$(printf '%s\n' "$dod" | grep -E '^- \[x\]' | grep -nE '（根拠:[[:space:]]*）|（根拠:[[:space:]]*$' | cut -d: -f1 | tr '\n' ' ' || true)"
  [ -z "$noroot" ] || TICKET_UNMET+=("チェック済み DoD の根拠欄が空（チェック済み項目の ${noroot}番目）")
  noroot2="$(printf '%s\n' "$dod" | grep -E '^- \[x\]' | grep -nv '（根拠:' | cut -d: -f1 | tr '\n' ' ' || true)"
  [ -z "$noroot2" ] || TICKET_UNMET+=("チェック済み DoD に根拠欄「（根拠: ）」そのものが無い（チェック済み項目の ${noroot2}番目）。欄を消して通さない")

  for h in "${TICKET_LOG_HEADINGS[@]}"; do
    # 見出しの一致は末尾の空白・CR を許し、前方一致の別見出し（### 現在地の続き）は数えない
    hc="$(grep -cE "^### $h[[:space:]]*\$" "$path" || true)"
    if [ "$hc" -eq 0 ]; then TICKET_UNMET+=("作業ログの見出し「$h」が無い")
    elif [ "$hc" -ge 2 ]; then TICKET_UNMET+=("作業ログの見出し「$h」が重複している（$hc 回。テンプレートの見出しを残したまま追記していないか）")
    fi
  done

  cur="$(ticket_section "$path" '^### 現在地')"
  if printf '%s\n' "$cur" | grep -qE '^- *(次|未着手)|未着手|^- *次[:：]'; then
    TICKET_UNMET+=("作業ログ「現在地」に未完了の項目が残っている（「次:」「未着手」）")
  fi
  ai="$(ticket_section "$path" '^### AI アセットに反映すべき内容' | sed '/^[[:space:]]*$/d')"
  [ -n "$ai" ] || TICKET_UNMET+=("作業ログ「AI アセットに反映すべき内容」が空（0 件なら 0 件である根拠を書く）")

  if [ "$skip_wt" -eq 0 ]; then
    st="$(git status --porcelain 2>/dev/null | tr -d '\r' | awk -v p="${path#./}" 'substr($0, 4) != p' | sed '/^$/d' || true)"
    if [ -n "$st" ]; then
      TICKET_UNMET+=("チケット以外に未コミットの変更がある（$(printf '%s\n' "$st" | wc -l | tr -d ' ') 件: $(printf '%s\n' "$st" | head -5 | sed 's/^...//' | tr '\n' ' ')）→ commit.sh で先にコミットする")
    fi
  fi

  [ "${#TICKET_UNMET[@]}" -eq 0 ]
}
