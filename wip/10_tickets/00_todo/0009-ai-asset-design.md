---
type: ticket
ticket_type: ai-asset-design
predecessors: ["0006"]
executor: main
human_review: {required: true, reason: "提供コマンドの仕様の変更（ticket.sh の commit 経路・frontmatter.sh・test-lib / run-tests）。承認④により opus 自己レビューで代替"}
adversarial_review: {required: true, reason: "仕様は正史。設計実施の切れ目で 1 回（全体計画の方針）"}
allow:
  write: [".claude/docs/00_requirement/**", ".claude/docs/10_spec/**", ".claude/docs/20_ddr/**", "wip/**"]
  ops: ["read"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0009 AI アセット設計実施 — 共通ステップ仕様（shell-script / ticket / report-view）と logger 要件の修正

## 目的

設計計画 0006 の採否表のうち、`20-common-step-shell-script`（D9 本体 `frontmatter.sh`・D12・D15・D19）、`00_requirement/rules/logger.md`（D12）、`20-common-step-ticket`（D8・D10・D13）、`20-common-step-report-view`（D16・D17・付録の命名）を現在の正史として書き換える。

## DoD

- [ ] shell-script 仕様に `frontmatter.sh`（関数・入れ子とインラインマップ・純 bash・CR 除去）と `test-lib.sh`（`source` 専用）・`run-tests.sh`（提供コマンド、`TR0xx`、サブコマンド）が OUT ひな形・Script 処理・テスト観点（FR-T\*・TR-T\*）に書かれている（根拠: ）
- [ ] shell-script 仕様の雛形サンプルと logger 要件「使い方」の読み込み 1 行が D12 のフォールバック鎖になっており、要件の「1 行で読み込む・コピー禁止」は維持されている（根拠: ）
- [ ] shell-script 仕様に D15（フックでは exit 2 を使わない。提供コマンドの 0/1/2 と切り分け）がある（根拠: ）
- [ ] ticket 仕様が D10（状態変更のコミットは `commit.sh` 経由。`overall-plan` 非コミットは維持）・D13（frontmatter が正）・D8（テンプレートの記載事項に `adversarial_review`）のとおりで、`commit-push` 仕様の呼出条件と矛盾しない（根拠: ）
- [ ] report-view 仕様に D16（必須節は空にせず「無し」1 行。一覧は書かない）・D17（プレースホルダは要素内容、`data-required` は属性で抽出）・付録の命名規約がある（根拠: ）
- [ ] shell-script の要件書に `frontmatter.sh` / `run-tests.sh` を載せるかを判断し、載せる場合は受け入れ基準が追加されている（根拠: ）
- [ ] 各文書の「要件との対応」表・用語・インターフェースの整合が崩れておらず、プレースホルダ 0 件（根拠: ）
- [ ] 決定の経緯が作業ログ「判断と根拠」に残っている（0010 の DDR の材料）（根拠: ）

## 作業内容

- 計画書 0006 の骨子に従い該当節を Edit で書き換える
- 変更箇所を作業ログに列挙する

## 作業ログ

### 現在地

- 未着手

### うまくいったこと

### うまくいかなかったこと

### 仕様からの逸脱

### 判断と根拠

### 拒否・確認・迂回の記録

### 使った AI アセットと効き目

### スコープ外で見つけたこと

### AI アセットに反映すべき内容

### 備考
