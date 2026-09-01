---
type: overall-plan
title: issue #9 全体計画 — 自己改善ワークフロー機構の実装 2/3（フック本体と登録）
description: フック本体 11 本の実装・settings.json への登録（人間の操作）・フック共通仕様 §12 の TBD T1〜T4 の実測検証を行う issue の全体計画。フェーズ列、受け入れ条件との対応、work-defaults との差分としての実行者・レビュー要否・やってよいこと、登録によるロックアウトの段取りを定める
tags: [overall-plan, issue-9, ai-asset]
keywords: [全体計画, フェーズ列, AI アセット, フック本体, settings.json 登録, TBD 検証, プローブフック, ロックアウト, work-defaults, HK-T01]
---

# issue #9 全体計画 — 自己改善ワークフロー機構の実装 2/3（フック本体と登録）

## 対象

- 対象 issue: #9 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/9
- MR: #12 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/pull/12（draft）
- ブランチ: `feature-9-hook-bodies-settings`（`origin/main` 058855e から分岐。058855e は #6 の PR #7 が squash で入った版）
- マージ方式: リポジトリは squash / merge commit / rebase のすべてが許可（`gh repo view --json squashMergeAllowed,mergeCommitAllowed,rebaseMergeAllowed` → すべて true）。main の履歴は #2・#5・#7 とも squash で 1 コミットに畳まれているので、本 MR も squash 前提とする（既定の設定変更は行わない）

## 種別

**AI アセット**。変更対象は `.claude/hooks/<イベント>/*.sh` と各テスト、`.claude/settings.json`（登録は人間）、および検証結果の書き戻し先 `.claude/docs/`（`10_spec/フック共通仕様.md`・各フック仕様・`20_ddr/`）。`docs/`・アプリのソースコードは含まない。

## フェーズ列

AI アセットのテンプレート（`10_spec/skills/00-workflow-issue-mr-driven.md`「フェーズ列のテンプレート」）をそのまま採用する。省略なし。

| 順 | フェーズ | チケット種類 | この issue での中身 |
|---|---|---|---|
| 1 | 全体計画 | `overall-plan` | 本計画（このチケット） |
| 2 | 調査 | `investigation-plan` → `investigation` | §12 の TBD **T1〜T4** と、実装の前提になる実物の形（`tool_response` の終了コードのフィールド名 = T7、`agent_type` / `model`、`WebFetch` / `WebSearch` の matcher 外の扱い、`permissionDecision: "defer"`）を、`wip/tmp/probe/` に置いたプローブフックで実測する。プローブの `settings.json` への一時登録と撤去は**人間の操作**（AI は貼り付ける JSON と手順を用意する）。あわせて `settings.json` 本登録の段取り（段階登録・切り戻し・緊急停止）の材料を集める |
| 3 | AI アセット設計 | `ai-asset-design-plan` → `ai-asset-design` | 調査結果を仕様に書き戻す: §12 の T1〜T4（＋分かれば T7）を消す / §2 の入力フィールドの確定 / `HOOK_DENY_ID` の既定を §6 の台帳と整合させる / 「作業中チケット 2 枚以上」の扱い（WF207 と `push.sh`・`run-tests.sh`・完了検査の非対称の解消方針）/ `web` の強制の可否（0022 D3）/ `investigation` 以外の実施タスクの `ops` 上限（0022 D5）/ `shellcheck` を CI で回す方針（0022 D6。方針決定まで）。経緯は DDR `i0009-NN` に残す |
| 4 | AI アセット実装・テスト | `ai-asset-implementation-plan` → `ai-asset-implementation` | 主作業。フック本体 11 本（案内側 6 本 → 拒否側 5 本の順）と各テストを実装 → `settings.json` への登録（人間）→ HK-T01（登録照合）と `run-tests.sh --ids` の全件通過。lib 5 本と `config/` は #6 で済んでいるので、この issue は本体・結線・登録に絞る |
| 5 | フィードバック計画 | `feedback-plan` | 実装で判明した仕様との食い違い・登録で分かったことを棚卸しし、追加の AI アセット設計（書き戻し + DDR）の要否を決める |
| 6 | 後続（フィードバック計画が選んだものだけ） | `ai-asset-design` 系 / `ai-asset-implementation` 系 | 未定 |
| 7 | 全体まとめ | `overall-summary` | 統括レポート、MR 本文の最終整形（成果物リンク一覧を本文の表に置く）、片付け、draft 解除 |

テンプレートとの差分: なし。フェーズ 3（AI アセット設計）は「対象あり」を見込む（調査結果の書き戻しが必ず発生するため）。実装フェーズは `.claude/docs/**` に書けない（`scope-limits.json` の `ai-asset-implementation.deny`）ので、書き戻しは必ずフェーズ 3 か 6 で行う。

## 受け入れ条件との対応

| # | issue #9 の受け入れ条件 | 満たすフェーズ | 検証の形 |
|---|---|---|---|
| 1 | フック本体 11 本が各仕様の判定順・識別子・終了方式どおりに動き、テスト（HK-T01 / HK-T09 / HK-T03 の登録部分を含む）が失敗ケースを含めて通る | 4 | 各フック仕様のテスト ID 表（SS-H\* / WE-T\* / WG-T\* / …）＋ 共通の HK-T01・T03・T04・T09 を `run-tests.sh` で実行 |
| 2 | `settings.json` への登録手順（人間の操作）が全体計画と結果報告に書かれ、登録後に `run-tests.sh --ids` の全件と HK-T01 が通る | 1（本計画の「settings.json の登録とロックアウト対策」）→ 4 | 登録前後のテスト結果を実装結果報告に記録 |
| 3 | §12 の TBD T1〜T4 の検証結果が共通仕様に反映され、経緯が DDR に残っている | 2 → 3 | 調査結果報告の実測ログ、共通仕様 §12 の該当行の消滅、DDR `i0009-NN` |
| 4 | `HOOK_DENY_ID` の既定と「作業中チケット 2 枚以上」の扱いが仕様（§6・該当フック）に決まり、テストで固定されている | 3 → 4 | 仕様の差分 ＋ テスト（WG-T\*（WF207）・登録ラッパーの WFx09） |
| 5 | `tool_response` / `agent_type` / `web` の強制 / `defer` の扱いが実物の確認に基づいて仕様に書かれている（扱わないものは理由つきで「扱わない」） | 2 → 3 | 調査結果報告の実測表 ＋ 共通仕様 §2・§8 の差分 |
| 6 | 実装で判明した仕様との食い違いは仕様書へ書き戻し、経緯を DDR に残している | 4（作業ログ「仕様からの逸脱」）→ 5 → 6 | フィードバック計画の棚卸し表、DDR |

## 方針

基準は `.claude/rules/work-defaults.md`（#6 で作成済み。この issue が初めてこの表を基準として使う）。

| type | 基準（work-defaults） | この issue | 差分の理由 |
|---|---|---|---|
| overall-plan | メイン / 人間レビュー要 / 敵対的不要 | 基準どおり | — |
| investigation-plan | opus サブ / 不要 / 不要 | **メインエージェント** | 下記（※1） |
| investigation | sonnet サブ / 要 / 不要 | **メインエージェント**・人間レビュー要 | （※1）。T1〜T4 の検証はプローブフックの登録（人間の操作）と往復が要り、結論が実装計画を左右するのでレビューは基準どおり要 |
| ai-asset-design-plan | opus サブ / 不要 / 不要 | **メインエージェント** | （※1） |
| ai-asset-design | opus サブ / 要 / 要 | **メインエージェント**・要 / 要 | （※1）。正史（仕様・DDR）の変更なので敵対的レビューは基準どおり要 |
| ai-asset-implementation-plan | opus サブ / 要 / 不要 | **メインエージェント**・要 | （※1）。中核（フック・`settings.json`）を含むので人間レビューは基準どおり要 |
| ai-asset-implementation | opus サブ / 要 / 要 | **メインエージェント**・要 / 要（切れ目ごと 1 回） | （※1）。中核そのものなので軽減しない |
| feedback-plan | メイン / 要 / 不要 | 基準どおり | — |
| overall-summary | メイン / 要（最終確認）/ 不要 | 基準どおり | — |

（※1）**実行者を全種類メインエージェントに倒す**。理由: サブエージェントの起動テンプレートと `task-executor` エージェントは 3/3（#10）の範囲で未実装であり、チケットの状態遷移・コミットの作法をサブエージェントに教える手段が無い。加えて、この issue で作る `subagent-start-check` はサブエージェントの実行者（`model`）とチケットの `executor` を突き合わせるフックであり、その検査対象の運用を検査の実装と同時に始めると、失敗の原因が「運用の誤り」か「フックの欠陥」か切り分けられない。サブエージェントは **T1・T2・T4 の検証（プローブ用の起動）と、敵対的レビュー**にだけ使う。既定のサブエージェント運用は #10 で提供コマンド・エージェントが揃ってから始める。

人間レビューの代替（承認④の扱い）: #6 と同じく、切れ目ごとの人間レビューを **opus サブエージェントによる敵対的自己レビュー**で代替する。差分を渡してレビューさせ、confidence >= 0.5 の指摘は同じ type の追加チケットに落としてから次のタスクへ進む。レビュー依頼コメントの MR への投稿は証跡として続ける。マージは人間が行う（`gh pr merge` は実行しない）。

やってよいこと（`allow`。`scope-limits.json` の上限の内側で絞る）:

| type | write | ops |
|---|---|---|
| 計画系（`*-plan`）・`feedback-plan` | `wip/**` | `read`, `remote-read` |
| `investigation` | `wip/**`（プローブフックは `wip/tmp/probe/**`。記録は `logs/**` で判定対象外） | `read`, `remote-read`, `build-test`, `web`（公式 hooks リファレンスの確認） |
| `ai-asset-design` | `.claude/docs/**`, `wip/**` | `read`, `remote-read` |
| `ai-asset-implementation` | `.claude/hooks/**`, `.claude/skills/20-common-step-shell-script/**`（テストヘルパの拡張が要る場合のみ）, `wip/**` | `read`, `build-test`, `hook-test`, `remote-read` |
| `overall-summary` | `wip/**` | `read`, `remote-read`, `remote-write:mr-edit`, `remote-write:mr-comment`, `remote-write:issue-create`, `remote-write:push`, `remote-write:draft-ready` |

- `.claude/settings.json` は**どの type でも AI が書かない**（宣言にも入れない）。登録は人間が行う
- `CLAUDE.md` / 旧ワークフロースキル / 用語集の参照更新は 3/3（#10）。この issue では触らない
- コミット・push・チケットの状態遷移は提供コマンド（`commit.sh` / `push.sh` / `ticket.sh`）経由のみ

## settings.json の登録とロックアウト対策

登録すると機構の強制が初めて実体を持つ。誤りがあると自分自身の操作（Edit / Bash / コミット）が止まるため、次の段取りで進める（詳細は実装計画で確定する）。

1. **登録は人間の操作**: AI は `settings.json` に貼り付ける JSON（§1 の登録表どおり。拒否側 5 登録は fail-closed ラッパー付き）と、貼る前の `settings.json` のバックアップ手順を用意して提示する
2. **段階登録**: ① 案内側のみ（SessionStart / PostToolUse / SubagentStart / SubagentStop）→ 動作確認 → ② 拒否側（PreToolUse 5 登録）→ 動作確認、の 2 段に分ける。段ごとに新しいセッションで軽い操作を通し、想定外の deny が出ないことを確かめる
3. **切り戻し**: 想定外の deny が出たら、人間が `settings.json` をバックアップに戻すか、環境変数（`WORKFLOW_ENFORCE=0` / `WORKFLOW_<NAME>_ENFORCE=0`）を設定した新しいセッションで再開する（環境変数はセッション開始時に読まれるため、同一セッションでは解除できない — 共通仕様 §4）
4. **登録の照合**: 登録後に HK-T01（§1 の表と `settings.json` の行単位の照合）と `run-tests.sh --ids` の全件を回し、結果を実装結果報告に記録する
5. **3/3 の未実装への依存**: `session-start` は `boundary.sh status --offline`（3/3）が無ければ何も出さずに終了 0、`workflow-entry` は `logs/` と作業領域を直接読むため 3/3 が無くても動く。この前提は調査で実機確認する

## 判断が必要になりそうな点（調査の問いの元）

1. T1: `SubagentStop` の出力がメインエージェントに届くか（届かないなら PostToolUse `Agent` 経由の通知を残す）
2. T2: サブエージェント内のツール呼び出しの `session_id` が親と同じか（違えば `agent_id` → 親の対応表が要る）
3. T3: `claude -p`（ヘッドレス）を入力から判別できるか。`permissionDecision: "defer"` の実在と挙動
4. T4: `SubagentStart` イベントと `model` / `agent_id` フィールドの実在
5. T7（実装の前提）: `tool_response` の終了コードのフィールド名（`exit_code` / `exitCode` / `returnCode` / `code` のどれか）
6. `WebFetch` / `WebSearch` を matcher に加えて `web` を強制するか（0022 D3）
7. `git 'commit'` のようにクォートで割った語のサブコマンド判定（`block-direct-git` は「特定できない」として扱う — 0022 D2）の実挙動確認

## 保留した点

| 項目 | 決める時期 |
|---|---|
| `HOOK_DENY_ID` の既定（§6 台帳に無い `WF009` をどう扱うか） | AI アセット設計（調査の結果を見て） |
| 「作業中チケット 2 枚以上」の扱いを機構の異常として拒否するか、警告に留めるか | AI アセット設計 |
| `investigation` 以外の実施タスクの `ops` 上限に「宣言必須の分類」を適用するか（0022 D5） | AI アセット設計 |
| `shellcheck` の CI 実行（0022 D6） | AI アセット設計で方針決定まで（CI 設定の変更は本 issue のスコープ外） |
| 後続フェーズ（追加の設計 / 実装）の要否 | フィードバック計画 |
| 実行者を既定のサブエージェントに戻す時期 | #10（3/3）の全体計画 |

## 合意の記録

| 承認 | 内容 | 誰が | いつ |
|---|---|---|---|
| ① | 次に着手する issue として #9（実装 2/3）を選ぶ | ユーザー（AskUserQuestion） | 2026-09-02 |
| ② | issue 本文は追記なしで進む。ブランチ `feature-9-hook-bodies-settings`・MR タイトル `feat: 自己改善ワークフロー機構の実装 2/3: フック本体 11 本と settings.json 登録・TBD T1〜T4 の検証 (#9)` | ユーザー（AskUserQuestion） | 2026-09-02 |
| ③ | フェーズ列（テンプレートどおり）・実行者（全種類メインエージェント）・レビュー要否（基準どおり）・やってよいこと・`settings.json` の 2 段階登録（案内側 → 拒否側） | ユーザー（AskUserQuestion） | 2026-09-02 |
| ④（以降の切れ目） | 人間レビューの代わりに opus サブエージェントによる敵対的自己レビューで切れ目を通過し、全体まとめの draft 解除まで進める。マージは人間 | ユーザー（AskUserQuestion） | 2026-09-02 |
