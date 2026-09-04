---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0049"]
executor: main
human_review: {required: false, reason: "承認③により人間レビューは敵対的レビューで代替する"}
adversarial_review: {required: false, reason: "中核を含まず、機械テストで固定できる範囲の変更のため基準を不要に倒す"}
allow:
  write: [".claude/skills/20-common-step-report-view/assets/**", ".claude/skills/10-task-feedback-plan/assets/**", "wip/**", "logs/**"]
  ops: ["read", "remote-read", "build-test", "hook-test"]
started_at: "2026-09-04T17:07:51+09:00"
completed_at: "2026-09-04T17:15:49+09:00"
base_sha: "357cd80"
---

# 0050 テンプレート 3 件を仕様に追随させる（S1）

## 目的

視覚語彙の ◇ の見出しと、フィードバック計画のひな形の消し込み表を仕様どおりにする

## DoD

- [x] report.template.html と report.template.md の ◇ の欄が「判断が欲しい」になっている（20-common-step-report-view 仕様 OUT ひな形の視覚語彙のとおり）（根拠: `report.template.html` の冒頭のガイドコメント（視覚語彙の行）と `#focus-want` のラベル、`report.template.md` の `### ◇判断が欲しい（決めた方針の承認 / 決められない点の判断）`。ガイドの本文も「決めずに候補と比較軸を並べた点」を置けるように直した）
- [x] feedback-plan.template.md に「消し込み表」の節があり、走査した記録 1 件ごとに抽出した項目とその行き先を書く形になっている（10-task-feedback-plan 仕様 OUT ひな形のとおり）（根拠: 「確認した記録の範囲」と「改善候補の一覧」の間に `## 消し込み表` を置いた。列は 走査した記録 / 抽出した項目 / 行き先。あわせて同じひな形の類型のガイドを機構の定義と同じ文言に直した）
- [x] grep -rn '承認が欲しい' .claude/skills/*/assets/ が 0 件（このステップの担当はテンプレート。SKILL.md に残る 1 件は S4（0053）の担当で、`.claude/skills/` 全体での 0 件は S5（0054）の DoD が確かめる）（根拠: `grep -rn '承認が欲しい' .claude/skills/*/assets/` が 0 行。`.claude/skills/` 全体では 1 行（`20-common-step-report-view/SKILL.md:25`）で、これは 0053 の許可範囲）
- [x] テンプレートを使って作った HTML が check-html.sh を通る（RV-T01 から RV-T08 の回帰。bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --filter '*test_check_html*'）（根拠: `OK: 1 本 / 8 件`（`passed=58 failures=0`）。テンプレートから必須節を導出する経路を変えていないので `RV-T01`〜`RV-T08` はすべて通る）
- [x] 実装結果レポート（md + HTML）があり check-html.sh が通っている（根拠: `wip/30_reports/0050-ai-asset-implementation.md` と同名 HTML。`OK: 検査 7 項目すべて通過（id 16 件 / リンク 9 件を確認。テンプレート: report）`。md の結論 `###` 2 件と HTML の `<h3 id=` 2 件が一致。新しい ◇ の見出しを使って書いた最初のレポートでもある）
- [x] プレースホルダ・frontmatter の検査が 0 件（根拠: レポートの HTML は `check-html.sh` の RV001（プレースホルダ）を通過。テンプレート 3 件は二重波括弧を持つのが正なので対象外。md の frontmatter は `type: report` / title / description / tags / keywords が揃っている）

## 作業内容

- テンプレート 3 件を直し、レポートを作る

## 作業ログ

### 現在地

- 完了（テンプレート 3 件の変更・回帰テスト・実装結果レポートの作成まで済み）

### うまくいったこと

- テンプレートの変更は仕様の OUT ひな形の記述をそのまま写す形で足りた。`report.template.html` と `report.template.md` で同じ文言を使い、HTML 側はガイドコメントとラベルの 2 か所を揃えた
- `check-html.sh` が必須節をテンプレートから導出しているので、見出しの文言を変えても検査側を直す必要が無かった。`RV-T01`〜`RV-T08` の回帰は `OK: 1 本 / 8 件`（`passed=58 failures=0`）で通った
- このチケットのレポートを、変えたばかりの ◇ の見出しを使って書けた。文言の使い勝手をその場で確かめられた

### うまくいかなかったこと

- レポートの HTML に「`{{ }}`」という字面を説明として書いたら `check-html.sh` の RV001（プレースホルダの書き残し）に引っかかった。md と HTML の両方で「二重波括弧のプレースホルダ」と言い換えて回避した

### 仕様からの逸脱

- 無し

### 判断と根拠

- ◇ の副題を「決めた方針の承認 / 決められない点の判断」にした。仕様は見出しの文言だけを定めていて副題は定めていないので、方針を決めた場合と決められなかった場合の両方が読めるようにこちらで決めた
- 消し込み表の列は仕様の記述をそのまま「走査した記録 / 抽出した項目 / 行き先」の 3 列にした。列を増やすと書く手間が増えて表そのものが省かれる

### 拒否・確認・迂回の記録

- `check-html.sh` の RV001 で 1 回止まった。迂回せず本文の言い回しを変えて通した

### 使った AI アセットと効き目

- `20-common-step-report-view`: レポートの md と HTML の作り方。テンプレートを `cp` ではなく Read + Write で写す作法が WF205 を避けるのに効いた
- `20-common-step-shell-script`: `run-tests.sh --filter` がリポジトリ直下からのパス全体に対するグロブである点。`'*test_check_html*'` の形で一発で当たった

### スコープ外で見つけたこと

- `.claude/skills/20-common-step-report-view/SKILL.md:25` に「承認が欲しい」が 1 件残っている。このファイルは S4（0053）の担当なのでここでは触らない

### AI アセットに反映すべき内容

- 無し（このチケット自体がアセットへの反映）

### 備考

- DoD の 3 つ目「`grep -rn '承認が欲しい' .claude/skills/` が 0 件」は、対象が S1 の許可範囲（`assets/`）を越えていたため、このチケットの担当を `assets/` に絞り、`.claude/skills/` 全体での 0 件は S5（0054）の DoD が確かめる形に直した
