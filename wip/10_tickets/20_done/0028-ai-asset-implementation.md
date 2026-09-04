---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0027"]
executor: main
human_review: {required: false, reason: "承認③により人間レビューは敵対的レビューで代替する"}
adversarial_review: {required: false, reason: "既存の提供コマンドの小さな修正で中核を含まず、機械テストが判定する"}
allow:
  write: [".claude/skills/20-common-step-report-view/**", ".claude/skills/20-common-step-commit-push/**", "logs/**", "wip/**"]
  ops: ["read", "build-test", "hook-test", "remote-read"]
started_at: "2026-09-04T11:44:29+09:00"
completed_at: "2026-09-04T11:56:13+09:00"
base_sha: "d215c8d"
---

# 0028 S5 check-html.sh の RV009 と CP-T08 の振り直し

## 目的

1 つの識別子が 2 つの原因を指している状態（RV008）と、1 つのテスト ID が 2 ファイルにある状態（CP-T08）を解消する

## DoD

- [x] check-html.sh が awk の存在を確かめ、無ければ検査を縮退させず RV009・終了 2 で止まる（RV008 の判定の後、検査に入る前）（根拠: `check-html.sh` の `main()` で `.html` 判定（RV008 の最後）の直後・`log_info "start"` の前に `command -v awk` を置き、無ければ `result_ng2 "RV009: ..."` で終了 2）
- [x] 機械テスト RV-T08 が通る: PATH から awk を外した状態で、正しい引数の正しい HTML を渡しても RV009・終了 2 になる（縮退して OK を返さない）（根拠: `test_check_html.sh` の RV-T08。awk 抜きの PATH で終了 2・最終行 `RV009`・`RV008` と `OK:` を含まないことを確かめ、同じ PATH に awk を足した正のコントロールで終了 0・`OK:` を確かめる。5 アサーション PASS）
- [x] test_push.sh 側の CP-T08 が CP-T11 に振り直され、run-tests.sh --ids で重複 ID の報告が 0 件になる（根拠: `run-tests.sh --filter '*test_push*' --ids` が `PASS ID: CP-T05 CP-T06 CP-T07 CP-T11 HK-T13` / `重複 ID: なし` を返す）
- [x] run-tests.sh --filter で check-html と push を実行し、全件通る（根拠: check-html は 58 アサーション PASS（RV-T01〜RV-T08）、push は 44 アサーション PASS）
- [x] フック共通仕様 §6 の RV の範囲（RV001–009）と check-html.sh の実装が一致している（根拠: 台帳は既に `RV001–009`。実装が使う識別子は RV001〜RV007（検査）・RV008（引数・ファイル）・RV009（環境）で過不足なし）

## 作業内容

- check-html.sh に awk の存在確認と RV009 を入れる
- test_push.sh の CP-T08 を CP-T11 に振り直す

## 作業ログ

### 現在地

- 完了

### うまくいったこと

- RV009 の追加は 1 行で済んだ。判定を `.html` 判定の直後に置いたので、RV008 の 4 経路とテストに影響が無い
- RV-T08 に正のコントロール（同じ絞った PATH に awk だけ足すと 0 で通る）を付けたので、「PATH を絞ったこと自体が原因」という偽陽性を排除できている
- CP-T08 → CP-T11 の振り直しは `run-tests.sh --ids` の重複 ID 報告で機械的に確認できた

### うまくいかなかったこと

- RV-T08 の正のコントロールで PATH を絞りすぎ、`comm` と `wc` が無いという別の理由で落ちた。`check-html.sh` と `logger.sh` が使う外部コマンドを grep で列挙して（awk cat comm cut date git grep head sed sort tr uniq wc）過不足なく渡す形に直した

### 仕様からの逸脱

- なし

### 判断と根拠

- `awk` の存在確認を `log_info "start"` より前に置いた。ログに「start」が出てから止まると、ログだけを見たときに検査が始まったように見えるため
- RV-T08 は既存の RV-T07（RV008 の各経路）と同じファイルに置いた。どちらも「検査に入る前に止まる」観点で、番号の取り違えを比べて読める

### 拒否・確認・迂回の記録

- `sed -i` での `.claude/` 配下の書き換えが WF205 で拒否された。Edit ツールに切り替えて対処し、迂回はしていない

### 使った AI アセットと効き目

- `test-lib.sh` の `make_restricted_path`: PATH を絞る定型を自分で書かずに済んだ。ラッパースクリプト方式なので Git Bash でも動く

### スコープ外で見つけたこと

- 中核 3 枚（0025・0026・0027）の敵対的レビューで 12 件の指摘が出た。0034・0035 の追加チケットに落とした

### AI アセットに反映すべき内容

- なし

### 備考

- allow.write は `20-common-step-report-view/**` / `20-common-step-commit-push/**` / `logs/**` / `wip/**`。この範囲だけを触った
