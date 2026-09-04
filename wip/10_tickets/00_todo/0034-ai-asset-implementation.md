---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0031"]
executor: main
human_review: {required: false, reason: "承認③により人間レビューは敵対的レビューで代替する"}
adversarial_review: {required: false, reason: "指摘の反映であり、2 回目の敵対的レビューを 0035 の完了後にまとめて行う"}
allow:
  write: ["wip/**"]
  ops: ["remote-read"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0034 S10 敵対的レビュー指摘の反映（boundary.sh 5 件）

## 目的

中核 3 枚の敵対的レビューで出た boundary.sh の指摘 5 件を直す

## DoD

- [ ] requested_at と GitHub の時刻を同じ基準（UTC）で比べる。now_iso のローカルオフセット表記と Z 表記を辞書順で比べる経路が無くなり、依頼直後に付いた指摘が findings から落ちない（根拠: ）（根拠: ）
- [ ] findings の kind: thread にも requested_at 以降の絞り込みが掛かる（未解決スレッドの停止判定は全件のまま）（根拠: ）（根拠: ）
- [ ] BD001・BD003・BD005 の複数項目メッセージで、一覧を先に出して最終行が 1 行の BD00x: になる。テストが最終行を assert_eq で固定する（根拠: ）（根拠: ）
- [ ] status --offline が review-state.json を none で上書きしない（読み取りだけで返すか、再導出の印を付けてオンラインの status が再導出する）（根拠: ）（根拠: ）
- [ ] logs/merge-state.json が別の issue・別ブランチのものなら無視される。ready まで終えた clone で新しい issue を始めても BD005 で止まらない（根拠: ）（根拠: ）
- [ ] test_boundary.sh に上記 5 件の再現テストを足し、run-tests.sh --filter で全件通る（根拠: ）（根拠: ）

## 作業内容

- 時刻は UTC に統一し、jq の比較を数値（fromdateiso8601）にするか Z 表記に揃える
- result_ng に渡すのは 1 行の要約だけにし、一覧は printf で先に出す
- merge-state.json に mr / branch を持たせ、現在の MR・ブランチと一致しないときは無視する

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
