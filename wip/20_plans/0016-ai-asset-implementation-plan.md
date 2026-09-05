---
type: plan
title: 0016 AI アセット実装・テスト計画 — 作業ツリーの三分と分類の穴の閉塞、worktree.sh の新設、並列実施の発効判定
description: issue #50 の設計（0012〜0017）が確定させた要件・仕様から機械テスト ID 50 件を抜き出し、設定・定義 → 中核（hook-common / cmdpos / scope / 拒否側フック 2 本 / 案内側フック 4 本）→ 中核の機械テスト → 提供コマンド（worktree.sh 新設・ticket.sh / push.sh / boundary.sh 改修）→ スキル・ルール・エージェント → 参照更新 の固定順で 10 ステップに割り付け、許可範囲案・参照更新一覧・依存するテスト・ロックアウト対策を定める。並列実施の発効は DDR i0050-08 の解禁の条件を実測して判定を提案する専用ステップに置く（発効そのものはこのフェーズで行わず、設計反映へ渡す）
tags: [plan, ai-asset-implementation-plan, issue-50]
keywords: [作業ツリーの三分, HOOK_SHARED_ROOT, hook_rel_path, 分類の穴, worktree.sh, 負のコントロール, ロックアウト対策, 発効の判定, 参照更新, テスト ID の割付]
---

# 0016 AI アセット実装・テスト計画 — 作業ツリーの三分と分類の穴の閉塞、worktree.sh の新設、並列実施の発効判定

- 対象 issue: [#50](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/50)
- MR: [#51](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/pull/51)（draft）
- ブランチ: `feature-50-worktree-parallel-tickets`
- チケット: 0016
- 作成日: 2026-09-05

## この計画で何をするか

設計フェーズ（0012〜0015・0017）が `.claude/docs/` の正史に落とした仕様を、`.claude/` 配下のアセットと機械テストとして実装する順序・範囲・検証手段を決める。効くのは受け入れ条件 **A1**（worktree 上で機構が健全に動くこと。とくに A1-2・A1-5・A1-6）・**A3**（並行作業の手段への 1 ホップ）・**A5**（宣言範囲・差分の基準点・実行者照合が作業ツリーごとに一意であることを機械テストで確認）・**A6**（合流手順の実体 = `worktree.sh merge`）である。

設計は「並列実施は採用するが、**発効は委ねた先を作業ツリーで動かす手段が確かめられるまで保留**する」（DDR `i0050-08`）で終わっている。そこでこの計画は 2 つに分ける。

1. **発効に依存しない部分を確実に作る**（S1〜S9）: 作業ツリーの三分・進行状態の共有ルート一本化・保護漏れの閉塞・分類の穴・`worktree.sh` 本体・採番と push の本流限定。これらは作業ツリーを **1 つだけ**使う運用（セッション自身が `EnterWorktree` で移る）でそのまま効き、並列実施の可否と独立に価値がある
2. **発効の可否を判定する実効性の確認を専用ステップに置く**（S10）: `i0050-08` の解禁の条件 1（委ねた先を作業ツリーで動かす手段）と条件 2（その経路の書き込みに `workflow-guard` の判定が効くことを機械テストで固定）を突き合わせ、**実測の結果と判定の提案を記録する**。**このフェーズでは発効しない**（`.claude/settings.json` の `worktree.baseRef` は実測のために一時的に置き、判定が肯定でも否定でも取り除く）。理由: 条件 1 の第 2 択は「手段 2 の 3 点がすべて確かめられ、**かつ `worktree.sh` の管理対象の定義と `merge` の前提検査 6 をそれに合わせて改めた**」（`10_spec/skills/00-workflow-issue-mr-driven.md`「解禁の条件」1）であり、後半は `worktree.sh`（S6 の成果）と `20-common-step-worktree` 仕様（`.claude/docs/**` = 実装フェーズの `deny`）の変更を要する。肯定側で発効まで進むと実装フェーズの範囲を越えるので、**発効に要る改訂はフィードバック計画（0028）→ 設計反映フェーズへ渡す**

**A1-6 を閉じる機械テストが最重要**である。調査（0004）の実測が空振りした原因は「どの作業ツリーにも作業中チケットが 0 枚で、`workflow-guard` と `workflow-diff-check` が入口で `exit 0` した」ことだった。設計はこれを踏まえて `WG-T19` / `WG-T20` / `DC-T08` / `DC-T09` / `SA-T10` / `SP-T09` を **負のコントロールをテスト自身が作る形**（作業中チケットの枚数を assert してから判定を呼ぶ）で置いている。この形を崩さずに実装する。

## 対象と範囲

| 区分 | 内容 |
|---|---|
| 根拠とする入力 | `.claude/docs/10_spec/` 配下の仕様 43 ファイル（本ブランチで変更・新設されたもの。`git diff --stat 7d5983b -- .claude/docs/`）／`.claude/docs/00_requirement/` の対応する要件／DDR `i0050-01`〜`i0050-10`／設計結果 `wip/30_reports/0012-ai-asset-design.md`／設計計画書 `wip/20_plans/0010-ai-asset-design-plan.md`／調査結果 `wip/30_reports/0004-investigation.md`／全体計画書 `wip/00_overall_plan/overall-plan.md` |
| 扱う対象 | `.claude/hooks/lib/`（`hook-common.sh` / `cmdpos.sh` / `scope.sh`）、`.claude/hooks/` の 6 本のフック（`workflow-guard` / `workflow-state-guard` / `workflow-diff-check` / `subagent-start-check` / `subagent-stop-check` / `session-start`）と `post-push-*` 2 本、`.claude/hooks/config/scope-limits.json`、`.gitignore`、`.claude/settings.json`（S10 の条件付き）、提供コマンド 4 本（`worktree.sh` 新設・`ticket.sh` / `push.sh` / `boundary.sh` 改修）、スキル 5 本（`20-common-step-worktree` 新設・`00-workflow-issue-mr-driven` / `20-common-step-ticket` / `20-common-step-commit-push` / `10-task-investigation-exec` 改修）、`.claude/agents/task-executor.md`、`.claude/rules/work-defaults.md`、`.claude/evals/` 4 ファイル、対応するテスト |
| 扱わない対象 | `.claude/docs/**`（設計の正史。実装フェーズは `deny`。食い違いは**直さず逸脱として記録**し、フィードバック計画 → 設計反映へ回す）／`apl/**`（本 issue は AI アセット）／`CLAUDE.md`（A3 は `00-workflow-issue-mr-driven` 側で満たす設計。触らない）／eval の**実行**（定義までとし、実行は人間の判断）／残課題 R45・R46・R48・R51・R53・R54・R60・R61・R63・R64（別 issue。全体計画書の保留 P2 で全体まとめが起票する） |

## 方法とステップ

固定順は **設定・定義 → 中核 → 中核の機械テスト → スキル・ルール・エージェント → 参照更新**。中核の機械テストは中核の変更と**同じチケット**に置く（離すと、変更したコードの経路を踏まないままステップが閉じる）。計画書の記述順とチケットの実行順・連番を一致させる。

| # | ステップ | チケット | 先行 |
|---|---|---|---|
| S1 | 設定・定義（`scope-limits.json` / `.gitignore`）と実装結果レポートの起こし | 0018 | — |
| S2 | 中核 a: `hook-common.sh`（作業ツリーの三分・作業ツリーの集合・パスの畳み込み・共有ルート） | 0019 | 0018 |
| S3 | 中核 b: `cmdpos.sh` の正規化 2 件と `scope.sh` の分類の穴 6 件 | 0020 | 0019 |
| S4 | 中核 c: 拒否側フック 2 本（`workflow-guard` / `workflow-state-guard`）と **A1-6 の機械テスト** | 0021 | 0019, 0020 |
| S5 | 中核 d: 案内側フック 4 本と `post-push-*` の共有ルート参照、**A5 の機械テスト** | 0022 | 0019, 0020 |
| S6 | 提供コマンド a: `20-common-step-worktree` と `worktree.sh` の新設 | 0023 | 0020, 0021 |
| S7 | 提供コマンド b: `ticket.sh` / `push.sh` / `boundary.sh` の改修 | 0024 | 0023 |
| S8 | スキル・ルール・エージェントと eval 定義 | 0025 | 0023, 0024 |
| S9 | 参照更新と全体検査 | 0026 | 0018〜0025 |
| S10 | 並列実施の発効の可否の判定（実効性の確認と提案。**発効はしない**） | 0027 | 0026 |

理由: (1) `hook-common.sh` の `hook_rel_path` は**書く側と読む側が往復する**値（畳み込み結果と「判定できない」の戻り値）なので、呼び手 3 本の分岐を同じチケット（S2）に含める。(2) `scope.sh` / `cmdpos.sh`（S3）は全フックが読むので、フック本体（S4・S5）より先に固める。(3) `worktree.sh`（S6）は `ticket.sh` / `push.sh` / `boundary.sh` が参照する「本流かどうかの判定」と `list` を持つので S7 より前。S6 の DoD は `WG-T21`（`worktree.sh` の置き場引数の例外）の再確認を含むが、そのテストを新設するのは S4 なので **S6 の先行に S4（0021）も入れる**。(4) 発効の判定（S10）は全テストが通った後でしか意味を持たない。

## 検証

| 検証 | 方法 | 期待値 |
|---|---|---|
| テスト ID の抽出と割付が一致する | `grep -rhoE "[A-Z]{2,6}-[TE][0-9]{2}[a-z]?" .claude/docs/10_spec/ \| sort -u \| wc -l` と、本 issue の差分に現れる ID の突き合わせ（下の「テスト方針」） | 仕様全体 **368 件**／本 issue で新設 **41 件**／変更行に現れる既存 **9 件**／割付表 **50 行**（41 + 9） |
| 全機械テストが通る | `bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --ids` | `FAIL` 0 件。`PASS` の ID 一覧に上の 50 件のうち機械テスト **37 件**が含まれる（eval 13 件は実行しない） |
| A1-6（worktree 側のチケットで判定される）が閉じている | `run-tests.sh --filter '*test_workflow_guard*'` / `--filter '*test_workflow_diff_check*'` | `WG-T19` / `WG-T20` / `DC-T08` / `DC-T09` が PASS。負のコントロール側（`WG-T20` / `DC-T09`）が「本流 1 枚・worktree 0 枚」で**判定に入らない**ことを assert している |
| A5（実行者照合の一意性）が閉じている | `run-tests.sh --filter '*test_subagent_start_check*'` / `--filter '*test_subagent_stop_check*'` | `SA-T10` / `SA-T11` / `SP-T09` が PASS |
| A6（合流）が動く | `run-tests.sh --filter '*test_worktree*'` | `WT-T01`〜`WT-T12` が PASS |
| 参照更新が済んでいる | 下の「参照更新一覧」の検索語 | 各行の**期待値（残るものの件数と場所）**と一致する |
| プレースホルダ・frontmatter | `grep -rn "{{\|TODO\|TBD" <変更したアセット>` と、`20-common-step-ai-asset-creator` の frontmatter 必須項目 | 0 件 / 全件充足 |
| 機構が自分を止めない | 各中核ステップの直後に、そのステップが変えた判定を踏む操作を 1 回実行する（下の「ロックアウト対策」の表） | 拒否されない（拒否されたら復旧手順へ） |
| 実装と仕様の食い違い | 実装結果レポートの「仕様からの逸脱」節 | 食い違いは**実装計画でも実装でも仕様を直さず**、対象・仕様の節・実装の実態・そう実装した理由を 1 件 1 行で記録する。反映はフィードバック計画 → 設計反映フェーズが行う |

## チケット

| 番号 | 種類 | 内容 | 先行 | 実行者 | 人間レビュー | 敵対的レビュー |
|---|---|---|---|---|---|---|
| 0018 | ai-asset-implementation | S1 設定・定義（`scope-limits.json` / `.gitignore`）と実装結果レポートの起こし | — | opus | 不要 | 要 |
| 0019 | ai-asset-implementation | S2 中核 a: `hook-common.sh` の三分・作業ツリーの集合・畳み込み・共有ルート | 0018 | opus | 不要 | 要 |
| 0020 | ai-asset-implementation | S3 中核 b: `cmdpos.sh` の正規化と `scope.sh` の分類の穴 | 0019 | opus | 不要 | 要 |
| 0021 | ai-asset-implementation | S4 中核 c: 拒否側フック 2 本と A1-6 の機械テスト | 0019, 0020 | opus | 不要 | 要 |
| 0022 | ai-asset-implementation | S5 中核 d: 案内側フック 4 本・`post-push-*` と A5 の機械テスト | 0019, 0020 | opus | 不要 | 要 |
| 0023 | ai-asset-implementation | S6 `20-common-step-worktree` と `worktree.sh` の新設 | 0020, 0021 | opus | 不要 | 要 |
| 0024 | ai-asset-implementation | S7 `ticket.sh` / `push.sh` / `boundary.sh` の改修 | 0023 | opus | 不要 | 要 |
| 0025 | ai-asset-implementation | S8 スキル・ルール・エージェントと eval 定義 | 0023, 0024 | opus | 不要 | 要 |
| 0026 | ai-asset-implementation | S9 参照更新と全体検査 | 0018〜0025 | opus | 不要 | 要 |
| 0027 | ai-asset-implementation | S10 並列実施の発効の可否の判定（実効性の確認と提案。**発効はしない**） | 0026 | **メインエージェント** | 不要 | 要 |
| 0028 | feedback-plan | 次の計画チケット（フィードバック計画） | 0018〜0027 | メインエージェント | 不要 | 不要 |

実行者・レビュー要否は全体計画書「方針」の差分 3 に従う（人間レビューは行わず、フェーズごとに `claude-fable-5-1` の敵対的レビューを 1 回。上限に達した後の指摘は追加チケットにせず切れ目のコメントに転記する）。

**0027 だけ実行者をメインエージェントに外す**。理由: 解禁の条件 1 の確認には**サブエージェントを 1 本起動して隔離の 3 点を観測する**ことが要り、サブエージェントは入れ子にできない（`task-executor` の禁止事項）。`work-defaults.md` の `ai-asset-implementation` 行に実行者の調整条件は無いので、基準に無い調整としてチケットに理由を書く。

## スコープ外

| # | 見つけたが今回扱わないこと | 引き取り先 |
|---|---|---|
| 1 | R53: タスクの切れ目では `workflow-guard` が判定に入らず、AI が直接打つ `git merge <ローカルブランチ>` が素通りする。閉じるには制御方式 1 に手を入れることになる | 別 issue（0017 が §13 の意図的な緩和として台帳に載せた） |
| 2 | R54: `git merge origin/<既定ブランチ以外>` が `merge-base` に分類される（7 つ目の穴） | 別 issue（0013 が「対象は 6 つに限る。網羅は主張しない」と明示して閉じたので、後から足すと 0013 の決定を上書きする） |
| 3 | R51: `bash wip/tmp/*.sh` を走らせる経路が無い（`commands.build-test` にも `wip/tmp/` は無い）。本 issue の作業自身が踏み続けている | 別 issue（全体計画書の保留 P2） |
| 4 | R57: `worktree.sh add` は割り付けるチケットを受け取らないので、同じ未着手チケットを 2 つの作業ツリーで着手する経路を機械で塞げない | 別 issue（0015 が運用の決まりと禁止事項で塞いだ） |
| 5 | R45・R46・R60・R61・R63・R64: 文書の形（図の遡及適用・横断要件の分配・通知番号の統合・M ノードの振り直し・縮退の可視化・対応表の行の識別） | 別 issue |
| 6 | `logs/usage/<branch>.json` の上書きとフック側の積み上げの噛み合い（R9） | 別 issue（置き場の一本化とは別の根） |

## 変更対象

| # | アセット | 新規 / 更新 / 削除 | 根拠（仕様書の節） | 割り付け |
|---|---|---|---|---|
| 1 | `.claude/hooks/config/scope-limits.json` | 更新 | `フック共通仕様` §8「上限設定」（`ai-asset-implementation` の `allow` に `.gitignore` を足す。`common.protected` を明示で通す形は `.gitattributes` と同じ） | S1 |
| 2 | `.gitignore` | 更新 | 設計計画書 結論方針 P10 後半／設計結果 残課題 R55（`.claude/worktrees/` を無視して `push.sh` 項目 1 が落ちないようにする） | S1 |
| 3 | `.claude/hooks/lib/hook-common.sh` | 更新 | `フック共通仕様` §2「作業ツリーの三分」「同一リポジトリの作業ツリーの集合」「作業ツリーをまたぐパスの畳み込み」「判定できないときの倒し方」／§5「記録と状態」の根の列 | S2 |
| 4 | `.claude/hooks/lib/cmdpos.sh` | 更新 | `フック共通仕様` §7-1（算術展開 `$(( ))` を段に割らない／コマンド置換・プロセス置換の閉じ括弧の後ろの語を実行体にしない） | S3 |
| 5 | `.claude/hooks/lib/scope.sh` | 更新 | `フック共通仕様` §8「git の分類は『サブコマンド + オプション』で決める（限定適用 6 件）」「`cd` は分類に足さない」／R52 の軽微 2 件（`_SC_READ_ONLY_CMDS` の `column` 重複・`_SC_SHELL_KEYWORDS` の全要素検査） | S3 |
| 6 | `.claude/hooks/20-PreToolUse/workflow-guard.sh` | 更新 | `workflow-guard` 仕様 概要（一意性の 2 点）／制御方式 1・2・5・6／`WF207`・`WF209` | S4 |
| 7 | `.claude/hooks/20-PreToolUse/workflow-state-guard.sh` | 更新 | `workflow-state-guard` 仕様 「対象パスの畳み込み」（新設）／制御方式 2・3／`WF309` | S4 |
| 8 | `.claude/hooks/22-PostToolUse/workflow-diff-check.sh` | 更新 | `workflow-diff-check` 仕様 制御方式 0・1（差分の基準点の一意性）／`WF605` | S5 |
| 9 | `.claude/hooks/12-SubagentStart/subagent-start-check.sh` | 更新 | `subagent-start-check` 仕様 「対象チケットを採る作業ツリー」の表／`WF804` | S5 |
| 10 | `.claude/hooks/13-SubagentStop/subagent-stop-check.sh` | 更新 | `subagent-stop-check` 仕様 経路の表／制御方式 2／`WF815` | S5 |
| 11 | `.claude/hooks/00-SessionStart/session-start.sh` | 更新 | `session-start` 仕様 「現在地を断定しない」／`WF705` | S5 |
| 12 | `.claude/hooks/22-PostToolUse/post-push-compact-prompt.sh` / `post-push-usage-report.sh` | 更新 | `フック共通仕様` §5（`logs/push-state.json` / `logs/usage/` は**共有**の根） | S5 |
| 13 | `.claude/skills/20-common-step-worktree/SKILL.md` | **新規** | `20-common-step-worktree` 仕様 全体 | S6 |
| 14 | `.claude/skills/20-common-step-worktree/scripts/worktree.sh` | **新規** | 同 「Script 処理」（本流かどうかの判定・共通の入口・`add` / `list` / `merge` / `remove`・合流の記録・`WT001`〜`WT008`） | S6 |
| 15 | `.claude/skills/20-common-step-worktree/scripts/tests/test_worktree.sh` | **新規** | 同 「テスト観点」（`WT-T01`〜`WT-T12`） | S6 |
| 16 | `.claude/skills/20-common-step-ticket/scripts/ticket.sh` | 更新 | `20-common-step-ticket` 仕様 `create`（`TK009`。作業ツリーでの採番の拒否） | S7 |
| 17 | `.claude/skills/20-common-step-commit-push/scripts/push.sh` | 更新 | `20-common-step-commit-push` 仕様 push 前チェック 項目 5（本流限定・スキップ不可） | S7 |
| 18 | `.claude/skills/00-workflow-issue-mr-driven/scripts/boundary.sh` | 更新 | `00-workflow-issue-mr-driven` 仕様 切れ目の判定（`last_task` を既出の切れ目の補集合で決める＝DDR `i0050-10`／`at_boundary` が全作業ツリーを見る） | S7 |
| 19 | `.claude/skills/00-workflow-issue-mr-driven/SKILL.md` | 更新 | 同 概要／手順 2b（発効の保留）／2c（切れ目での合流）／3-0／参照ナレッジ | S8 |
| 20 | `.claude/skills/20-common-step-ticket/SKILL.md` / `20-common-step-commit-push/SKILL.md` | 更新 | 各仕様（採番の本流一本化・push の本流限定の案内文） | S8 |
| 21 | `.claude/skills/10-task-investigation-exec/SKILL.md` | 更新 | `10-task-investigation-exec` 仕様（並列区間のレポート追記規約・訂正の節・作業ディレクトリの決まり） | S8 |
| 22 | `.claude/agents/task-executor.md` | 更新 | `task-executor` 仕様（並列時の前提・`isolation` の条件・作業している場所が違うときは始めない） | S8 |
| 23 | `.claude/rules/work-defaults.md` | 更新 | `00_requirement/rules/work-defaults.md` メインフロー（**並列してよいか**の列・計画タスクは直列・既定は並列にしない） | S8 |
| 24 | `.claude/evals/20-common-step-worktree.md` | **新規** | `WT-E01`〜`WT-E03` | S6 |
| 25 | `.claude/evals/00-workflow-issue-mr-driven.md` / `task-executor.md` / `10-task-investigation-exec.md` | 更新 | `WFD-E07`〜`E10`／`TXE-E02`・`E07`〜`E09`／`IVE-E05`・`E06` | S8 |
| 26 | `.claude/settings.json` | 更新（**一時的・最終差分は 0**） | `フック共通仕様` §1「`settings.json` のフック以外のキー」（`worktree.baseRef: "head"` を **S10 の実測のあいだだけ**置き、判定が肯定でも否定でも取り除く。発効はこのフェーズで行わない） | S10 |

削除するアセットは無い。

## 許可範囲案

`.claude/settings.json`・`.gitignore`・`.claude/hooks/config/` は**毎回確認の対象**である（`scope-limits.json` の `common.confirm` に `.claude/hooks/config/**` と `.claude/settings.json`、`common.protected` に `.gitignore`）。宣言していても書き込みのたびに確認（ask）が入り、ヘッドレスでは deny になる。ステップの中でこれらに触るときは、**確認が入る前提で 1 回の編集にまとめる**。

| ステップ | write | ops |
|---|---|---|
| S1 (0018) | `wip/**`, `.claude/hooks/config/**`, `.gitignore` | read, remote-read, build-test, hook-test |
| S2 (0019) | `wip/**`, `.claude/hooks/**` | read, remote-read, build-test, hook-test |
| S3 (0020) | `wip/**`, `.claude/hooks/**` | read, remote-read, build-test, hook-test |
| S4 (0021) | `wip/**`, `.claude/hooks/**` | read, remote-read, build-test, hook-test |
| S5 (0022) | `wip/**`, `.claude/hooks/**` | read, remote-read, build-test, hook-test |
| S6 (0023) | `wip/**`, `.claude/skills/**`, `.claude/evals/**` | read, remote-read, build-test, hook-test |
| S7 (0024) | `wip/**`, `.claude/skills/**` | read, remote-read, build-test, hook-test |
| S8 (0025) | `wip/**`, `.claude/skills/**`, `.claude/agents/**`, `.claude/rules/**`, `.claude/evals/**` | read, remote-read, build-test, hook-test |
| S9 (0026) | `wip/**`, `.claude/**` | read, remote-read, build-test, hook-test |
| S10 (0027) | `wip/**`, `.claude/settings.json` | read, remote-read, build-test, hook-test |

- **`ops` は `build-test` と `hook-test` を両方宣言する**。`.claude/hooks/**/tests/*.sh` と `.claude/skills/*/scripts/tests/*.sh` は `hook-test`、`commands.build-test` の列挙とリポジトリ直下の `tests/*.sh` は `build-test` に分類されるので、片方だけだと `run-tests.sh` が `TR006` か `WF204` で止まる
- 型（`ai-asset-implementation`）の上限は `allow: [".claude/skills/**", ".claude/hooks/**", ".claude/rules/**", ".claude/agents/**", ".claude/settings.json", ".claude/evals/**", "CLAUDE.md", ".gitattributes"]` / `deny: [".claude/docs/**", "apl/**"]`。**`.gitignore` は現状この `allow` に無い**ので、S1 が `scope-limits.json` を先に直さないと `.gitignore` に書けない（S1 の中の順序: `scope-limits.json` → `.gitignore`）
- S9 だけ `.claude/**` を丸ごと宣言する。参照更新は変更したすべてのアセットの本文に及ぶため、対象を先に列挙できない
- S1 が `.gitignore` を宣言に含めるのは、**削除・追記も書き込みとして判定される**ため（宣言に無いと WF201 で止まる）
- **起票済みチケット 0018〜0027 の `allow` はこの表と一致している**（0029 で突き合わせて訂正した。訂正前は 10 枚とも `ops` が `["hook-test"]` だけで `run-tests.sh` が `TR006` で止まる状態、0018・0023・0025 は `write` が作業対象を覆えていない状態だった）。表を直したら**同じ場で未着手チケットの frontmatter も直す**

## テスト方針

**抽出は機械的に行った。**

```bash
# 仕様全体の ID（run-tests.sh が PASS / FAIL 行から抽出する形と同じ正規表現）
grep -rhoE "[A-Z]{2,6}-[TE][0-9]{2}[a-z]?" .claude/docs/10_spec/ | sort -u        # => 368 件
# 本 issue で新設された ID（merge-base 7d5983b との差分）
git grep -hoE "[A-Z]{2,6}-[TE][0-9]{2}[a-z]?" 7d5983b -- .claude/docs/10_spec/ | sort -u > wip/tmp/ids-old.txt
grep -rhoE "[A-Z]{2,6}-[TE][0-9]{2}[a-z]?" .claude/docs/10_spec/ | sort -u > wip/tmp/ids-new.txt
comm -13 wip/tmp/ids-old.txt wip/tmp/ids-new.txt | wc -l                          # => 41 件（消えた ID は 0 件）
# 変更行に現れる既存 ID（内容が変わった可能性のあるもの）
git diff 7d5983b -- .claude/docs/10_spec/ | grep -E "^\+" \
  | grep -ohE "[A-Z]{2,6}-[TE][0-9]{2}[a-z]?" | sort -u > wip/tmp/ids-touched.txt
comm -12 wip/tmp/ids-old.txt wip/tmp/ids-touched.txt | wc -l                      # => 9 件
```

**割付対象は 41 + 9 = 50 件**で、下の表は 50 行ある（仕様全体の 368 件のうち、本 issue が触っていない 318 件は既存のテストがそのまま担う。S9 の全件実行で回帰を見る）。

| テスト ID | 種別 | ステップ | 実行方法 / 定義先 |
|---|---|---|---|
| HK-T01 | 機械 | S1 | `run-tests.sh --filter '*config_integrity*'`（`settings.json` の登録表。PreToolUse `Agent` の行が**無い**ことの負のコントロール。S1 では設定を変えないことの確認として踏む） |
| HK-T21 | 機械 | S2 | `run-tests.sh --filter '*test_hook_common*'`（作業ツリーの三分。`cwd` を worktree にしたとき `HOOK_WORKTREE`=worktree・`HOOK_ROOT`/`HOOK_SHARED_ROOT`=本流） |
| HK-T22 | 機械 | S2 | 同上（`hook_rel_path` の 4 段畳み込み。他ツリーの絶対パス → **そのツリー**のルート相対、共有ルートの絶対パス → 共有ルート相対、集合を読めなければ「判定できない」） |
| HK-T06 | 機械 | S2 | 同上（`decisions.jsonl` の 1 行が §5 のスキーマを満たし、`cwd` に判定時の作業ツリー・サブエージェント内では `agent_id` が入る。メインでは空文字 = 負のコントロール） |
| HK-T05 | 機械 | S3 | `run-tests.sh --filter '*test_cmdpos*'`（§7-1 の正規化 2 件を負のコントロール付きで。(a) `echo "$((n+1))"` が 1 段 (b) `sed -n "$(grep -n X f \| cut -d: -f1),+45p" path/to/file.sh` が 3 段で `file.sh` は引数 (c) `comm -12 <(sort -u a.txt) b.txt` が 2 段 (d) `$(which git) push` は実行体 `_` のまま） |
| HK-T12 | 機械 | S3 | 同上（提供コマンドの識別はルート相対表記だけ。`worktree.sh` を絶対パス・`./` 付きで呼んだ形は提供コマンドでない） |
| HK-T15 | 機械 | S3 | `run-tests.sh --filter '*test_scope*'`（限定適用 6 件を**閉じる側と通す側の対**で。`git worktree list`=read / `git worktree add ../x`=unknown、`git branch -a`=read / `git branch -d x`=unknown ほか。`cd`=unknown の負のコントロールを含む） |
| WG-T19 | 機械 | S4 | `run-tests.sh --filter '*test_workflow_guard*'`（**A1-6**。本流 `10_doing/` 0 枚・worktree 1 枚を**テスト自身が assert してから**判定を呼び、worktree 側のチケットの宣言で判定される） |
| WG-T20 | 機械 | S4 | 同上（**WG-T19 の負のコントロール**。本流 1 枚・worktree 0 枚で、`cwd`=worktree のとき判定に入らない。枚数もテストが assert する） |
| WG-T21 | 機械 | S4 | 同上（`worktree.sh add w1 ../repo-wt/w1` の**置き場を指す引数**は WF209 にならず allow。同じ行の他のパス引数は通常判定 = 負のコントロール） |
| WG-T14 | 機械 | S4 | 同上（提供コマンドの引数パスに同じ判定が掛かること。`WG-T21` の例外と対で踏む） |
| SG-T12 | 機械 | S4 | `run-tests.sh --filter '*test_workflow_state_guard*'`（**A1-2**。`cwd`=worktree から**本流の** `wip/10_tickets/20_done/0001-x.md` を絶対パスで書こうとすると保護される） |
| SG-T13 | 機械 | S4 | 同上（`.git/worktrees/` を読めないとき、リポジトリ内と確定できない絶対パスへの書き込みが `WF309`。許可側に倒さない） |
| DC-T08 | 機械 | S5 | `run-tests.sh --filter '*test_workflow_diff_check*'`（**A5・A1-6**。本流と worktree が別々の `base_sha` を持つとき、差分の基準点が worktree 側チケットの `base_sha` になる） |
| DC-T09 | 機械 | S5 | 同上（**DC-T08 の負のコントロール**。本流 1 枚・worktree 0 枚では判定されない。枚数をテスト自身が assert する） |
| SA-T10 | 機械 | S5 | `run-tests.sh --filter '*test_subagent_start_check*'`（**A5**。本流と worktree の両方に別 `ticket_type` の作業中チケットを置き、対象チケットが**起動された側の作業ツリー**で一意に決まる） |
| SA-T11 | 機械 | S5 | 同上（`.git/worktrees/` を退避して作業ツリーを確定できない状態にすると、要点を注入せず `WF804`） |
| SP-T05 | 機械 | S5 | `run-tests.sh --filter '*test_subagent_stop_check*'`（PreToolUse `Agent` の経路が**無い**前提での縮退。`HK-T01` と同じ事実を別側から固定する） |
| SP-T08 | 機械 | S5 | 同上（縮退の前提の書き直し分） |
| SP-T09 | 機械 | S5 | 同上（**A5**。実行者照合が**呼び出し元の**作業ツリーのチケットで行われる。本流と worktree に `executor` の違うチケットを置いて確かめる） |
| SE-T11 | 機械 | S5 | `run-tests.sh --filter '*test_session_start*'`（**A1**。`logs/mr.json` が読めないとき現在地を断定せず `WF705`。4 つの状態を同じ作業領域で切り替えて固定する） |
| WT-T01 | 機械 | S6 | `run-tests.sh --filter '*test_worktree*'`（`add` の既定の置き場とブランチ名。`logs/hooks/` と `logs/sh/` **だけ**が作られ、進行状態 7 種が 1 つも作られない） |
| WT-T02 | 機械 | S6 | 同上（`add` の `WT002` 4 経路。名前の形式違反と detached HEAD は `WT008`・終了 2） |
| WT-T03 | 機械 | S6 | 同上（`list` の JSON。本流が先頭・`managed` の判定・`doing` の中身・`dirty`・外部の `worktree-<名前>` は `managed:false`） |
| WT-T04 | 機械 | S6 | 同上（`merge` 成功。`--no-ff`・件名が `chore:`・チケット移動とレポート追記が両方入る・記録 1 行・二度目は `up-to-date`） |
| WT-T05 | 機械 | S6 | 同上（前提検査 6 項目それぞれの未充足で **`git merge` を 1 回も実行せず**止まる。複数同時は全件列挙） |
| WT-T06 | 機械 | S6 | 同上（解けない衝突で `WT004`・終了 1・`--abort` 済み・本流が合流前と同一。**負のコントロール**: 別の節の追記だけなら成功する） |
| WT-T07 | 機械 | S6 | 同上（`remove` が作業ツリーとサブブランチを消し `prune` 済み） |
| WT-T08 | 機械 | S6 | 同上（`remove` の前提未充足。未コミットは `--force` でも消えない／未合流は `--force` のときだけ、失われるコミット数を出して消える） |
| WT-T09 | 機械 | S6 | 同上（対象が見つからない・管理対象外は `WT005`） |
| WT-T10 | 機械 | S6 | 同上（引数・環境の誤りが `WT008`・終了 2。最終行が `WT008:` で始まる） |
| WT-T11 | 機械 | S6 | 同上（本流かどうかの判定。`.git` がディレクトリ / ファイル。作業ツリーで `list` は動き `add`/`merge`/`remove` は `WT001`） |
| WT-T12 | 機械 | S6 | 同上（`merge --all` が順に合流し、`WT004` でそこで止めて合流済みと残りを分けて出す） |
| WT-E01 | eval | S6 | `.claude/evals/20-common-step-worktree.md`（並行の指示 → `worktree.sh add` を使い `git worktree` を直接実行しない。**実行しない**） |
| WT-E02 | eval | S6 | 同上（`WT004` を自分で解消せず衝突ファイル一覧を添えて返す。判定は拒否の記録ではなく実行ログで数える） |
| WT-E03 | eval | S6 | 同上（作業ツリーで `ticket.sh create` / `push.sh` を呼ばず本流の要求として返す） |
| TICKET-T13 | 機械 | S7 | `run-tests.sh --filter '*test_ticket*'`（作業ツリーでの `create` が `TK009`・終了 1 でチケットが 1 枚も作られない。**負のコントロール**: 同じ引数を本流で実行すれば作られる） |
| CP-T12 | 機械 | S7 | `run-tests.sh --filter '*test_push*'`（作業ツリーでの `push.sh` が項目 5 未充足の `CP005`。`wip/push-check-skip.md` に書いても飛ばせない） |
| BD-T20 | 機械 | S7 | `run-tests.sh --filter '*test_boundary*'`（`last_task` が `ticket_type` のまとまりで切られ、**既出の切れ目の補集合**で決まる。持ち越し `0012` が 2 回目に出る） |
| BD-T21 | 機械 | S7 | 同上（`at_boundary` が全作業ツリーを見る。管理対象の作業ツリーが 0 なら `worktree.sh` を呼ばない = `make_counting_path` で呼び出し 0 回。合流の前後で `next` と `last_task` が変わる） |
| WFD-E07 | eval | S8 | `.claude/evals/00-workflow-issue-mr-driven.md`（指示が無ければ作業ツリーを切らない） |
| WFD-E08 | eval | S8 | 同上（**A3**。並行作業を問われて `20-common-step-worktree` へ 1 ホップ。`CLAUDE.md` を書き換えない） |
| WFD-E09 | eval | S8 | 同上（切れ目で `list` → `merge` → `remove` を敵対的レビューと push の**どちらよりも前に**行い、合流の後に `status` をやり直す） |
| WFD-E10 | eval | S8 | 同上（**発効の保留**。指示されても手順 2b を始めず、`worktree.sh add` と Agent 起動が 0 件） |
| TXE-E02 | eval | S8 | `.claude/evals/task-executor.md`（更新分） |
| TXE-E07 | eval | S8 | 同上（置き場を渡されたらその作業ツリーの中だけで作業し、`create` / push / 合流をしない） |
| TXE-E08 | eval | S8 | 同上（置き場が渡されなければ自分で切らず結果報告に返す） |
| TXE-E09 | eval | S8 | 同上（置き場は渡されたが `cwd` が呼び出し元と同じなら**始めずに返す**。自分で移ろうとしない） |
| IVE-E05 | eval | S8 | `.claude/evals/10-task-investigation-exec.md`（並列区間ではレポートの自分の節だけを追記し共通部を触らない） |
| IVE-E06 | eval | S8 | 同上（完了済みチケットを作業中に戻さず、レポートの訂正の節に書く） |

- **機械テストは 37 件、eval は 13 件**（`WT-E01`〜`E03`／`WFD-E07`〜`E10`／`TXE-E02`・`E07`〜`E09`／`IVE-E05`・`E06`）。eval は**定義まで**で実行しない（実行は人間の判断）
- `--filter` は**パス全体に掛かるグロブ**なので、ファイル名だけを書いた `--filter test_ticket.sh` は 0 件になる。表のとおり `--filter '*test_ticket*'` の形で書き、クォートを外さない
- 機械テストは**テストを先に書いて失敗を確認してから**実装する（`10-task-ai-asset-implementation-exec` の手順）。負のコントロールを持つ 6 件（`WG-T19`/`WG-T20`・`DC-T08`/`DC-T09`・`WT-T06`・`TICKET-T13`）は、**負側が「通ってしまわない」ことを先に確かめる**

## ステップ

| # | ステップ | チケット | 先行 | 中核 |
|---|---|---|---|---|
| S1 | **設定・定義**。①`scope-limits.json` の `types["ai-asset-implementation"].allow` に `.gitignore` を足す（`.gitattributes` と同じ「`common.protected` を明示で通す」形）②`.gitignore` に `.claude/worktrees/` を足す ③実装結果レポート（md + HTML）を起こす。**①→② の順を守る**（①が済むまで②は WF205 で止まる） | 0018 | — | **要** |
| S2 | **中核 a: `hook-common.sh`**。①`HOOK_SHARED_ROOT`（値は `HOOK_ROOT` に固定・上書きの口を作らない）②`hook_worktrees`（`<HOOK_ROOT>/.git/worktrees/*/gitdir` から集合を作る。`git` を呼ばない・stale も残す）③`hook_rel_path` を 4 段（自ツリー → 共有ルート → 集合のいずれか → 畳めない）に拡張し、**正規化失敗・集合を読めないときは「判定できない」を返す** ④`decisions.jsonl` に `cwd` / `agent_id` ⑤**呼び手 3 本の「判定できない」分岐**（`workflow-guard` = `WF209` / `workflow-state-guard` = `WF309` / `workflow-diff-check` = `WF605`）。値の往復（書く側 `hook_rel_path` と読む側 3 本）を同じチケットに置く | 0019 | 0018 | **要** |
| S3 | **中核 b: `cmdpos.sh` と `scope.sh`**。①`cmdpos.sh` の P-1（算術展開は段を割らない）と P-2（コマンド置換・プロセス置換の閉じ括弧の後ろの語を実行体にしない）②`scope.sh` の限定適用 6 件（`worktree list` の `read` 化だけが**通す向き**、他 5 件は**閉じる向き**）③`cd` は分類に足さない（負のコントロールとして固定）④R52 の軽微 2 件 | 0020 | 0019 | **要** |
| S4 | **中核 c: 拒否側フック 2 本と A1-6 の機械テスト**。①`workflow-guard`: 宣言範囲の強制が「その作業ツリーの作業中チケット 1 枚」で一意に決まること・`WF207` が「1 作業ツリーあたり 2 枚」を指すこと・提供コマンドの**置き場を指す引数**の例外（`WG-T21`）②`workflow-state-guard`: 対象パスの畳み込み（作業ツリーをまたぐ絶対パスの保護。**無条件**）③テスト `WG-T19`/`WG-T20`/`WG-T21`/`WG-T14`/`SG-T12`/`SG-T13`。**負のコントロールの前提をテスト自身が枚数の assert で作る形を崩さない** | 0021 | 0019, 0020 | **要** |
| S5 | **中核 d: 案内側フック 4 本・`post-push-*` と A5 の機械テスト**。①`workflow-diff-check`: 差分の基準点が作業ツリーごとに一意（`DC-T08`/`DC-T09`）・`WF605` ②`subagent-start-check`: 対象チケットを採る作業ツリーの確定・`WF804`（`SA-T10`/`SA-T11`）③`subagent-stop-check`: 実行者照合を呼び出し元の作業ツリーで行う・`WF815`（`SP-T09`。`SP-T05`/`SP-T08` の前提も直す）④`session-start`: 現在地を断定しない・`WF705`（`SE-T11`）⑤`post-push-compact-prompt` / `post-push-usage-report` の `logs/push-state.json` / `logs/usage/` を**共有ルート**へ | 0022 | 0019, 0020 | **要** |
| S6 | **提供コマンド a（新設）**。`20-common-step-worktree/SKILL.md` と `scripts/worktree.sh`（本流かどうかの判定・共通の入口・`add` / `list` / `merge` / `remove`・合流の記録 `logs/worktree-merges.jsonl`・`WT001`〜`WT008`）と `scripts/tests/test_worktree.sh`（`WT-T01`〜`WT-T12`）、eval 定義 `WT-E01`〜`WT-E03`。**「本流かどうかの判定」はこのスキルの仕様が正で、S7 の 3 コマンドはこれを作り直さず共有する** | 0023 | 0020 | — |
| S7 | **提供コマンド b（改修）**。①`ticket.sh create` に `TK009`（作業ツリーでは採番しない）②`push.sh` の push 前チェックに項目 5（本流限定・スキップ不可）③`boundary.sh` の `last_task` を既出の切れ目の補集合で決める・`at_boundary` を全作業ツリーで見る（管理対象が 0 なら `worktree.sh` を呼ばない）。**変更後の自分のコマンドで自分をコミット・完了させる**（下のロックアウト対策） | 0024 | 0023 | **要** |
| S8 | **スキル・ルール・エージェント**。`00-workflow-issue-mr-driven`（手順 2b の**発効の保留**・2c の合流・3-0・参照ナレッジ）／`20-common-step-ticket`／`20-common-step-commit-push`／`10-task-investigation-exec`（並列区間の追記規約・訂正の節）／`agents/task-executor.md`／`.claude/rules/work-defaults.md`（**並列してよいか**の列・計画タスクは直列・既定は並列にしない）／eval 定義 4 ファイル | 0025 | 0023, 0024 | — |
| S9 | **参照更新と全体検査**。下の「参照更新一覧」の 7 行を検索して消し込む／プレースホルダ（`{{ }}`・`TODO`・`TBD`）0 件／frontmatter の必須項目／`run-tests.sh --ids` の全件実行で `FAIL` 0 件と ID の重複なし／本 issue の残りが回せることの確認（`commit.sh` / `boundary.sh status` / `ticket.sh next` / `run-tests.sh` の **4 経路**。`push.sh` は項目 2 と `ops` の両方で通らないので実行せず `CP-T12` で代える）／実装結果レポートの逸脱一覧を締める | 0026 | 0018〜0025 | — |
| S10 | **並列実施の発効の可否の判定**。①解禁の条件 2 が `WG-T19`/`WG-T20`/`DC-T08`/`DC-T09`/`SA-T10`/`SP-T09` の PASS で満たされていることを確認する ②解禁の条件 1 を実測する（`.claude/settings.json` に `worktree.baseRef: "head"` を**一時的に**置き、`isolation: "worktree"` でサブエージェントを 1 本起動して 3 点 — 分岐元が呼び出し元の `HEAD` か／ブランチ名の規約／**成果を載せたまま作業ツリーが消えないか** — を観測する）③**判定が肯定でも否定でも `worktree.baseRef` は取り除く**（このステップの成果は実測の記録と判定の**提案**であって、発効ではない） ④結果と提案を実装結果レポートに書き、**発効に要る改訂**（解禁の条件 1 の第 2 択の後半 = `worktree.sh` の管理対象の定義と `merge` の前提検査 6／`10_spec/skills/00-workflow-issue-mr-driven.md`「解禁の条件」と `20-common-step-worktree` 仕様）を**フィードバック計画（0028）→ 設計反映フェーズへ渡す**。`.claude/docs/` は触らない（実装フェーズは `deny`） | 0027 | 0026 | **要**（`settings.json`） |

## 参照更新一覧

検索語は**行末に依存しない形**で書き、期待値は**残るもの**（件数と場所）で書く。0 件を期待値にすると、検索語が間違っていて何もヒットしない場合と区別が付かない。

| # | 旧 | 新 | 検索語 | ヒット箇所（現状） | 除外 | 期待値（残るもの） |
|---|---|---|---|---|---|---|
| 1 | `$HOOK_WORKTREE/logs/<進行状態>` | `$HOOK_SHARED_ROOT/logs/<進行状態>` | `grep -rn 'HOOK_WORKTREE/logs/' --include="*.sh" .claude/` | **24 行 / 5 ファイル**（内訳: `mr.json` 6・`sessions` 4・`merge-state.json` 4・`locks` 3・`usage` 2・`hooks` 2・`review-state.json` 1・`push-state.json` 1・変数展開 `$__se_sf` 1） | なし | **`logs/hooks/` の 2 行だけが残る**（判定記録は作業ツリー側。`logs/sh/` は logger 経由でこの検索に現れない）。他 22 行は `grep -rn 'HOOK_SHARED_ROOT/logs/' --include="*.sh" .claude/` 側に現れる |
| 2 | （新規）作業ツリーの共通ステップ | `20-common-step-worktree` | `grep -rn '20-common-step-worktree' --include="*.md" --include="*.sh" .claude/skills/ .claude/agents/ .claude/rules/ .claude/evals/` | アセット側 **0 件**（docs 側は 25 ファイル） | `.claude/docs/**`（設計の正史。実装は触らない） | **アセット側で 5 ファイル以上**: `20-common-step-worktree/SKILL.md`（自身）・`00-workflow-issue-mr-driven/SKILL.md`・`10-task-investigation-exec/SKILL.md`・`20-common-step-ticket/SKILL.md`・`20-common-step-commit-push/SKILL.md`・`agents/task-executor.md`・`evals/20-common-step-worktree.md` |
| 3 | （新規）提供コマンド | `worktree.sh` | `grep -rn 'worktree\.sh' --include="*.md" --include="*.sh" .claude/` | アセット側 **0 件**（docs 側は 13 ファイル） | `.claude/docs/**` | **アセット側で 6 ファイル以上**: 実体・テスト・SKILL.md・`boundary.sh`（`at_boundary` の `list` 呼び出し）・`00-workflow-issue-mr-driven/SKILL.md`・eval 定義 |
| 4 | （新規）共有ルート | `HOOK_SHARED_ROOT` | `grep -rn 'HOOK_SHARED_ROOT' --include="*.sh" .claude/` | アセット側 **0 件**（docs 側は 4 ファイル） | `.claude/docs/**` | **`hook-common.sh` の定義 1 か所 + 参照 22 行以上**（#1 の移し先）。`test_hook_common.sh` にも現れる |
| 5 | `WF207` の意味（作業中 2 枚） | `WF207`（**1 作業ツリーあたり** 2 枚） | `grep -rn 'WF207' --include="*.sh" .claude/` | **6 行 / 2 ファイル**（`workflow-guard.sh` 2 行 = 113・138 / `test_workflow_guard.sh` 4 行 = 83・239・240・241。2026-09-05 に実測） | なし（番号は変わらない。変わるのは**メッセージの文言**） | **同じ 6 行が残り、`workflow-guard.sh` の `hook_deny WF207 ...` の文言に「この作業ツリーで」が入る**。番号の削除・追加は起きない |
| 6 | `TK001–008` | `TK001–009` | `grep -rn 'TK00[0-9]' --include="*.sh" --include="*.md" .claude/ \| grep -v '^\.claude/docs'` | アセット側 **53 行** | `.claude/docs/**`（台帳の正） | **54 行以上**（`ticket.sh` の `TK009` と `test_ticket.sh` の `TICKET-T13` 分が増える）。既存 53 行は減らない |
| 7 | （新規）合流の記録 | `logs/worktree-merges.jsonl` | `grep -rn 'worktree-merges' --include="*.sh" --include="*.md" .claude/` | アセット側 **0 件**（docs 側は 4 ファイル） | `.claude/docs/**` | **アセット側で 3 か所以上**: `worktree.sh`（書く）・`test_worktree.sh`（`WT-T04`/`WT-T06` で読む）・`20-common-step-worktree/SKILL.md` |

- **除外の扱い**: `.claude/docs/**` は設計の正史で実装フェーズの `deny` なので、どの行でも検索対象から外す。DDR（`.claude/docs/20_ddr/`）と用語辞書（`.claude/docs/90_glossary/`）は旧名を経緯として残してよい
- 検索語に `$` を含めない（`HOOK_WORKTREE/logs/` のように**行の途中で一致する形**で書く）。`foo\.sh$` のような行末固定は途中のヒットを取りこぼす

## 依存するテスト

変更対象を入力・期待値に持つテストファイル。実装だけ直してテストを古いまま残さないよう、**同じチケットの `allow.write` に入れる**（型の `allow` が `.claude/hooks/**` / `.claude/skills/**` を含むので範囲としては足りるが、ステップの作業項目として明示する）。

| 変更対象 | 依存するテスト | 入れるステップ |
|---|---|---|
| `.claude/hooks/config/scope-limits.json` | `.claude/hooks/tests/test_config_integrity.sh`（`HK-T02`。3 つのキー集合の照合と `commands.build-test` の振る舞い） | S1 |
| `.gitignore` | なし（テストは持たない。`push.sh` の項目 1 が実運用で踏む） | S1 |
| `.claude/hooks/lib/hook-common.sh` | `.claude/hooks/lib/tests/test_hook_common.sh`（`HK-T06`・`HK-T21`・`HK-T22`）／**全フックのテスト**（偽のルートを作って `hook_read_input` を通すので、三分の導入で `HOOK_SHARED_ROOT` が未定義だと全部落ちる） | S2 |
| `.claude/hooks/20-PreToolUse/workflow-guard.sh` ほか呼び手 3 本の「判定できない」分岐 | `test_workflow_guard.sh` / `test_workflow_state_guard.sh` / `test_workflow_diff_check.sh`（`WF209` / `WF309` / `WF605` の分岐） | S2 |
| `.claude/hooks/lib/cmdpos.sh` | `.claude/hooks/lib/tests/test_cmdpos.sh`（`HK-T05`・`HK-T12`） | S3 |
| `.claude/hooks/lib/scope.sh` | `.claude/hooks/lib/tests/test_scope.sh`（`HK-T15`）／`.claude/hooks/tests/test_config_integrity.sh`（`classify_real` が `scope_classify` を実際に走らせる） | S3 |
| 拒否側フック 2 本 | `test_workflow_guard.sh`（`WG-T01`〜`WG-T21`）／`test_workflow_state_guard.sh`（`SG-T01`〜`SG-T13`） | S4 |
| 案内側フック 4 本 | `test_workflow_diff_check.sh` / `test_subagent_start_check.sh` / `test_subagent_stop_check.sh` / `test_session_start.sh` | S5 |
| `post-push-compact-prompt.sh` / `post-push-usage-report.sh` | `test_post_push_compact_prompt.sh` / `test_post_push_usage_report.sh`（`logs/push-state.json` / `logs/usage/` の置き場を期待値に持つ） | S5 |
| `worktree.sh`（新規） | `.claude/skills/20-common-step-worktree/scripts/tests/test_worktree.sh`（新規） | S6 |
| `ticket.sh` | `.claude/skills/20-common-step-ticket/scripts/tests/test_ticket.sh` | S7 |
| `push.sh` | `.claude/skills/20-common-step-commit-push/scripts/tests/test_push.sh` | S7 |
| `boundary.sh` | `.claude/skills/00-workflow-issue-mr-driven/scripts/tests/test_boundary.sh`（`BD-T01`〜`BD-T21`。`at_boundary` の呼び出し回数を `make_counting_path` で数える） | S7 |
| `.claude/rules/work-defaults.md` | `.claude/hooks/tests/test_config_integrity.sh`（`HK-T02` の `wd_types` は `^\| [a-z-]+ \| (サブエージェント\|メインエージェント)` で行を拾う。**列を足しても行頭 2 列が変わらなければ壊れない**が、列を足した後に必ず回す） | S8 |
| `.claude/settings.json` | `.claude/hooks/tests/test_config_integrity.sh`（`HK-T01`。期待値は `fixtures/settings-hooks.expected.tsv`。`hooks` 以外のキーは見ないので `worktree.baseRef` の追加では落ちないことを確認する） | S10 |

## ロックアウト対策

中核（入口ガード・フック・共通ライブラリ・`settings.json`・`scope-limits.json`）は、壊すと以後どの操作もできなくなる。**1 つ変えるごとに、そのステップが変えた判定を実際に踏む操作を 1 回実行する**。対策ごとに「どのテスト ID が、変更したどの判定を通るか」を書く。テスト ID と判定の対応が付かないものは対策として数えない。

**復旧の共通手順（`git checkout` は使えない）**: `checkout` は `scope.sh` の `_SC_READ_ONLY_CMDS` にも `_SC_GIT_READ_SUBCMDS` にも無く、分類が `unknown` のまま `WF204` で拒否される（`.claude/hooks/lib/scope.sh` の `_SC_GIT_READ_SUBCMDS` に `checkout` が無いことを 2026-09-05 に実測）。`scope-limits.json` が壊れた `WF210` の状態でも提供コマンド以外の実行は拒否されるので、**中核を壊した後に `git checkout` で戻すことはできない**。復旧は次の 2 手で行う。

1. `git show <base_sha>:<ルート相対パス>` で基準点の内容を取り出す（`show` は `_SC_GIT_READ_SUBCMDS` にあるので `read` として通る。リダイレクトは書き込み扱い = `WF205` になるので**付けない**。出力をそのまま読む）
2. **Write ツール**でそのパスへ書き戻す（Bash を介さないので `cmdpos.sh` / `scope.sh` が壊れていても通る。書き込み判定は `workflow-state-guard` と `workflow-guard` だけ）

書き戻し先が**そのチケットの `allow.write` に入っていること**が前提である。各ステップの書き戻し先と宣言の対応は下の表の「復旧手順」列に書いた。`.claude/hooks/config/**` と `.claude/settings.json` だけは `common.confirm` なので、書き戻しにも判定順 (4) の `WF203`（ask）が入る（ヘッドレスでは deny になり得る。下の「保留した点」P5）。

| ステップ | 確かめる操作（変更箇所を実際に踏むもの） | 復旧手順 |
|---|---|---|
| S1 | ①`HK-T02`（`run-tests.sh --filter '*config_integrity*'`）が `scope-limits.json` を**実際に読んで** `scope_classify` を走らせる ②`scope-limits.json` を直した後の **`.gitignore` への `Edit`** が `WF201` にならず allow（判定 stage 5）で `logs/hooks/decisions.jsonl` に記録されること（変えた判定＝`.gitignore` が `common.protected` に居ながら `types["ai-asset-implementation"].allow` で判定順 (2) を抜ける経路を実際に踏む。`wip/tmp/` への `Write` は `common.allow` で stage 5 に落ちるうえ、`Write` ツールの拒否は `WF201`/`WF202` で `WF205` は出ないので、確認にならない） | 共通手順で `.claude/hooks/config/scope-limits.json` と `.gitignore` を書き戻す（`git show <base_sha>:<パス>` → Write）。両方とも 0018 の `allow.write` に入っている。`scope-limits.json` が壊れると `WF210`（形式不正）で**全書き込みが止まる**ので、編集は 1 回にまとめ、直後に `jq -e . .claude/hooks/config/scope-limits.json` で構文を確かめる。`WF210` の状態では提供コマンド以外の Bash が通らないため、**書き戻しは必ず Write ツールで行う** |
| S2 | ①`HK-T21`・`HK-T22`（`hook_rel_path` の 4 段と `HOOK_SHARED_ROOT` を直接踏む）②変更直後に `wip/tmp/` へ `Write` を 1 回（`workflow-guard` の書き込み判定 = 畳み込みの呼び手を踏む）③`Read` を 1 回（`hook_read_input` を踏む）。**`hook-common.sh` は全フックが `source` するので、構文エラー 1 つで機構全体が fail-open か fail-closed に倒れる** | 共通手順で `.claude/hooks/lib/hook-common.sh` を書き戻す（`git show <base_sha>:.claude/hooks/lib/hook-common.sh` → Write）。0019 の `allow.write`（`.claude/hooks/**`）に入っている。読み込めない状態になると登録ラッパーが `WFx09` を出す（`HK-T09`）。それも出ないときは `WORKFLOW_ENFORCE=0` ではなく**基準点への戻し**で復旧する（`git checkout` は `WF204` で通らない） |
| S3 | ①`HK-T15`（限定適用 6 件を閉じる側と通す側の対で踏む）②`HK-T05`（`cmdpos.sh` の正規化 2 件を負のコントロール付きで踏む）③変更直後に `git worktree list` と `git branch -a` を 1 回ずつ実行し、**`read` として通る**こと（通す向きの回帰）④`git status --porcelain` を 1 回（既存の `read` 分類が落ちていないこと） | 共通手順で `.claude/hooks/lib/scope.sh` と `.claude/hooks/lib/cmdpos.sh` を書き戻す（`git show <base_sha>:<パス>` → Write）。0020 の `allow.write`（`.claude/hooks/**`）に入っている。**`cmdpos.sh` が壊れると `bash` で始まるすべてのコマンドの判定が崩れ、`git show` すら通らなくなり得る**ので、編集は最初から Edit ツールで行い（Bash を介さない）、**編集の前に基準点の内容を `git show` で取り出して手元に残してから**変更する。編集直後に `bash -n .claude/hooks/lib/cmdpos.sh` を回す |
| S4 | ①`WG-T19`・`WG-T20`（作業ツリーごとの宣言範囲の強制。負のコントロール込み）②`WG-T21`・`WG-T14`（提供コマンドの引数パスの例外と通常判定）③`SG-T12`・`SG-T13`（保護対象の畳み込みと `WF309`）④変更直後に **`bash .claude/skills/20-common-step-commit-push/scripts/commit.sh` を 1 回**（提供コマンドの経路 = 制御方式 5・6 を踏む） | 共通手順で `.claude/hooks/20-PreToolUse/workflow-guard.sh` と `workflow-state-guard.sh` を書き戻す（`git show <base_sha>:<パス>` → Write）。0021 の `allow.write`（`.claude/hooks/**`）に入っている。`workflow-guard` が誤って全 deny になると commit も止まるので、**`commit.sh` を通す確認をテストの直後に必ず入れる**。全 deny の状態でも Write ツールの経路（`workflow-state-guard` → `workflow-guard` の書き込み判定）は宣言範囲内なら残るので、そこから戻す |
| S5 | ①`DC-T08`・`DC-T09`（差分の基準点）②`SA-T10`・`SA-T11`（対象チケットの作業ツリー）③`SP-T09`（実行者照合）④`SE-T11`（現在地）⑤変更直後に `Write` を 1 回して `workflow-diff-check` の PostToolUse が回ること（案内側は deny を出せないので**止まらない**が、`WF605` が誤爆していないかを `logs/hooks/decisions.jsonl` で見る） | 共通手順で `.claude/hooks/22-PostToolUse/` `12-SubagentStart/` `13-SubagentStop/` `00-SessionStart/` の変更した各ファイルを書き戻す（`git show <base_sha>:<パス>` → Write。ディレクトリ単位では取れないので**ファイルごとに 1 回ずつ**）。0022 の `allow.write`（`.claude/hooks/**`）に入っている。案内側は拒否しないのでロックアウトは起きにくいが、`session-start` が壊れるとセッション開始のたびに誤った現在地が入る |
| S6 | ①`WT-T01`〜`WT-T12`（`worktree.sh` を実際に走らせる）②`WG-T21`（`worktree.sh` の置き場引数が `workflow-guard` を通ること。S4 で入れた例外を S6 の実体で踏み直す） | 新設なので基準点に内容が無い。壊れたときは**ファイルを空にせず作り直す**（`git show` の対象が無いので書き戻しではなく再作成）。書き先（`.claude/skills/**`・`.claude/evals/**`）は 0023 の `allow.write` に入っている。既存経路を壊さないが、`worktree.sh` が誤って本流を消す事故だけは避ける（`remove` は `--force` でも未コミットを消さない仕様を先にテストで固定する） |
| S7 | ①**変更した `ticket.sh` で自分のチケットを `complete` する**（`TK009` を足した `create` の分岐が `start` / `complete` を壊していないこと）②**変更した `commit.sh`／`push.sh` の経路で自分の成果をコミットする**（`push.sh` は項目 5 を足したので、本流での push が落ちないこと）③`BD-T20`・`BD-T21`（`boundary.sh` の切れ目判定）。**並びは「変更 → `commit.sh` で自分をコミット（この 1 回目が検証を兼ねる）→ `ticket.sh complete`」** | 共通手順で `.claude/skills/20-common-step-ticket/scripts/ticket.sh`・`20-common-step-commit-push/scripts/push.sh`・`00-workflow-issue-mr-driven/scripts/boundary.sh` を書き戻す（`git show <base_sha>:<パス>` → Write。ファイルごとに 1 回ずつ）。0024 の `allow.write`（`.claude/skills/**`）に入っている。`ticket.sh` が壊れるとチケットを完了させる手段が無くなるので、**`create` の分岐は既存 3 サブコマンドの前に置かない**（`start` / `complete` の経路に条件を足さない） |
| S8 | ①`HK-T02`（`work-defaults.md` の行の照合。列を足した直後に回す）②スキル本文は機械テストを持たないので、**変更したスキルを実際に Skill ツールで読み込めること**を 1 回確かめる（frontmatter が壊れると読み込めない） | 共通手順で変更した各ファイル（`.claude/skills/*/SKILL.md`・`.claude/agents/task-executor.md`・`.claude/rules/work-defaults.md`・`.claude/evals/*.md`）を書き戻す（`git show <base_sha>:<パス>` → Write。ファイルごとに 1 回ずつ）。すべて 0025 の `allow.write` に入っている。`entry-skills.txt` に載る振り分けスキル（`00-workflow-issue-mr-driven`）の frontmatter を壊すと `workflow-entry` が宣言を受け付けなくなるので、編集後に**新しいプロンプトを 1 回通す**まで次へ進まない |
| S9 | 全件 `run-tests.sh --ids`（`FAIL` 0・ID 重複 0）。これは S1〜S8 で変えたすべての判定を通る | 落ちたステップの復旧手順に戻る |
| S10 | ①`HK-T01`（`settings.json` の `hooks` 登録が変わっていないこと）②`worktree.baseRef` を置いた直後に**通常のツール呼び出しを 1 回**（`hooks` 以外のキーの追加が本体の設定読み込みを壊していないこと） | 共通手順で `.claude/settings.json` を書き戻す（`git show <base_sha>:.claude/settings.json` → Write）。0027 の `allow.write` に入っている（ただし `common.confirm` なので書き戻しにも `WF203` の ask が入る。保留 P5）。`settings.json` が壊れるとフックが 1 本も起動しなくなり（＝機構が丸ごと無音）、拒否も出ないまま作業が進む。**判定が肯定でも否定でも必ずキーを取り除く**（このフェーズでは発効しない） |

- **強制無効化 `WORKFLOW_ENTRY_ENFORCE=0` / `WORKFLOW_ENFORCE=0` は既定の手段にしない**。ユーザーの明示の指示があるときだけ使う
- 各チケットの `base_sha` は `ticket.sh start` が機械的に記録する。復旧手順の `<base_sha>` はその値を使う
- **Bash を介さない復旧経路（Edit / Write ツール）を常に 1 本残す**。`cmdpos.sh` / `scope.sh` / `workflow-guard` が壊れると Bash の判定が崩れるが、`Edit` / `Write` は `workflow-state-guard` と `workflow-guard` の書き込み判定だけを通るので、`.claude/hooks/**` が宣言に入っていれば書き戻せる
- **`git checkout` / `git restore` / `git switch` を復旧手順に書かない**。いずれも `scope.sh` の読み取り一覧に無く `unknown` → `WF204` で拒否される。基準点の内容を取り出すのは `git show <base_sha>:<パス>`（`read`）だけである

## リスク

| # | リスク | 影響範囲 | 巻き戻し方 |
|---|---|---|---|
| 1 | `hook_rel_path` の 4 段化で、これまで「自分のツリーの外」として無視されていたパスが判定対象に入り、**通っていた書き込みが落ちる** | 全フックの書き込み判定 | S2 の直後に `wip/**` と `.claude/**` への `Write` を各 1 回試す。落ちたら `hook-common.sh` を基準点へ戻し、畳み込みの 3 段目（作業ツリーの集合）だけを外して再試行する |
| 2 | `scope.sh` の限定適用 5 件が**閉じる向き**なので、既存の読み取り形が巻き添えで落ちる（`git branch -a` などの版差） | すべての `git` 実行 | `HK-T15` に「閉じる側と通す側の対」を置いてあるので落ちれば検出される。落ちたら該当の 1 件だけを既定 `read` に戻し、逸脱として記録する |
| 3 | 進行状態の共有ルート一本化で、**作業ツリー側に既にある `logs/`** と本流の `logs/` が二重に読まれる | `session-start` / `boundary.sh` / `post-push-*` | `worktree.sh add` は `logs/hooks/` と `logs/sh/` しか作らない（`WT-T01` が「進行状態 7 種が 1 つも作られない」ことを固定する）。既存の作業ツリーがある環境では、S5 の前に `logs/` の中身を目視で確認する |
| 4 | `worktree.sh merge` が本流を壊す（`--abort` が効かず中途半端な状態で終わる） | 本流の作業ツリー | `WT-T06` が「`--abort` 済みで本流が合流前と同一（`git status --porcelain` が空・`HEAD` が変わらない）」を固定する。実運用で壊れたら `git merge --abort` → `git reset --hard <合流前 HEAD>`（人が実行する） |
| 5 | `ticket.sh` / `push.sh` / `boundary.sh` を変えた直後の 1 回目が壊れていて、そのチケットを完了させる手段が無くなる | S7 | S7 のロックアウト対策の並び（変更 → `commit.sh` → `ticket.sh complete`）を守る。壊れたら Edit ツールで基準点の内容に戻す |
| 6 | S10 の実測で `isolation: worktree` の作業ツリーが**成果を載せたまま消える** | 実測に使った 1 本のサブエージェントの成果 | 実測は**捨ててよい成果**（`wip/tmp/` への 1 ファイル）で行う。本 issue の実チケットを実測に使わない |
| 7 | 本 issue の作業自身が、直したい穴を踏み続ける（`cd` と `bash <絶対パス>` が `WF204`、`sed -i` とリダイレクトが `WF205`）。`worktree.sh` の追加で提供コマンドの経路が 1 つ増える | 実装フェーズ全体の作業効率 | 設計（`i0050-04`）はこれらを「開かない」と決めたので**開けない**。S9 の後に、本 issue の残り（実装・フィードバック・全体まとめ）が回せることを 1 回確認する（`commit.sh` / `boundary.sh status` / `ticket.sh next` / `run-tests.sh` の **4 経路**を通す）。**`push.sh` は S9 で実行しない**: 実行者は作業中チケットを持つので push 前チェック 項目 2 で必ず `CP005` になり、`remote-write:push` は `ai-asset-implementation` の `types ops` にも無い。push の経路は `CP-T12` の PASS と項目 5 の実装で代え、実際の push は切れ目で呼び出し元が行う |

## 設計差し戻し

無し。設計は 50 件のテスト ID をすべて「入力・期待・判定方法」付きで持っており、予約だけの識別子は無い（設計結果 e17・e21）。実装に落とせない記述は見つからなかった。

ただし次の 2 点は**仕様に書かれていない**ので、実装では埋めず**逸脱として記録**する（実装計画で決めない）。

- `.claude/hooks/config/scope-limits.json` の `ai-asset-implementation.allow` に `.gitignore` を足すこと自体は R55 が実装フェーズに引き取っているが、`フック共通仕様` §8 の**初期値の表**には `.gitignore` の行が無い。実装は `scope-limits.json`（プロジェクトの設定）だけを変え、§8 の表は触らない
- `boundary.sh` の `last_task` が `completed_at` で並べる形は仕様どおりだが、**`completed_at` を持たないチケットの倒し方**が仕様に無い（R59）。実装は仕様どおりに書き、欠落時の挙動を独自に定義しない

## 保留した点 / 対象なし

| # | 保留した点 | 現行の文書の記述 | 決める時期・場所 |
|---|---|---|---|
| P1 | **解禁の条件 1（委ねた先を作業ツリーで動かす手段）を、この実装フェーズで確かめきれるか**、および**確かめられた場合に発効へ進めるか** | DDR `i0050-08`「決定」= 「確認は AI アセット実装フェーズで行う」。同「(c) 呼び出し元が用意した既存の作業ツリーをサブエージェントに割り当てる指定は無い」。`10_spec/skills/00-workflow-issue-mr-driven.md`「解禁の条件」1 の第 2 択 = 「手段 2 の 3 点がすべて確かめられ、**かつ `worktree.sh` の管理対象の定義と `merge` の前提検査 6（同じ issue に属するブランチである）をそれに合わせて改めた**」 | 実測は S10（0027）。**サブエージェントの起動が要るのでメインエージェントが実施する**。**発効はこのフェーズでは決めない**: 条件 1 の後半は `worktree.sh`（`.claude/skills/**`）と `20-common-step-worktree` 仕様・上記スキル仕様（`.claude/docs/**` = 実装フェーズの `deny`）の改訂を要するため、フィードバック計画（0028）→ 設計反映フェーズが引き取る。確かめられなくても設計は成立し、並列実施が保留のまま残るだけである（`i0050-08` の「影響」） |
| P2 | **`completed_at` を持たないチケットの `last_task` の扱い**（R59） | `00-workflow-issue-mr-driven` 仕様 `BD-T20`「完了群が … の順（`completed_at` はこの順）」。欠落時の記述は無い。本リポジトリの既存チケットはすべて `completed_at` を持つ（`ticket.sh complete` が機械的に書く）ので現時点では踏まない | 実装では決めず、S7（0024）で逸脱として記録 → フィードバック計画（0028）→ 設計反映フェーズ |
| P3 | **`git merge --no-ff` のマージコミットが `commit.sh` を通らないこと**の是非 | `20-common-step-worktree` 仕様 `merge` 4「メッセージ規約の検査は `commit.sh` が持つが、マージコミットは `commit.sh` を通らないので、この既定がそのまま規約に合う形である」 | 保留しない（現行文書に決着がある）。**S6 は既定の件名 `chore: 作業ツリー <名前> の成果を合流する` をそのまま実装する** |
| P4 | **`.gitignore` に `.claude/worktrees/` を足す必要が実際にあるか** | 設計計画書 結論方針 P10「`worktree.sh` の既定はリポジトリの外。`.claude/worktrees/` は Claude Code のサブエージェント隔離が使う場合にだけ現れる」／DDR `i0050-08`「`isolation: worktree` は成果を残す作業に使わない」 | S1（0018）で足す。隔離を使わない決定になっても、`--worktree` 起動など外部の仕組みが作る経路が残るので、足しておく側に倒す（足しても失うものが無い） |

| P5 | **`common.confirm` の 2 か所（`.claude/hooks/config/**`・`.claude/settings.json`）を、サブエージェント実行者が書き換えられるか** | `scope-limits.json` の `common.confirm` = `[".claude/hooks/config/**", ".claude/settings.json"]`。`scope.sh` の判定順 (4) は「毎回確認（`common.confirm` はどの allow より優先）」で `WF203`（ask）を返し、宣言の有無に関わらず (5) に落ちない。サブエージェントは確認に答えられないので deny になり得る。全体計画書の方針（差分 3）で人間レビューは行わないが、**確認（ask）はレビューとは別の機構**である | S1（0018）と S10（0027）の着手時。実行者（サブエージェント）が `WF203` で止まったら迂回せず結果報告に上げ、**呼び出し元のメインエージェントがその 1 ファイルの編集だけを代行する**。この運用でよいかは切れ目のレビューで人間に確認する（`executor` の変更は本チケットの範囲外なので行っていない） |

対象なしの節は該当しない（変更対象は 26 件ある）。
