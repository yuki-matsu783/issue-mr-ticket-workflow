---
type: ticket
ticket_type: investigation
predecessors: ["0002"]
executor: main
human_review: {required: false, reason: "承認③により人間レビューは fable の敵対的レビューで代替する"}
adversarial_review: {required: true, reason: "調査フェーズの切れ目で 4 枚まとめて 1 回行う（全体計画「敵対的レビューの回し方」）"}
allow:
  write: ["wip/**"]
  ops: ["read", "remote-read"]
started_at: "2026-09-03T14:13:42+09:00"
completed_at: ""
base_sha: "b20e7a4"
---

# 0004 観点 B: boundary.sh / finalize.sh の仕様の洗い出しと実装済みフックとの食い違い

## 目的

提供コマンド 2 本の判定順・入出力・logs のスキーマを仕様から書き出し、実装済みフックが前提にしている姿との食い違いを列挙して設計が解消先を決められるようにする

## DoD

- [ ] 観点『boundary.sh と finalize.sh は何をどの順に検査し、何を入出力し、logs に何を書くのか。仕様と実装済みフックはどこで食い違うのか』への答えが wip/30_reports/0004-investigation.md に書かれている（根拠: ）
- [ ] サブコマンドごとの判定順と入出力の要約が、根拠（仕様のファイル:行）付きで添えられている（根拠: ）
- [ ] logs の 4 ファイル（mr.json / review-state.json / review-history.jsonl / merge-state.json）のスキーマが、書く側（仕様）と読む側（フック）の両方から書き出されている（根拠: ）
- [ ] 食い違いが「項目 / 仕様の言い分 / 実装の言い分 / 実測に依存するか」の表で全件挙がっている（置き場の食い違いを含む）（根拠: ）
- [ ] 解消の判断は行わず「設計へ回す」と明示され、答えが出なかった問いは理由付きで残課題に残っている（根拠: ）
- [ ] md と同名の HTML があり check-html.sh が通っている（根拠: ）

## 作業内容

- 00-workflow-issue-mr-driven 仕様の boundary.sh（BD001〜005 / BD-T01〜13）を読み、サブコマンドごとに判定順と入出力を書き出す
- 10-task-overall-summary 仕様の finalize.sh（FN001〜003 / FN-T01〜05）について同じことを行う
- workflow-state-guard / session-start / workflow-entry と hooks/lib が前提にしているパス・スキーマを読み出す
- 食い違いの表を作り、レポートと HTML を書く

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
