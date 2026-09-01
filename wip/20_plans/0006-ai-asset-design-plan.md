---
type: plan
title: 0006 AI アセット設計計画 — 調査で見つかった仕様の食い違い D1〜D21 とテスト ID 不在 5 本の設計反映
description: issue #6 の調査結果（D1〜D21・Q6）を受け、実装前に直す仕様・要件・DDR を確定する計画。中核変更の要否、採否表、文書一覧と骨子、横断整合、ヘッドレス実行の帰結、設計チケット 3 枚と次の計画チケット
tags: [plan, ai-asset-design, issue-6]
keywords: [AI アセット設計計画, 仕様修正, フック共通仕様, §8, §9, §12, frontmatter, commit.sh 経由, data-required, test-lib, run-tests, eval ID, DDR i0006, 採否表]
---

# 0006 AI アセット設計計画

## 対象

- issue #6 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/6 / PR #7 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/pull/7
- 起点: 調査結果レポート `wip/30_reports/0003-investigation.md`（D1〜D21、Q6、申し送り H1〜H6、実装計画の判断点）
- 全体計画の見込みは「対象なし」だったが、調査で **実装計画の前提を崩す仕様の不整合**（仕様内矛盾 D10、テスト ID 不在 5 本、§8 の上限と実装の食い違い D14・D20）が見つかったため **対象あり** と判定する

## 結論方針

- **中核（フック・settings.json）の変更要否: 本 issue では中核の実装・登録を行わない**（2/3）。ただし中核の**仕様**（`フック共通仕様.md` §3・§6・§7-8・§8・§9・§12、`post-push-compact-prompt` 仕様）に文言の追加・修正を行う。フックが動いていないためロックアウトの可能性は無い。2/3 の実装はこの修正後の仕様を正として読む
- 採る案: 調査の推奨どおり **D9 = A 案（パーサ拡張）+ 置き場 (b)**（`20-common-step-shell-script/scripts/frontmatter.sh` を `source` 専用の純 bash ライブラリとして置き、hooks/lib と `ticket.sh` の両方から読む。依存方向を logger と揃える）、**D10 = `commit.sh` 経由**、**D16 = テンプレートの `data-required` で格上げ（仕様に一覧は書かない）**、**D19 = `test-lib.sh` + `run-tests.sh`（接頭辞 `TR`）**、**D20 = (a) 計画チケットが `allow.ops` に `build-test` を宣言したときだけ調査で実行可（上限にも追加）**
- 仕様変更はすべて**現在の正史を書き換える**（履歴は書かない）。採らなかった案と理由は DDR `i0006-NN` に残す

### 採否表

| # | 内容（要約） | 採否 | 反映先 | 担当チケット |
|---|---|---|---|---|
| D1 | 宣言 `d.write` は絞る役（参考と逆） | 仕様変更なし（実装計画へ。テストで最優先に固定） | — | — |
| D2 | glob の `*` は `/` を跨がない、跨ぐ一致は `**` | **採用** | フック共通仕様 §8 | 0008 |
| D3 | push 検知 2 の `@{upstream}` 縮退経路 | **採用** | `10_spec/hooks/22-PostToolUse/post-push-compact-prompt.md`（該当節） | 0008 |
| D4 | 提供コマンド識別はリポジトリルート相対のパス一致。パス不定は通常判定 | **採用** | フック共通仕様 §7-8 | 0008 |
| D5 | deny の JSON 経路が効くかを TBD に追加 | **採用** | フック共通仕様 §12 | 0008 |
| D6 | T5 を確認済みに、T3 を出典付きで補強 | **採用** | フック共通仕様 §12 | 0008 |
| D7 | `UserUtteranceSelect.jq` は採らない | 採らない（要件追加なし） | — | — |
| D8 | `adversarial_review: {required, reason}` を frontmatter に追加 | **採用** | フック共通仕様 §9、`20-common-step-ticket` 仕様（OUT ひな形・WF208 の監視対象に加えるか明記） | 0008・0009 |
| D9 | 入れ子 frontmatter の読み取り | **採用（A 案 + 置き場 (b)）**: `frontmatter.sh`（純 bash・source 専用・`parent.child` キーとインラインマップ対応）を `20-common-step-shell-script/scripts/` に新設し、hooks/lib の読み取りと `ticket.sh` が共用 | フック共通仕様 §7 冒頭の共有ライブラリ一覧（参照を追加）、`20-common-step-shell-script` 仕様（Script 処理に `frontmatter.sh` の関数・テスト観点 FM-T\*）、`20-common-step-ticket` 仕様（参照ナレッジ） | 0009（本体）、0008（参照） |
| D10 | `ticket.sh` の状態変更コミットは `commit.sh` 経由 | **採用** | `20-common-step-ticket` 仕様 Script 処理（冒頭の規定と各サブコマンド）。`commit-push` 仕様は現状維持 | 0009 |
| D11 | redact は最後の砦、一次防御は値を出さないこと | **採用** | フック共通仕様 §3 | 0008 |
| D12 | logger の読み込み 1 行をフォールバック鎖に | **採用** | `00_requirement/rules/logger.md`「使い方」、`20-common-step-shell-script` 仕様の雛形サンプル | 0009 |
| D13 | ファイル名と `ticket_type` の食い違いは frontmatter が正 | **採用** | `20-common-step-ticket` 仕様 | 0009 |
| D14 | `.gitattributes` を `ai-asset-implementation.allow` に追加 | **採用** | フック共通仕様 §8 初期値表 | 0008 |
| D15 | フックでは exit 2 を使わない（提供コマンドの終了コード規約との切り分け） | **採用** | `20-common-step-shell-script` 仕様 | 0009 |
| D16 | 必須節の格上げは `data-required` で。必須節は空にせず「無し」1 行 | **採用** | `20-common-step-report-view` 仕様（規約 1 文。一覧は書かない）、DDR | 0009 |
| D17 | プレースホルダは要素内容に置く。`data-required` は要素種別を問わず属性で抽出 | **採用** | `20-common-step-report-view` 仕様（テンプレート規約・検査 6） | 0009 |
| D18 | 計画書テンプレートのレイアウト | 実装計画で決める | — | — |
| D19 | `test-lib.sh`・`run-tests.sh`（提供コマンド、接頭辞 `TR`） | **採用** | `20-common-step-shell-script` 仕様（OUT ひな形・Script 処理・テスト観点）、フック共通仕様 §6 採番台帳 | 0009（本体）、0008（台帳） |
| D20 | 調査でのテスト実行は計画チケットの `allow.ops` 宣言があるときだけ可 | **採用（(a)）** | `10_spec/skills/10-task-investigation-exec.md`（禁止事項・固有手順）、`10-task-investigation-plan.md`（計画で宣言する旨）、フック共通仕様 §8 初期値表（`investigation.ops` に `build-test`）。要件側（`00_requirement/skills/10-task-investigation-exec.md`）に同じ禁止があれば要件も直す | 0010（タスク仕様）、0008（§8） |
| D21 | `.claude/**` の一時変更を調査で計画しない | **採用** | `10-task-investigation-plan.md` 固有手順 | 0010 |
| Q6 | テスト ID の無い共通ステップ仕様 5 本（`ai-asset-creator` / `feature-mr` / `issue` / `requirement` / `spec`）にテスト観点（eval ID）を追加 | **採用** | 5 本の仕様書に「テスト観点」表（eval。ID は `<接頭辞>-E01` 形式。接頭辞は §6 台帳に追加）、`20-common-step-ai-asset-creator` 仕様に eval テンプレートの形式（参考 `evals.json` → md への移し替え） | 0010（5 本）、0008（台帳） |
| 付録命名 | 調査結果レポートの付録 `<連番>-<種類>-appendix-<記号>.md` | **採用** | `20-common-step-report-view` 仕様（置き場の規約） | 0009 |

## 文書一覧と骨子

1:1:1 を保つ。すべて**更新**（新規のアセット・文書は無い。`frontmatter.sh` / `test-lib.sh` / `run-tests.sh` は `20-common-step-shell-script` スキルの配下に増えるスクリプトで、同スキルの要件・仕様の中で扱う）。

| アセット | 要件定義書 | 仕様書 | 骨子（変更点） |
|---|---|---|---|
| フック共通（横断） | 変更なし（要件は `自己改善ワークフロー機構.md`・各フック要件） | `10_spec/フック共通仕様.md` | §3 に D11 の 1 文 / §6 に接頭辞 `TR`・`FM`・eval 接頭辞 5 種を追加 / §7 の共有ライブラリ一覧に `frontmatter.sh`（shell-script スキル配下、hooks/lib から `source`）を追記し §7-8 を D4 で補う / §8 に D2 の glob 規則、初期値表に D14（`.gitattributes`）と D20（`investigation.ops` に `build-test`）/ §9 に `adversarial_review` / §12 に D5 を追加し T5 を確認済み・T3 を補強 |
| `hooks/22-PostToolUse/post-push-compact-prompt` | 変更なし | `10_spec/hooks/22-PostToolUse/post-push-compact-prompt.md` | push 検知 2 に D3 の縮退経路（`@{upstream}` 不在 → `origin/<branch>` → 初回は終了コード 0 + `push-state.json` 未記録で真） |
| `20-common-step-shell-script` | `00_requirement/skills/20-common-step-shell-script.md`（`frontmatter.sh` と `run-tests.sh` の存在を要件に含めるか確認。含める場合は受け入れ基準を 1 行ずつ追加） | `10_spec/skills/20-common-step-shell-script.md` | 雛形の読み込み行を D12 のフォールバック鎖に / D15 の終了コード切り分け / OUT ひな形に `test-lib.sh`（`source` 専用）と `run-tests.sh`（提供コマンド `TR0xx`・テスト観点 TR-T\*）/ `frontmatter.sh`（関数: `fm_extract` `fm_get <file> <key>`（`parent.child` 可）`fm_list <file> <key>`、インラインマップ対応、純 bash、CR 除去。テスト観点 FM-T01〜T05: フラット / 入れ子 / インラインマップ / フロー配列 / CRLF） |
| `rules/logger` | `00_requirement/rules/logger.md` | （rules は要件のみ） | 「使い方」の読み込み 1 行を D12 のフォールバック鎖（BASH_SOURCE 上向き探索 → `CLAUDE_PROJECT_DIR` → `git rev-parse` → no-op）に |
| `20-common-step-ticket` | 変更なし | `10_spec/skills/20-common-step-ticket.md` | D10（状態変更のコミットは `commit.sh` 経由。`overall-plan` 非コミット規定は維持）/ D13（frontmatter が正）/ D8（テンプレートの記載事項に `adversarial_review`）/ 参照ナレッジに `frontmatter.sh` |
| `20-common-step-report-view` | 変更なし | `10_spec/skills/20-common-step-report-view.md` | D16（必須節は空にせず「無し」1 行。一覧は書かない）/ D17（プレースホルダは要素内容、`data-required` は属性で抽出）/ 付録の命名 |
| `10-task-investigation-plan` / `-exec` | `00_requirement/skills/10-task-investigation-exec.md`（禁止事項に「テスト実行」があれば D20 に合わせる） | 両仕様 | D20（計画が `allow.ops` に `build-test` を宣言した調査チケットだけ実行可。既定は禁止のまま）/ D21（`.claude/**` の一時変更を計画しない） |
| `20-common-step-{ai-asset-creator,feature-mr,issue,requirement,spec}` | 変更なし | 5 本の仕様書 | 「テスト観点」表を追加（eval。例: `AC-E01` テンプレートのコピーと検査、`FM-E01` issue 連携モードでブランチと draft MR、`IS-E01` 検索 → 作成、`RQ-E01` 要件書のフォーマット、`SP-E01` 仕様書のフォーマット。入力・期待する振る舞い・判定方法を 1 行ずつ）。`ai-asset-creator` には eval テンプレートの形式（`skill_name` / `evals[{id, prompt, expected_output, files}]` を md 表に） |
| DDR | — | `20_ddr/i0006-01〜05` | 01 frontmatter パーサは拡張し置き場は shell-script スキル配下 / 02 ticket.sh のコミットは commit.sh 経由 / 03 必須節の格上げは data-required で表し一覧は仕様に書かない / 04 テストは素の bash + 共通ヘルパ + ランナー（bats 非導入）/ 05 調査でのテスト実行は計画の宣言があるときだけ可 |

## 横断整合

- `00_requirement/自己改善ワークフロー機構.md`: 変更なしの見込み（提供コマンドの一覧に `run-tests.sh` を載せる箇所があれば追記。0010 で確認）
- `00_requirement/rules/ルール体系.md`: 変更なし（ルールの追加は無い）
- `90_glossary/スキル名.md`・`ワークフロー用語.md`: スキルの追加は無い。用語「提供コマンド」の例に `run-tests.sh` を加えるか 0010 で確認。`frontmatter.sh` は用語にしない
- `20-common-step-spec.md`（仕様書の書き方）: 「テスト観点」に eval ID を書く形式を許す旨が無ければ 1 文追加（0010）

## ヘッドレス実行の帰結

| 変更 | ヘッドレスでの帰結 |
|---|---|
| §8 の glob 規則・初期値の追加（D2・D14・D20） | 判定が確定的になる方向。`ask` になる経路は増えない |
| D20（調査でのテスト実行） | 計画チケットの宣言が無ければ従来どおり拒否。宣言があれば `build-test` として通る（承認不要） |
| D10（`commit.sh` 経由） | `commit.sh` の検査が `ticket.sh` にも効く。拒否されれば `ticket.sh` は非 0 で止まる（ヘッドレスでも同じ） |
| D16・D17（テンプレート規約） | `check-html.sh` の RV001 / RV006 が機械的に判定。人間の判断は不要 |
| D19（`run-tests.sh`） | 提供コマンドとして許可。CI でも同じ 1 コマンド |
| eval ID の追加 | eval は定義のみ（実行は人間の判断）。ヘッドレスでは実行しない |

## 受け入れ条件（候補）との対応

| issue #6 の受け入れ条件 | 文書 | テスト ID の予定 |
|---|---|---|
| 2 hooks/lib 5 本とテスト | フック共通仕様 §7・§8（D2・D4・D9 参照） | HK-T\*（既存）+ FM-T01〜T05（新） |
| 3 tsv / json の整合 | フック共通仕様 §8 初期値表（D14・D20） | HK-T02 |
| 4 共通ステップ 9 本の SKILL.md と assets | 5 本の仕様の eval ID、report-view の D16・D17、ticket の D8 | AC/FM/IS/RQ/SP-E01〜（新）、RV-T\* |
| 5 提供コマンド 4 本とテスト | ticket 仕様（D10・D13）、shell-script 仕様（D19） | TICKET-T\*、CP-T\*、TR-T\*（新） |
| 6 シェルスクリプトの規約 | shell-script 仕様（D12・D15）、logger 要件 | LG-T\*、SS-T\* |
| 7 食い違いの書き戻しと T5 | フック共通仕様 §12（D5・D6）、DDR i0006-01〜05 | — |

## AI アセット設計チケット

| チケット | まとまり | 依存 |
|---|---|---|
| 0008 ai-asset-design | フック共通仕様（§3・§6・§7・§8・§9・§12）+ post-push-compact-prompt 仕様 | なし |
| 0009 ai-asset-design | 共通ステップ仕様: shell-script（D9 本体・D12・D15・D19）+ logger 要件 + ticket（D8・D10・D13）+ report-view（D16・D17・付録） | なし |
| 0010 ai-asset-design | タスク仕様 investigation-plan / exec（D20・D21）+ 5 本の eval ID + ai-asset-creator の eval 形式 + DDR i0006-01〜05 + 横断整合の確認 | 0008・0009（DDR と横断整合は両方の結果を見る） |

次の計画チケット: 0011 `ai-asset-implementation-plan`（predecessors: 0008, 0009, 0010）。

## 保留した点

- `frontmatter.sh` と `run-tests.sh` を shell-script スキルの**要件**に載せるか（要件は外部的に書く方針。0009 で要件書を読んで判断し、載せるなら受け入れ基準を追加）
- eval ID の接頭辞（`AC` / `FM` / `IS` / `RQ` / `SP`）が §6 台帳の既存接頭辞と衝突しないか（`FM` は `frontmatter.sh` のテスト ID とも重なる → 0008 で台帳を作るときに決める。候補: frontmatter は `FR`）
