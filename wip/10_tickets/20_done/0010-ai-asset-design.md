---
type: ticket
ticket_type: ai-asset-design
predecessors: ["0008", "0009"]
executor: main
human_review: {required: true, reason: "タスク仕様の変更と DDR。承認④により opus 自己レビューで代替"}
adversarial_review: {required: true, reason: "仕様は正史。設計実施の切れ目で 1 回（全体計画の方針）"}
allow:
  write: [".claude/docs/00_requirement/**", ".claude/docs/10_spec/**", ".claude/docs/20_ddr/**", ".claude/docs/90_glossary/**", "wip/**"]
  ops: ["read"]
started_at: "2026-09-01T02:48:41Z"
completed_at: "2026-09-01T02:53:20Z"
base_sha: "10f5dcb"
---

# 0010 AI アセット設計実施 — タスク仕様（調査）・eval ID 5 本・DDR・横断整合

## 目的

設計計画 0006 の採否表のうち、`10-task-investigation-plan` / `-exec`（D20・D21。要件側に同じ禁止があれば要件も）、テスト ID の無い共通ステップ仕様 5 本の eval ID、`20-common-step-ai-asset-creator` の eval 形式、DDR `i0006-01〜05`、横断文書・用語集・`20-common-step-spec` の整合を反映する。

## DoD

- [x] investigation-plan / exec の仕様（と必要なら要件）が D20（計画チケットの `allow.ops` 宣言があるときだけテスト実行可。既定は禁止）・D21（`.claude/**` の一時変更を計画しない）のとおりで、§8 初期値（0008）と整合している（根拠: exec 仕様の禁止事項 2 箇条と固有手順 2 箇条、exec 要件のメイン 1 項目と例外 1 項目、plan 仕様の固有手順 3 箇条、plan 要件のメイン 2 項目。§8 の `investigation` 行（`build-test, web` は宣言必須）と同じ語）
- [x] `ai-asset-creator` / `feature-mr` / `issue` / `requirement` / `spec` の仕様に「テスト観点」表（eval ID、入力・期待する振る舞い・判定方法）があり、接頭辞が §6 台帳（0008）と一致している（根拠: 5 本の Script 処理に「テスト観点（eval）」表を追加（AC-E01〜03 / FM-E01〜03 / IS-E01〜03 / RQ-E01〜03 / SP-E01〜03）。§6 台帳の行「AC-E / FM-E / IS-E / RQ-E / SP-E」と一致）
- [x] `ai-asset-creator` 仕様に eval テンプレートの形式（参考 `evals.json` の項目を md 表に）がある（根拠: OUT ひな形の `assets/eval.template.md` の箇条に評価シナリオの項目（eval ID・入力・期待・判定・添付）と `evals.json` との対応、仕様書の表との 1:1 を追記）
- [x] DDR `i0006-01〜05`（frontmatter パーサと置き場 / ticket.sh のコミット経路 / 必須節の格上げ / テスト方式 / 調査でのテスト実行）が DDR のフォーマットで作成され、採らなかった案と理由がある（根拠: `.claude/docs/20_ddr/i0006-01〜05-*.md`。各 frontmatter（type: ddr）と 背景 / 決定 / 理由 / 却下した案 / 影響 の 5 節）
- [x] 横断文書（`自己改善ワークフロー機構.md`・`ルール体系.md`）と用語集、`20-common-step-spec.md` の eval ID 記法を確認し、必要な箇所だけ更新されている（変更なしの場合は確認した旨が作業ログにある）（根拠: `20-common-step-spec.md` のスキル行に eval ID の規則を追記。機構要件・ルール体系・用語集は変更なし（確認内容は作業ログ「判断と根拠」）。ただしルール体系の確認で「ルールは 14 本（成果物 7 + 行動 7）」と分かり、issue の受け入れ条件 1 の「4 本」との関係を実装計画へ申し送り）
- [x] 各文書の「要件との対応」表・用語の整合が崩れておらず、プレースホルダ 0 件（根拠: 変更はいずれも節内の追記・行追加。exec / plan 仕様の「要件との対応」は既存行（外部技術調査の明示・書き込み拒否）が新項目も指すため行の追加は不要と判断。プレースホルダの grep は全ファイル 0 件）

## 作業内容

- 0008・0009 の作業ログ「判断と根拠」を DDR の材料にする
- 計画書 0006 の骨子に従い該当節を Edit で書き換え、DDR を新規作成する

## 作業ログ

### 現在地

- 完了（未完了の項目なし）

### うまくいったこと

- 0008・0009 の作業ログ「判断と根拠」に却下案まで書いてあったので、DDR 5 本はそれを DDR の節に写すだけで済んだ

### うまくいかなかったこと

- なし

### 仕様からの逸脱

- 手作業代替（ticket.sh 未実装）

### 判断と根拠

- D20 は要件（exec・plan）にも及ぶ変更なので要件を先に直し、仕様はそれに従う形にした（要件は外部的な振る舞い「明示があるときだけ実行できる」、仕様は `allow.ops` の `build-test` という実現手段）
- eval ID は各スキル 3 件（代表的な正常系 2 + 例外 1）にとどめた。網羅は実装計画の eval 定義（`.claude/evals/<アセット>.md`）で広げる
- 横断整合の確認結果: `自己改善ワークフロー機構.md` は提供コマンドを個別に列挙していないので `run-tests.sh` の追記は不要。`ルール体系.md` は `bash-script` ルールを既に成果物ルール 7 本の 1 つとして持っており（shell-script 仕様の参照先は実在する要件）、logger 要件との重複も無い。用語集「提供コマンド」は総称の定義で列挙が無く変更不要。「敵対的レビュー」の定義は現状のまま（`adversarial_review` の frontmatter 化は用語の変更ではない）
- ルール体系は成果物ルール 7 本 + 行動ルール 7 本 = 14 本を要求しており、個別要件書を持つのは 4 本（work-defaults・design-docs・ai-asset-design-docs・logger）だけ。issue #6 の受け入れ条件 1「ルール 4 本」は個別要件書のある 4 本を指すが、`00_requirement/rules/` どおりに作るなら 14 本が対象になる。**実装計画（0011）で 14 本を本 issue に含めるか（推奨: 含める。取り込み元が参考実装にあり工数は小さい）を決める**

### 拒否・確認・迂回の記録

- なし

### 使った AI アセットと効き目

- DDR の既存例（i0004-04・i0004-07）: 節構成と frontmatter の形を写せて足りた
- `20-common-step-spec` 仕様: 「Script 処理（テスト観点含む）」の規定に eval の扱いが無かったので追記した（自分で使っている仕様の欠けを埋めた形）

### スコープ外で見つけたこと

- ルール 14 本と issue 受け入れ条件「4 本」の関係（上記。0011 で判定）
- `investigation` 以外の実施タスク（design / implementation 等）の `ops` 上限にも同じ「宣言必須の分類」の考え方を適用できるが、本 issue の範囲外（2/3 の scope-limits 実装時に検討）

### AI アセットに反映すべき内容

- 実装計画 0011 へ: ルールの本数（14 本）の判定、`.gitattributes` を最初のステップに、`frontmatter.sh` / `test-lib.sh` / `run-tests.sh` を中核ステップに含める
- eval 定義の網羅（各アセットの `.claude/evals/<アセット>.md`）は実装フェーズの成果物

### 備考
