---
type: plan
title: 0026 AI アセット設計計画 — フィードバック計画の候補 27 件を仕様・要件・DDR へ書き戻す
description: issue #6 のフィードバック計画（0022）で「この MR」とした改善候補 27 件（実装の逸脱 D-1〜D-34、横断的な食い違い、敵対的レビュー由来の仕様の判断）を、1:1:1 の文書一覧と骨子、横断整合、ヘッドレス実行の帰結、設計チケット 3 枚と次の計画チケット（実装計画）に落とす計画
tags: [plan, ai-asset-design, issue-6, feedback]
keywords: [AI アセット設計計画, 仕様の書き戻し, 逸脱 D-1〜D-34, フック共通仕様, 台帳, CP007, RV008, TK008, HK-T15, 承認単位, redact, DDR i0006-07, ルール体系, 節順, 実装計画]
---

# 0026 AI アセット設計計画

## 対象

- issue #6 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/6 / PR #7 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/pull/7
- 起点: フィードバック計画書 `wip/20_plans/0022-feedback-plan.md` の「この MR」27 件（A1〜A9・B1〜B5・B9・C1・C2・H4・G1〜G6・G10〜G12）。実装結果レポート `wip/30_reports/0013-ai-asset-implementation.md` の逸脱 D-1〜D-34 が主な入力
- 受け入れ条件 7「仕様との食い違いは仕様書へ書き戻し DDR に残す」を満たすフェーズ。実装フェーズは `.claude/docs/**` を書けないため、ここで書き戻し先と骨子を確定する

## 結論方針

- **中核（フック・settings.json）の変更要否: なし**。本 issue はフック本体を持たず `settings.json` にも登録していない。変更するのは中核の**仕様**（`フック共通仕様.md` §1・§3・§6・§7・§8・§11・§12、`post-push-usage-report` / `post-push-compact-prompt` 仕様）の文言で、実装済みの `hooks/lib` の振る舞いを正史に写す方向。ロックアウトの経路は生じない
- **採る案**: 実装が既に採った振る舞い（D-1〜D-34）は、レビューで欠陥と判定されたもの以外は**実装を正として仕様に写す**（0022 の A〜B 節の提案どおり）。実装を変える設計は 5 件だけ: G1（`read` / `remote-read` は常に可 — 仕様を実装に合わせる）、G2（引数・環境の誤りの識別子 CP007 / RV008 / TK008 を新設し、提供コマンドの出力を合わせる）、G12（完了検査に固定見出しの重複を加える）、B3（eval 接頭辞 `SP-E` を `SC-E` に改名）、A8（scope の判定順・ops 分類のテスト ID HK-T15 を新設し既存テストの ID を付け替える）
- **実装を伴う候補**（A8・B3・C1・C2・G2・G11・G12）は設計で仕様に書いたうえで、**次の計画チケットを `ai-asset-implementation-plan` にして実装チケットへ落とす**（ワークの連鎖規則。全体まとめはその実装計画が起こす）
- 仕様変更はすべて現在の正史を書き換える（履歴は書かない）。判断の経緯と却下案は DDR `i0006-07〜12` に残す

### 候補との対応表（0022「この MR」27 件）

| # | 候補（要約） | この issue で扱う | 反映先 | 担当 |
|---|---|---|---|---|
| A1 | ルール frontmatter のキー（`category` / `paths` / `applies_when`）と SKILL.md は `name` / `description` のみ | 扱う | `00_requirement/rules/ルール体系.md`（成果物 / 行動ルールの frontmatter の規定）、`20-common-step-ai-asset-creator` 仕様（SKILL.md の frontmatter） | 0030 / 0029 |
| A2 | `task-types.tsv` のヘッダ行、`commands.build-test` は空でよい（B6 の 1 行） | 扱う | フック共通仕様 §8 | 0028 |
| A3 | 読み込み行の `FATAL:` 行・`HOOK_DENY_ID`・`nop` の `LOGGER_ROOT`（D-31）・`fm_get` の戻り | 扱う | `20-common-step-shell-script` 仕様「読み込み行」「frontmatter.sh」 | 0029 |
| A4 | CP007（`git commit` 失敗）、CP001 の条件（ステージ不可・ディレクトリ D-29）、スキップ記録の形と HEAD の版（D-30） | 扱う | `20-common-step-commit-push` 仕様、台帳 §6 | 0029（仕様）/ 0028（台帳） |
| A5 | ticket 仕様の `create` オプション名・`next` の返却・`cancel` の記録（§9 とテンプレート）・未知の種類・T10 文言・判定語・index 復元・YAML エスケープと根拠欄なし（D-32） | 扱う | `20-common-step-ticket` 仕様、フック共通仕様 §9 | 0029 / 0028 |
| A6 | `<body data-template>`、計画書の節構成、必須節の判断の DDR | 扱う | `20-common-step-report-view` 仕様、DDR i0006-11 | 0029 |
| A7 | `type: requirement`、追記テンプレートの「受け入れ条件（任意）」、glab の draft 指定（G3 と一緒）、要件書の章名の統一 | 扱う | `20-common-step-requirement` / `-issue` / `-feature-mr` 仕様 | 0030 |
| A8 | cmdpos の出力の形、redact の注記（D-25・D-34・H4 の再一致）、HK-T15、H6 の jq、`last_offset` の単位 | 扱う（HK-T15 の ID 付け替えは実装） | フック共通仕様 §3・§7・§11、H6、`post-push-usage-report` 仕様 | 0028 |
| A9 | `tool_response` の形（D-23）と案内側の `scope.sh` 読み込みポリシー（D-27）を §12 の TBD に | 扱う（TBD 行の追加のみ。確認は 2/3） | フック共通仕様 §12、`post-push-compact-prompt` 仕様 | 0028 |
| B1 | `ルール体系` の本数（7 vs 8）と logger の glob 表記 | 扱う | `00_requirement/rules/ルール体系.md` | 0030 |
| B2 | §1 の lib 一覧全行に HK-Txx の所在 | 扱う | フック共通仕様 §1 | 0028 |
| B3 | 接頭辞 `SP-` の重複（eval 側を `SC-E` に） | 扱う（eval 定義 5 本の改名は実装） | 台帳 §6、`20-common-step-spec` 仕様のテスト観点 | 0028 / 0030 |
| B4 | `build-test` と `hook-test` の重なりと判定順 | 扱う | フック共通仕様 §8 | 0028 |
| B5 | プレースホルダ表記を `{{名前}}` に統一 | 扱う | exec 仕様のうち `<...>` を使う箇所（`10-task-*-exec.md`、`20-common-step-*` の OUT ひな形）。0030 で grep して一覧化 | 0030 |
| B9 | フィードバック計画書の節（feedback-plan 仕様の OUT ひな形）と計画書 HTML テンプレートの必須節が対応しない | 扱う | `20-common-step-report-view` 仕様（計画の種類ごとの固有節は必須節の後に追加してよい。フィードバック計画の 6 節と必須節の対応） | 0029 |
| C1 | `hook_payload` の `session_id` 指定 | 扱う（実装） | `20-common-step-shell-script` 仕様「test-lib.sh」 | 0029 |
| C2 | `skill.template.md` のガイド（冒頭段落 = 禁止事項の要約） | 扱う（テンプレート修正は実装） | `20-common-step-ai-asset-creator` 仕様 OUT ひな形 | 0029 |
| H4 | redact の置換結果に再一致しない規則 | 扱う | フック共通仕様 §3（A8 と一緒） | 0028 |
| G1 | `read` / `remote-read` / `provided` は宣言によらず常に可 | 扱う（仕様を実装に合わせる。DDR） | フック共通仕様 §8、DDR i0006-09 | 0028 |
| G2 | 引数・環境の誤りの識別子 CP007 / RV008 / TK008 と、CP005 / CP006 / TK004 の転用の解消 | 扱う（出力の変更は実装） | 台帳 §6、commit-push / report-view / ticket 仕様、DDR i0006-12 | 0028（台帳）/ 0029（仕様） |
| G3 | feature-mr の glab コマンドを SKILL.md（API + ファイル渡し）に寄せる | 扱う | `20-common-step-feature-mr` 仕様 処理フロー 5 | 0030 |
| G4 | 正史 4 本の受け入れ基準の節順（メイン → 代替 → 例外）と `自己改善ワークフロー機構.md` の「関連するドキュメント」節の削除 | 扱う | `00_requirement/rules/design-docs.md`、`rules/ai-asset-design-docs.md`、`skills/10-task-overall-plan.md`、`00_requirement/自己改善ワークフロー機構.md` | 0030 |
| G5 | TR004 / TR005 は終了 2、`build-test` の bash テスト判定 | 扱う | `20-common-step-shell-script` 仕様、フック共通仕様 §8 | 0029 / 0028 |
| G6 | D-29〜D-34 | 扱う | A3・A4・A5・A8・G1 の行に含む（D-33 承認単位 → §8 (7)、DDR i0006-07） | 0028 / 0029 |
| G10 | テストの書き方（語彙表の全要素・負のケースの正の期待値・計数） | 扱う | `20-common-step-shell-script` 仕様「テスト観点」の規約節（`bash-script` ルールは別 issue のため仕様に置く） | 0029 |
| G11 | `make_counting_path` の使いどころ | 扱う（SKILL.md は実装） | `20-common-step-shell-script` 仕様「test-lib.sh」 | 0029 |
| G12 | 完了済み 4 枚の作業ログに固定見出しの空の複製。`ticket.sh complete` が見逃す | 扱う（検査の追加は実装） | `20-common-step-ticket` 仕様 complete 3 の検査条件 | 0029 |

「扱わない」は 0 件（0022 で既に絞られている）。

## 文書一覧と骨子

1:1:1 を保つ。**新規の文書は DDR 6 件だけ**で、他はすべて更新。アセット本体（`hooks/lib`・提供コマンド・テンプレート・eval）の変更は次の実装計画で扱う。

| アセット | 要件定義書 | 仕様書 | 骨子（変更点） |
|---|---|---|---|
| フック共通（横断仕様） | 変更なし | `10_spec/フック共通仕様.md` | §1: lib 一覧の全行に「lib 単体のテスト観点は §11 HK-Txx」（B2）/ §3: redact のパターン注記 — `/` を含む 40 文字語は対象外、ハイフン区切り小文字と識別子は残す、`*_key=` 系のキー名、置換結果に再一致しない（A8・D-25・D-34・H4）/ §6: CP007・RV008・TK008 の追加と条件、eval 接頭辞 `SP-E` → `SC-E`（G2・B3）/ §7: cmdpos の出力の形 `CP_*` 配列と gitlike の定義（D-22・F-19）/ §8: tsv のヘッダ行、`commands.build-test` は空でよい、`build-test` と `hook-test` の判定順、`read` / `remote-read` / `provided` は宣言によらず常に可、承認単位 (7) の例外（ルート直下はファイル単位、`"."` は認めない）（A2・B6・B4・G1・D-33）/ §9: `cancelled_at` / `cancel_reason`（D-12）/ §11: HK-T15（scope の判定順・宣言の絞り込み・ops 分類・設定検査）（D-26）/ §12: TBD に `tool_response` の形と案内側の読み込みポリシー（D-23・D-27）/ H6: jq 1.6（Windows）の `strptime` 不可 |
| `hooks/22-PostToolUse/post-push-usage-report` | 変更なし | `10_spec/hooks/22-PostToolUse/post-push-usage-report.md` | `last_offset` の単位は処理済み行数（D-24） |
| `hooks/22-PostToolUse/post-push-compact-prompt` | 変更なし | `10_spec/hooks/22-PostToolUse/post-push-compact-prompt.md` | push 検知 3 の終了コードの読み方（`exit_code` / `exitCode` / `returnCode` / `code`、無ければ 0、`interrupted` は失敗）を「実機未確認」と明記し §12 を参照（D-23） |
| `20-common-step-shell-script` | 変更なし（要件は外部的な振る舞いのみ） | `10_spec/skills/20-common-step-shell-script.md` | 読み込み行: `fatal` の最終行 `FATAL: <理由>`・`deny` の `HOOK_DENY_ID`（既定は呼び手が設定。番号は 2/3）・`nop` でも `LOGGER_ROOT` を設定（D-3・D-4・D-31）/ frontmatter.sh: `fm_get` はマップ・配列キーに生の文字列（D-5）/ run-tests.sh: TR004 / TR005 の終了コードは 2（G5）/ test-lib.sh: `make_counting_path` / `counted_calls`、`hook_payload` の `session_id` 指定（G11・C1）/ テスト観点の規約節: 表形式の実装は全要素ループ、負のケースには正の期待値、性能・回数の約束は計数で（G10） |
| `20-common-step-commit-push` | 変更なし | `10_spec/skills/20-common-step-commit-push.md` | CP001 の条件に「ステージできないパス・ディレクトリ・`-m` の値なし」、CP007「`git commit` 自体の失敗」、`push.sh` の引数誤り・環境誤りは CP007 に寄せ CP005 / CP006 は本来の条件だけに、スキップ記録の行の形と「コミット済みの版（HEAD）だけを読む」、ステージ後の実パスへの除外の当て直し（A4・D-7〜D-9・D-29・D-30・G2） |
| `20-common-step-ticket` | 変更なし | `10_spec/skills/20-common-step-ticket.md` | `create` のオプション名一覧、complete 3 に「作業ログの固定見出しが重複していない」（G12）、`next` が作業中でも `type` / `skill` を返す、`cancel` の記録項目、TK008「引数・環境の誤り」と TK004 の条件の限定、TICKET-T10 の文言、complete 3 の判定語（`次:` / `未着手`）と「根拠欄そのものが無い行は未充足」、commit 拒否時の index 復元、frontmatter 値の YAML エスケープ（A5・D-10〜D-15・D-32・G2） |
| `20-common-step-report-view` | 変更なし | `10_spec/skills/20-common-step-report-view.md` | OUT ひな形に `<body data-template="report\|plan">`、計画書テンプレートの節構成（この計画で何をするか / 対象と範囲 / 方法とステップ / 検証 / チケット / リスク（任意）/ スコープ外（任意）/ 保留した点）、RV008「引数・ファイル不正」、計画の種類ごとの固有節は必須節の後に追加してよい（B9）（A6・D-16・D-17・G2・B9） |
| `20-common-step-ai-asset-creator` | 変更なし | `10_spec/skills/20-common-step-ai-asset-creator.md` | OUT ひな形: `skill.template.md` の冒頭段落は禁止事項の要約、SKILL.md の frontmatter は `name` / `description` のみ（C2・D-19） |
| `20-common-step-requirement` / `-issue` / `-feature-mr` / `-spec` | 変更なし | 各仕様 | requirement: `type: requirement`、要件書の章名を「他のスキル・機構との整合」に統一（D-20・A7）/ issue: 追記テンプレートに「受け入れ条件（任意）」（D-21）/ feature-mr: 処理フロー 5 を `glab api projects/:id/merge_requests`（本文はファイル渡し、draft はタイトル接頭辞 `Draft:`）に（G3・A7）/ spec: テスト観点の eval ID を `SC-E`（B3） |
| `10-task-*-plan`（計画タスク仕様 7 本） | 変更なし | `10_spec/skills/10-task-{investigation,design,implementation,design-feedback,ai-asset-design,ai-asset-implementation}-plan.md`、共通手順（`10-task-investigation-plan.md`） | プレースホルダ表記 `<...>` → `{{名前}}`（B5。0030 で grep して該当箇所を一覧化） |
| `rules/ルール体系`（要件のみ） | `00_requirement/rules/ルール体系.md` | — | 成果物ルール / 行動ルールの frontmatter（`category: artifact\|behavior`、`paths`、`applies_when`）の規定、成果物ルールの本数（表に合わせる）、logger の適用範囲を glob 表記に（A1・B1・D-1・D-28） |
| 要件 4 本の節順（`rules/design-docs` / `rules/ai-asset-design-docs` / `10-task-overall-plan` / `自己改善ワークフロー機構`） | 上記 4 本の要件定義書 | — | 受け入れ基準の節を「メインフロー → 代替フロー → 例外フロー」の順・この文言に直し、`自己改善ワークフロー機構.md` のルールが禁じる「関連するドキュメント」節を削る（G4。内容は変えない） |
| DDR | — | `20_ddr/i0006-07〜12` | 07 承認単位はルート直下をファイル単位にし `"."` を認めない（却下: 親ディレクトリ一律）/ 08 redact 規則 5 の除外条件（却下: `/` を含めて全部マスク、40 文字を 16 進に限定）/ 09 `read` / `remote-read` は宣言によらず常に可（却下: 宣言必須）/ 10 提供コマンドの自己強制 — skip 記録は HEAD の版、ディレクトリ引数の拒否（却下: 未コミットの版も読む、ディレクトリを展開して除外）/ 11 計画書テンプレートの必須節（D-17。却下: 調査計画の節をそのまま）/ 12 引数・環境の誤りの識別子を種別ごとに新設（却下: 既存番号の転用を仕様に明記して済ます） |

## 横断整合

- `00_requirement/自己改善ワークフロー機構.md`: 節順と「関連するドキュメント」節の削除（G4）。提供コマンド・識別子の列挙は無いので他の候補による変更なし（0030 で確認）
- `00_requirement/rules/ルール体系.md`: 上表のとおり更新（frontmatter・本数・glob）
- `90_glossary/ワークフロー用語.md`: 「承認単位」「提供コマンドの自己強制」を用語にするか 0030 で判断（現状は文中の説明で足りる見込み。追加するなら 1 行ずつ）。`スキル名.md`: 変更なし（スキルの追加なし）
- `20-common-step-spec` 仕様（仕様書の書き方）: 「テスト観点」に規約節（G10）を置く形が種別ごとの固定節構成に収まるか 0029 で確認し、収まらなければ「Script 処理」のサブ節にする

## ヘッドレス実行の帰結

| 変更 | ヘッドレスでの帰結 |
|---|---|
| G1（`read` / `remote-read` は常に可） | 読むだけの操作が宣言漏れで `deny` になる経路が無いことを仕様で保証。`ask` は増えない |
| D-33（承認単位）| ルート直下のファイルは 1 つずつ `ask`（WF202）。ヘッドレスでは `deny`（WF213）になる回数が増え得るが、`"."` で全体が通る危険を優先して塞ぐ |
| G2（識別子の新設） | 提供コマンドの失敗理由が識別子で機械的に分かれる。ヘッドレスの再試行判断（引数の誤りは再試行しない）に効く |
| D-29・D-30（commit / push の自己強制） | ディレクトリ引数・未コミットの skip 記録は無条件に止まる。人間の判断を挟まない |
| B7（自律運用の差し戻し起票） | 承認④相当の合意があるときだけ。無ければ従来どおり提案を返して止まる |
| HK-T15・SC-E（ID の付け替え） | 判定に影響なし。`run-tests.sh --ids` の突合が変わるだけ |
| その他（文言の明記） | 判定に影響なし |

## 受け入れ条件（候補）との対応

| issue #6 の受け入れ条件 | 文書 | テスト ID の予定 |
|---|---|---|
| 2 hooks/lib 5 本とテスト | フック共通仕様 §3・§7・§8・§11（A8・G1・D-33） | HK-T15（新）、HK-T05 / HK-T10 / HK-T11 の観点追記 |
| 4 共通ステップ 9 本の SKILL.md と assets | ai-asset-creator（C2・D-19）、spec（SC-E）、feature-mr（G3）、issue（D-21）、requirement（D-20） | SC-E01〜03（改名） |
| 5 提供コマンド 4 本とテスト | commit-push（A4・G2）、ticket（A5・G2）、report-view（A6・G2）、shell-script（A3・G5） | CP-T03 / CP-T06 / TICKET-T03 / TICKET-T05 / RV-T02 の観点追記、CP007 / RV008 / TK008 と重複見出し（TICKET-T03）のテスト観点（新） |
| 6 シェルスクリプトの規約 | shell-script 仕様（G10・G11・C1） | SS-T / TR-T の観点追記 |
| 7 食い違いの書き戻しと DDR | 上表すべて、DDR i0006-07〜12 | — |

## AI アセット設計チケット

| チケット | まとまり | 依存 |
|---|---|---|
| 0028 ai-asset-design | フック共通仕様（§1・§3・§6・§7・§8・§9・§11・§12・H6）+ post-push-usage-report / post-push-compact-prompt 仕様 + DDR i0006-07・08・09・12 | なし |
| 0029 ai-asset-design | 共通ステップ仕様 5 本: shell-script（A3・C1・G5・G10・G11）+ commit-push（A4・G2）+ ticket（A5・G2・G12）+ report-view（A6・G2・B9）+ ai-asset-creator（C2・D-19）+ DDR i0006-10・11 | 0028（台帳の番号 CP007 / RV008 / TK008 と HK-T15 を先に確定） |
| 0030 ai-asset-design | requirement / issue / feature-mr / spec 仕様（A7・G3・B3）+ 計画タスク仕様の B5 の一覧化 + ルール体系要件（A1・B1）+ 要件 4 本の節順と関連ドキュメント節（G4）+ 横断整合（機構要件・用語辞書・spec 仕様の節構成）の確認 | 0028・0029（台帳の接頭辞と節構成の判断を見る） |

- 実行者: main（全体計画の方針。2/3 以降はサブエージェント opus に戻す）。人間レビュー: 要（承認④により opus 自己レビューで代替。切れ目 1 回）。敵対的レビュー: 要（切れ目 1 回。`work-defaults` の「1 文書・50 行未満なら省略可」には当たらない — 3 枚で 10 文書超）
- やってよいこと: `.claude/docs/**`（要件・仕様・DDR・用語辞書）と `wip/**`。read
- DoD の型（各チケット共通）: 「担当の要件定義書・仕様書がテンプレートに沿って更新されている」「受け入れ条件 <X> が仕様のテスト観点（テスト ID）に落ちている」「横断文書・用語辞書と整合している」「決定の経緯が DDR に残っている」「ヘッドレス実行の帰結が書かれている」「参照先（他チケットの担当文書）の文言を再読して一致している」

次の計画チケット: 0031 `ai-asset-implementation-plan`（predecessors: 0028, 0029, 0030）。対象は設計で仕様に書いた実装 7 件（HK-T15 の ID 付け替え、eval 5 本の `SC-E` 改名、CP007 / RV008 / TK008 の出力、`hook_payload --session`、`skill.template.md` のガイド、shell-script SKILL.md の `make_counting_path`、`ticket.sh complete` の重複見出し検査）。全体まとめチケットはその実装計画が起こす。

## 保留した点

| 項目 | 決める時期 |
|---|---|
| G10 の規約節を仕様の「テスト観点」に置くか「Script 処理」のサブ節にするか（`20-common-step-spec` の固定節構成との整合） | 0029 |
| B5 のプレースホルダ表記の該当箇所（`10-task-*-exec.md` 等）の一覧 | 0030（grep して確定。件数が多ければ機械的な置換の可否も判断） |
| 用語「承認単位」「自己強制」の辞書追加 | 0030 |
| `HOOK_DENY_ID` の既定番号（`WF009` は台帳に無い） | 2/3（仕様には「呼び手が設定する」とだけ書く） |
