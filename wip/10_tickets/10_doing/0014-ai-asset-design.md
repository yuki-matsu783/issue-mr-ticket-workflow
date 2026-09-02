---
type: ticket
ticket_type: ai-asset-design
predecessors: ["0012"]
executor: main
human_review: {required: true, reason: "正史（要件・仕様）の変更"}
adversarial_review: {required: false, reason: "フェーズ 3 の敵対的レビューの指摘対応であり、対応そのものは再レビューしない"}
allow:
  write: [".claude/docs/**"]
  ops: ["read", "remote-read"]
started_at: "2026-09-02T10:47:58+00:00"
completed_at: ""
base_sha: "09288af"
---

# 0014 設計: 敵対的レビュー（フェーズ3）の指摘のうち正史に当たる 5 件を直す

## 目的

許可範囲の穴・要件書と仕様書の不整合・移行の記述の誤りを正史の側で直し、実装が従える状態にする

## DoD

- [ ] フック共通仕様 §8 の implementation の allow が apl/*/* の丸ごと許可でなくなり、CLAUDE.md・.gitattributes・入れ子の .claude が実装タスクから無確認で書けない形になっている（根拠: ）
- [ ] フック共通仕様 §8 の移行の記述が実際の構成（src/vscode-ticket-board/ をディレクトリごと apl/vscode-ticket-board/ へ）と一致している（根拠: ）
- [ ] 10_spec/skills/20-common-step-spec.md の処理フローで設計文書ルートの決定が手順 1 になり、要件との対応表の実現箇所の番号がそれに追随している（根拠: ）
- [ ] 10_spec/skills/20-common-step-spec.md のアプリの「なし」の規定が 10 節すべてに一般化され、要件（00_requirement/skills/20-common-step-spec.md）と一致している（根拠: ）
- [ ] 00_requirement/rules/design-docs.md の規約: requirement と spec が ai-asset-design-docs と同じ細目（図の 1 行 1 辺・ラベル・外部依存なし / 定型章の項目数と行数の目安）を持つ（根拠: ）
- [ ] 指摘 5 件それぞれについて、直した箇所と直さなかった理由を作業ログに書いた（根拠: ）

## 作業内容

- 指摘ごとに正史の該当箇所を特定し、要件と仕様の順序（要件が先）を守って直す

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
