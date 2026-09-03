---
type: ticket
ticket_type: investigation
predecessors: ["0006"]
executor: main
human_review: {required: false, reason: "承認③により人間レビューは fable の敵対的レビューで代替する"}
adversarial_review: {required: true, reason: "調査フェーズの切れ目で 5 枚まとめて 1 回行う（全体計画「敵対的レビューの回し方」）"}
allow:
  write: ["wip/**"]
  ops: ["read", "remote-read", "hook-test", "build-test"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0008 観点 D 補足: run-tests.sh の実行による fm_get / TICKET-T05 / CP-T08 の確認

## 目的

0006 が許可範囲の不足（hook-test 未宣言）で実行できなかったテストを、宣言を揃えたチケットで実行し、読み取りで出した結論を実測で裏づける

## DoD

- [ ] run-tests.sh --ids の出力（テスト ID の一覧と重複の報告）が 0006 のレポートに追記されている（根拠: ）
- [ ] FR-T03 と TICKET-T05 を含むテストが通ることが、実行コマンドと出力を根拠に書かれている（根拠: ）
- [ ] CP-T08 の重複が run-tests.sh の報告として現れることが確認され、現れない場合はその理由が書かれている（根拠: ）
- [ ] 読み取りで出した 0006 の d4・d5 の結論と実測が食い違う場合、食い違いが明記されている（根拠: ）

## 作業内容

- run-tests.sh --ids でテスト ID の一覧と重複を得る
- frontmatter とチケットのテストを実行して結果を得る
- 0006 のレポート（md と HTML）に実測の節を追記して check-html.sh に通す

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
