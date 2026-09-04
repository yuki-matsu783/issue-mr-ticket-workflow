---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0031"]
executor: main
human_review: {required: false, reason: "承認③により人間レビューは敵対的レビューで代替する"}
adversarial_review: {required: false, reason: "指摘の反映であり、2 回目の敵対的レビューを 0035 の完了後にまとめて行う"}
allow:
  write: [".claude/skills/00-workflow-issue-mr-driven/**", "logs/**", "wip/**"]
  ops: ["read", "build-test", "hook-test", "remote-read"]
started_at: "2026-09-04T12:56:36+09:00"
completed_at: ""
base_sha: "5b0e44f"
---

# 0037 S10 敵対的レビュー指摘の反映（boundary.sh 5 件）

## 目的

中核 3 枚の敵対的レビューで出た boundary.sh の指摘 5 件を直す（0034 の再起票）

## DoD

- [ ] requested_at とホストの時刻を同じ基準（エポック秒）で比べる。ローカルのオフセット表記（+09:00）と UTC の Z 表記を辞書順で比べる経路が無くなり、依頼直後に付いた指摘が findings から落ちない（根拠: ）
- [ ] findings の kind: thread にも requested_at 以降の絞り込みが掛かる（未解決スレッドの停止判定は全件のまま）（根拠: ）
- [ ] BD001・BD003・BD005 の複数項目メッセージで、一覧を先に出して最終行が 1 行の BD00x: になる。テストが最終行を assert_eq で固定する（根拠: ）
- [ ] status --offline が review-state.json を none で上書きしない（書き戻すのはオンラインで実態を確かめたときだけ）（根拠: ）
- [ ] logs/merge-state.json が別の MR・別ブランチのものなら無視される。ready まで終えた clone で新しい issue を始めても BD005 で止まらない（根拠: ）
- [ ] test_boundary.sh に上記 5 件の再現テストを足し、run-tests.sh --filter で全件通る（根拠: ）

## 作業内容

- 時刻はエポック秒に直してから比べる（jq に自前の変換を持たせる）
- result_ng に渡すのは 1 行の要約だけにし、一覧は printf で先に出す
- merge-state.json は現在の MR・ブランチと結びつかなければ無視する

## 経緯

0034 として起票したが、`--allow-write` / `--allow-ops` を繰り返し指定したため最後の 1 つしか入らず、宣言が作業の実体と合わなかった。着手済みチケットの `allow` は WF208 で変えられないので、0034 を取り消してこのチケットに起こし直した。フラグはカンマ区切りの 1 引数で渡す。

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
