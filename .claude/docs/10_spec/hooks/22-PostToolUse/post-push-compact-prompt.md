---
type: spec
title: post-push-compact-prompt フック 仕様
description: push の成功を検知し、レビュー依頼に載せる参照リンク（MR・default との差分・前回 push からの差分とコメント一覧・変更ファイルのリンク候補）を origin と logs/ とローカル git から組み立てて AI に渡し、切れ目の処理後に /compact を促すよう伝えるフックの内部仕様。push 検知の規則（正）、logs/push-state.json、リンク形式、WF90x を定める
tags: [spec, hook, post-push-compact-prompt]
keywords: [PostToolUse, push 検知, push.sh, 参照リンク, MR リンク, compare, 前回 push, push-state.json, 変更ファイル, リンク候補, compact, GitLab, GitHub, WF901, WF902, WF903]
---

# post-push-compact-prompt フック 仕様

## 概要・禁止事項

対応する要件は [00_requirement/hooks/22-PostToolUse/post-push-compact-prompt.md](../../../00_requirement/hooks/22-PostToolUse/post-push-compact-prompt.md)。共通事項は [フック共通仕様](../../フック共通仕様.md)。**push 検知の規則の正はこのフック**で、`post-push-usage-report` が共有する（`lib/push-detect.sh`）。

禁止事項:

- リモートへの問い合わせ（リンクは origin の URL と記録から組み立てる）
- URL 文字列の推測での書き換え（ホストごとの既知の形式だけ）
- 載せるリンクの選択（候補の供給まで。選ぶのは AI）
- `/compact` の代行、`AskUserQuestion` での確認

## 呼出条件（イベント・matcher・登録）

- PostToolUse、matcher `Bash|PowerShell`（usage-report の前）
- 前置判定で push でなければ即抜ける

## 入出力

- 入力: `tool_input.command`。参照: `git remote get-url origin`、`git rev-parse HEAD` / `@{upstream}`、`git diff --name-only <前回>..HEAD`、`logs/mr.json`、`logs/push-state.json`
- 出力: additionalContext（WF901）と `logs/push-state.json` の更新

## 制御方式

### push 検知（`lib/push-detect.sh`。正）

`push_detect <起点 sha>` は**状態ファイルを読まず書かない**。「前回どこまで push したか」は**呼び手が自分の状態から渡す**（このフックは `push-state.json[b].sha`、`post-push-usage-report` は `usage/<branch>.json` の `last_push_sha`）。共有ライブラリが特定の状態ファイルを持つと、先に走ったフックの状態更新が後のフックの検知を偽にしてしまう（フックは並列に走るのでレースにもなる。DDR i0009-24）。

1. コマンド列（`cmdpos.sh`）に提供コマンド `push.sh` があるか、または実行位置に `git push`（緊急停止時の直接実行）がある
2. かつ成功: **PostToolUse に届いた時点で成功とみなす**（公式は「`PostToolUse` hooks fire after a tool has already executed successfully.」と明記し、失敗は別イベント `PostToolUseFailure` に流れる。`tool_response` に終了コードのフィールドは存在しない — `Bash` が返すのは `stdout` / `stderr` / `interrupted` / `isImage`。DDR i0009-07）、かつ HEAD がリモートに反映された — `git rev-parse HEAD` と `git rev-parse @{upstream}` が一致。`@{upstream}` が解決できないとき（初回 push で上流が未設定など）は `origin/<b>` と比較し、それも無ければ PostToolUse に届いたこと自体をもって反映されたとみなす（縮退）、かつ**呼び手が渡した起点 sha が HEAD と異なる**（前回 push 時点から進んでいる。起点が空なら初回として真。push するものが無かった成功は検知しない）
3. 満たさなければ何もしない（前回 push 時点も更新しない）

### 本体

1. 停止中 → `disabled` を記録して抜ける
2. push 検知を通過 → ブランチ `b`、今回 `head`、前回 `prev`（`push-state.json[b].sha`。無ければ初回）、`count` を得る
3. ホスト判定: origin の URL から `github` / `gitlab`（それ以外は WF903 相当でリンクを省く）。URL をブラウザ形式（`git@host:owner/repo.git` → `https://host/owner/repo`）に正規化する
4. リンクの組み立て:

| 項目 | GitHub | GitLab |
|---|---|---|
| MR | `<repo>/pull/<M>` | `<repo>/-/merge_requests/<M>` |
| default との差分 | `<repo>/compare/<default>...<b>` | `<repo>/-/compare/<default>...<b>` |
| 前回 push からの差分 | `<repo>/compare/<prev>...<head>` | `<repo>/-/compare/<prev>...<head>` |
| MR のコメント一覧 | `<repo>/pull/<M>#issuecomment-` 以下（本文末尾へのリンク: `<repo>/pull/<M>` にアンカー無し）| `<repo>/-/merge_requests/<M>#notes` |
| 変更ファイル本体 | `<repo>/blob/<head>/<path>` | `<repo>/-/blob/<head>/<path>` |
| 差分ページ内の位置 | `<repo>/pull/<M>/files#diff-<sha256(path)>` | `<repo>/-/merge_requests/<M>/diffs#<sha1(path)>` |

   - default ブランチ名は `git symbolic-ref refs/remotes/origin/HEAD` から（無ければ `main`）
   - 変更ファイルは `git diff --name-only <prev>..<head>`（初回は `origin/<default>..<head>`）。上限 15 件。超過分は件数だけ
   - MR 未記録（`logs/mr.json` 無し）→ MR に依存するリンクを省き **WF903** の注記
   - 初回（`prev` 無し）→ 前回 push からの差分とコメント一覧を省き **WF902** の注記
5. `push-state.json[b]` を `{sha: head, at, count+1}` に更新する（**このフック専用の状態**。`post-push-usage-report` はこれを読まない — DDR i0009-24）。書き換えは §5 の規則に従い一時ファイル + `mv` で行う（`logs/` はコミット対象外・片付け対象外なので、片付け後の最終 push でも前回が残る）
6. additionalContext（WF901）: リンク一覧（日本語の見出し + URL）に続けて「レビュー依頼メッセージ（`boundary.sh request` の本文）にこれらを含めること」「タスクの切れ目の処理（MR 本文更新・レビュー依頼）を終えたら、ユーザーに `/compact` の実行を促すこと。`AskUserQuestion` で待たない」
7. origin・差分・記録の取得に失敗 → 取得できた分だけ伝える（何も取れなければ無出力）

## エラー識別子とメッセージ

| ID | 種別 | 内容 |
|----|------|------|
| WF901 | 情報 | 参照リンクの供給と `/compact` の促し |
| WF902 | 情報 | 前回 push の記録なし（初回扱い） |
| WF903 | 情報 | MR 未記録（MR 依存のリンクを省略） |

## 回復手順

- WF903: `boundary.sh status`（CLI あり）で `logs/mr.json` を再導出してから次の push
- 何も出ない: `logs/sh/hook-post-push-compact-prompt.log` を確認。push 自体は成功している

## 記録（logs/）

- `logs/push-state.json`（共通仕様 §5）
- `decisions.jsonl`: `inject`（`note` に push 時点・リンク件数・省略の有無）
- 実行ログ: `logs/sh/hook-post-push-compact-prompt.log`

## テスト観点

| テスト ID | 種別 | 固定する振る舞い |
|-----------|------|----------------|
| PP-T01 | 正常系 | `push.sh` 成功（HEAD == upstream）で WF901 が出て `push-state.json` が更新される |
| PP-T02 | 正常系 | push 失敗・`git status` などでは何も出ず記録も変わらない。`grep "git push"` でも働かない |
| PP-T03 | 正常系 | 直接 `git push` が成功したときも働く |
| PP-T04 | 正常系 | GitHub / GitLab の origin（https / ssh）でリンク形式が表どおり |
| PP-T05 | 境界 | 初回で WF902、MR 未記録で WF903、変更 20 件で 15 件 + 「他 5 件」 |
| PP-T06 | 正常系 | ブランチごとに `push-state.json` が独立 |
| PP-T07 | 異常系 | origin 取得失敗で変更ファイル一覧だけ伝える。全滅で無出力 |
| PP-T08 | 境界 | 機械テスト。上流未設定の初回 push（`@{upstream}` 不在）でも `origin/<b>`、それも無ければ PostToolUse に届いたこと自体で検知され、`push-state.json` が作られる |

## 要件との対応

| 要件（受け入れ基準） | 実現箇所 |
|--------------------|---------|
| メイン: push 成功の検知 | push 検知 |
| メイン: 失敗・他コマンドは何もしない | push 検知 3 |
| メイン: コマンド位置で検知（共有） | push 検知 1（cmdpos） |
| メイン: 直接 push でも働く | push 検知 1、PP-T03 |
| メイン: 伝える項目（MR・default 差分・ファイルごと・前回差分・コメント一覧） | 本体 4 |
| メイン: 情報源（origin / 進行状態 / git / 自身の記録） | 入出力 |
| メイン: ホスト別の既知形式 | 本体 4 の表 |
| メイン: 件数上限と AI の選択 | 本体 4（15 件）、禁止事項 |
| メイン: AI はレビュー依頼に含める | 本体 6 |
| メイン: MR 未記録は依存リンクを省く | WF903 |
| メイン: `/compact` の促し・AskUserQuestion 禁止 | 本体 6 |
| メイン: compact 後は session-start が再注入 | （session-start 仕様） |
| メイン: 今回 push 時点の記録・ブランチ独立・logs/ | 本体 5、PP-T06 |
| メイン: 記録・日本語・具体的 URL | 記録、本体 6 |
| 代替: 単独実行モード | WF903 と同じ扱い |
| 代替: 緊急停止 | 本体 1 |
| 例外: 取得失敗は取れた分だけ | 本体 7 |
| 例外: 前回記録なしは初回扱い | WF902 |
