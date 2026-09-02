---
type: plan
title: チケットボード拡張の調査計画
description: issue #13 の設計に必要な 3 つの問い（チケット Markdown の実形と壊れ方 / ビルド・テスト環境の成立性 / 既存機構との境界と置き場）と、その調べ方・成果物の形
tags: [plan, investigation-plan]
---

# チケットボード拡張の調査計画

## 対象

- 対象 issue: #13 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/13
- PR: #14 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/pull/14
- ブランチ: `claude/vscode-ticket-visualization-ci8etr`
- チケット: 0002-investigation-plan

## この計画で何をするか

設計に入る前に、答えが出ていないと設計を書けない 3 つの問いだけを潰す。答えが後続の計画に効かない問いは含めない。

決めたこと。

- 調査は 3 観点・3 チケット。1 観点 = 1 チケット
- 0004 だけは実際にコマンドを動かして確かめる（`allow.ops` に `build-test` と `web`）。0003 と 0005 はリポジトリ内の読み取りに限る
- どのチケットもソースコード・設計文書・`.claude/` 配下には書き込まない。直したい箇所が見つかったら結果レポートに書いて後続フェーズへ回す

## 調査観点

| # | 問い | どの判断点・受け入れ条件に効くか |
|---|---|---|
| Q1 | チケットの frontmatter と本文はどのキー・値域・見出し構造を取り、カードに出す 6 項目（番号・タイトル・ticket_type・executor・人間レビュー要否・敵対的レビュー要否）はどこから取れるか | 受け入れ条件 2。パーサが読むキーと表示項目の対応が決まる |
| Q2 | 現実に起こりうる frontmatter / 本文の壊れ方は何か | 受け入れ条件 7。落ちない条件と「不備が分かる表示」の中身が決まる |
| Q3 | この実行環境で npm から拡張の開発依存（typescript / @types/vscode / テストランナー）を取得できるか | 受け入れ条件 9・10。全体計画の保留事項「テストランナーの選択」 |
| Q4 | 取得できない場合、依存ゼロで受け入れ条件 9・10 を満たせるか | 同上。Q3 が否のときの退避路 |
| Q5 | 拡張のソースと設計文書の置き場として、機構の上限設定 `scope-limits.json` と設計文書ルールが想定するパスはどこか | 全体計画の保留事項「設計文書の置き場」。設計・実装フェーズの許可範囲 |
| Q6 | ソース追加が push.sh の push 前チェック 4 項目・`.gitignore` に触れないか | 実装フェーズで push が止まらないこと |

issue #13 の詳細欄は置き場を `tools/vscode-ticket-board/` と書いているが、`scope-limits.json` の `implementation` は `src/**` と `tests/**` を許可し `design` は `docs/**` を許可する。この食い違いを Q5 で確定する。

## 対象と方法

| 問い | 読む場所・確かめ方 | 書き込み |
|---|---|---|
| Q1 | `.claude/skills/20-common-step-ticket/assets/ticket.template.md`、`scripts/ticket.sh` の frontmatter 書き込み箇所、`.claude/skills/20-common-step-shell-script/scripts/frontmatter.sh` の読み取り実装、`.claude/hooks/config/task-types.tsv`、実在するチケット 6 枚 | なし |
| Q2 | `ticket.sh` の `yaml_escape` と `set_field`、`frontmatter.sh` が受け付ける形、テンプレートのプレースホルダ検査。手で壊した例を `wip/tmp/` に置いて読み取りの挙動を見る | `wip/tmp/` のみ |
| Q3 | `node --version` / `npm --version`、`npm view typescript version` などレジストリへの到達確認、`wip/tmp/` に捨てるプロジェクトを作って `npm install --no-save` を実際に走らせる | `wip/tmp/` のみ |
| Q4 | Node 標準の `node:test` と `node --experimental-strip-types` の可否を実際に動かして確認。VS Code API を使う部分を分離してテストできるかを構造の観点で検討 | `wip/tmp/` のみ |
| Q5 | `.claude/hooks/config/scope-limits.json` の `types`、`.claude/rules/design-docs.md`、`.claude/docs/00_requirement/` と `10_spec/` のディレクトリ規約、`20-common-step-requirement` / `20-common-step-spec` の仕様 | なし |
| Q6 | `.claude/skills/20-common-step-commit-push/scripts/push.sh` の検査 4 項目、`assets/exclude-patterns.txt`、`.gitignore` | なし |

Q3 と Q4 は外部（npm レジストリ）への到達を伴い、コマンドも実行する。担当チケット 0004 の `allow.ops` に `build-test` と `web` を含めた。他の 2 枚は `read` のみ。

## 調査チケット

| 番号 | 種類 | 担う問い | 先行 |
|---|---|---|---|
| 0003 | investigation | Q1・Q2 | 0002 |
| 0004 | investigation | Q3・Q4 | 0002 |
| 0005 | investigation | Q5・Q6 | 0002 |
| 0006 | design-plan | 次の計画 | 0003, 0004, 0005 |

## 成果物の形

調査結果レポート `wip/30_reports/0003-investigation.md` / `0004-investigation.md` / `0005-investigation.md` と同名の HTML。設計計画が判断できるよう、各レポートに次を入れる。

- 問いごとの答えと、その根拠（ファイルと行、またはコマンドと出力）
- 答えが設計のどの判断に効くか（例: 「Q3 が否なので依存ゼロ構成を採る」）
- 答えが出なかった問いと、出なかった理由・残課題としての扱い

## リスクと復旧

| リスク | 影響 | 対処 |
|---|---|---|
| 0004 で npm レジストリに到達できない | テストランナーの選択肢が狭まり、受け入れ条件 9・10 の満たし方が変わる | Q4 の退避路（Node 標準の `node:test`、依存ゼロ）を同じチケットで確かめる。両方だめなら残課題にして設計計画で扱いを決める |
| `wip/tmp/` に作った捨てプロジェクトの `node_modules` が残る | リポジトリが汚れる | `wip/tmp/*` は `.gitignore` で追跡対象外。チケット完了時に削除する |
| Q5 の結論が issue #13 の詳細欄（`tools/` 配下）と食い違う | issue の記述と実装がずれる | 受け入れ条件は場所を規定していないので条件は変わらない。食い違ったら設計計画で issue への追記の要否を判断する |

## スコープ外

- 設計そのもの（パーサの構造・Webview の実装方針）。設計フェーズで扱う
- チケットの状態遷移や ticket.sh の変更
- `.claude/` 配下への一時的な変更（機構の上限が拒否する経路のため計画しない）

## 保留した点

| 項目 | 決める時期・根拠 |
|---|---|
| 拡張のソースと設計文書の最終的な置き場 | Q5 の答えを受けて設計計画で決める |
| テストランナーの採用 | Q3・Q4 の答えを受けて設計計画で決める |
| 依存グラフ表示（issue のスコープ外）を将来入れる余地を設計に持たせるか | 設計フェーズ。今回の受け入れ条件には無い |
