---
type: ticket
ticket_type: implementation
predecessors: ["0034"]
executor: main
human_review: {required: true, reason: "ソースの変更"}
adversarial_review: {required: false, reason: "フェーズ 6 の敵対的レビューの指摘対応"}
allow:
  write: ["apl/**"]
  ops: ["read", "build-test", "remote-read"]
started_at: "2026-09-02T11:48:07+00:00"
completed_at: ""
base_sha: "f5fb890"
---

# 0035 実装: render.ts のヘッダコメントが指す節名を改名後に合わせる

## 目的

存在しない節を名指ししているヘッダコメントを直す

## DoD

- [x] apl/vscode-ticket-board/src/ と test/ に「HTML の構造と CSP」が 0 件（根拠: `grep -rn 'HTML の構造と CSP' apl/vscode-ticket-board/src/ apl/vscode-ticket-board/test/` が 0 件）
- [x] render.ts のヘッダコメントが「画面・出力の構造」を指している（根拠: `apl/vscode-ticket-board/src/core/render.ts:3` が `仕様: docs/10_spec/vscode-ticket-board.md「画面・出力の構造」`。参照先の節は実在する（同仕様書 350 行目））
- [x] npm test が 47 件 pass する（根拠: `apl/vscode-ticket-board/` で `npm test` が `# pass 47 / # fail 0`）

## 作業内容

- render.ts の 1 行を直す

## 作業ログ

### 現在地

- 完了。`render.ts` のヘッダコメントが指す節名を改名後に合わせた。これでフェーズ 6 の敵対的レビューの指摘 7 件すべての対応が終わった

### うまくいったこと

- 直したあとにリポジトリ全体を旧節名で検索し、残った 6 件がすべて DDR の中（`i0013-02` の本文と `i0020-04` の説明）であることを確かめた。どちらも旧名を書くのが正しい箇所で、直すべき参照は 0 件

### うまくいかなかったこと

- 特になし（0028 での見落としの原因と対処は 0034 の作業ログに書いた）

### 仕様からの逸脱

- 実行者: 全体計画のとおりメインエージェント（`10-task-implementation-exec` スキル本体が未整備のため、`.claude/docs/10_spec/skills/` の対応する仕様書に従って主体で実施。issue #10 の範囲）

### 判断と根拠

- **DDR の中の旧節名は残す**: `i0013-02` の本文は当時「`HTML の構造と CSP` と名付ける」と決めた記録で、マージ済み DDR の本文は変えない。`i0020-04` は改名そのものを説明する DDR なので、旧名を書かないと何を何に変えたかが読めない。どちらも「古い参照」ではない
- **ヘッダコメントの参照の基準は変えない**: `docs/10_spec/…` はアプリルート相対で、README がその基準を宣言している（0024・0029）。今回変えたのは節名だけ

### 拒否・確認・迂回の記録

- なし（`allow.write` の `apl/**` の範囲内）

### 使った AI アセットと効き目

- 0034 で書き直した `i0020-04` の「影響」: `render.ts` を直すのが別チケットであることと、その理由（許可範囲）が書かれていたので、何をどこまでやるかが決まっていた

### スコープ外で見つけたこと

- 特になし

### AI アセットに反映すべき内容

- 特になし（0034 で挙げた「改名の波及はリポジトリ全体を旧名で検索して数える」が今回の教訓のすべて）

### 備考

- フェーズ 6 の指摘 7 件の内訳: 正史の定義 2 件（0032）、ルール本体とテスト 2 件（0033）、仕様書と DDR 3 件（0034）、ソース 1 件（このチケット）。重なりを含む
- 次はフェーズ 7（0027 全体まとめ）
