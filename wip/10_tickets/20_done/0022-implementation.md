---
type: ticket
ticket_type: implementation
predecessors: ["0021"]
executor: main
human_review: {required: false, reason: "全体計画の方針の差分 4 により、人間レビューはワークごとの敵対的レビューに置き換える"}
adversarial_review: {required: false, reason: "テスト 1 件の追加とコメントの訂正で、機械テストが全通過なら足りる（基準の調整条件に該当）"}
allow:
  write: ["src/**", "wip/**"]
  ops: ["read", "build-test"]
started_at: "2026-09-02T07:27:03+00:00"
completed_at: "2026-09-02T07:27:24+00:00"
base_sha: "6d14f6d"
---

# 0022 種類不明・実行者不明のテスト追加とコード内の仕様参照の訂正

## 目的

仕様に書いた「種類不明」「実行者不明」の表示を機械テストで守り、コード内の仕様参照の手順番号を直す

## DoD

- [x] test/render.test.ts の TB-T14 に、ticket_type と executor が未設定のカードに「種類不明」「実行者不明」が出ることを確かめるテストがある（根拠: test/render.test.ts の「TB-T14 種類と実行者が未設定のカードに「種類不明」「実行者不明」を出す」。バッジが消えていないことと、対応する TB002 が ul.issues に出ることを両方確かめる）
- [x] src/core/ticket.ts の仕様参照コメントが手順 6 を指している（根拠: src/core/ticket.ts の findHeading の直前のコメント。手順 5 → 手順 6）
- [x] npm test が全通過する（根拠: npm test → # tests 47 / # pass 47 / # fail 0（46 → 47 件））

## 作業内容

- DoD の各項目を順に満たす

## 作業ログ

### 現在地

- 完了

### うまくいったこと

- 仕様に書いた「バッジそのものを消さない」という要点を、テストで守れる形にできた。バッジの有無と TB002 の対応を同じテストで見ている

### うまくいかなかったこと

- 無し

### 仕様からの逸脱

- 無し

### 判断と根拠

- テストは既存の TB-T14 の並びに足した。仕様のテスト観点表でも TB-T14 の観点として書いたため

### 拒否・確認・迂回の記録

- 無し

### 使った AI アセットと効き目

- `20-common-step-commit-push`（commit.sh）: 2 ファイルだけを明示してコミットできた

### スコープ外で見つけたこと

- 無し

### AI アセットに反映すべき内容

- 現時点で新規は 0 件。理由: テスト 1 件の追加とコメント 1 行の訂正で、使ったアセットはいずれも仕様どおり動いた

### 備考

- 無し
