#!/usr/bin/env bash
# cmdpos.sh — コマンド位置の判定（source 専用・純 bash。外部プロセスを起動しない）
# 仕様: .claude/docs/10_spec/フック共通仕様.md §7（前処理・分割・ラッパー・正規化・opaque・PowerShell・縮退・提供コマンド）
# 提供: cmdpos_parse <コマンド文字列> [bash|powershell] → 実行位置にあるセグメントの列を配列に置く
#   CP_DEGRADED        1 = 判定を行わなかった（bash 4.3 未満 / 4096 文字超）。呼び出し側は対象語の部分一致で判定する
#   CP_COUNT           セグメント数
#   CP_EXE[i]          実行体（ディレクトリ部と .exe を除いた basename。クォート等で潰れていれば `_`）
#   CP_ARGS[i]         引数（US = \x1e 区切り。cmdpos_args i で配列 REPLY_ARGS に展開）
#   CP_SUBCMD[i]       git のときグローバルオプションを飛ばした第 1 サブコマンド（他のコマンドでは最初の非オプション引数）
#   CP_REDIRECTS[i]    書き込みリダイレクト（> >> &> <>）の宛先（US 区切り。宛先が潰れていれば `_`）
#   CP_WRITE_TARGETS[i] cp mv tee touch mkdir rm truncate sed -i install ln の書き込み先（US 区切り）
#   CP_OPAQUE[i]       1 = 文字列をコードとして受け取る実行系（eval / bash -c / xargs / find -exec / pwsh 等）
#   CP_PROVIDED[i]     提供コマンドならそのルート相対パス（§7-8）。それ以外は空
#   CP_GITLIKE[i]      1 = 実行体は特定できない（`_`）が生の文字列に git を含む（PowerShell の判定不能を呼び出し側が拒否側に倒すため）
#   CP_LOWER           小文字化した元の文字列（縮退時の部分一致用）
# 呼び出し側はこの出力だけを見て判定し、コマンド文字列を再パースしない（規則の複製禁止）。
# 正規化部（クォート・ヒアドキュメント・コメント・$( ) の扱い）は参考実装 CommandPosition.sh から流用。

# 直接実行されたら何もしない
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then exit 0; fi

_CP_NL=$'\n'
_CP_BT='`'
_CP_US=$'\x1e'
_CP_DUP=$'\x01'     # `>&` `<&`（fd 複製）の保護
_CP_AMPRED=$'\x02'  # `&>`（stdout+stderr のリダイレクト）の保護
_CP_MAX_LEN=4096

# パターンは $'...' で組み立ててから、パラメータ展開の中へクォートせず展開する
_CP_CODE_CHARS=$'[\'"#\\\\`<()$\n]'
_CP_DQ_CHARS=$'["\\\\$`]'
_CP_SQ_CHARS=$'[\']'

# 透過的なラッパー・予約語（§7-3 の列挙を包含）
_CP_PREFIX_WORDS=' if then elif else do while until ! time sudo doas env command builtin exec nohup nice ionice setsid stdbuf timeout '
_CP_PREFIX_OPTS_WITH_VALUE=' -u -g -p -h -r -t -c -a -n -s -k -i -o -e '
_CP_PREFIX_WORDS_WITH_LEADING_VALUE=' timeout '
# 文字列をコードとして受け取る実行系（無条件）と、コード指定オプションと併用されたときだけのもの（§7-5）
_CP_OPAQUE_WORDS=' eval xargs ssh watch flock parallel '
_CP_OPAQUE_WITH_OPT=' bash sh zsh ksh dash busybox python python3 perl ruby node deno pwsh powershell '
_CP_CODE_OPTS=' -c -e -E --command -command -encodedcommand -ec '
_CP_FIND_EXEC_OPTS=' -exec -execdir -ok -okdir '
# 値を別トークンで取る git のグローバルオプション
_CP_GIT_OPTS_WITH_VALUE=' -c --git-dir --work-tree --namespace --exec-path --super-prefix '
# 書き込み先を引数に取るコマンド（§7）
_CP_WRITE_CMDS=' cp mv tee touch mkdir rm truncate install ln sed '

CP_DEGRADED=0; CP_COUNT=0; CP_LOWER=""
CP_EXE=(); CP_ARGS=(); CP_SUBCMD=(); CP_REDIRECTS=(); CP_WRITE_TARGETS=(); CP_OPAQUE=(); CP_PROVIDED=(); CP_GITLIKE=()

# ---- 正規化（参考実装から流用）----
# クォート・コメント・ヒアドキュメント本文をプレースホルダ `_` へ潰す。ダブルクォート内の $( ) と ` ` はコードとして残す
_cp_normalize_to_reply() {
  local raw="$1"
  local -a lines=()
  mapfile -t lines <<<"$raw"
  local out='' state='code' rest head c prev=''
  local li=0 nlines=${#lines[@]} paren=0 line_cont=0
  local -a ret_states=() ret_parens=() ret_closes=() hd_delims=() hd_strips=()
  while ((li < nlines)); do
    rest="${lines[li]}"
    while [[ -n $rest ]]; do
      case "$state" in
        code)
          head="${rest%%$_CP_CODE_CHARS*}"
          if ((${#head} == ${#rest})); then out+="$rest"; prev="${rest: -1}"; rest=''; break; fi
          out+="$head"; [[ -n $head ]] && prev="${head: -1}"
          rest="${rest:${#head}}"; c="${rest:0:1}"
          case "$c" in
            "'") state='sq'; out+='_'; prev='_'; rest="${rest:1}" ;;
            '"') state='dq'; out+='_'; prev='_'; rest="${rest:1}" ;;
            '#')
              case "$prev" in
                '' | ' ' | $'\t' | $'\r' | ';' | '&' | '|' | '(' | ')' | '{' | '}' | "$_CP_BT") out+='_'; prev='_'; rest='' ;;
                *) out+='#'; prev='#'; rest="${rest:1}" ;;
              esac ;;
            '\')
              if ((${#rest} == 1)); then line_cont=1; rest=''
              else
                c="${rest:1:1}"
                case "$c" in [A-Za-z0-9_./-]) out+="$c" ;; *) out+='_'; c='_' ;; esac
                prev="$c"; rest="${rest:2}"
              fi ;;
            '$')
              if [[ "${rest:1:2}" == '((' ]]; then
                _cp_skip_arithmetic_to_reply "$rest"; out+="$REPLY"; prev='_'; rest="$REPLY_CP_REST"
              else out+='$'; prev='$'; rest="${rest:1}"; fi ;;
            "$_CP_BT")
              if ((${#ret_states[@]} > 0)) && [[ "${ret_closes[-1]}" == "$_CP_BT" ]]; then
                state="${ret_states[-1]}"; paren="${ret_parens[-1]}"; unset 'ret_states[-1]' 'ret_parens[-1]' 'ret_closes[-1]'
              fi
              out+=" $_CP_BT "; prev="$_CP_BT"; rest="${rest:1}" ;;
            '(') paren=$((paren + 1)); out+=' ( '; prev='('; rest="${rest:1}" ;;
            ')')
              if ((paren > 0)); then paren=$((paren - 1))
              elif ((${#ret_states[@]} > 0)) && [[ "${ret_closes[-1]}" == ')' ]]; then
                state="${ret_states[-1]}"; paren="${ret_parens[-1]}"; unset 'ret_states[-1]' 'ret_parens[-1]' 'ret_closes[-1]'
              fi
              out+=' ) '; prev=')'; rest="${rest:1}" ;;
            '<')
              _cp_read_heredoc_open_to_reply "$rest"
              if [[ -n "$REPLY_CP_DELIM_SET" ]]; then hd_delims+=("$REPLY_CP_DELIM"); hd_strips+=("$REPLY_CP_STRIP"); fi
              out+="$REPLY"; prev='_'; rest="$REPLY_CP_REST" ;;
          esac ;;
        sq)
          head="${rest%%$_CP_SQ_CHARS*}"
          if ((${#head} == ${#rest})); then rest=''; else rest="${rest:${#head}+1}"; state='code'; fi ;;
        dq)
          head="${rest%%$_CP_DQ_CHARS*}"
          if ((${#head} == ${#rest})); then rest=''; break; fi
          rest="${rest:${#head}}"; c="${rest:0:1}"
          case "$c" in
            '"') state='code'; rest="${rest:1}" ;;
            '\') rest="${rest:2}" ;;
            '$')
              if [[ "${rest:1:1}" == '(' ]]; then
                ret_states+=('dq'); ret_parens+=("$paren"); ret_closes+=(')'); state='code'; paren=0
                out+=' ( '; prev='('; rest="${rest:2}"
              else rest="${rest:1}"; fi ;;
            "$_CP_BT")
              ret_states+=('dq'); ret_parens+=("$paren"); ret_closes+=("$_CP_BT"); state='code'; paren=0
              out+=" $_CP_BT "; prev="$_CP_BT"; rest="${rest:1}" ;;
          esac ;;
      esac
    done
    while ((${#ret_states[@]} > 0)) && [[ "${ret_closes[-1]}" == "$_CP_BT" ]]; do
      state="${ret_states[-1]}"; paren="${ret_parens[-1]}"; unset 'ret_states[-1]' 'ret_parens[-1]' 'ret_closes[-1]'
    done
    li=$((li + 1))
    if ((line_cont)); then line_cont=0; else out+="$_CP_NL"; prev="$_CP_NL"; fi
    if ((${#hd_delims[@]} > 0)); then
      local d strip body_line
      while ((${#hd_delims[@]} > 0)); do
        d="${hd_delims[0]}"; strip="${hd_strips[0]}"
        hd_delims=("${hd_delims[@]:1}"); hd_strips=("${hd_strips[@]:1}")
        while ((li < nlines)); do
          body_line="${lines[li]}"; body_line="${body_line%$'\r'}"
          [[ "$strip" == '1' ]] && body_line="${body_line#"${body_line%%[!$'\t']*}"}"
          li=$((li + 1))
          [[ "$body_line" == "$d" ]] && break
        done
      done
      out+="_$_CP_NL"; prev="$_CP_NL"
    fi
  done
  REPLY="$out"
}

# `$((` から対応する `))` までを読み飛ばす（中の `<<` は左シフト）
_cp_skip_arithmetic_to_reply() {
  local r="$1" i=1 depth=0 ch n=${#1}
  while ((i < n)); do
    ch="${r:i:1}"
    case "$ch" in
      '(') depth=$((depth + 1)) ;;
      ')') depth=$((depth - 1)); if ((depth == 0)); then REPLY='_'; REPLY_CP_REST="${r:i+1}"; return 0; fi ;;
    esac
    i=$((i + 1))
  done
  REPLY='$'; REPLY_CP_REST="${r:1}"; return 0
}

# `<` から始まる並びを読み、ヒアドキュメントの開始なら区切り語を返す
_cp_read_heredoc_open_to_reply() {
  local r="$1"
  REPLY_CP_DELIM_SET=''; REPLY_CP_DELIM=''; REPLY_CP_STRIP='0'
  if [[ "${r:0:3}" == '<<<' ]]; then REPLY='<<<'; REPLY_CP_REST="${r:3}"; return 0; fi
  if [[ "${r:0:2}" != '<<' ]]; then REPLY='<'; REPLY_CP_REST="${r:1}"; return 0; fi
  r="${r:2}"
  if [[ "${r:0:1}" == '-' ]]; then REPLY_CP_STRIP='1'; r="${r:1}"; fi
  while [[ "${r:0:1}" == ' ' || "${r:0:1}" == $'\t' ]]; do r="${r:1}"; done
  local delim='' ch part
  while [[ -n $r ]]; do
    ch="${r:0:1}"
    case "$ch" in
      ' ' | $'\t' | $'\r' | ';' | '&' | '|' | '<' | '>' | '(' | ')') break ;;
      "'") r="${r:1}"; part="${r%%$_CP_SQ_CHARS*}"; delim+="$part"; r="${r:${#part}}"; r="${r#\'}" ;;
      '"') r="${r:1}"; part="${r%%\"*}"; delim+="$part"; r="${r:${#part}}"; r="${r#\"}" ;;
      '\') delim+="${r:1:1}"; r="${r:2}" ;;
      *) delim+="$ch"; r="${r:1}" ;;
    esac
  done
  if [[ -z "$delim" || "$delim" =~ ^[0-9]+$ ]]; then REPLY='_'; REPLY_CP_REST="$r"; return 0; fi
  REPLY_CP_DELIM_SET='1'; REPLY_CP_DELIM="$delim"; REPLY='_'; REPLY_CP_REST="$r"
}

# ---- PowerShell の前処理（§7-6）----
# ヒアストリング @'…'@ / @"…"@ を潰し、バッククォートの行継続を結合し、残るバッククォート（エスケープ）を除き、
# バックスラッシュ区切りのパスを / にし、呼び出し演算子 `&` を落とす。分割・トークン化は bash と同じ規則で行う
_cp_ps_preprocess_to_reply() {
  local s="$1" pre rest q
  for q in "'" '"'; do
    while [[ "$s" == *"@$q"* ]]; do
      pre="${s%%@"$q"*}"; rest="${s#*@"$q"}"
      if [[ "$rest" == *"$q@"* ]]; then rest="${rest#*"$q"@}"; s="$pre _ $rest"; else break; fi
    done
  done
  s="${s//$_CP_BT$'\r'$_CP_NL/ }"; s="${s//$_CP_BT$_CP_NL/ }"
  s="${s//$_CP_BT/}"
  s="${s//\\//}"
  # 呼び出し演算子: 行頭・区切りの直後の `& ` を落とす（`2>&1` は `>&` で保護済みのため無関係）
  s=" $s"
  while [[ "$s" =~ ([[:space:]\;\|\(\{]|^)\&[[:space:]]*([\'\"./A-Za-z_]) ]]; do
    s="${s/"${BASH_REMATCH[0]}"/"${BASH_REMATCH[1]} ${BASH_REMATCH[2]}"}"
  done
  REPLY="${s:1}"
}

# ---- 補助 ----
_cp_basename_to_reply() { # パス → basename（.exe を除く。小文字）
  local t="${1,,}"
  t="${t##*/}"; t="${t%.exe}"
  REPLY="$t"
}

cmdpos_args() { # $1=セグメント番号 → REPLY_ARGS 配列
  local s="${CP_ARGS[$1]:-}"
  REPLY_ARGS=()
  [[ -n "$s" ]] || return 0
  while [[ "$s" == *"$_CP_US"* ]]; do REPLY_ARGS+=("${s%%"$_CP_US"*}"); s="${s#*"$_CP_US"}"; done
  REPLY_ARGS+=("$s")
}

_cp_join_us_to_reply() { # 配列要素を US で結合
  local out="" a
  for a in "$@"; do out+="${out:+$_CP_US}$a"; done
  REPLY="$out"
}

# 1 セグメント分のトークン列（配列 _CP_SEG）を解析して CP_* に 1 行積む
_cp_emit_segment() {
  local -a toks=("$@")
  local n=${#toks[@]} i=0 t tl base exe="" j
  local -a args=() redirects=() writes=()
  local opaque=0 provided="" gitlike=0 subcmd="" sticky=1 in_prefix=0 prefix_base="" leading_value=0
  # 1. リダイレクト・代入・ラッパーを処理しながら実行体を探す
  while ((i < n)); do
    t="${toks[i]}"
    # リダイレクト（コマンドの前でも後でも同じ扱い）
    if [[ "$t" =~ ^[0-9]*(\>\>|\>|\<\>|\<\<\<|\<|${_CP_AMPRED}\>)(.*)$ ]]; then
      local op="${BASH_REMATCH[1]}" rest="${BASH_REMATCH[2]}"
      if [[ "$rest" == "$_CP_DUP"* ]]; then i=$((i + 1)); continue; fi   # 2>&1 など fd 複製
      if [[ -z "$rest" ]]; then i=$((i + 1)); rest="${toks[i]:-}"; fi
      case "$op" in '>'|'>>'|'<>'|"${_CP_AMPRED}>") [[ "$rest" != /dev/null ]] && redirects+=("$rest") ;; esac
      i=$((i + 1)); continue
    fi
    if [[ -z "$exe" ]]; then
      if [[ "$t" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then i=$((i + 1)); continue; fi   # 変数代入
      _cp_basename_to_reply "$t"; base="$REPLY"
      if ((in_prefix)); then
        # ラッパーのオプション（値を取るものは 2 つ）と先頭の値（timeout DURATION）を読み飛ばす
        if [[ "$t" == -* ]]; then
          if [[ "$_CP_PREFIX_OPTS_WITH_VALUE" == *" ${t,,} "* ]]; then i=$((i + 2)); else i=$((i + 1)); fi
          continue
        fi
        if ((leading_value)); then leading_value=0; i=$((i + 1)); continue; fi
      fi
      if [[ "$_CP_PREFIX_WORDS" == *" $base "* ]]; then
        in_prefix=1; prefix_base="$base"
        [[ "$_CP_PREFIX_WORDS_WITH_LEADING_VALUE" == *" $base "* ]] && leading_value=1
        i=$((i + 1)); continue
      fi
      exe="$base"
      i=$((i + 1)); continue
    fi
    args+=("$t")
    i=$((i + 1))
  done
  [[ -n "$exe" ]] || { ((${#redirects[@]} > 0)) && exe="_redirect_" || return 0; }
  # 2. 実行体ごとの解釈
  case "$exe" in
    git)
      j=0
      while ((j < ${#args[@]})); do
        tl="${args[j],,}"
        if [[ "$_CP_GIT_OPTS_WITH_VALUE" == *" $tl "* ]]; then j=$((j + 2))
        elif [[ "$tl" == -* ]]; then j=$((j + 1))
        else subcmd="$tl"; break; fi
      done ;;
    *)
      for t in "${args[@]}"; do [[ "$t" == -* ]] && continue; subcmd="${t,,}"; break; done ;;
  esac
  if [[ "$_CP_OPAQUE_WORDS" == *" $exe "* ]]; then opaque=1
  elif [[ "$exe" == find ]]; then
    for t in "${args[@]}"; do [[ "$_CP_FIND_EXEC_OPTS" == *" ${t,,} "* ]] && { opaque=1; break; }; done
  elif [[ "$_CP_OPAQUE_WITH_OPT" == *" $exe "* ]]; then
    for t in "${args[@]}"; do [[ "$_CP_CODE_OPTS" == *" ${t,,} "* ]] && { opaque=1; break; }; done
  fi
  # 提供コマンド（§7-8）: bash / sh の第 1 引数がルート相対表記で .claude/skills/*/scripts/*.sh か .claude/hooks/**/*.sh
  if [[ "$exe" == bash || "$exe" == sh ]] && ((opaque == 0)) && ((${#args[@]} > 0)); then
    t="${args[0]}"
    if [[ "$t" =~ ^\.claude/skills/[^/]+/scripts/[^/]+\.sh$ || "$t" =~ ^\.claude/hooks/([^/]+/)*[^/]+\.sh$ ]]; then provided="$t"; fi
  fi
  # 書き込み先（§7）
  if [[ "$_CP_WRITE_CMDS" == *" $exe "* ]]; then
    local -a nonopt=()
    local skip=0 has_i=0 has_e=0 vopts
    # 値を別トークンで取るオプション（コマンドごと）
    case "$exe" in
      truncate) vopts=' -s -r --size --reference ' ;;
      mkdir) vopts=' -m --mode ' ;;
      cp|mv|ln) vopts=' -t --target-directory -S --suffix ' ;;
      install) vopts=' -t -m -o -g -S --target-directory --mode --owner --group --suffix ' ;;
      sed) vopts=' -e -f --expression --file -l --line-length ' ;;
      *) vopts=' ' ;;
    esac
    for t in "${args[@]}"; do
      if ((skip)); then skip=0; continue; fi
      if [[ "$t" == -* && "$t" != - ]]; then
        [[ "$exe" == sed && "$t" == -i* ]] && has_i=1
        [[ "$exe" == sed && ( "$t" == -e* || "$t" == -f* || "$t" == --expression* || "$t" == --file* ) ]] && has_e=1
        [[ "$vopts" == *" $t "* ]] && skip=1
        continue
      fi
      nonopt+=("$t")
    done
    case "$exe" in
      cp|mv|install|ln) ((${#nonopt[@]} >= 2)) && writes+=("${nonopt[-1]}") ;;
      sed) if ((has_i)); then if ((has_e)); then writes+=("${nonopt[@]}"); else writes+=("${nonopt[@]:1}"); fi; fi ;;
      *) writes+=("${nonopt[@]}") ;;
    esac
  fi
  if [[ "$exe" == "_" && "$CP_LOWER" == *git* ]]; then gitlike=1; fi
  [[ "$exe" == "_redirect_" ]] && exe=""
  _cp_join_us_to_reply "${args[@]}"; CP_ARGS+=("$REPLY")
  _cp_join_us_to_reply "${redirects[@]}"; CP_REDIRECTS+=("$REPLY")
  _cp_join_us_to_reply "${writes[@]}"; CP_WRITE_TARGETS+=("$REPLY")
  CP_EXE+=("$exe"); CP_SUBCMD+=("$subcmd"); CP_OPAQUE+=("$opaque"); CP_PROVIDED+=("$provided"); CP_GITLIKE+=("$gitlike")
  CP_COUNT=$((CP_COUNT + 1))
  return 0
}

# ---- 公開 API ----
# cmdpos_parse <コマンド文字列> [bash|powershell]
cmdpos_parse() {
  local s="${1:-}" shell="${2:-bash}" norm m
  CP_DEGRADED=0; CP_COUNT=0; CP_LOWER="${s,,}"
  CP_EXE=(); CP_ARGS=(); CP_SUBCMD=(); CP_REDIRECTS=(); CP_WRITE_TARGETS=(); CP_OPAQUE=(); CP_PROVIDED=(); CP_GITLIKE=()
  [[ -n "$s" ]] || return 0
  # 縮退（§7-7）: bash 4.3 未満、または 4096 文字超
  if (( BASH_VERSINFO[0] < 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] < 3) )) || (( ${#s} > _CP_MAX_LEN )); then
    CP_DEGRADED=1; return 0
  fi
  if [[ "$shell" == powershell || "$shell" == PowerShell ]]; then _cp_ps_preprocess_to_reply "$s"; s="$REPLY"; fi
  # fd 複製と &> を保護してから正規化・分割する
  s="${s//>&/>$_CP_DUP}"; s="${s//<&/<$_CP_DUP}"; s="${s//&>/$_CP_AMPRED>}"
  _cp_normalize_to_reply "$s"; norm="$REPLY"
  for m in ';' '&' '|' '(' ')' "$_CP_BT"; do norm="${norm//"$m"/ $m }"; done
  norm="${norm//"$_CP_NL"/ ; }"
  local -a tokens=() seg=()
  local IFS=$' \t\r\n'
  read -ra tokens <<<"$norm" || true
  local t
  for t in "${tokens[@]}"; do
    case "$t" in
      ';' | '&' | '|' | '(' | ')' | '{' | '}' | "$_CP_BT")
        ((${#seg[@]} > 0)) && _cp_emit_segment "${seg[@]}"
        seg=() ;;
      *) seg+=("$t") ;;
    esac
  done
  ((${#seg[@]} > 0)) && _cp_emit_segment "${seg[@]}"
  return 0
}

# 実行位置に git <サブコマンド> があるか（縮退時は部分一致）。$1=サブコマンド
cmdpos_has_git_subcommand() {
  local sub="${1,,}" i
  if ((CP_DEGRADED)); then [[ "$CP_LOWER" =~ git[[:space:]]+$sub ]] && return 0; return 1; fi
  for ((i = 0; i < CP_COUNT; i++)); do
    [[ "${CP_EXE[i]}" == git && "${CP_SUBCMD[i]}" == "$sub" ]] && return 0
  done
  return 1
}

# 提供コマンド <ルート相対パス> が実行位置にあるか
cmdpos_has_provided() {
  local p="$1" i
  for ((i = 0; i < CP_COUNT; i++)); do [[ "${CP_PROVIDED[i]}" == "$p" ]] && return 0; done
  return 1
}
