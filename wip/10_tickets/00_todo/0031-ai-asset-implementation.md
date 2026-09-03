---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0030"]
executor: main
human_review: {required: false, reason: "承認③により人間レビューは敵対的レビューで代替する"}
adversarial_review: {required: false, reason: "中核を含まず、件数と旧名 0 件は検索で機械的に判定できる"}
allow:
  write: [".claude/evals/**", ".claude/skills/**", ".claude/rules/**", "wip/**"]
  ops: ["read", "remote-read"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0031 S8 eval 定義 19 件と旧資産 5 件の処遇（旧名 26 件）

## 目的

0023 が仕様書に書いた eval の表を .claude/evals/ に落とし、旧ワークフロースキルに残った資産 5 件を削除・移設・移行で片付ける

## DoD

- [ ] .claude/evals/<アセット名>.md が 19 本作成され、対応する仕様書の「テスト観点」節の eval ID と 1:1 で対応している（定義まで。評価の実行はしない）（根拠: ）
- [ ] .claude/evals/ のファイル数が 28 になっている（既存 9 + 新規 19。ls での実測を根拠に貼る）（根拠: ）
- [ ] 旧 evals/evals.json 2 本が .claude/evals/00-workflow-issue-mr-driven.md と .claude/evals/00-workflow-quick-request.md へ移行され、移行先で旧名 26 件が新名に書き換わっている（持ち越さない）（根拠: ）
- [ ] 旧資産のうち削除 2 件（issue-addendum.template.md・issue-notify.template.md）が消え、削除の前に中身が新しい置き場にあること（前者は 20-common-step-issue/assets/）を確かめている（根拠: ）
- [ ] references/issue-triage.md が 20-common-step-issue へ移設されている（根拠: ）
- [ ] rules/work-defaults.md に敵対的レビュアーのモデルを書く行があり、レビュアーであることが明記されている（残課題 R7・R9）（根拠: ）

## 作業内容

- eval 定義 19 件を作る（うち 2 件は evals.json からの移行）
- 旧資産 5 件を削除・移設・移行し、work-defaults にレビュアーのモデルの行を足す

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
