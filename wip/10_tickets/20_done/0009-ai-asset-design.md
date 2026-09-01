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
started_at: "2026-09-01T02:43:05Z"
completed_at: "2026-09-01T02:48:37Z"
base_sha: "eeec720"
---

# 0009 AI アセット設計実施 — 共通ステップ仕様（shell-script / ticket / report-view）と logger 要件の修正

## 目的

設計計画 0006 の採否表のうち、`20-common-step-shell-script`（D9 本体 `frontmatter.sh`・D12・D15・D19）、`00_requirement/rules/logger.md`（D12）、`20-common-step-ticket`（D8・D10・D13）、`20-common-step-report-view`（D16・D17・付録の命名）を現在の正史として書き換える。

## DoD

- [x] shell-script 仕様に `frontmatter.sh`（関数・入れ子とインラインマップ・純 bash・CR 除去）と `test-lib.sh`（`source` 専用）・`run-tests.sh`（提供コマンド、`TR0xx`、サブコマンド）が OUT ひな形・Script 処理・テスト観点（FR-T\*・TR-T\*）に書かれている（根拠: 仕様書「OUT ひな形」の 5 箇条、「Script 処理」の frontmatter.sh（fm_extract / fm_get / fm_list / fm_has）・run-tests.sh（TR001〜005）節、「テスト観点」FR-T01〜05・TR-T01〜04・SS-T03〜04）
- [x] shell-script 仕様の雛形サンプルと logger 要件「使い方」の読み込み 1 行が D12 のフォールバック鎖になっており、要件の「1 行で読み込む・コピー禁止」は維持されている（根拠: 仕様書「Script 処理 > 読み込み行」の解決順 1〜4、IN/OUT サンプルの注記、`00_requirement/rules/logger.md`「使い方」の書き換え。「1 行」「行の中身を自作・改変しない」を両方に明記）
- [x] shell-script 仕様に D15（フックでは exit 2 を使わない。提供コマンドの 0/1/2 と切り分け）がある（根拠: 仕様書「Script 処理 > 終了コード」の 3 箇条）
- [x] ticket 仕様が D10（状態変更のコミットは `commit.sh` 経由。`overall-plan` 非コミットは維持）・D13（frontmatter が正）・D8（テンプレートの記載事項に `adversarial_review`）のとおりで、`commit-push` 仕様の呼出条件と矛盾しない（根拠: ticket 仕様「Script 処理」冒頭（`commit.sh -m ... -- <チケット>`、拒否時は移動しない）、create 4、OUT ひな形の記載事項行、ファイル名の段落、参照ナレッジ 2 行、TICKET-T10・T11、要件との対応 1 行。commit-push 仕様「呼出条件」2 行目と一致）
- [x] report-view 仕様に D16（必須節は空にせず「無し」1 行。一覧は書かない）・D17（プレースホルダは要素内容、`data-required` は属性で抽出）・付録の命名規約がある（根拠: 処理フロー 3、OUT ひな形の規約 2 箇条 + 付録の箇条、Script 処理の検査 6 の段落、RV-T06）
- [x] shell-script の要件書に `frontmatter.sh` / `run-tests.sh` を載せるかを判断し、載せる場合は受け入れ基準が追加されている（根拠: 載せる（要件は「共通ライブラリの提供と重複禁止」として外部的に書ける）。`00_requirement/skills/20-common-step-shell-script.md`「共通 logger の提供」に 1 項目追加。仕様書「要件との対応」に対応行を追加）
- [x] 各文書の「要件との対応」表・用語・インターフェースの整合が崩れておらず、プレースホルダ 0 件（根拠: 4 文書 + 要件 1 本の変更はいずれも節内の追記・行追加。プレースホルダの grep は全ファイル 0 件。関数名（fm_get / run_cmd / finish）と ID（TR / FR / TICKET-T10・11 / RV-T06）は §6 台帳（0008）と一致）
- [x] 決定の経緯が作業ログ「判断と根拠」に残っている（0010 の DDR の材料）（根拠: 本チケット作業ログ「判断と根拠」の 5 項目）

## 作業内容

- 計画書 0006 の骨子に従い該当節を Edit で書き換える
- 変更箇所を作業ログに列挙する

## 作業ログ

### 現在地

- 完了（未完了の項目なし）

### うまくいったこと

- 正規表現を使わない差し替えツール（`wip/tmp/apply-pairs.pl` + OLD/NEW の対を書いたテキスト）に切り替えたところ、5 ファイル 25 箇所の差し替えが一度も失敗しなかった

### うまくいかなかったこと

- なし（0006・0008 の事故を受けて手順を変えた後は問題なし）

### 仕様からの逸脱

- 手作業代替（ticket.sh 未実装）

### 判断と根拠

- D9（DDR i0006-01 の材料）: `frontmatter.sh` は shell-script スキル配下に置き、hooks/lib と `ticket.sh` の両方から `source`。純 bash・汎用 YAML でない（§9 の形だけ）。却下案: (1) hooks/lib に置いて skills から読む — 依存の向きが logger と逆になる。(2) yq — 本環境に無く依存を増やす。(3) frontmatter をフラット化する仕様変更 — 可読性を落とし §8・§9・WF208 の書き換えが要る
- D10（i0006-02）: `ticket.sh` は `commit.sh` を呼ぶ。拒否時は移動もしない（移動とコミットを分離すると「移動だけ済んでコミットされていない」状態が生まれる）。却下案: `git` 直実行 — 規約検査・除外突合が 2 箇所に散る
- D12: 読み込み行の解決順は BASH_SOURCE 上向き → CLAUDE_PROJECT_DIR → git → no-op。`frontmatter.sh` が読めない提供コマンドだけは終了 2（判定値が読めないのに続行すると危険側）。却下案: `git rev-parse` 単独 — fork と `set -e` 即死
- D16（i0006-03）: 必須節の一覧は仕様に書かずテンプレートの `data-required` だけが持つ。「無し」1 行の運用を処理フローに追加。却下案: 仕様に一覧を書く — テンプレートとの二重管理
- D19（i0006-04）: `test-lib.sh` に assert を集約し `test.template.sh` は source する骨格に。`run-tests.sh` は提供コマンド（TR001〜005）。却下案: bats — 依存追加と雛形・許可 glob の変更。各テストに assert を複製 — DRY 違反（参考実装の状態）
- D15: フックは終了 0 + JSON に統一し `exit 2` を使わない（§12 T6 が外れたときだけ縮退）

### 拒否・確認・迂回の記録

- なし

### 使った AI アセットと効き目

- 設計計画 0006 の骨子・調査レポートの Q2・Q4・付録 B §2-2: 関数名や解決順まで材料が揃っていて足りた
- `20-common-step-spec` 仕様の節構成: Script 処理にサブ節を増やす形で収まった

### スコープ外で見つけたこと

- `20-common-step-commit-push` 仕様の `commit.sh` の引数形（`-m "<件名>" -- <files>`）を ticket 仕様から参照した。commit-push 仕様側の Script 処理の記法と一致するか 0011（実装計画）で確認する
- `rules/` の bash-script ルール（`rules/` bash-script）が要件一覧（4 本）に無い。shell-script 仕様の参照ナレッジが指す先が実在しない → 0010 の横断整合で扱う

### AI アセットに反映すべき内容

- DDR i0006-01〜04 の材料は上記「判断と根拠」（0010 で作成）
- bash-script ルールの不在（上記）を 0010 で判定（logger 要件に統合するか、ルール体系に追加するか）

### 備考
