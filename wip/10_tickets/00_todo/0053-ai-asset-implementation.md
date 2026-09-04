---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0052"]
executor: main
human_review: {required: false, reason: "承認③により人間レビューは敵対的レビューで代替する"}
adversarial_review: {required: false, reason: "中核を含まない文書の追随"}
allow:
  write: [".claude/skills/20-common-step-report-view/SKILL.md", ".claude/skills/20-common-step-requirement/SKILL.md", ".claude/skills/20-common-step-spec/SKILL.md", ".claude/skills/20-common-step-shell-script/SKILL.md", ".claude/skills/20-common-step-ai-asset-creator/SKILL.md", ".claude/skills/20-common-step-feature-mr/SKILL.md", ".claude/rules/work-defaults.md", "wip/**"]
  ops: ["read", "remote-read"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0053 共通ステップスキル 6 本とルール 1 本を仕様に追随させる（S4）

## 目的

作法系の仕様に足した規約を、対応する SKILL.md とルール本体に写す

## DoD

- [ ] 20-common-step-report-view/SKILL.md の手順が cp ではなく Read と Write でテンプレートを書き出す形になり、節の対応表と数え方（内訳を添える・累積は 1 か所）がある（根拠: ）
- [ ] 20-common-step-requirement/SKILL.md のセルフレビューが 16 項目になり、図の更新要否の判断と数の書き方がある（根拠: ）
- [ ] 20-common-step-spec/SKILL.md に、識別子表に引数・環境の誤りの番号を 1 つ置く規約・eval の表の階層・番号参照は名前でも辿れるようにすることがある（根拠: ）
- [ ] 20-common-step-shell-script/SKILL.md にテストの書き方 5 項目（コミットしない / 外部プロセスを増やさない / 負のコントロールは環境が変わっても落ちるか / jq の前に JSON か検査 / 1 行 1 値）と --filter の意味がある（根拠: ）
- [ ] 20-common-step-ai-asset-creator/SKILL.md に標準構成の但し書き・移設の完了条件・参照更新の作法・eval の要否の参照がある（根拠: ）
- [ ] 20-common-step-feature-mr/SKILL.md のブランチ作成が --no-track 付きになっている（根拠: ）
- [ ] .claude/rules/work-defaults.md に、既定のモデルで敵対的レビュアーを起動できないときの代替の決め方がある（根拠: ）
- [ ] 7 本それぞれについて、仕様書（ルールは要件）の該当節と 1:1 で対応することを根拠付きで示している（根拠: ）
- [ ] プレースホルダ・frontmatter の検査が 0 件。実装結果レポートに S4 の節が追記されている（根拠: ）

## 作業内容

- 6 本の SKILL.md とルール 1 本を順に直す

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
