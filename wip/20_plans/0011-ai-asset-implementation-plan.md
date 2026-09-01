---
type: plan
title: 0011 AI アセット実装・テスト計画 — 基盤（ルール 4・hooks/lib 5 + config 2・共通ステップ 9 と提供コマンド・テスト）
description: issue #6 の範囲を固定順（設定・定義 → 中核 → 中核の機械テスト → スキル・ルール → 参照更新）のステップに割り、テスト ID の割付・許可範囲・提供コマンドへの切り替え境目・ロックアウト対策・参照更新一覧を定めた実装計画。実装チケット 0013〜0021 とフィードバック計画チケット 0022 を起こす
tags: [plan, ai-asset-implementation, issue-6]
keywords: [AI アセット実装計画, 固定順, 中核, 提供コマンド, ticket.sh, commit.sh, push.sh, check-html.sh, hooks/lib, frontmatter.sh, test-lib.sh, run-tests.sh, task-types.tsv, scope-limits.json, work-defaults, .gitattributes, 切り替え境目, ロックアウト対策, 参照更新一覧]
---

# 0011 AI アセット実装・テスト計画

## 対象

- issue #6 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/6 / PR #7 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/pull/7
- 根拠とする要件・仕様（0012 までの修正後が正）:
  - `10_spec/フック共通仕様.md` §1・§3・§5・§6・§7・§8・§9・§10・§11
  - `10_spec/skills/20-common-step-{shell-script,ticket,commit-push,report-view,ai-asset-creator,feature-mr,issue,requirement,spec}.md`
  - `00_requirement/rules/{ルール体系,work-defaults,logger,design-docs,ai-asset-design-docs}.md`
  - 設計結果レポート `wip/30_reports/0008-ai-asset-design.md`、調査結果レポート `wip/30_reports/0003-investigation.md`（申し送り H1〜H6・判断点）
- 実行者: 全チケットともメインエージェント（全体計画の方針。提供コマンド未完成のため）。人間レビューは切れ目 1 回（承認④により opus 自己レビューで代替）、敵対的レビュー 1 回

## 判断点の決着（調査「実装計画の判断点」と設計からの申し送り）

| 判断点 | 決定 | 根拠 |
|---|---|---|
| frontmatter パーサの置き場 | (b) `20-common-step-shell-script/scripts/frontmatter.sh`（設計で決定済み。DDR i0006-01） | 依存方向を logger と揃える |
| テスト方式 | 素の bash + `test-lib.sh` + `run-tests.sh`（設計で決定済み。DDR i0006-04） | 両 OS・依存追加なし |
| 計画書テンプレートのレイアウト（D18） | **サイドバー型に統一**（`reports-clean.template.html` の CSS 系統 1 つを計画書にも使う） | CSS を 1 系統に保ち、RV006 の `data-required` 導出と見た目を揃える。改変量は増えるが初版で済む |
| ルールの本数（体系の一覧は 15 本 = 成果物 8 + 行動 7。本文の「7 本」と表の 8 行が食い違う — 0022 の入力） vs issue の 4 本 | **本 issue は 4 本**（`work-defaults` / `logger` / `design-docs` / `ai-asset-design-docs`）。残り 11 本はフィードバック計画（0022）で送り先を決める | issue #6 の受け入れ条件が 4 本。`bash-script` / `markdown-docs` 等は参考実装の移植が主で、本 issue の成果物（sh・md）に効くため 3/3 より前倒しの価値はあるが、範囲の追加は人間の判断 |
| `web` の強制（F11） | 本 issue では扱わない（matcher は 2/3） | フック登録は 2/3 |
| `agent_type` の実物（F12） | 本 issue では扱わない（`subagent-stop-check` は 2/3） | 同上 |
| HK-T01（settings.json 照合）/ HK-T09（ラッパー） | 本 issue では書かない（フック登録が無い） | 2/3 で実装 |
| `work-defaults.md` の置き場 | S1（設定・定義）に置く。他のルール 3 本は固定順どおり S4-3 | HK-T02 の 3 データの 1 つ（tsv・json と同格の定義データ）で、ルール本文としての性格より整合テストの入力が先に要る |
| `push-detect.sh` / `transcript.sh` の lib 単位のテスト ID が仕様に無い（フック本体の PP-T / UR-T は 2/3） | 実装チケット 0015 はこの 2 本の ID が共通仕様 §11 に足されるまで着手しない。`ai-asset-design` の追加チケット 0024 で §11 に HK-T13（push の検知と成功判定）・HK-T14（transcript の差分集計）を追加する | 実装計画仕様 処理フロー「テスト ID が無い場合は実装チケットを起こさず、設計の追加チケットを起こす提案を返す」 |
| push の時期 | 本 issue はチケットごと（完了コミット直後、doing が空の時点）に push する（PR に進捗を残す。全体計画の手作業代替の運用を継続） | 境目 A 以降は `push.sh` の項目 3（md/html 対）が既存の md 単独の計画書・レポートで落ちるため、`wip/push-check-skip.md` が必要になる |
| 提供コマンドへの切り替え境目 | 下記「切り替え境目」 | 全体計画「機構未実装期間の手作業代替」 |

## 変更対象

| # | アセット | 新規/更新 | 仕様書の節 |
|---|---|---|---|
| A1 | `.gitattributes` | 新規 | 共通仕様 §8（`ai-asset-implementation.allow`。`*.sh text eol=lf` が sh の前提） |
| A2 | `.claude/hooks/config/task-types.tsv` | 新規 | `00-workflow-issue-mr-driven` 仕様 OUT ひな形（列 `#` / type / タスク名 / 担当 / スキル名 / 対の相手）、対応表（15 行） |
| A3 | `.claude/hooks/config/scope-limits.json` | 新規 | 共通仕様 §8（構造・キー規則・初期値表） |
| A4 | `.claude/rules/work-defaults.md` | 新規 | 要件 `rules/work-defaults.md`（15 種 × 実行者・人間レビュー・敵対的レビュー・理由・調整条件）。行動ルール |
| A5 | `.claude/skills/20-common-step-shell-script/scripts/{logger,frontmatter,test-lib,run-tests}.sh`、`assets/{script,test}.template.sh` | 新規 | `20-common-step-shell-script` 仕様 Script 処理（読み込み行・終了コード・frontmatter.sh・run-tests.sh・logger.sh）、OUT ひな形 |
| A6 | `.claude/hooks/lib/{hook-common,cmdpos,scope,push-detect,transcript}.sh` | 新規 | 共通仕様 §1（一覧）・§3（出力・redact・fail-closed）・§4（緊急停止）・§5（記録）・§7（cmdpos）・§8（scope）・§10（ヘッドレス） |
| A7 | `.claude/skills/20-common-step-commit-push/scripts/{commit,push}.sh`、`assets/exclude-patterns.txt` | 新規 | `20-common-step-commit-push` 仕様 Script 処理 |
| A8 | `.claude/skills/20-common-step-ticket/scripts/ticket.sh`、`assets/ticket.template.md` | 新規 | `20-common-step-ticket` 仕様 Script 処理・OUT ひな形 |
| A9 | `.claude/skills/20-common-step-report-view/scripts/check-html.sh`、`assets/{report,plan}.template.html` | 新規 | `20-common-step-report-view` 仕様 Script 処理・OUT ひな形 |
| A10 | `.claude/skills/20-common-step-{shell-script,ticket,commit-push,report-view}/SKILL.md` | 新規 | 各仕様の処理フロー・参照ナレッジ |
| A11 | `.claude/skills/20-common-step-{ai-asset-creator,feature-mr,issue,requirement,spec}/SKILL.md` と assets（`skill.template.md`・`eval.template.md`・`mr-body.template.md`・`issue.template.md`・`issue-addendum.template.md`・`requirements.template.md`。`spec` はテンプレートを持たない） | 新規 | 各仕様の処理フロー・OUT ひな形・参照ナレッジ |
| A12 | `.claude/evals/20-common-step-{ai-asset-creator,feature-mr,issue,requirement,spec}.md` | 新規 | 各仕様「テスト観点（eval）」、`ai-asset-creator` 仕様 処理フロー 5 |
| A13 | `.claude/rules/{logger,design-docs,ai-asset-design-docs}.md` | 新規 | 要件 `rules/logger.md`・`design-docs.md`・`ai-asset-design-docs.md`、`ルール体系.md`「成果物ルールの章スキーマ」（7 章固定・該当なしは根拠 1 行） |
| A14 | テスト: `.claude/skills/*/scripts/tests/test_*.sh`、`.claude/hooks/lib/tests/test_*.sh`、`.claude/hooks/tests/test_config_integrity.sh` | 新規 | 各仕様「テスト観点」、共通仕様 §11 |
| A15 | `wip/push-check-skip.md`（一時。HTML 遡及作成後に削除）、既存計画書・レポートの HTML（`wip/20_plans/*.html`・`wip/30_reports/*.html`。付録を除く） | 新規 → 削除 / 新規 | `commit-push` 仕様 push.sh 2、`report-view` 仕様 |

## 許可範囲案

全チケット共通の上限は共通仕様 §8 の `ai-asset-implementation`（`.claude/docs/**` は deny）。宣言はステップごとに最小にする。

| ステップ | write | ops |
|---|---|---|
| S1（設定・定義） | `.gitattributes`, `.claude/hooks/config/**`, `.claude/rules/work-defaults.md`, `wip/**` | read |
| S2-1（shell-script 中核） | `.claude/skills/20-common-step-shell-script/**`, `.claude/hooks/tests/**`, `wip/**` | read, build-test, hook-test |
| S2-2（hooks/lib） | `.claude/hooks/lib/**`, `wip/**` | read, build-test, hook-test |
| S2-3（commit/push） | `.claude/skills/20-common-step-commit-push/**`, `wip/**` | read, build-test, hook-test |
| S2-4（ticket） | `.claude/skills/20-common-step-ticket/**`, `wip/**` | read, build-test, hook-test |
| S2-5（check-html） | `.claude/skills/20-common-step-report-view/**`, `wip/**` | read, build-test, hook-test |
| S4-1（SKILL.md 4 本 + ai-asset-creator のテンプレート 2 本） | `.claude/skills/20-common-step-{shell-script,ticket,commit-push,report-view}/**`, `.claude/skills/20-common-step-ai-asset-creator/assets/**`, `wip/**` | read |
| S4-2（SKILL.md 5 本・assets・eval） | `.claude/skills/20-common-step-{ai-asset-creator,feature-mr,issue,requirement,spec}/**`, `.claude/evals/**`, `wip/**` | read |
| S4-3 + S5（ルール 3 本・参照更新・HTML 遡及） | `.claude/rules/**`, `wip/**` | read, build-test, hook-test |

- `wip/**` は `common.allow` により宣言によらず書ける（§8 判定順 (5)。`d.write` の `wip/**` は意図の記録で判定には効かない）
- テストの実行は `run-tests.sh`（提供コマンド。フックは分類を問わず許可）経由で、`run-tests.sh` 自身が作業中チケットの `allow.ops` に `build-test`（`.claude/hooks/**` のテストを含めば `hook-test` も）を要求する（TR006）。テストを実行するチケットは両方を宣言する。§8 の `build-test`（`tests/` 配下の sh）と `hook-test`（`.claude/hooks/**/tests/*.sh`・`.claude/skills/*/scripts/tests/*.sh`）の定義が重なる点は 0022 の入力
- `logs/` は判定対象外（§5）。`.claude/docs/**` への書き込みが必要になったら作業ログ「仕様からの逸脱」に記録し、フィードバック計画（0022）へ回す。

## テスト方針

機械テストは `test-lib.sh` の assert に仕様の ID を渡し `PASS <ID>` / `FAIL <ID>: …` を出す。実行は `bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh [--filter <glob>] --ids`（run-tests.sh 完成前の S2-1 内は `bash <test>` 直接）。eval は定義まで（実行しない）。

| テスト ID | ステップ | 種別 | 実行方法 / eval 定義の置き場 |
|---|---|---|---|
| LG-T01〜05, SS-T01〜04, FR-T01〜05, TR-T01〜05 | S2-1 | 機械 | `scripts/tests/test_{logger,templates,frontmatter,run_tests}.sh`（shell-script） |
| HK-T02 | S3-1（S2-1 と同じチケット） | 機械 | `.claude/hooks/tests/test_config_integrity.sh`（tsv × json × work-defaults の type 集合と件数） |
| HK-T03（lib 部分: `hook_enforce_enabled` の判定と `disabled` 記録）, HK-T04（依存不足で deny ヘルパが WFx09 を出す）, HK-T05, HK-T06, HK-T07, HK-T08, HK-T10, HK-T11, HK-T12, HK-T13・HK-T14（0024 で §11 に追加後） | S2-2 | 機械 | `.claude/hooks/lib/tests/test_{hook_common,cmdpos,scope,push_detect,transcript}.sh`。フック本体が要る HK-T01・T09 と T03 の登録部分は 2/3 |
| CP-T01〜07 | S2-3 | 機械 | `commit-push/scripts/tests/test_{commit,push}.sh`（一時リポジトリ + bare リモート） |
| TICKET-T01〜11 | S2-4 | 機械 | `ticket/scripts/tests/test_ticket.sh`（一時リポジトリ。`commit.sh` 実物を呼ぶ） |
| RV-T01〜06 | S2-5 | 機械 | `report-view/scripts/tests/test_check_html.sh`（テンプレートを正しく埋めた HTML と壊した HTML） |
| AC-E01〜03, FM-E01〜03, IS-E01〜03, RQ-E01〜03, SP-E01〜03 | S4-2 | eval | `.claude/evals/20-common-step-<名前>.md`（`eval.template.md` から。未実行を明記） |
| 本 issue の対象外（フック本体・boundary.sh・finalize.sh のテスト ID: WE-T / SA-T / SP-T（subagent-stop-check）/ BC-T / BG-T / WG-T / SG-T / PP-T / UR-T / DC-T は 2/3、BD-T / FN-T は 3/3） | — | — | 割り付けない（実装対象が無い）。網羅性の確認は「仕様の全 ID − この行 = 上の行の合計」 |
| 規約検査（受け入れ条件 6） | 各 S2 | 機械 | 各テストに「`logs/sh/<name>.log` に行が書かれる」「最終行が `OK:` / `<ID>:`」「stdout にログが混ざらない」「終了コード 0/1/2」のケースを含める。`bash -n` を全 sh に実行（shellcheck 不在は作業ログに記録） |

受け入れ条件 4（SKILL.md と assets が仕様と 1:1）は機械テストを持たないため、S4 のチケットは DoD に「仕様の処理フロー・OUT ひな形・参照ナレッジ × SKILL.md の節」の対応表を作業ログに残す。

完了前の検査（exec 仕様）の範囲: プレースホルダ検査（`{{名前}}`・`TODO`・`TBD`）は **テンプレート（`**/assets/*.template.*`）を対象外**にする（テンプレートはプレースホルダを持つのが正）。テンプレートは frontmatter が完成形として正しいことを検査する。実装結果レポート `wip/30_reports/0013-ai-asset-implementation.md` は 0013 が作成し、0014〜0020 が担当ステップの節を追記、0021 が集約する（実施タスクの共通手順 4）。

## ステップ（固定順）

| 順 | ステップ | 内容 | 依存 | チケット |
|---|---|---|---|---|
| S1 | 設定・定義 | (1) `.gitattributes`（`* text=auto` は置かず、`*.sh text eol=lf`・`*.tsv text eol=lf`・`*.json text eol=lf`・`*.html text eol=lf` の最小形。既存 md の再正規化を起こさない）(2) `task-types.tsv`（15 行・6 列）、`scope-limits.json`（§8 初期値。`types` 15 種すべてに `ops` 必須、`common` 5 キー。`commands.build-test` は空配列 — このリポジトリに外部のビルド・テストコマンドは無く、機構のテストは提供コマンド `run-tests.sh` 経由）(3) `rules/work-defaults.md`（行動ルール。15 行の表。初期値案は下記）(4) 実装結果レポートの作成 | — | 0013 |
| S0 | 設計差し戻し | 共通仕様 §11 に lib 単位のテスト ID HK-T13（push-detect）・HK-T14（transcript）を追加（`ai-asset-design` の追加チケット。`.claude/docs/**` は実装チケットでは書けない） | — | 0024 |
| S2-1 | 中核 | `script.template.sh` / `test.template.sh` → `test-lib.sh` → `logger.sh` → `frontmatter.sh` → `run-tests.sh` の順（雛形を先に固定し、以降の sh は雛形からコピーする）。各 sh はテスト先行 | 0013 | 0014 |
| S3-1 | 中核の機械テスト | HK-T02 `test_config_integrity.sh`（S1 の成果を S2-1 の道具で検査） | S2-1 | 0014 |
| S2-2 | 中核 | `hook-common.sh`（`hook_jq`・入力読取・`redact`・deny/ask/notify ヘルパ・`decisions.jsonl`・セッション状態・緊急停止・ヘッドレス置換）→ `cmdpos.sh` → `scope.sh`（`frontmatter.sh` を `source`）→ `push-detect.sh` → `transcript.sh`。1 lib ごとにテストを通してから次へ | 0014, 0024 | 0015 |
| S2-3 | 中核 | `exclude-patterns.txt` → `commit.sh` → `push.sh`。完了直後に **切り替え境目 A** | 0014 | 0016 |
| S2-4 | 中核 | `ticket.template.md` → `ticket.sh`（create / start / complete / cancel / next。状態変更は `commit.sh` 経由）。完了直後に **切り替え境目 B** | 0016 | 0017 |
| S2-5 | 中核 | `report.template.html` / `plan.template.html`（`reports-clean.template.html` を土台に固有記述を削除、`data-required` は Q5 の案）→ `check-html.sh`（RV001〜007。RV006 はテンプレートから導出）。完了直後に **切り替え境目 C** | 0014 | 0018 |
| S4-1 | スキル | `ai-asset-creator` の `skill.template.md` / `eval.template.md`（SKILL.md のひな形を先に）→ SKILL.md 4 本（shell-script / ticket / commit-push / report-view。スクリプトの使い方・処理フロー・参照ナレッジ。規約の再掲禁止） | 0017, 0018 | 0019 |
| S4-2 | スキル | SKILL.md 5 本 + assets 4 本（`mr-body` / `issue` / `issue-addendum` / `requirements`）+ eval 定義 5 本 | 0019 | 0020 |
| S4-3 | ルール | `logger.md` / `design-docs.md` / `ai-asset-design-docs.md`（成果物ルール。7 章固定・該当なしは根拠 1 行・`paths` を frontmatter に） | 0015, 0020 | 0021 |
| S5-1 | 参照更新 | 下記「参照更新一覧」の検索を再実行し件数が増えていないことを記録。既存計画書・レポートの HTML を `plan.template.html` / `report.template.html` から作り `check-html.sh` を全件通す。`wip/push-check-skip.md` を削除。全テスト実行と実装結果レポートの集約 | S4-3（同じチケット） | 0021 |

依存欄はチケットの `predecessors` と同じ値（チケット側が導出元）。

`work-defaults.md` の初期値案（全体計画の方針をサブエージェント前提に直したもの。1 type 1 行、並びは対応表の 15 種順。HK-T02 はこの表の 1 列目を type 集合として読む）:

| 種類 | 既定の実行者 | 人間レビュー | 敵対的レビュー | 理由（要約） | 調整してよい条件 |
|---|---|---|---|---|---|
| overall-plan | メインエージェント | 要 | 不要 | フェーズ列と方針の合意は人間 | なし（常に要） |
| investigation-plan | サブエージェント（`opus`） | 不要 | 不要 | 計画書は調査結果と一緒に見る | 問いが issue の受け入れ条件を超えるなら要 |
| investigation | サブエージェント（`sonnet`） | 要 | 不要 | 結論が後続の計画を左右する | 読むだけの小さな調査（1 観点）は不要に下げてよい |
| design-plan | サブエージェント（`opus`） | 不要 | 不要 | 計画書は設計結果と一緒に見る | 対象なしの見込みなら省略可 |
| design | サブエージェント（`opus`） | 要 | 要 | 正史の変更 | 差分が 1 文書・50 行未満なら敵対的レビューを省略してよい |
| implementation-plan | サブエージェント（`opus`） | 要 | 不要 | 許可範囲とロックアウト対策を先に見る | 中核を含まなければ不要に下げてよい |
| implementation | サブエージェント（`sonnet`） | 要 | 要 | 振る舞いが変わる | 機械テスト全通過なら人間レビューを「approve のみ」に軽くしてよい |
| feedback-plan | メインエージェント | 要 | 不要 | 後続フェーズの要否は人間の判断 | なし |
| design-feedback-plan | サブエージェント（`opus`） | 不要 | 不要 | 計画書は反映結果と一緒に見る | — |
| design-feedback | サブエージェント（`opus`） | 要 | 要 | 正史の変更 | 差分が 1 文書・50 行未満なら敵対的レビューを省略してよい |
| ai-asset-design-plan | サブエージェント（`opus`） | 不要 | 不要 | 計画書は設計結果と一緒に見る | 対象なしの見込みなら省略可 |
| ai-asset-design | サブエージェント（`opus`） | 要 | 要 | 正史の変更 | 差分が 1 文書・50 行未満なら敵対的レビューを省略してよい |
| ai-asset-implementation-plan | サブエージェント（`opus`） | 要 | 不要 | 許可範囲とロックアウト対策を先に見る | 中核（フック・settings.json）を含まなければ不要に下げてよい |
| ai-asset-implementation | サブエージェント（`opus`。中核を含まなければ `sonnet`） | 要 | 要 | 中核の変更は自分を止め得る | 中核を含まず機械テスト全通過なら人間レビューを「approve のみ」に軽くしてよい |
| overall-summary | メインエージェント | 要（`--final`） | 不要 | 片付け前の最終確認 | なし |

## 切り替え境目（提供コマンドへの移行）

| 境目 | 時点 | それ以降 | 影響 |
|---|---|---|---|
| A | 0016 完了（`commit.sh` / `push.sh` のテスト全通過 + 0016 自身の完了コミットを `commit.sh` で行えた） | コミットは `bash .claude/skills/20-common-step-commit-push/scripts/commit.sh -m "<件名>" <パス>...`、push は `bash .claude/skills/20-common-step-commit-push/scripts/push.sh` | push.sh の項目 3（md/html 対）が既存の md 単独の計画書・レポートで未充足になる → 0016 で `wip/push-check-skip.md` に「項目 3: `check-html.sh` 未完成のため HTML は 0021 で遡及作成」と書いてコミットする。項目 2 は切れ目（doing 空）で push するので通る |
| B | 0017 完了（`ticket.sh` のテスト全通過。0017 自身の完了も `ticket.sh complete` で行う — 成果物を先に `commit.sh` でコミットしておけば「チケット以外の未コミットなし」の検査は通る。完了後に `ticket.sh next` が 0018 を返すことを確認） | チケットの作成・着手・完了は `bash .claude/skills/20-common-step-ticket/scripts/ticket.sh <sub>`。既存チケット（0018〜0024）は手作業で作ったものだが frontmatter・見出しは同じ形なので `start` / `complete` の検査対象になる | `complete` の検査（DoD 全チェック・根拠・現在地の消込・「AI アセットに反映すべき内容」非空・未コミットなし）を満たさないと完了できない。0018 以降の作業ログはこれを前提に書く。境目以降に手作業でチケットを動かすことはしない（ticket 仕様の禁止事項） |
| C | 0018 完了 | 計画書・レポートは md + HTML の対で作り `check-html.sh` を通す。0021 で既存分を遡及作成 | 以降の結果報告（実装結果レポート・フィードバック計画書）は HTML 付き |

境目の前後で手作業に戻すのは、提供コマンド自身の不具合で作業が止まったときだけ（理由を作業ログ「拒否・確認・迂回の記録」に残し、不具合は同じチケット内で直す）。

## 参照更新一覧

本 issue で改名・移設するアセットは無い（すべて新規）。旧名の残存検索は「検索した」ことの記録として残し、3/3 の参照更新の入力にする。

| 名称・パス | 検索語 | ヒット箇所（`.claude/docs` を除く `.claude/` 配下。2026-09-01） | 除外 |
|---|---|---|---|
| 参考実装の提供コマンド置き場 | `\.claude/scripts/` | 0 件 | — |
| 参考実装の lib | `workflow-lib.sh` | 1 件（`00-workflow-quick-request/evals/evals.json`） | 旧ワークフロースキルの eval。3/3 で更新 |
| 参考実装の境界コマンド | `work-boundary.sh` | 26 件（`00-workflow-issue-mr-driven/SKILL.md`・`evals/evals.json`） | 旧ワークフロースキル。3/3 で `boundary.sh` に置換 |
| 参考実装の片付けコマンド | `merge-prep.sh` | 26 件（`00-workflow-issue-mr-driven/SKILL.md`・`evals/evals.json`・`assets/issue-notify.template.md`） | 旧ワークフロースキル。3/3 で `finalize.sh` に置換 |
| 旧タスクスキル名 | `10-work-` | 31 件（`00-workflow-issue-mr-driven/SKILL.md`・`evals/evals.json`、`00-workflow-quick-request/SKILL.md`） | 3/3 |
| 旧共通ステップ名 | `20-task-gh-` | 25 件（同上 2 スキルの SKILL.md） | 3/3 |
| PowerShell 版 logger | `logger\.ps1` | 0 件 | — |
| 参考の種別定義 | `workflow-types\.json` | 0 件 | — |
| `commit.sh` の旧引数形 | `commit.sh -m "[^"]*" --` | `.claude/docs` 内 0 件（0012 で修正済み）| DDR i0006-02 は修正済みの文言 |

S5-1 で同じ検索語（`grep -roE "<語>" .claude --include='*.md' --include='*.sh' --include='*.json' --exclude-dir=docs | wc -l`）を再実行し、件数が上の値から増えていないことを確認する（新規アセットが旧名を持ち込まないこと）。除外は DDR・用語辞書の別名（`.claude/docs` 配下）と、3/3 で置換する旧ワークフロースキル 2 本。

## ロックアウト対策

- `.claude/settings.json` にフックは登録されていない（確認: `hooks` キーなし。2026-09-01）。本 issue はフック本体を作らず登録もしないため、**フックによるロックアウトの経路は無い**
- 残る「自分が止まる」経路は提供コマンドの検査であり、各境目の直後に次の操作で確認する:

| 境目 | 最初の操作 | 止まったときの復旧 |
|---|---|---|
| A | 0016 の完了直前のコミット（成果物）を `commit.sh` で行う | CP001〜004 の理由を読み、コマンドの不具合なら 0016 内で直す（テストにケースを追加）。規約側の理由（件名・除外）なら入力を直す。直せないときは報告して停止する（`git commit` への回帰はユーザーの明示があるときだけ — commit-push 仕様の禁止事項） |
| A | 切れ目の push を `push.sh` で行う | CP005 の未充足一覧のうち項目 3 は `wip/push-check-skip.md` で飛ばす（理由付き・コミット済み）。項目 1・2 は状態を直す。CP006 は報告して止まる |
| B | `ticket.sh next` → `ticket.sh start 0018` | TK004 / TK006 なら置き場・先行の実態を直す。`start` の巻き戻しが効くこと（拒否時に `00_todo/` に残る）を確認 |
| B | 0017 自身の `ticket.sh complete`、続いて 0018 の `start` / `complete` | TK003 の未充足一覧に従って DoD の根拠・作業ログを埋める。検査自体の誤判定なら報告して停止し、0017 に戻って `ticket.sh` を直す（0017 の許可範囲内。0017 完了後に見つかった場合は同種の追加チケットで直す）。手作業でチケットを動かさない |
| C | 0018 のレポート HTML を `check-html.sh` に通す | RV001〜007 の理由に従って HTML を直す。RV007（0 件検出）はテンプレート側の id 欠落を疑う |

- `.gitattributes` の追加は既存ファイルの再正規化を起こさないパターンだけにする（`*.md` を含めない）。追加後 `git status` が空であることを確認する
- 基準点への戻し: `git checkout <base_sha> -- <path>`（各チケットの `base_sha`）。`WORKFLOW_ENTRY_ENFORCE=0` 等の強制無効化は使わない（本 issue に該当フックが無い）

## リスク

| リスク | 影響 | 対処・巻き戻し |
|---|---|---|
| Windows Git Bash 固有の差（jq の CRLF・fork 遅延・`printf %(%:z)T` 不可・MSYS のパス変換） | テストが CI（Linux）と Windows で結果が変わる | H6 の対策を `hook-common.sh` / `test-lib.sh` に集約し、両環境で通す前提でテストを書く。Windows 固有の失敗は理由付きでケースを分ける |
| `commit.sh` の除外パターンが `wip/tmp/**` 以外を過剰に除外 | 必要なファイルがコミットから落ちる | CP-T03 に「除外一覧の出力」を含め、除外は必ず表示。パターンは最小 |
| `ticket.sh complete` の検査が厳しく既存チケットの形と合わない | 0018 以降の完了が止まる | 境目 B の確認で `complete` を先に 0017 の一時リポジトリで既存チケットのコピーに対して試す（TICKET-T03 のケースに実物の 0012 相当を使う） |
| HTML テンプレートの必須節の決め方（D16・D17）が実施タスクの節と合わない | RV006 が正しい HTML を落とす | 0018 で 0003・0008 のレポートを試し埋めして通す。必須節の判断は DDR に残す（`.claude/docs` は書けないので 0022 へ） |
| 参照更新が 3/3 に残る | 旧 SKILL.md が新コマンドを知らない期間が続く | 本 issue の間は手作業代替（全体計画）で運用。3/3 の入力として一覧を残す |

巻き戻しは各チケットの `base_sha` 単位。提供コマンドの導入後に問題が出た場合は境目の前の運用（手作業代替）に戻し、理由を記録する。

## 実装チケットと次の計画チケット

| チケット | 種類 | ステップ | 先行 |
|---|---|---|---|
| 0013 | ai-asset-implementation | S1 | — |
| 0014 | ai-asset-implementation | S2-1・S3-1 | 0013 |
| 0015 | ai-asset-implementation | S2-2 | 0014, 0024 |
| 0016 | ai-asset-implementation | S2-3（境目 A） | 0014 |
| 0017 | ai-asset-implementation | S2-4（境目 B） | 0016 |
| 0018 | ai-asset-implementation | S2-5（境目 C） | 0014 |
| 0019 | ai-asset-implementation | S4-1 | 0017, 0018 |
| 0020 | ai-asset-implementation | S4-2 | 0019 |
| 0021 | ai-asset-implementation | S4-3・S5-1 | 0015, 0020 |
| 0022 | feedback-plan | 実装で見つかった仕様との食い違い・TBD 検証結果の棚卸し、後続フェーズの要否、ルール 11 本の送り先 | 0013〜0021, 0023, 0024 |
| 0023 | ai-asset-implementation-plan（追加） | 0011 の自己レビュー指摘 R1〜R17 の反映 | 0011 |
| 0024 | ai-asset-design（追加） | S0: 共通仕様 §11 に HK-T13 / HK-T14 を追加 | — |

`next` の選び方（先行がすべて完了した最小連番）により、実行順は 0013 → 0014 → 0016 → 0017 → 0018 → 0024 → 0015 → 0019 → 0020 → 0021 → 0022 になる（0015 は 0024 の完了を待つ）。

## 保留した点

| 項目 | 決める時期 |
|---|---|
| ルール残り 11 本（`markdown-docs` / `plan-report` / `html-view` / `bash-script` / `ai-asset-authoring` / `agent-common` / `directory-structure` / `document-lifecycle` / `git-workflow` / `ai-command-style` / `headless-awareness`）の実装時期 | 0022 フィードバック計画 |
| `web` の強制・`agent_type` の実物・HK-T01/T09・§12 T1〜T4 | 2/3 |
| shellcheck の CI 実行 | 2/3 以降 |
| §8 の `build-test`（`tests/` 配下の sh）と `hook-test` の定義の重なり・優先 | 0022（仕様の書き戻し候補） |
| 接頭辞 `SP-` が `subagent-stop-check`（SP-T）と `20-common-step-spec`（SP-E）で重複 | 0022（§6 の書き戻し候補） |
| exec 仕様のプレースホルダ表記 `<...>` とテンプレートの `{{名前}}` の表記差 | 0022（実装は `{{名前}}` を採り、逸脱として記録） |
| `commands.build-test` の中身（外部コマンドの列挙。提供コマンドは分類を問わず許可されるため含めない） | 0013 で空配列。プロジェクトが調整 |
