---
type: ticket
ticket_type: ai-asset-implementation-plan
predecessors: ["0008"]
executor: main
human_review: {required: true, reason: "許可範囲とロックアウト対策を実装前に見る（中核 scope-limits.json を含む）"}
adversarial_review: {required: false, reason: "基準どおり"}
allow:
  write: ["wip/**"]
  ops: ["read", "remote-read"]
started_at: "2026-09-02T10:19:55+00:00"
completed_at: "2026-09-02T10:22:31+00:00"
base_sha: "7fd5cac"
---

# 0009 AI アセット実装計画: ルール本体・スキル本体・scope-limits.json

## 目的

レビュー済みの設計から、ルール本体・共通ステップスキル本体・テンプレート・scope-limits.json・eval 定義の変更範囲とテスト、ロックアウト対策を決める

## DoD

- [x] 実装計画書と HTML ビューが wip/20_plans/ にある（根拠: wip/20_plans/0009-ai-asset-implementation-plan.md と .html。check-html.sh が 7 項目通過）
- [x] 変更するアセットとテスト（run-tests.sh の対象 ID）が一覧化されている（根拠: 計画書「変更するアセット」表 A1〜A8 と「検証」表（HK-T11 / HK-T15 / HK-T02 / 全テスト ID））
- [x] scope-limits.json の変更でロックアウトが起きないことの確認手順がある（根拠: 計画書「ロックアウト対策」表 5 件。それぞれに手当と test_scope.sh のアサーションを対応づけた）
- [x] 実装チケットと次の計画チケット（implementation-plan）が起票されている（根拠: 0011 / 0012（ai-asset-implementation）と 0013（implementation-plan））

## 作業内容

- DoD の各項目を順に満たす

## 作業ログ

### 現在地

- 完了。実装計画書と HTML ビューを作り、実装チケット 2 枚と次の計画チケットを起票した

### うまくいったこと

- ロックアウト対策の 5 件をそれぞれ `test_scope.sh` のアサーションに落とせる形で書いた。対策が「気をつける」で終わらず機械で固定される
- `run-tests.sh` が計画チケットの `allow.ops` を見て TR006 で止めたので、テスト実行を実装チケットに宣言する必要があることが実地で確認できた

### うまくいかなかったこと

- 変更前のテスト結果（ベースライン）を取ろうとしたが、計画チケットでは `run-tests.sh` を実行できず取れなかった。回帰の比較は 0012 の中で「変更前に一度実行してから直す」形にする

### 仕様からの逸脱

- 計画書のテンプレート `assets/ai-asset-implementation-plan.template.md` が存在しないため、仕様書の「OUT ひな形」の節から起こした（他の計画チケットと同じ）

### 判断と根拠

- 0011（ルール本体）と 0012（スキル本体・設定）を分けた。宣言的な規約と、手順・機械が読む値ではレビューの観点が違う。0012 だけが中核（`scope-limits.json`）を含み `hook-test` の宣言が要る
- `scope-limits.json` を最後に変え、`test_scope.sh` を先に落としてから直す順序にした。テストが変更を検出することを確かめてから本体を直す（TDD の形）
- eval 定義（A8）は 0011 に含めた。ルール本体の `paths` と 1:1 で対応するため

### 拒否・確認・迂回の記録

- `run-tests.sh` が TR006（計画チケットの `allow.ops` に `build-test` `hook-test` が無い）で止まった。迂回せず、実装チケット 0012 の宣言に含めた

### 使った AI アセットと効き目

- `run-tests.sh`: 作業中チケットの宣言を見て実行を止める仕組みが正しく効いた。計画と実施の境界がテスト実行にも効いている
- `10-task-ai-asset-implementation-plan` の仕様書: OUT ひな形にロックアウト対策の節があり、中核変更の計画で何を書くべきかが決まっていた

### スコープ外で見つけたこと

- 計画タスク用の md テンプレートがどのスキルにも無い（3 回目）。issue #10 の範囲

### AI アセットに反映すべき内容

- 本チケット時点で追加のアセット修正は 0 件。計画の内容は 0011 / 0012 で反映する

### 備考
