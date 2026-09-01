#!/usr/bin/env bash
# test-lib.sh — テスト共通ヘルパ（source 専用）
# 仕様: .claude/docs/10_spec/skills/20-common-step-shell-script.md「OUT ひな形」test-lib.sh
# 提供: run_cmd / assert_eq / assert_exit / assert_contains / assert_not_contains / make_tmp_repo /
#       make_restricted_path / hook_payload / tl_jq / pass / fail / finish
# 出力: 1 ケース 1 行 `PASS <ID>` / `FAIL <ID>: <理由>`、最後に `passed=N failures=N`
# Windows（Git Bash）対策はここに集約する: PATH を絞るときは symlink ではなくラッパースクリプト、jq 出力の CR 除去、
# 性能閾値は TEST_SKIP_PERF=1 で無効化

# 直接実行されたら何もしない
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then exit 0; fi

TL_PASS=0
TL_FAIL=0
R_EXIT=0
R_OUT=""
R_ERR=""
_TL_TMPS=()
_TL_ERRF="$(mktemp)"

_tl_cleanup() {
  local d
  for d in "${_TL_TMPS[@]:-}"; do
    [[ -n "$d" && -d "$d" ]] && rm -rf "$d"
  done
  [[ -f "$_TL_ERRF" ]] && rm -f "$_TL_ERRF"
  return 0
}
trap _tl_cleanup EXIT

pass() { # $1=ID
  printf 'PASS %s\n' "$1"
  TL_PASS=$((TL_PASS + 1))
}

fail() { # $1=ID $2=理由（1 行に畳む）
  local reason="${2:-}"
  reason="${reason//$'\n'/\\n}"
  printf 'FAIL %s: %s\n' "$1" "$reason"
  TL_FAIL=$((TL_FAIL + 1))
}

# コマンドを実行し R_EXIT / R_OUT / R_ERR に格納する（set -e の影響を受けない）
run_cmd() {
  R_OUT="$("$@" 2>"$_TL_ERRF")"
  R_EXIT=$?
  R_ERR="$(cat "$_TL_ERRF" 2>/dev/null || true)"
  return 0
}

assert_eq() { # $1=ID $2=expected $3=actual
  if [[ "$2" == "$3" ]]; then pass "$1"; else fail "$1" "expected '$2' actual '$3'"; fi
}

assert_exit() { # $1=ID $2=期待する終了コード（直前の run_cmd）
  if [[ "$R_EXIT" -eq "$2" ]]; then pass "$1"; else fail "$1" "exit $R_EXIT (expected $2) : ${R_ERR}${R_OUT}"; fi
}

assert_contains() { # $1=ID $2=含まれるべき文字列（直前の run_cmd の stdout+stderr）
  if [[ "${R_OUT}${R_ERR}" == *"$2"* ]]; then pass "$1"; else fail "$1" "出力に '$2' が無い : ${R_OUT}${R_ERR}"; fi
}

assert_not_contains() { # $1=ID $2=含まれてはいけない文字列
  if [[ "${R_OUT}${R_ERR}" != *"$2"* ]]; then pass "$1"; else fail "$1" "出力に '$2' が含まれる : ${R_OUT}${R_ERR}"; fi
}

# 一時 git リポジトリを作り TMP_REPO に置く（パスに非 ASCII を含めない。後始末は trap）
make_tmp_repo() {
  TMP_REPO="$(mktemp -d)"
  _TL_TMPS+=("$TMP_REPO")
  git -C "$TMP_REPO" init -q -b main
  git -C "$TMP_REPO" config user.name "test"
  git -C "$TMP_REPO" config user.email "test@example.com"
  git -C "$TMP_REPO" config commit.gpgsign false
  git -C "$TMP_REPO" config core.autocrlf false
  return 0
}

# 一時ディレクトリ（git なし）を作り TMP_DIR に置く
make_tmp_dir() {
  TMP_DIR="$(mktemp -d)"
  _TL_TMPS+=("$TMP_DIR")
  return 0
}

# 引数のコマンドだけを含む PATH 用ディレクトリを作り RESTRICTED_PATH に置く。
# symlink ではなくラッパースクリプトを生成する（MSYS の bash.exe は同ディレクトリの dll を要求するため）
make_restricted_path() { # $@=残すコマンド名
  local dir name real
  dir="$(mktemp -d)"
  _TL_TMPS+=("$dir")
  for name in "$@"; do
    real="$(command -v "$name" 2>/dev/null || true)"
    [[ -z "$real" ]] && continue
    printf '#!/bin/bash\nexec "%s" "$@"\n' "$real" > "$dir/$name"
    chmod +x "$dir/$name" 2>/dev/null || true
  done
  RESTRICTED_PATH="$dir"
  return 0
}

# jq の出力から CR を除く（Windows ネイティブ jq は CRLF を出す）
tl_jq() {
  jq "$@" | tr -d '\r'
}

# フック入力 JSON を組む: hook_payload <event> <tool_name> [key=value ...]（key=value は tool_input の文字列フィールド）
hook_payload() {
  local event="$1" tool="$2" kv key val args=()
  shift 2
  local filter='{hook_event_name: $ev, tool_name: $tn, session_id: "testsession", cwd: $cwd, tool_input: {}}'
  for kv in "$@"; do
    key="${kv%%=*}"
    val="${kv#*=}"
    args+=(--arg "ti_$key" "$val")
    filter+=" | .tool_input[\"$key\"] = \$ti_$key"
  done
  MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL="*" jq -nc --arg ev "$event" --arg tn "$tool" --arg cwd "$PWD" "${args[@]}" "$filter" | tr -d '\r'
}

# 集計行を出し、失敗があれば非 0 で終了する
finish() {
  printf 'passed=%d failures=%d\n' "$TL_PASS" "$TL_FAIL"
  if [[ "$TL_FAIL" -gt 0 ]]; then exit 1; fi
  exit 0
}
