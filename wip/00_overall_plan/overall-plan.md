---
type: overall-plan
title: issue #6 全体計画 — 自己改善ワークフロー機構の実装 1/3（基盤）
description: ルール・フック共通ライブラリと設定・共通ステップスキル 9 本と提供コマンド・テストを作る issue の全体計画。フェーズ列、受け入れ条件との対応、実行者・レビュー要否・やってよいことの方針、機構未実装期間の手作業代替の扱いを定める
tags: [overall-plan, issue-6, ai-asset]
keywords: [全体計画, フェーズ列, AI アセット, 基盤, 提供コマンド, ticket.sh, commit.sh, push.sh, check-html.sh, hooks/lib, task-types.tsv, scope-limits.json, work-defaults, 手作業代替]
---

# issue #6 全体計画 — 自己改善ワークフロー機構の実装 1/3（基盤）

## 対象

- 対象 issue: #6 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/6
- PR: #7 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/pull/7（draft）
- ブランチ: `feature-6-workflow-foundation`（`main` 09a5e6b から分岐）
- マージ方式: リポジトリは squash / merge commit / rebase のすべてが許可。main の履歴は PR #2・#5 とも squash で取り込まれている（`docs: ...(#4) (#5)` の 1 コミット）ので、本 PR も squash を前提にする（設定変更は行わない）

## 種別

**AI アセット**。変更対象がすべて `.claude/` 配下（`rules/`・`hooks/lib/`・`hooks/config/`・`hooks/tests/`・`skills/20-common-step-*/`）と、その仕様の書き戻し先 `.claude/docs/`（`10_spec/`・`20_ddr/`・`90_glossary/`）であり、`docs/`・アプリのソースコードは含まない。

## フェーズ列

AI アセットのテンプレート（`10_spec/skills/00-workflow-issue-mr-driven.md`「フェーズ列のテンプレート」）をそのまま採用する。省略なし。

| 順 | フェーズ | チケット種類 | この issue での中身 |
|---|---|---|---|
| 1 | 全体計画 | `overall-plan` | 本計画（このチケット） |
| 2 | 調査 | `investigation-plan` → `investigation` | 下記「判断が必要になりそうな点」を問いにする。参考ディレクトリ（`agent-workflow` / `MR-driven-workflow`）の既存スクリプト・テストの流用可否、TBD T5（PowerShell ツールのフック入力）の実機確認、テストの実行方式の確定 |
| 3 | AI アセット設計 | `ai-asset-design-plan` → `ai-asset-design` | 要件・仕様は issue #1・#4 で作成済み。計画チケットで**対象なし**の判定を見込む（調査で仕様の欠落が見つかれば、そこだけ設計実施チケットを起こす） |
| 4 | AI アセット実装・テスト | `ai-asset-implementation-plan` → `ai-asset-implementation` | 主作業。固定順（設定・定義 → 中核 → 中核の機械テスト → スキル・ルール → 参照更新）で、ルール 4 → hooks/lib 5 + config 2 → 提供コマンド 4 本（+ logger）→ 共通ステップ SKILL.md 9 本と assets → 参照更新（`.claude/skills` 内。用語集 `90_glossary/スキル名.md` の更新は `.claude/docs` 配下なので後続の AI アセット設計へ） |
| 5 | フィードバック計画 | `feedback-plan` | 実装で見つかった仕様との食い違い・TBD の検証結果を棚卸しし、追加の AI アセット設計（仕様の書き戻し + DDR）の要否を決める |
| 6 | 後続（フィードバック計画が選んだものだけ） | `ai-asset-design` 系 / `ai-asset-implementation` 系 | 未定（フィードバック計画で決める） |
| 7 | 全体まとめ | `overall-summary` | 統括レポート、PR 本文の最終整形、片付け |

テンプレートとの差分: なし（フェーズ 3 は「対象なし」の見込みだが、省かず計画チケットで判定する）。

## 受け入れ条件との対応

| # | issue #6 の受け入れ条件 | 満たすフェーズ | 検証の形 |
|---|---|---|---|
| 1 | ルール 4 本が要件どおり `.claude/rules/` にある | 4（実装） | 要件書の受け入れ基準との対応表を実装計画書に書き、レビューで確認 |
| 2 | `hooks/lib/` 5 本がフック共通仕様どおりに動き、テストが失敗ケース含めて通る | 2（テスト方式）→ 4 | 機械テスト（テスト ID は共通仕様の HK-T\*・各ライブラリの観点） |
| 3 | `task-types.tsv` / `scope-limits.json` が種別表と一致し、3 データの整合テストが通る | 4 | HK-T02 |
| 4 | 共通ステップスキル 9 本の SKILL.md と assets が仕様と 1:1 | 4 | 仕様書の「処理フロー / OUT ひな形 / 参照ナレッジ」との対応表 + プレースホルダ・frontmatter 検査 |
| 5 | `ticket.sh` / `commit.sh` / `push.sh` / `check-html.sh` が仕様どおりに動き、TICKET-T\* / CP-T\* / RV-T\* が通る | 2（流用可否）→ 4 | 機械テスト |
| 6 | シェルスクリプトが `20-common-step-shell-script` の規約に従う | 4 | 規約の検査項目（ログ・エラー ID・終了コード・redact）をテストに含める |
| 7 | 仕様との食い違いは仕様書へ書き戻し DDR に残す。T5 の結果を仕様に反映 | 2（T5 の確認）→ 5 → 6（追加の AI アセット設計。実装フェーズは `.claude/docs/**` に書けない） | フィードバック計画の棚卸し表、DDR `i0006-NN` |

## 方針

`rules/work-defaults.md` は**未作成**（この issue の成果物そのもの）。したがって基準は無く、各スキルの既定（リスクの高いタスクは人間レビュー要）を使う。この issue で `work-defaults.md` を作るとき、下表の判断を初期値の材料にする。

| タスク | 実行者 | 人間レビュー | 敵対的レビュー | 理由 |
|---|---|---|---|---|
| 全体計画 | メイン | 要 | 不要 | フェーズ列と方針の合意（承認③）を PR 上にも残す |
| 調査計画 | メイン（※） | 不要 | 不要 | 問いは本計画で提示済み。計画書は調査結果と一緒に見てもらう |
| 調査実施 | メイン（※） | 要 | 不要 | 流用可否・テスト方式・T5 の結論が実装計画を左右する |
| AI アセット設計計画 | メイン（※） | 不要 | 不要 | 対象なしの見込み。対象ありなら結果報告で示し、実施側でレビュー |
| AI アセット設計実施 | メイン（※） | 要 | 要 | （起きた場合）仕様の変更は正史の変更 |
| AI アセット実装計画 | メイン（※） | 要 | 不要 | ステップ順・許可範囲・テスト割付・ロックアウト対策の確認 |
| AI アセット実装 | メイン（※） | 要 | 要（各切れ目 1 回） | 中核（提供コマンド・lib）を含む。実装チケットは複数枚になるが、切れ目（種類の切り替わり）は 1 回 |
| フィードバック計画 | メイン | 要 | 不要 | 後続フェーズの要否は人間の判断 |
| 全体まとめ | メイン | 要（`--final`） | 不要 | 片付け前の最終確認 |

（※）**スキルの既定（サブエージェント）からの逸脱**。理由: 提供コマンド（`ticket.sh` 等）とサブエージェント起動テンプレート・`task-executor` が未実装で、チケットの状態遷移・コミットを手作業で行う必要がある。サブエージェントに手作業の状態遷移を許すと、機構が禁じる操作をサブエージェントに教えることになるため、この issue ではメインエージェントが一貫して実施する。2/3 以降（提供コマンドが main にある状態）で既定のサブエージェントに戻す。

やってよいこと（`allow`）の方針:

| タスク | write | ops |
|---|---|---|
| 計画系・フィードバック計画・全体まとめ | `wip/**` | read, remote-read（全体計画・全体まとめは加えて remote-write:issue-create / issue-append / mr-create / push） |
| 調査実施 | `wip/**` | read, remote-read（参考ディレクトリの読み取りを含む。外部への問い合わせなし。T5 の確認は Claude Code のフック入力を `logs/` に記録して読むだけの一時フック — 書き込み先は `wip/tmp/` と `logs/`、`settings.json` の一時変更は調査チケットに明記し、完了時に戻す） |
| AI アセット実装 | `.claude/rules/**`, `.claude/hooks/lib/**`, `.claude/hooks/config/**`, `.claude/hooks/tests/**`, `.claude/skills/20-common-step-*/**`, `wip/**`（`.claude/docs/**` は type の上限で deny。仕様との食い違いは作業ログ「仕様からの逸脱」に記録し、書き戻しは後続の AI アセット設計で行う） | read, build-test, hook-test, remote-read |

- `settings.json` へのフック登録・`CLAUDE.md`・旧 `00-workflow-*` SKILL.md は本 issue では触らない（2/3・3/3）
- コミットは `commit.sh` が出来るまでは `git commit` を直接行う（本 issue の前半は避けられない。`commit.sh` が通ったらそれ以降は提供コマンドに切り替える — 実装計画でステップの境目を明示する）

## 判断が必要になりそうな点（調査の問いの元）

1. 参考実装の流用範囲: `agent-workflow` の `.claude/hooks/*.sh`（work-boundary / merge-prep / workflow-entry）とそのテスト、`MR-driven-workflow` の `.claude/scripts/`（commit / push / logger / check-html 相当）のうち、仕様（`10_spec`）にそのまま合う部分・書き直す部分
2. テストの実行方式: 参考実装のテスト（素の bash スクリプト）を踏襲するか、bats 等を導入するか。Windows（Git Bash）/ CI（Linux）の両方で通す前提
3. TBD T5: PowerShell ツールのフック入力（`tool_input.command`）が Bash と同じか（実機確認。共通仕様 §12）
4. `logger.sh` と `redact` の実装の置き場と、各スクリプトからの読み込み方（`20-common-step-shell-script` 仕様の確認）
5. HTML テンプレート（report / plan）の土台にする参考実装のレポートテンプレートの所在と、`check-html.sh` の検査 6（`data-required` の導出）に必要な構造

## 保留した点

| 項目 | 決める時期 |
|---|---|
| AI アセット設計フェーズの対象の有無 | 調査結果を受けた AI アセット設計計画チケット |
| 後続フェーズ（追加の設計 / 実装）の要否 | フィードバック計画 |
| `work-defaults.md` の初期値（上表をそのまま既定にするか、サブエージェント前提に直すか） | AI アセット実装計画（ルール 4 本のステップ） |

## 合意の記録

| 承認 | 内容 | 誰が | いつ |
|---|---|---|---|
| ① | 実装を 3 分割し、1/3（基盤）を新規 issue で進める | ユーザー（AskUserQuestion） | 2026-09-01 |
| ② | issue #6 の本文・ブランチ `feature-6-workflow-foundation`・PR タイトル `feat: 自己改善ワークフロー機構の実装 1/3: 基盤と共通ステップ (#6)` | ユーザー（AskUserQuestion） | 2026-09-01 |
| ③ | フェーズ列・実行者（全タスクをメインエージェント）・レビュー要否・やってよいこと・手作業代替の方針 | ユーザー（AskUserQuestion） | 2026-09-01 |

## 機構未実装期間の手作業代替（この issue 固有）

提供コマンド・フックが無いため、次を手作業で行う。仕様の禁止事項（手動移動の禁止）に当たるが、機構そのものを作る issue のブートストラップとして許容し、実装が出来た段階から提供コマンドに切り替える。

| 操作 | 本来 | 本 issue での代替 |
|---|---|---|
| チケット作成・着手・完了 | `ticket.sh create/start/complete` | テンプレート相当の内容を Write し、`git mv` で `00_todo → 10_doing → 20_done`。開始・完了時刻・`base_sha` は手で記入。完了検査（DoD 全チェック・根拠・作業ログ必須項目・未コミットなし）は自分で確認して作業ログに記す |
| コミット・push | `commit.sh` / `push.sh` | `git commit`（件名 `<prefix>: <日本語>`、パス指定 add）/ `git push`。`commit.sh` `push.sh` の実装完了後はそれらを使う |
| 切れ目の判定・レビュー依頼・完了 | `boundary.sh status/request/complete` | 完了チケットの種類の切り替わりを目視で判定し、`gh pr comment --body-file` でレビュー依頼。完了はユーザーの連絡 + PR コメントの確認 |
| 敵対的レビュー | `adversarial-reviewer` エージェント（未実装） | Agent ツール（Read/Glob/Grep のみ）に仕様のプロンプト相当を渡して実施し、結果を PR コメントに残す |
| HTML ビューの検査 | `check-html.sh` | 実装されるまで計画書・レポートは md のみ（HTML は `check-html.sh` 完成後に遡って作る） |
