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
completed_at: "2026-09-04T13:07:14+09:00"
base_sha: "5b0e44f"
---

# 0037 S10 敵対的レビュー指摘の反映（boundary.sh 5 件）

## 目的

中核 3 枚の敵対的レビューで出た boundary.sh の指摘 5 件を直す（0034 の再起票）

## DoD

- [x] requested_at とホストの時刻を同じ基準（エポック秒）で比べる。ローカルのオフセット表記（+09:00）と UTC の Z 表記を辞書順で比べる経路が無くなり、依頼直後に付いた指摘が findings から落ちない（根拠: findings の jq に `civil_days` / `ep` を足し、`$since` と `created_at` / `submitted_at` の両方を `ep` でエポック秒にしてから比べる。`fromdateiso8601` を使わないのは Windows の jq が `strptime/1 not implemented on this platform` で落ちるため。`BD-T14` が依頼の 1 秒後のコメントを拾い、1 時間前のコメントを落とすことを固定する）
- [x] findings の kind: thread にも requested_at 以降の絞り込みが掛かる（未解決スレッドの停止判定は全件のまま）（根拠: `after($se)` を thread / review / comment の 3 経路すべてに掛けた。`unresolved`（停止判定）は従来どおり全件を見る。`BD-T15` が「前の切れ目のスレッド」を落とし「今回のスレッド」だけを拾うことを固定する）
- [x] BD001・BD003・BD005 の複数項目メッセージで、一覧を先に出して最終行が 1 行の BD00x: になる。テストが最終行を assert_eq で固定する（根拠: 5 か所（`check_conflicts` / `request` / `skip` / `complete` の変更要求と未解決スレッド）を「`printf` で一覧 → `result_ng` に 1 行」に直した。`BD-T16` が BD001 × 2 経路と BD005 の最終行を `assert_eq` で固定する）
- [x] status --offline が review-state.json を none で上書きしない（書き戻すのはオンラインで実態を確かめたときだけ）（根拠: 再導出の書き戻しを `[ "$offline" -eq 0 ]` で囲み、offline では `log_info` を残すだけにした。`BD-T17` が「offline の後にファイルが無い」「online の後にファイルがある」を確かめる）
- [x] logs/merge-state.json が別の MR・別ブランチのものなら無視される。ready まで終えた clone で新しい issue を始めても BD005 で止まらない（根拠: `merge_state()` が `.mr` と `.branch` を現在の MR・ブランチと突き合わせ、食い違えば空を返す。`BD-T18` が「別 MR・別ブランチの ready は素通り」「同じブランチの ready は BD005」を確かめる）
- [x] test_boundary.sh に上記 5 件の再現テストを足し、run-tests.sh --filter で全件通る（根拠: `BD-T14`〜`BD-T18` を追加し、`test_boundary.sh` が **97 アサーション PASS**（従来 74 + 新規 23）。`BD-T14` と `BD-T15` は `date -u -d` が使えない環境では実時刻を作り分けられないので飛ばす分岐を持つが、この環境では 4 アサーションずつ実際に走っている）

## 作業内容

- 時刻はエポック秒に直してから比べる（jq に自前の変換を持たせる）
- result_ng に渡すのは 1 行の要約だけにし、一覧は printf で先に出す
- merge-state.json は現在の MR・ブランチと結びつかなければ無視する

## 経緯

0034 として起票したが、`--allow-write` / `--allow-ops` を繰り返し指定したため最後の 1 つしか入らず、宣言が作業の実体と合わなかった。着手済みチケットの `allow` は WF208 で変えられないので、0034 を取り消してこのチケットに起こし直した。フラグはカンマ区切りの 1 引数で渡す。

## 作業ログ

### 現在地

- 完了

### うまくいったこと

- 時刻の比較を「文字列の辞書順」から「エポック秒」に変えたことで、タイムゾーンの取り違えが構造的に起きなくなった。`ep` は `Z` / `+09:00` / `+0900` / 小数秒付きのどれも受ける
- 最終行の契約の崩れは 5 か所すべてが同じ形（`result_ng` に改行入りの文字列を渡す）だったので、まとめて同じ直し方にできた
- `merge_state()` に MR とブランチの突き合わせを入れたことで、`logs/` がブランチに紐づかない問題の実害（次の issue が始められない）が消えた

### うまくいかなかったこと

- `fromdateiso8601` が使えなかった。Windows の jq 1.6 は `strptime/1 not implemented on this platform` で落ちる。`civil_days`（Howard Hinnant の days_from_civil）を jq で書いて日数を自前に計算した。エポック 0（1970-01-01T00:00:00Z）と「解釈できない」が同じ 0 になるが、実際の時刻として 0 は出てこないので実害は無い
- 起票時に `--allow-write` / `--allow-ops` を繰り返し指定したため最後の 1 つしか入らず、宣言が実体と合わなかった（0034）。着手済みチケットの `allow` は WF208 で変えられないので、0034 を取り消してこのチケットに起こし直した。フラグはカンマ区切りの 1 引数で渡す

### 仕様からの逸脱

- **`logs/merge-state.json` に `branch` を足すことを前提にした**。仕様のスキーマは `{"issue": N, "mr": M, "state": ...}` で `branch` を持たない。`boundary.sh` は `branch` が無くても動く（`mr` だけで突き合わせる）が、offline では `mr` が取れないので `branch` があるほうが確実。書き込み側（`finalize.sh`）の対応は 0035 で行い、スキーマの追記は設計反映へ送る
- **時刻の未取得を「残す」側に倒した**。`created_at` が無い・解釈できない指摘は絞り込みで落とさず findings に載せる。仕様は「`requested_at` 以降の指摘を整形」としか書いていないが、人間の指摘を黙って落とすほうが害が大きい

### 判断と根拠

- 記録する時刻の表記（`now_iso` のローカルオフセット）は変えなかった。表記を UTC に変えると既存の記録との一貫性が崩れ、人間が読むときも分かりにくい。比較の側をエポックに直すほうが影響が小さい
- `unresolved`（未解決スレッドによる停止判定）には `$since` を掛けなかった。前の切れ目から残っている未解決スレッドは「まだ解決していない」のだから、今回の切れ目でも止めるのが正しい

### 拒否・確認・迂回の記録

- WF208（着手済みチケットの `allow` の変更）に 1 回当たった。迂回せず、0034 を取り消して 0037 として起こし直した
- TR006（`allow.ops` に無い分類でのテスト実行）に 1 回当たった。上と同じ原因で、宣言を直した 0037 で実行した

### 使った AI アセットと効き目

- `test-lib.sh` の `run_cmd` / `R_OUT`: 最終行の契約（`${R_OUT##*$'\n'}`）を `assert_eq` で固定する形が既にあり、そのまま使えた
- 敵対的レビュアーの指摘 JSON: `path` と `line` が入っているので、直す箇所を探す時間がほぼ要らなかった

### スコープ外で見つけたこと

- `ticket.sh create` の `--allow-write` / `--allow-ops` はカンマ区切りの 1 引数で、繰り返し指定は最後だけが効く。使い方の行には書かれているが、繰り返し指定を黙って捨てるのは気づきにくい（エラーにするか累積するかを検討したい）

### AI アセットに反映すべき内容

- `merge-state.json` のスキーマに `branch` を足す（設計反映）
- `ticket.sh create` の繰り返しフラグの扱い（フィードバック計画）

### 備考

- allow.write は `00-workflow-issue-mr-driven/**` / `logs/**` / `wip/**`。この範囲だけを触った
