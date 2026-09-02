---
type: ticket
ticket_type: implementation
predecessors: ["0028"]
executor: main
human_review: {required: true, reason: "利用者が読む文書の変更"}
adversarial_review: {required: false, reason: "フェーズ 6 の敵対的レビューでまとめて見る"}
allow:
  write: ["apl/**"]
  ops: ["read", "build-test", "remote-read"]
started_at: "2026-09-02T11:31:21+00:00"
completed_at: ""
base_sha: "c7b725d"
---

# 0029 実装: README の暫定の 1 行を落とす

## 目的

設計文書の移動が済んだので、宙ぶらりんを説明していた断り書きを現状に合わせる

## DoD

- [x] README の参照がアプリルート相対であることは残り、「まだリポジトリ直下の docs/ にある」の記述が消えている（根拠: `apl/vscode-ticket-board/README.md:8` が「この README とソースのヘッダコメントに書かれた `docs/...` は、**このアプリルート（`apl/vscode-ticket-board/`）からの相対**を指す。」の 1 文だけになった。「設計文書はまだリポジトリ直下の `docs/` にあり…」の 2 文が消えている。参照先（5・6 行目）は実在する（`apl/vscode-ticket-board/docs/00_requirement/vscode-ticket-board.md` と `10_spec/`））
- [x] npm test が 47 件 pass する（根拠: `apl/vscode-ticket-board/` で `npm test` が `# pass 47 / # fail 0`）

## 作業内容

- README の 1 行を書き換える

## 作業ログ

### 現在地

- 完了。README の暫定の 2 文を削り、基準の宣言だけを残した

### うまくいったこと

- 0024 で「参照を書き換える」ではなく「基準を宣言する」形にしておいたので、移動が済んだ後は暫定の説明を削るだけで済んだ。参照そのものは 1 度も動かしていない

### うまくいかなかったこと

- 特になし

### 仕様からの逸脱

- 実行者: 全体計画のとおりメインエージェント（`10-task-implementation-exec` スキル本体が未整備のため、`.claude/docs/10_spec/skills/` の対応する仕様書に従って主体で実施。issue #10 の範囲）

### 判断と根拠

- **基準の宣言（1 文目）は残した**: 移動が済んでも「`docs/...` がどこからの相対か」は自明ではない。リポジトリルート相対と読む人がいる限り、宣言する価値がある。削ったのは「まだ移動していない」という時限の説明の 2 文だけ

### 拒否・確認・迂回の記録

- なし（`allow.write` の `apl/**` の範囲内）

### 使った AI アセットと効き目

- `wip/20_plans/0026-design-feedback-plan.md` の F6: 何を削って何を残すかが決まっていた

### スコープ外で見つけたこと

- 特になし

### AI アセットに反映すべき内容

- 段階的な移行で置く「暫定の説明」は、消す担当を計画に書いておかないと残る。今回は F6 として計画に持たせたので消せた。移行を計画するときの型として残したい（0024 で挙げた B4 と同じ話）

### 備考

- 次は 0030（フック共通仕様 §8 から旧置き場を落とす）→ 0031（設定とテスト）
