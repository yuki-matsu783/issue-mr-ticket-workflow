---
type: plan
title: 0002 調査計画 — 参考実装の流用範囲・テスト方式・TBD T5・HTML テンプレートの土台
description: issue #6（基盤の実装）の AI アセット実装計画に必要な判断材料を集める調査の計画。参考実装 2 系統のスクリプト・テスト・テンプレートの流用可否、テストの実行方式、PowerShell ツールのフック入力（TBD T5）、logger と redact の置き場を問いにする
tags: [plan, investigation, issue-6]
keywords: [調査計画, 参考実装, agent-workflow, MR-driven-workflow, 流用, テスト方式, bats, TBD T5, PowerShell, tool_input, logger, redact, HTML テンプレート, data-required]
---

# 0002 調査計画

## 対象

- issue #6 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/6 / PR #7 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/pull/7
- 全体計画: `wip/00_overall_plan/overall-plan.md`「判断が必要になりそうな点」1〜5
- 種別 AI アセット。読む対象は参考ディレクトリ（`参考ディレクトリ/agent-workflow`・`参考ディレクトリ/MR-driven-workflow`、git 管理外・読み取りのみ）と `.claude/docs/` の要件・仕様

## 調査観点

| # | 問い | 効く判断点 / 受け入れ条件 |
|---|---|---|
| Q1 | 参考実装のうち、仕様（`10_spec`）にそのまま合う部分・書き直す部分はどれか。対象: agent-workflow `.claude/hooks/{workflow-lib,workflow-guard,workflow-entry,workflow-diff-check,block-chmod,work-boundary,merge-prep}.sh` と `workflow-types.json`、MR-driven `.claude/hooks/lib/{CommandPosition,UsageTracking}.sh`、`.claude/hooks/{block-direct-git-commit,block-unchecked-push,session-start}.sh`、`.claude/scripts/src/{create-commit,push-checklist,extract-frontmatter,cleanup-task}.sh` と `vcs/` | 判断点 1 / 受け入れ条件 2・5（lib 5 本と提供コマンド 4 本の設計の出発点） |
| Q2 | テストをどう実行するか。参考実装のテスト（素の bash: agent-workflow `hooks/tests/*.sh`、MR-driven `scripts/test/test_*.sh` + `fixtures/`）の書き方・共通ヘルパ・実行方法、Windows（Git Bash）と Linux CI の両方で通る前提で bats 等を入れる価値があるか | 判断点 2 / 受け入れ条件 2・5・6（テスト ID を機械テストに落とす形） |
| Q3 | TBD T5: PowerShell ツールのフック入力は Bash と同じ `tool_input.command` か（`tool_name` の値、`tool_input` のキー） | 判断点 3 / 受け入れ条件 7（共通仕様 §12 T5 の確定、`hook-common.sh` / `cmdpos.sh` の読み取り） |
| Q4 | `logger.sh` と `redact` をどこに置き、各スクリプト（skills 配下の提供コマンドと hooks 配下）からどう読み込むか。参考実装の logger 相当（MR-driven `shell-script-style.md`・`UsageTracking.sh` のログ関数）と `20-common-step-shell-script` 仕様・`rules/logger.md` 要件の突き合わせ | 判断点 4 / 受け入れ条件 6 |
| Q5 | HTML テンプレート（report / plan）の土台にする参考実装のレポートテンプレートはどこにあり、`check-html.sh` の検査（プレースホルダ・重複 ID・外部依存・必須節 `data-required` の導出）に必要な構造を持つか | 判断点 5 / 受け入れ条件 5（check-html.sh の RV-T\*） |

含めなかった問い: フック本体の実装方針（2/3 の調査）、サブエージェント起動・T1〜T4（2/3・3/3）、CLAUDE.md の書き換え（3/3）。

## 対象と方法

| 問い | 読む場所 | 確かめ方（書き込みなし） |
|---|---|---|
| Q1 | 上記パス、`10_spec/フック共通仕様.md` §1〜8、`10_spec/skills/20-common-step-{ticket,commit-push,report-view,shell-script}.md` | 仕様の機能単位（cmdpos の出力形式、scope 判定順、push-detect、transcript、ticket.sh サブコマンド、commit.sh の規約検査）ごとに「流用 / 改変 / 新規」を表にし、根拠の行番号を添える |
| Q2 | 参考実装のテストファイルと fixtures、`.claude/hooks/tests/`（空）、CLAUDE.md のテスト方針 | テストの構造（assert の書き方・一時リポジトリの作り方・実行スクリプト）を読み、`bash <test>.sh` で 1 本実行して Git Bash で通るかを確認する（参考ディレクトリ内で実行。書き込みは一時ディレクトリのみ）。`command -v bats` の有無 |
| Q3 | Claude Code 公式ドキュメント（hooks リファレンスの PreToolUse 入力、PowerShell ツール）を `claude-code-guide` エージェントで確認 | ドキュメントで確定できなければ、`wip/tmp/` に stdin を `logs/` へ書くだけの一時フックを置き `.claude/settings.json` に一時登録して PowerShell ツールを 1 回実行する（フック設定はセッション開始時に読まれるため、反映に再起動が要る場合はその旨を残課題にし、ドキュメントの答えを採る）。`settings.json` は完了時に元へ戻す |
| Q4 | MR-driven `rules/shell-script-style.md`、`hooks/lib/UsageTracking.sh`、`10_spec/skills/20-common-step-shell-script.md`、`00_requirement/rules/logger.md` | 仕様が定める関数・出力先（`logs/sh/<name>.log`）・redact パターンと参考実装の差を表にする。skills 配下 / hooks 配下からの相対パス解決の方法（`BASH_SOURCE` 起点）を確認 |
| Q5 | MR-driven `.claude/docs/` 配下のレポートテンプレート（`find -name '*.html'`）、`10_spec/skills/20-common-step-report-view.md` 検査 1〜6 | テンプレートの節構成・ID・外部参照（script/link/img の src・href）を列挙し、`data-required` を付ける節を決める材料にする |

外部技術調査: Q3 のみ（公式ドキュメントの参照。問い合わせ先は Claude Code ドキュメントに限る）。

## 調査チケット

| チケット | 担う問い | 依存 |
|---|---|---|
| 0003 investigation | Q1・Q4（参考実装スクリプトの読解はまとめて行う方が速い） | なし |
| 0004 investigation | Q2・Q5（テストとテンプレートの「動かして確かめる」もの） | なし |
| 0005 investigation | Q3（外部技術調査。一時フックの可能性があるため分離） | なし |

次の計画チケット: 0006 `ai-asset-design-plan`（predecessors: 0003, 0004, 0005）。

## 成果物の形

調査結果レポート `wip/30_reports/0003-investigation.md`（3 チケットで 1 本に追記。HTML は `check-html.sh` 完成後）に次があれば、AI アセット設計計画（対象なしの判定）と AI アセット実装計画（ステップ・テスト割付）が判断できる:

- Q1: 機能単位 × 流用 / 改変 / 新規 の表と、流用時に仕様と食い違う点（→ 設計フェーズの対象候補）
- Q2: 採用するテスト方式（ヘルパの形・実行コマンド・置き場 `.claude/hooks/tests/` と `.claude/skills/*/scripts/tests/`）と、Git Bash で通った証跡
- Q3: `tool_name` / `tool_input` の実際の値（出典: ドキュメントの節 or 記録したフック入力）と、T5 の結論（前提どおり / 縮退）
- Q4: logger / redact の置き場と読み込み方、仕様との差分
- Q5: 土台テンプレートのパスと、`data-required` 候補・外部依存の有無

## 保留した点

- 一時フックの登録が要るかは Q3 のドキュメント確認の結果で決める（チケット 0005 の作業ログに記す）
