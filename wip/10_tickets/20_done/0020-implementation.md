---
type: ticket
ticket_type: implementation
predecessors: ["0018"]
executor: main
human_review: {required: false, reason: "全体計画の方針の差分 4 により、人間レビューはワークごとの敵対的レビューに置き換える"}
adversarial_review: {required: false, reason: "未使用の引数 1 つの削除で、機械テストが全通過なら足りる（基準の調整条件に該当）"}
allow:
  write: ["src/**", "wip/**"]
  ops: ["read", "build-test"]
started_at: "2026-09-02T07:14:43+00:00"
completed_at: "2026-09-02T07:15:02+00:00"
base_sha: "4278ced"
---

# 0020 使われていない RenderOptions.cspSource を型から削る

## 目的

設計反映で「型から削る」と決めた F07 を実装に反映し、仕様書と実装を一致させる

## DoD

- [x] core/render.ts の RenderOptions から cspSource が消え、board-panel.ts が渡していない（根拠: grep -rn 'cspSource' src test → 0 件）
- [x] test/render.test.ts の OPTIONS から cspSource が消えている（根拠: 同上。OPTIONS は { nonce: "TEST-NONCE-123" } のみ）
- [x] npm test が全通過する（根拠: npm test → # tests 46 / # pass 46 / # fail 0）

## 作業内容

- 仕様書「データの形」「表示と更新 4」の記述どおりに src/ を直す

## 作業ログ

### 現在地

- 完了

### うまくいったこと

- 設計反映（0018）で仕様書を先に直してあったため、実装は仕様書の記述どおりに 3 ファイルを削るだけで済んだ。テストは 46 件のまま全通過

### うまくいかなかったこと

- 無し

### 仕様からの逸脱

- 無し

### 判断と根拠

- `board-panel.ts` の `webview.cspSource` の取得ごと削った。CSP は nonce だけで閉じており、渡す先が無くなったため

### 拒否・確認・迂回の記録

- 無し

### 使った AI アセットと効き目

- `20-common-step-commit-push`（commit.sh）: 3 ファイルだけを明示してコミットできた

### スコープ外で見つけたこと

- 無し

### AI アセットに反映すべき内容

- 現時点で新規は 0 件。理由: 未使用の引数 1 つを削るだけの作業で、使ったアセットはいずれも仕様どおり動いた

### 備考

- 無し
