---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0038"]
executor: main
human_review: {required: false, reason: "承認③により人間レビューは敵対的レビューで代替する"}
adversarial_review: {required: false, reason: "実装フェーズの敵対的レビューは上限 2 回に達している"}
allow:
  write: [".claude/skills/10-task-overall-summary/**", ".claude/skills/00-workflow-issue-mr-driven/**", "logs/**", "wip/**"]
  ops: ["read", "build-test", "hook-test", "remote-read"]
started_at: "2026-09-04T14:10:31+09:00"
completed_at: "2026-09-04T14:21:19+09:00"
base_sha: "44bee00"
---

# 0039 S14 提供コマンドの残り 4 件（敵対的レビュー 2 回目の指摘）

## 目的

finalize.sh の GitLab 経路の draft 判定・merge-state の branch・porcelain のクォート、test_boundary の TZ 依存を直す

## DoD

- [x] GitLab の is_draft が draft:false を「draft でない」（戻り 1）として返す。jq の // が false を右辺に倒す形を使わない（根拠: `jq -r 'if has("draft") then (.draft | tostring) else "" end'` に替えた。実測で `{draft:false}` → `false`、`{draft:true}` → `true`、キー無し → 空。旧式 `.draft // empty` は `{draft:false}` で出力が空になることも実測した）
- [x] finalize.sh の write_state が branch を書き、boundary.sh の merge-state の突き合わせ（.branch）が実際に効く。仕様のスキーマとの差は逸脱として記録する（根拠: `write_state` の jq に `branch: (if $br == "" then (.branch // "") else $br end)` を足した。逸脱は「仕様からの逸脱」S14-1）
- [x] BD-T18 に mr.json の番号が一致するとき・しないときのケースが足され、.mr の比較分岐が実際に踏まれる（根拠: `logs/mr.json` に `mr:35` を置いた状態で、merge-state の `mr:999` は無視（終了 0）、`mr:35` は BD005（終了 1）を追加。`OK: 1 本 / 18 件` / `passed=100`）
- [x] 片付けの再実行が git status --porcelain の引用付きパスで壊れない（空白や日本語を含むファイル名で FN002 にならない）（根拠: `git status --porcelain -z` を NUL 区切りで読む形に替え、改名・複製の 2 レコード目を読み飛ばす。再現テスト `FN-T17`（`wip/00_overall_plan/全体計画 メモ.md`）を追加）
- [x] BD-T14 が実行環境のタイムゾーンに依存しない。date -d が無い環境では pass ではなく skip として数える（根拠: 依頼時刻を `set_requested_at` で `2026-09-04T21:00:00+09:00` に固定し、比較する時刻も UTC の固定値にした。**`date -d` への依存自体が消えた**ので「date が無いと飛ばす」分岐ごと削除した（skip として数える必要が無くなった）。BD-T15 も同じ形に揃えた）
- [x] run-tests.sh --filter で test_finalize と test_boundary が全通過（根拠: `test_boundary` が `OK: 1 本 / 18 件` / `passed=100 failures=0`、`test_finalize` が `OK: 1 本 / 17 件` / `passed=57 failures=0`）

## 作業内容

- DoD の各項目を順に満たす

## 作業ログ

### 現在地

- 完了（4 件を直し、BD-T18 を拡張、FN-T17 を追加）

### うまくいったこと

- 指摘 4 件のうち 3 件が「片側しか無い」形の欠陥だった。`.branch` は読む側だけ・`.mr` はテストが踏んでいない・`is_draft` は GitLab 側だけ。**対で成り立つものは対で確かめる**という同じ直し方でそろえられた
- BD-T14 / BD-T15 は時刻を固定値にしたことで、`date -d` への依存も条件分岐も消えて短くなった

### うまくいかなかったこと

- BD-T14 は「修正前のコードで落ちること」を実行環境（TZ=+09:00）でしか確かめていなかった。負のコントロールは**環境が変わっても落ちるか**まで見ないと、CI で黙って通る

### 仕様からの逸脱

- **S14-1**: `logs/merge-state.json` に `branch` を書くようにした。仕様（`10_spec/skills/10-task-overall-summary.md` の Script 処理のスキーマ）に `branch` の項目が無い。読む側（`boundary.sh` の merge-state の突き合わせ）は既に `.branch` を見ているので、書く側を合わせた形。設計反映でスキーマに足す

### 判断と根拠

- **`.branch` を消さずに書く側を足した**: 突き合わせを消すと、前の issue の `merge-state.json` が残った clone で毎回 BD005 に当たる（0037 で直した問題に戻る）。読む側の条件はそのままに、書く側を仕様に足す方が筋が良い
- **`git ls-files --deleted` ではなく `git status --porcelain -z` を保った**: 片付けの再実行では削除以外（未コミットの変更）も拾う必要がある。改名・複製の 2 レコード目を読み飛ばす形にして、引用の問題だけを消した
- **`is_draft` は `has("draft")` で見る**: `// empty` は `false` と `null` を区別できない。3 値（draft / draft でない / 判定できない）を返す関数で、この 2 つを混ぜてはいけない

### 拒否・確認・迂回の記録

- 無し

### 使った AI アセットと効き目

- 敵対的レビュアー（2 回目・中核コード担当）: `jq` を実際に走らせて `.draft // empty` が `false` を落とすことまで確かめており、そのまま直せた。BD-T18 が「書き手の無い `branch` 分岐しか踏んでいない」という指摘は、テストが緑でも意味が無い場合を突いていて効いた

### スコープ外で見つけたこと

- GitLab 経路は依然としてテストが無い（残課題 R4）。今回の `is_draft` の修正も、根拠は jq の実測であって `glab` の応答を通した検証ではない

### AI アセットに反映すべき内容

- `logs/merge-state.json` のスキーマに `branch` を足す（S14-1）
- 「負のコントロールは環境（タイムゾーン・ロケール）が変わっても落ちるか確かめる」をテストの作法に足す

### 備考
