---
type: ddr
title: i0009-67. review-state と merge-state は hook_read_state へ移す
description: logs は作業ツリーの下にあり作業ツリーは stdin の cwd を読んで初めて決まるため、§1 の表で jq の 1 回目に置いていた 2 つの副入力を 2 回目へ移すと定めた判断
tags: [ddr, hooks, 副入力, 仕様の書き戻し]
keywords: [review-state, merge-state, hook_read_state, hook_read_input, HOOK_SESSION_ID, jq 2 回, HC_STATE, i0009-46]
---

# i0009-67. `review-state` と `merge-state` は `hook_read_state` へ移す

## 背景

共通仕様 §1 の表は、フックが読む副入力をどの jq で読むかを定めている。ホットパスの jq は最大 2 回（`i0009-46`。stdin 側 1 回と、セッション依存の 1 回）。表は `review-state` / `merge-state` を **1 回目**（stdin と同じ jq）で読む形になっていた。

0027 で `hook_read_input` / `hook_read_state` を実装したところ、この 2 つは 1 回目では読めないと分かった。**`review-state.json` / `merge-state.json` は `logs/` 直下にあり、`logs/` は作業ツリーの下にある**（§5）。そして作業ツリーは **stdin の `cwd` を読んで初めて決まる**（§2）。1 回目の jq は stdin を読むための呼び出しなので、それを組み立てる時点では `--rawfile` に渡すファイルのパスが確定していない。

同じ経路にまとめる `approvals` / `entry` は、さらに `session_id` にも依存する（`logs/sessions/<session_id>/…`）。依存の深さは違うが、**どちらも stdin を読み終えるまでパスが決まらない**点で共通する。

## 決定

- `review-state` / `merge-state` は **2 回目（`hook_read_state`）で読む**。§1 の表をそう書き直す
- 2 回目のグループは「**stdin を読み終えて作業ツリー（と必要ならセッション）が決まってから読むもの**」で統一する（`approvals` / `entry` と同じ経路）
- jq の回数は変えない（最大 2 回のまま。`i0009-46` は維持）
- `hook_read_state` は要求しなかった副入力も `null` で渡し、4 変数すべてを定義する（呼び手が未定義参照を踏まない）

## 理由

- **パスが stdin の内容に依存するものは、stdin を読んだ後でしか読めない**。`logs/` は作業ツリー側にあり、作業ツリーは `cwd` から決まる。実装の都合ではなく順序の必然で、仕様の側が現実的でなかった
- **副入力の状態管理が 1 か所で済む**。`HC_<名前>_STATE`（`ok` / `missing` / `broken`）の立て方が 1 回目と 2 回目で分かれていると、呼び手が「どちらの規約か」を副入力ごとに覚えることになる。`i0009-47` の受け方（`--rawfile` + `fromjson? // null`）を 1 か所に集められる
- **回数は増えない**。2 回目はもともと `approvals` / `entry` のために走るので、そこに 2 つ足すだけ。ホットパスの上限に影響しない

## 却下した案

- **`review-state` / `merge-state` をセッションに依存しない場所へ移す**: セッション単位の状態をセッション横断の場所に置くことになり、並行するセッションが互いの状態を踏む
- **1 回目を「`HOOK_SESSION_ID` の取得だけ」の軽い jq に分け、全体で 3 回にする**: `i0009-46` の上限を破る。ホットパス 5 本ぶんの fork が毎ツール呼び出しで増える
- **各フックが必要なときだけ自分で読む**: フックごとに jq が増え、回数の上限が守られているかを機械で数えられなくなる（HK-T19 が数えている）
- **セッション ID を環境変数などから先に得る**: フックの入力 JSON が唯一の供給元で、外から先に知る手段が無い

## 影響

- `10_spec/フック共通仕様.md` §1（副入力の表。`review-state` / `merge-state` を 2 回目へ。`hook_read_state` が要求しない副入力も `null` で渡すことを併記）
- 実装は 0027 の `hook_read_state` が該当。HK-T19 が「副入力ありで jq 1 回・`hook_read_state` を足して 2 回」を固定している
- 関連: `i0009-46`（ホットパスの jq は最大 2 回）・`i0009-47`（副入力は `--rawfile` と `fromjson` で読み、破損で判定ごと落とさない）・`i0009-48`（`scope.sh` の読み込み関数は JSON のファイルを開かない）
