#!/usr/bin/env bash
# frontmatter.sh — Markdown frontmatter の読み取り（source 専用・純 bash。外部プロセスを起動しない）
# 仕様: .claude/docs/10_spec/skills/20-common-step-shell-script.md「frontmatter.sh」、フック共通仕様 §9
# 対象: フラットなスカラー / フロー配列 ["a", "b"] / 入れ子マッピング（2 段） / インラインマップ {k: v, k2: "v2"}
# 対象外: ブロック配列（- a）・複数行スカラー → 空 + 戻り値 1
# 提供: fm_extract <file> / fm_get <file> <key> / fm_list <file> <key> / fm_has <file> <key>
#       key は `ticket_type` か `allow.write` / `human_review.required` のようなドット区切り

# 直接実行されたら何もしない
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then exit 0; fi

FM_BLOCK=""
FM_FILE=""

# frontmatter 本文（区切り --- を含まない。CR 除去済み）を FM_BLOCK に格納する。無ければ空で 1
fm_extract() {
  local file="$1" line first=1
  FM_BLOCK=""
  FM_FILE=""
  [[ -r "$file" ]] || return 1
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    if (( first )); then
      first=0
      [[ "$line" == "---" ]] || return 1
      continue
    fi
    if [[ "$line" == "---" ]]; then
      FM_FILE="$file"
      return 0
    fi
    FM_BLOCK+="$line"$'\n'
  done < "$file"
  FM_BLOCK=""
  return 1
}

# 内部: 行から # コメント（クォート外）を除き前後の空白を落として REPLY に返す
__fm_clean() {
  local s="$1" out="" q="" i c
  for (( i = 0; i < ${#s}; i++ )); do
    c="${s:i:1}"
    if [[ -n "$q" ]]; then
      out+="$c"
      [[ "$c" == "$q" ]] && q=""
      continue
    fi
    case "$c" in
      \"|\') q="$c"; out+="$c" ;;
      \#) break ;;
      *) out+="$c" ;;
    esac
  done
  out="${out#"${out%%[![:space:]]*}"}"
  out="${out%"${out##*[![:space:]]}"}"
  REPLY="$out"
}

# 内部: 文字列を区切り文字（クォート外）で分割し __FM_PARTS に入れる
__fm_split() {
  local s="$1" sep="$2" q="" cur="" i c
  __FM_PARTS=()
  for (( i = 0; i < ${#s}; i++ )); do
    c="${s:i:1}"
    if [[ -n "$q" ]]; then
      cur+="$c"
      [[ "$c" == "$q" ]] && q=""
      continue
    fi
    case "$c" in
      \"|\') q="$c"; cur+="$c" ;;
      "$sep") __FM_PARTS+=("$cur"); cur="" ;;
      *) cur+="$c" ;;
    esac
  done
  __FM_PARTS+=("$cur")
}

# 内部: 前後の空白とクォートを外して REPLY に返す
__fm_unquote() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  if [[ ${#s} -ge 2 ]]; then
    case "$s" in
      \"*\") s="${s:1:${#s}-2}" ;;
      \'*\') s="${s:1:${#s}-2}" ;;
    esac
  fi
  REPLY="$s"
}

# 内部: インラインマップ {k: v, k2: "v2"} から k を引いて REPLY に返す（生の値）
__fm_inline_get() { # $1=マップ文字列 $2=キー
  local inner="${1#\{}" item k v
  inner="${inner%\}}"
  __fm_split "$inner" ","
  for item in "${__FM_PARTS[@]}"; do
    __fm_split "$item" ":"
    __fm_unquote "${__FM_PARTS[0]}"
    k="$REPLY"
    if [[ "$k" == "$2" ]]; then
      v="${item#*:}"
      v="${v#"${v%%[![:space:]]*}"}"
      v="${v%"${v##*[![:space:]]}"}"
      REPLY="$v"
      return 0
    fi
  done
  REPLY=""
  return 1
}

# 内部: FM_BLOCK からキー（a または a.b）の生の値を REPLY に返す。__FM_KIND = scalar | list | inline | map | block
__fm_lookup() {
  local key="$1" top sub raw line ind k v cur=""
  if [[ "$key" == *.* ]]; then top="${key%%.*}"; sub="${key#*.}"; else top="$key"; sub=""; fi
  REPLY=""
  __FM_KIND=""
  while IFS= read -r raw; do
    [[ -z "${raw//[[:space:]]/}" ]] && continue
    ind="${raw%%[! ]*}"
    ind=${#ind}
    __fm_clean "$raw"
    line="$REPLY"
    [[ -z "$line" ]] && continue
    if (( ind == 0 )); then
      [[ "$line" =~ ^([A-Za-z0-9_-]+)[[:space:]]*:(.*)$ ]] || continue
      k="${BASH_REMATCH[1]}"
      v="${BASH_REMATCH[2]}"
      v="${v#"${v%%[![:space:]]*}"}"
      cur="$k"
      [[ "$k" == "$top" ]] || continue
      if [[ -z "$v" ]]; then
        # 入れ子マッピング（子行が続く）
        if [[ -z "$sub" ]]; then __FM_KIND="map"; REPLY=""; return 0; fi
        continue
      fi
      case "$v" in
        \{*)
          if [[ -z "$sub" ]]; then __FM_KIND="inline"; REPLY="$v"; return 0; fi
          if __fm_inline_get "$v" "$sub"; then
            case "$REPLY" in \[*) __FM_KIND="list" ;; *) __FM_KIND="scalar" ;; esac
            return 0
          fi
          REPLY=""; return 1 ;;
        \[*)
          [[ -n "$sub" ]] && { REPLY=""; return 1; }
          __FM_KIND="list"; REPLY="$v"; return 0 ;;
        *)
          [[ -n "$sub" ]] && { REPLY=""; return 1; }
          __FM_KIND="scalar"; REPLY="$v"; return 0 ;;
      esac
    else
      # 子行（インデントあり）。直前のトップレベルが top のときだけ見る
      [[ "$cur" == "$top" && -n "$sub" ]] || continue
      case "$line" in
        -*) __FM_KIND="block"; REPLY=""; return 1 ;;
      esac
      [[ "$line" =~ ^([A-Za-z0-9_-]+)[[:space:]]*:(.*)$ ]] || continue
      k="${BASH_REMATCH[1]}"
      v="${BASH_REMATCH[2]}"
      v="${v#"${v%%[![:space:]]*}"}"
      [[ "$k" == "$sub" ]] || continue
      case "$v" in
        "") __FM_KIND="block"; REPLY=""; return 1 ;;
        \[*) __FM_KIND="list" ;;
        \{*) __FM_KIND="inline" ;;
        *) __FM_KIND="scalar" ;;
      esac
      REPLY="$v"
      return 0
    fi
  done <<< "$FM_BLOCK"
  REPLY=""
  return 1
}

# 内部: 必要なら抽出する
__fm_ensure() {
  if [[ "$FM_FILE" != "$1" || -z "$FM_BLOCK" ]]; then
    fm_extract "$1" || return 1
  fi
  return 0
}

# スカラー値を標準出力に返す（クォート除去）。無ければ空で 1
fm_get() { # $1=file $2=key
  __fm_ensure "$1" || return 1
  __fm_lookup "$2" || return 1
  case "$__FM_KIND" in
    scalar) __fm_unquote "$REPLY"; printf '%s\n' "$REPLY"; return 0 ;;
    list|inline) printf '%s\n' "$REPLY"; return 0 ;;
    *) return 1 ;;
  esac
}

# フロー配列の要素を 1 行 1 要素で返す（クォート除去）。無ければ空で 1
fm_list() { # $1=file $2=key
  __fm_ensure "$1" || return 1
  __fm_lookup "$2" || return 1
  [[ "$__FM_KIND" == "list" ]] || return 1
  local inner="${REPLY#\[}" item
  inner="${inner%\]}"
  __fm_split "$inner" ","
  for item in "${__FM_PARTS[@]}"; do
    __fm_unquote "$item"
    [[ -n "$REPLY" ]] && printf '%s\n' "$REPLY"
  done
  return 0
}

# 存在すれば 0
fm_has() { # $1=file $2=key
  __fm_ensure "$1" || return 1
  __fm_lookup "$2" && return 0
  [[ "$__FM_KIND" == "map" ]] && return 0
  return 1
}
