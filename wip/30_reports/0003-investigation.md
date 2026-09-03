---
type: report
title: 0003 調査結果 — 19 本の仕様から作るものの全件一覧と重複・欠落・共通化候補
description: issue #10 で作るタスクスキル 15 本・ワークフロースキル 2 本・エージェント 2 本について、各仕様の OUT ひな形・Script 処理・定義ひな形から作成物を全件書き出し、55 件の一覧と、eval ID の未採番・レポート md テンプレートの不在という 2 件の欠落、共通手順の正の所在という共通化候補、旧スキルに残る 4 件の不要資産を列挙した調査結果
tags: [report, investigation, issue-10]
keywords: [作成物一覧, SKILL.md, assets, テンプレート実体, eval ID, 未採番, レポートテンプレート, 共通手順, 正の所在, 旧資産, boundary.sh, finalize.sh]
---

# 0003 調査結果 — 19 本の仕様から作るものの全件一覧と重複・欠落・共通化候補

## サマリ

19 本の仕様（タスクスキル 15・ワークフロースキル 2・エージェント 2）から作るものは **55 件**で、種類ごとの内訳は SKILL.md 17 件（新規 15・改訂 2）/ エージェント定義 2 件 / `assets/` のテンプレート実体 13 件 / 提供コマンド 2 件とそのテスト 2 件 / eval 定義 19 件。**ほとんどの仕様は作成物の名前とパスを自分で書いており、そのまま実装計画のステップに落とせる**。

一方で、受け入れ条件 A1（「eval 定義がある」）を満たすうえで**設計で先に決めないと実装に入れない欠落が 2 件**ある。最も重いのは **eval ID が 19 本中 1 本（`AS-E01`）にしか振られていない**こと。仕様書に ID が無いと eval 定義の行と仕様の「テスト観点（eval）」を 1:1 に対応させられず、`20-common-step-ai-asset-creator` の手順 5 が成立しない。次に、実施タスク 6 本が使う**調査・実装結果レポートの md テンプレートの実体がどこにも無い**こと（`20-common-step-report-view` は HTML テンプレートだけを持つ）。

- ◎良 5 件 / △注意 3 件 / ✕問題 2 件

### ◆特に見てほしい（判断に困っている）

- **a6**: eval ID が未採番。19 本のうち ID があるのは `10-task-ai-asset-design-exec` の `AS-E01`（説明の例文）のみ。**採番規則そのものは既に正史にある**（`フック共通仕様` §6 の `<接頭辞>-E<2 桁>`、`20-common-step-spec` の節構成が eval ID の表を義務づけ）ので、判断が要るのは「接頭辞を何にするか」と「19 本分をどう設計チケットに割るか」だけ。**設計フェーズで 19 本の仕様に eval ID の表を足す以外の選択肢は無い**（下記 a6 の改訂）
- **a7**: レポートの md テンプレートが存在しない。実施タスク 6 本の OUT ひな形はいずれも「report-view のレポートテンプレート」と書くが、`20-common-step-report-view/assets/` にあるのは `report.template.html` と `plan.template.html` の 2 本だけ。**md 側のテンプレートを誰の assets に置くか**（report-view に集約 / 各実施タスクスキルに複製）は全体計画の保留 P3・調査の Q2 そのもの

### ◇承認が欲しい（方針は決めた）

- **a8**: 旧 `00-workflow-issue-mr-driven` に残る 4 件（`assets/issue-addendum.template.md`・`assets/issue-notify.template.md`・`references/issue-triage.md`・`evals/evals.json`）は、新仕様の OUT ひな形に無い。前 2 件は `20-common-step-issue` / 新しい全体まとめの流れに置き換わっており**削除**、`references/issue-triage.md` は `20-common-step-issue` へ**移設**、`evals/evals.json` は `.claude/evals/00-workflow-issue-mr-driven.md` へ**移行**が妥当と見る。最終判断は設計へ
- **a9**: SKILL.md の共通手順（計画タスク 8 本・実施タスク 6 本）は各スキルに複製せず、**正のスキルを参照する**形にする。仕様が 13 本とも「共通手順に加えて」と書いているため、複製すると正が 2 つになる

### ・細かいレビューは不要（ほぼ確実）

- **a1**: 作成物 55 件の一覧（仕様からの転記）
- **a2**: `assets/` のテンプレート実体 13 件の名前とパスは全件仕様に明記されている
- **a3**: 提供コマンドを持つ仕様は 2 本だけ（`10-task-overall-summary` の `finalize.sh`、`00-workflow-issue-mr-driven` の `boundary.sh`）。残る 15 本は「Script 処理: なし」
- **a4**: `references/` を要求する仕様は 1 本も無い
- **a5**: エージェント 2 本は定義ひな形（frontmatter + 本文の骨子）が仕様にそのまま書かれている

## 確かめられなかったこと（この結果が言っていないこと）

- 各仕様の**中身が実装可能な粒度か**（この調査は作成物の名前・パス・出典の節を数え上げるところまで。手順の実装可能性は各スキルを書くときに分かる）
- `boundary.sh` / `finalize.sh` の**中身と置き場**（**0004 の担当**。この報告は「2 本ある」ことと仕様上のパスを挙げるだけ）
- 旧名の残存箇所（**0005 の担当**）
- 申し送りの反映先（**0006 の担当**）
- eval を**実行**したときの結果（issue のスコープ外。定義まで）
- チケット分割の粒度（全体計画の保留 P6。実装計画の担当。この報告は 55 件の内訳を渡すだけ）
- **この 55 件に含まれないが、この issue の実装に入る見込みのもの**: `session-start` の注入整形（0004 の b5）と `session-start.sh:64` のパス修正、それに伴うテスト 8 件（0006 の e5）。0003 の観点は「19 本の仕様から作るもの」で、フック側の残作業は範囲外。0007 は 0003 だけでなく 0004・0006 も入力にすること

## 実施条件（読んだ対象）

| 対象 | 本数 | 読んだ節 |
|---|---|---|
| `.claude/docs/10_spec/skills/10-task-*.md` | 15 | 概要・禁止事項 / 処理フロー / OUT ひな形 / 参照ナレッジ / Script 処理 |
| `.claude/docs/10_spec/skills/00-workflow-*.md` | 2 | 同上 |
| `.claude/docs/10_spec/agents/*.md` | 2 | ツール権限 / 定義ひな形 / 参照ナレッジ |
| `.claude/docs/10_spec/skills/20-common-step-ai-asset-creator.md` | 1 | 処理フロー（種別と置き場）/ OUT ひな形 |
| `.claude/skills/`・`.claude/evals/` の現物 | — | 既存の有無の確認（`find` / `ls`） |

読み取りのみ。テスト・ビルドは実行していない（このチケットに `build-test` の宣言は無い）。

## 実施した内容と結果

### a1. 作るものは 55 件。種類ごとの内訳は次のとおり ◎良

| 種類 | 件数 | 新規 / 改訂 |
|---|---|---|
| SKILL.md（タスクスキル） | 15 | 全件新規 |
| SKILL.md（ワークフロースキル） | 2 | 全件改訂（既存を書き換え） |
| エージェント定義 | 2 | 全件新規 |
| `assets/` のテンプレート実体 | 13 | 全件新規 |
| 提供コマンド（`.sh`） | 2 | 全件新規 |
| 提供コマンドのテスト | 2 | 全件新規 |
| eval 定義 | 19 | 新規 17 / 移行 2（旧 `evals/evals.json` から） |
| 合計 | 55 | — |

eval 定義を除いた実体は 36 件。eval 定義 19 件を含めた総数が 55 件。**実装チケットに割り付ける単位はこの 55 件**で、うち 2 件（ワークフロースキルの SKILL.md）は既存ファイルの改訂、2 件（eval）は旧 `evals/evals.json` からの移行、残り 51 件が新規作成。

### a2. `assets/` のテンプレート実体は 13 件。全件が仕様に名前とパスで書かれている ◎良

| # | パス | 出典（仕様の節） |
|---|---|---|
| 1 | `.claude/skills/10-task-overall-plan/assets/overall-plan.template.md` | `10-task-overall-plan` OUT ひな形 |
| 2 | `.claude/skills/10-task-investigation-plan/assets/investigation-plan.template.md` | `10-task-investigation-plan` OUT ひな形 |
| 3 | `.claude/skills/10-task-design-plan/assets/design-plan.template.md` | `10-task-design-plan` OUT ひな形 |
| 4 | `.claude/skills/10-task-implementation-plan/assets/implementation-plan.template.md` | `10-task-implementation-plan` OUT ひな形 |
| 5 | `.claude/skills/10-task-design-feedback-plan/assets/design-feedback-plan.template.md` | `10-task-design-feedback-plan` OUT ひな形 |
| 6 | `.claude/skills/10-task-ai-asset-design-plan/assets/ai-asset-design-plan.template.md` | `10-task-ai-asset-design-plan` OUT ひな形 |
| 7 | `.claude/skills/10-task-ai-asset-implementation-plan/assets/ai-asset-implementation-plan.template.md` | `10-task-ai-asset-implementation-plan` OUT ひな形 |
| 8 | `.claude/skills/10-task-feedback-plan/assets/feedback-plan.template.md` | `10-task-feedback-plan` OUT ひな形 |
| 9 | `.claude/skills/10-task-overall-summary/assets/attachment-comment.template.md` | `10-task-overall-summary` OUT ひな形 |
| 10 | `.claude/skills/00-workflow-issue-mr-driven/assets/subagent-prompt.template.md` | `00-workflow-issue-mr-driven` OUT ひな形 |
| 11 | `.claude/skills/00-workflow-issue-mr-driven/assets/review-request.template.md` | 同上 |
| 12 | `.claude/skills/00-workflow-issue-mr-driven/assets/decision-note.template.md` | 同上 |
| 13 | `.claude/skills/00-workflow-issue-mr-driven/assets/adversarial-review-prompt.template.md` | 同上 |

- 計画タスク 8 本はすべて自分の計画書テンプレートを持つ（#1〜#8）。**実施タスク 6 本は assets を 1 件も持たない**（レポートは report-view のテンプレートを使う設計）
- `00-workflow-quick-request` は「テンプレートファイルは持たず、SKILL.md に形式を書く」と OUT ひな形が明記しており、assets は 0 件
- `task-types.tsv` は「対応表の実体（機構の設定。このスキルの assets には置かない）」と仕様が明記しており、既に `.claude/hooks/config/` にある（作成済み）

### a3. 提供コマンドを持つ仕様は 2 本だけ ◎良

「Script 処理」節を 17 本すべてで確認した結果、`なし。` で始まるものが 15 本、スクリプトを持つものが 2 本。

| スクリプト | 仕様上のパス | 状態記録 | エラー ID | テスト ID |
|---|---|---|---|---|
| `boundary.sh` | `.claude/skills/00-workflow-issue-mr-driven/scripts/boundary.sh` | `logs/review-state.json` ほか | BD001〜BD005 | BD-T01〜BD-T13 |
| `finalize.sh` | `.claude/skills/10-task-overall-summary/scripts/finalize.sh` | `logs/merge-state.json` | FN001〜FN003 | FN-T01〜FN-T05 |

- テストは `20-common-step-shell-script` の作法により `scripts/tests/` 配下に置く（既存の `ticket.sh` / `commit.sh` / `push.sh` と同じ）。よってテストファイルも 2 件
- **この 2 本の置き場は実装済みフックの案内文と食い違う**（`workflow-state-guard` は `.claude/hooks/boundary.sh` / `.claude/hooks/finalize.sh` と案内する）。詳細と解消の材料は 0004 の担当

### a4. `references/` を要求する仕様は 1 本も無い ◎良

19 本の「参照ナレッジ」節はいずれも**他の文書へのリンク**であって、スキル内に置く参照資料ファイルを求めていない。`20-common-step-ai-asset-creator` の標準構成は `references/`（参照資料。必要時）を挙げるが、必要時に当たる記述が無いため**新規に作る `references/` は 0 件**。

例外は既存の `.claude/skills/00-workflow-issue-mr-driven/references/issue-triage.md`（類似 issue の判定基準と `gh` コマンド集）で、これは a8 の扱い。

### a5. エージェント 2 本は定義ひな形がそのまま書かれている ◎良

| エージェント | パス | frontmatter | 本文の骨子 |
|---|---|---|---|
| `task-executor` | `.claude/agents/task-executor.md` | `name` / `description` / `tools: Read, Glob, Grep, Edit, Write, MultiEdit, Bash, Skill, WebFetch, WebSearch` / `model: inherit` | task スキルの読み込み → 手順どおり実施 → `ticket.sh` で着手・完了 → 迷ったら所定の置き場 → 拒否時は現在地を残す → 結果報告のスキーマ |
| `adversarial-reviewer` | `.claude/agents/adversarial-reviewer.md` | `name` / `description` / `tools: Read, Glob, Grep` / `model: inherit` | 役割 → 入力（patch のパス・対象ファイル・観点）→ 進め方 4 段階 → 禁止事項 → 出力スキーマ → 0 件と unreviewed の扱い |

- `adversarial-reviewer` に `Bash` を与えないのは仕様の明示的な決定（`git log` / `gh` を止める手段が無いため）。差分は呼び出し元が `wip/tmp/adversarial-<n>.patch` に書き出して渡す
- `model: inherit` は起動時の `model` 指定で上書きされる前提。**この issue では敵対的レビュアーに fable を指定する**（全体計画の合意）ので、その運用と `inherit` の既定は矛盾しない

### a6. eval ID が 19 本中 1 本にしか振られていない ✕問題

`10-task-*` 15 本・`00-workflow-*` 2 本・`agents/*` 2 本を `[A-Z][A-Z]-E[0-9][0-9]` で検索した結果、ヒットは **1 件だけ**（`10-task-ai-asset-design-exec.md` の `AS-E01`。しかもこれは自分の eval ID ではなく、「仕様書のテスト観点の書き方」を説明する例文中の ID）。

これが問題になる理由:

- `20-common-step-ai-asset-creator` 手順 5 は「指示文の効果が機械検証できないものは eval 定義を `.claude/evals/<アセット名>.md` に作成する」と定める
- `eval.template.md` の評価シナリオ表は「各行は仕様書『テスト観点（eval）』の行と 1:1 に対応する（**eval ID が対応の鍵**）」と明記する
- したがって**仕様書側に eval ID が無いと、eval 定義を作っても対応が取れない**。受け入れ条件 A1 の「eval 定義がある」を形式的に満たしても、A1 前半の「仕様書と 1:1 で対応」が崩れる

**［訂正 — 敵対的レビュー 1 回目の指摘 2］** 初版はここに「接頭辞の決め方（採番規則）はどこにも文書化されていない」「`FM-E01〜03` が唯一の実例」と書いたが、**どちらも誤り**。正史には次がある。

| 出どころ | 内容 |
|---|---|
| `10_spec/フック共通仕様.md:162` | 「eval ID は `<接頭辞>-E<2 桁>`（eval。定義のみで実行は人間の判断）で、これらの接頭辞は所属アセットの仕様が持つ（台帳への登録義務はエラー識別子の接頭辞だけ）」 |
| `10_spec/フック共通仕様.md:187` | 接頭辞の実例 5 件: `AC-E` / `FM-E` / `IS-E` / `RQ-E` / `SC-E`（`20-common-step-{ai-asset-creator, feature-mr, issue, requirement, spec}`）。`SC-E` は `SP-T` と接頭辞を重ねない旨まで書かれている |
| `10_spec/skills/20-common-step-spec.md:56` | スキルの節構成の定義に「Script 処理（テスト観点含む。**スクリプトが無ければ「なし」と理由を書き、テスト観点は eval ID（`<接頭辞>-E<2 桁>`。台帳は `フック共通仕様` §6）の表で定義する** — 実装計画が「テスト ID の無いアセット」を起こせないため）」 |
| `10_spec/skills/20-common-step-spec.md:87` | `SC-E03`「スクリプトを持たないスキルの仕様 → Script 処理に『なし』と理由を書き、テスト観点は eval ID で定義する」 |

実測でも `10_spec/` に `AC-E01〜04` / `FM-E01〜03` / `IS-E01〜03` / `RQ-E01〜07` / `SC-E01〜03` の **20 件**が存在する。

したがって、**17 本の仕様（`10-task-*` 15 + `00-workflow-*` 2）に eval ID の表が無いのは「未決定」ではなく「既存の規則への不適合」**である。`20-common-step-spec` が節構成として義務づけている表が欠けている状態で、選択の余地は無い。

| 案 | 判定 |
|---|---|
| (a) 設計フェーズで 17 本の仕様に eval ID の表を足す（エージェント 2 本も同様） | **これ以外に無い**。`20-common-step-spec.md:56` の義務 |
| (b) eval 定義側だけで採番し仕様には書かない | **不可**。`20-common-step-spec` の節構成と `SC-E03` に反する |
| (c) 規則だけ決めて ID は実装時に振る | **不可**。実装フェーズは `.claude/docs/**` に書けず、仕様に表を残せない |

設計で決めるのは「**19 本それぞれの接頭辞を何にするか**」（既存の `AC-E` / `FM-E` / `IS-E` / `RQ-E` / `SC-E` および全テスト ID の接頭辞と重ならないこと）と「**19 本ぶんをどう設計チケットに割るか**」の 2 点だけ。

### a7. 実施タスク 6 本が使うレポートの md テンプレートが存在しない ✕問題

実施タスク 6 本（`investigation-exec` / `design-exec` / `implementation-exec` / `design-feedback-exec` / `ai-asset-design-exec` / `ai-asset-implementation-exec`）と `10-task-overall-summary` の統括レポートは、いずれも OUT ひな形で「**report-view のレポートテンプレート**」を使うと書いている。

しかし `.claude/skills/20-common-step-report-view/assets/` にあるのは次の 2 本だけで、md のテンプレートは無い。

- `plan.template.html`
- `report.template.html`

計画側は各タスクスキルが md テンプレートを持つ（a2 の #1〜#8）ので、**同じ構造なら実施側にも md テンプレートが要る**。現状はレポートの md を毎回ゼロから書いており、節の並び（サマリ → 確かめられなかったこと → 実施した内容と結果 → 設計への反映 → 想定と異なった点 → 残課題）は各仕様の OUT ひな形の文章にしか書かれていない。

候補（決めない）:

| 案 | 内容 | 変更量 | 既存パターンとの整合 |
|---|---|---|---|
| (a) `20-common-step-report-view/assets/report.template.md` を 1 本作る | 6 本の実施タスク + 全体まとめが共有する | 小 | HTML が report-view にあるので置き場が揃う |
| (b) 実施タスクごとに `assets/<種類>-report.template.md` を作る | 7 本増える | 大 | 計画側（各スキルが持つ）と揃う |
| (c) 作らない | 現状維持 | 0 | 申し送り 0022 E4「テンプレート実体を作る」に反する |

**(a) を推す**。実施タスク 6 本の OUT ひな形は「レポートに含める項目」が異なるだけで節の骨格は共通しており、差分は各 SKILL.md に書けば足りる。ただしこれは全体計画の保留 P3 と調査の Q2 の一部であり、**決定は 0007**。

### a8. 旧 `00-workflow-issue-mr-driven` に、新仕様の OUT ひな形に無い資産が 4 件残っている △注意

| 現物 | 新仕様での扱い | 見立て |
|---|---|---|
| `assets/issue-addendum.template.md` | 新 OUT ひな形に無い。同名のものが `20-common-step-issue/assets/issue-addendum.template.md` にある | **削除**（重複。申し送り 0022 E1 が指すもの） |
| `assets/issue-notify.template.md` | 新 OUT ひな形に無い。本文に旧名 `merge-prep.sh` を含む。新しい全体まとめは issue コメントではなく MR 本文に成果物一覧を置く | **削除**（置き換わった） |
| `references/issue-triage.md` | 新 OUT ひな形に無い。issue の検索・分類は `20-common-step-issue` に委譲された | **移設**（`20-common-step-issue` へ）または削除 |
| `evals/evals.json` | eval の置き場は `.claude/evals/<アセット名>.md`（`20-common-step-ai-asset-creator` 手順 5） | **移行**（`.claude/evals/00-workflow-issue-mr-driven.md` へ） |

`00-workflow-quick-request` にも `evals/evals.json` が 1 件あり、同じく移行対象。

**旧形式 `evals/evals.json` はこの 2 本だけ**で、`20-common-step-*` は既に `.claude/evals/*.md` に統一されている。

### a9. 共通手順は 13 本の仕様が「正」を参照している。SKILL.md も同じ形にすべき △注意

- 計画タスク 8 本のうち、共通手順の本体を持つのは `10-task-investigation-plan`（「計画タスクの共通手順（正）」）だけ。残る 7 本は「共通手順に加えて:」で始まる固有手順しか持たない
- 実施タスク 6 本も同じで、本体は `10-task-investigation-exec`（「実施タスクの共通手順（正）」）。残る 5 本は「共通手順に加えて（3 の実施）:」

したがって SKILL.md も、共通手順を各スキルに複製せず**正のスキルを参照する**形にしないと、正が 2 つに割れて仕様と実体がずれる。ただし「参照しろ」とだけ書いたスキルが実際に読まれるか（サブエージェントが 2 つ読むか）は運用上の懸念があり、**設計で書き方を決める**（例: 共通手順を `20-common-step-*` に切り出すか、正のスキルへのリンクに留めるか）。

### a10. 既存 eval 定義は 9 本。今回 19 本を足すと 28 本になる △注意

現物: `20-common-step-ai-asset-creator` / `20-common-step-feature-mr` / `20-common-step-issue` / `20-common-step-requirement` / `20-common-step-spec` / `ai-asset-design-docs` / `design-docs` / `logger` / `work-defaults`。

- `20-common-step-*` 9 本のうち eval があるのは 5 本。無い 4 本（`commit-push` / `report-view` / `shell-script` / `ticket`）はいずれも提供コマンドを持ち、機械テストで検証できる部分が主
- この基準を当てはめると、**提供コマンドを持つ `10-task-overall-summary` と `00-workflow-issue-mr-driven` も eval が要るか**は判断が要る（指示文の部分は機械検証できないので要る、と読むのが素直）。設計で確定する

## 検証の結果

この調査は読み取りのみで、機械テストの実行は無い。数え上げの根拠は次のコマンド。

```
# assets / references / scripts の抽出
grep -ro "assets/[A-Za-z0-9._-]*\|references/[A-Za-z0-9._-]*\|scripts/[A-Za-z0-9._-]*" \
  .claude/docs/10_spec/skills/10-task-*.md .claude/docs/10_spec/skills/00-workflow-*.md .claude/docs/10_spec/agents/*.md

# eval ID の抽出
grep -rno "[A-Z][A-Z]-E[0-9][0-9]" \
  .claude/docs/10_spec/skills/10-task-*.md .claude/docs/10_spec/skills/00-workflow-*.md .claude/docs/10_spec/agents/*.md

# Script 処理の有無
for f in .claude/docs/10_spec/skills/10-task-*.md .claude/docs/10_spec/skills/00-workflow-*.md; do
  sed -n '/^## Script 処理/,/^## 要件との対応/p' "$f" | sed -n '3p'
done
```

## 設計への反映

| # | 設計で決めること | 効く受け入れ条件・保留 |
|---|---|---|
| 1 | 19 本それぞれの eval ID の**接頭辞**（既存の `AC-E` / `FM-E` / `IS-E` / `RQ-E` / `SC-E` と全テスト ID の接頭辞に重ねない）と、19 本ぶんの設計チケットの割り方。採番規則そのものは既に正史にあるので決め直さない（a6 の訂正） | A1、保留 P6 |
| 2 | レポートの md テンプレートの置き場（a7 の案 a / b / c） | 申し送り 0022 E4、保留 P3・Q2 |
| 3 | 旧 `00-workflow-*` の 4 資産の処遇（削除 / 移設 / 移行） | A3、申し送り 0022 E1 |
| 4 | 共通手順を SKILL.md にどう書くか（複製しない書き方） | A1 |
| 5 | 提供コマンドを持つ 2 本に eval を作るか | A1 |
| 6 | 55 件をどうチケットに割るか（実装計画の入力） | 保留 P6 |

## 想定と異なった点

- **実施タスク 6 本が assets を 1 件も持たない**のは想定外だった。計画タスクが全件テンプレートを持つので対称だと思っていたが、実施側はレポートに寄せる設計になっている。その結果、レポート md テンプレートの不在（a7）が表に出た
- `task-types.tsv` を「このスキルの assets には置かない」と仕様が明示していた。作成物から外れるので、実装の対象は 1 件減る
- eval 定義の本数（19 件）が SKILL.md の本数（17 件）を上回る。エージェント 2 本にも eval が要るためで、作業量の見積もりでは eval 側が支配的になる

## 付録: 作成物 55 件の全件一覧

`既存` 列は現物の有無（`無` = 新規作成、`有` = 改訂または移行）。

| # | 種類 | パス | 出典（仕様） | 既存 |
|---|---|---|---|---|
| 1 | SKILL.md | `.claude/skills/10-task-overall-plan/SKILL.md` | `10-task-overall-plan` | 無 |
| 2 | SKILL.md | `.claude/skills/10-task-investigation-plan/SKILL.md` | `10-task-investigation-plan`（計画共通手順の正） | 無 |
| 3 | SKILL.md | `.claude/skills/10-task-investigation-exec/SKILL.md` | `10-task-investigation-exec`（実施共通手順の正） | 無 |
| 4 | SKILL.md | `.claude/skills/10-task-design-plan/SKILL.md` | `10-task-design-plan` | 無 |
| 5 | SKILL.md | `.claude/skills/10-task-design-exec/SKILL.md` | `10-task-design-exec` | 無 |
| 6 | SKILL.md | `.claude/skills/10-task-implementation-plan/SKILL.md` | `10-task-implementation-plan` | 無 |
| 7 | SKILL.md | `.claude/skills/10-task-implementation-exec/SKILL.md` | `10-task-implementation-exec` | 無 |
| 8 | SKILL.md | `.claude/skills/10-task-feedback-plan/SKILL.md` | `10-task-feedback-plan` | 無 |
| 9 | SKILL.md | `.claude/skills/10-task-design-feedback-plan/SKILL.md` | `10-task-design-feedback-plan` | 無 |
| 10 | SKILL.md | `.claude/skills/10-task-design-feedback-exec/SKILL.md` | `10-task-design-feedback-exec` | 無 |
| 11 | SKILL.md | `.claude/skills/10-task-ai-asset-design-plan/SKILL.md` | `10-task-ai-asset-design-plan` | 無 |
| 12 | SKILL.md | `.claude/skills/10-task-ai-asset-design-exec/SKILL.md` | `10-task-ai-asset-design-exec` | 無 |
| 13 | SKILL.md | `.claude/skills/10-task-ai-asset-implementation-plan/SKILL.md` | `10-task-ai-asset-implementation-plan` | 無 |
| 14 | SKILL.md | `.claude/skills/10-task-ai-asset-implementation-exec/SKILL.md` | `10-task-ai-asset-implementation-exec` | 無 |
| 15 | SKILL.md | `.claude/skills/10-task-overall-summary/SKILL.md` | `10-task-overall-summary` | 無 |
| 16 | SKILL.md | `.claude/skills/00-workflow-issue-mr-driven/SKILL.md` | `00-workflow-issue-mr-driven` | 有（改訂） |
| 17 | SKILL.md | `.claude/skills/00-workflow-quick-request/SKILL.md` | `00-workflow-quick-request` | 有（改訂） |
| 18 | エージェント | `.claude/agents/task-executor.md` | `agents/task-executor` 定義ひな形 | 無 |
| 19 | エージェント | `.claude/agents/adversarial-reviewer.md` | `agents/adversarial-reviewer` 定義ひな形 | 無 |
| 20 | assets | `.claude/skills/10-task-overall-plan/assets/overall-plan.template.md` | OUT ひな形 | 無 |
| 21 | assets | `.claude/skills/10-task-investigation-plan/assets/investigation-plan.template.md` | OUT ひな形 | 無 |
| 22 | assets | `.claude/skills/10-task-design-plan/assets/design-plan.template.md` | OUT ひな形 | 無 |
| 23 | assets | `.claude/skills/10-task-implementation-plan/assets/implementation-plan.template.md` | OUT ひな形 | 無 |
| 24 | assets | `.claude/skills/10-task-design-feedback-plan/assets/design-feedback-plan.template.md` | OUT ひな形 | 無 |
| 25 | assets | `.claude/skills/10-task-ai-asset-design-plan/assets/ai-asset-design-plan.template.md` | OUT ひな形 | 無 |
| 26 | assets | `.claude/skills/10-task-ai-asset-implementation-plan/assets/ai-asset-implementation-plan.template.md` | OUT ひな形 | 無 |
| 27 | assets | `.claude/skills/10-task-feedback-plan/assets/feedback-plan.template.md` | OUT ひな形 | 無 |
| 28 | assets | `.claude/skills/10-task-overall-summary/assets/attachment-comment.template.md` | OUT ひな形 | 無 |
| 29 | assets | `.claude/skills/00-workflow-issue-mr-driven/assets/subagent-prompt.template.md` | OUT ひな形 | 無 |
| 30 | assets | `.claude/skills/00-workflow-issue-mr-driven/assets/review-request.template.md` | OUT ひな形 | 無 |
| 31 | assets | `.claude/skills/00-workflow-issue-mr-driven/assets/decision-note.template.md` | OUT ひな形 | 無 |
| 32 | assets | `.claude/skills/00-workflow-issue-mr-driven/assets/adversarial-review-prompt.template.md` | OUT ひな形 | 無 |
| 33 | 提供コマンド | `.claude/skills/00-workflow-issue-mr-driven/scripts/boundary.sh` | Script 処理（置き場は要決定） | 無 |
| 34 | 提供コマンド | `.claude/skills/10-task-overall-summary/scripts/finalize.sh` | Script 処理（置き場は要決定） | 無 |
| 35 | テスト | `boundary.sh` のテスト（BD-T01〜13） | `20-common-step-shell-script` の作法 | 無 |
| 36 | テスト | `finalize.sh` のテスト（FN-T01〜05） | 同上 | 無 |
| 37〜53 | eval 定義 | `.claude/evals/<#1〜#15 と #18・#19 のアセット名>.md`（17 件） | `20-common-step-ai-asset-creator` 手順 5 | 無 |
| 54 | eval 定義 | `.claude/evals/00-workflow-issue-mr-driven.md` | 同上 | 有（`evals/evals.json` から移行） |
| 55 | eval 定義 | `.claude/evals/00-workflow-quick-request.md` | 同上 | 有（`evals/evals.json` から移行） |

削除・移設の対象（作成物ではないが実装の範囲に入る。a8）:

| 現物 | 処遇の見立て |
|---|---|
| `.claude/skills/00-workflow-issue-mr-driven/assets/issue-addendum.template.md` | 削除 |
| `.claude/skills/00-workflow-issue-mr-driven/assets/issue-notify.template.md` | 削除 |
| `.claude/skills/00-workflow-issue-mr-driven/references/issue-triage.md` | `20-common-step-issue` へ移設、または削除 |
| `.claude/skills/00-workflow-issue-mr-driven/evals/evals.json` | #54 へ移行して削除 |
| `.claude/skills/00-workflow-quick-request/evals/evals.json` | #55 へ移行して削除 |

## 残課題

| # | 残課題 | 引き取り先 |
|---|---|---|
| R1 | ~~eval ID の採番規則がどこにも文書化されていない~~ → **誤り**（敵対的レビュー 1 回目の指摘 2）。規則は `フック共通仕様` §6 と `20-common-step-spec` にあり、`SC-E03` が義務づけている。残るのは接頭辞の選定と設計チケットの割り方（a6 の訂正） | 設計（0007 が割り付け） |
| R2 | 共通手順を参照する形にしたとき、サブエージェントが実際に 2 つのスキルを読むかは検証されていない | 実装フェーズの検証項目に追加を提案（V8 相当） |
| R3 | `10-task-overall-summary` の統括レポートが使うテンプレートは、実施タスクのレポートと同じでよいか（節が違う） | 設計 |
| R4 | 19 本の仕様の「中身」が実装可能な粒度かは未確認。各スキルを書く段で不足が出る可能性がある | 実装フェーズ（逸脱として作業ログへ） |
