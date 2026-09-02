---
type: ticket
ticket_type: feedback-plan
predecessors: ["0024"]
executor: main
human_review: {required: true, reason: "後続フェーズの要否は人間の判断"}
adversarial_review: {required: false, reason: "基準どおり"}
allow:
  write: ["wip/**"]
  ops: ["read", "remote-read", "remote-write:issue-create"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0025 フィードバック計画: 後続フェーズの要否と別 issue の候補を決める

## 目的

各チケットで見つかった機構の課題を集約し、フェーズ 6 で扱うものと別 issue に回すものを分ける（0018 の再起票）

## DoD

- [ ] 完了チケットの「AI アセットに反映すべき内容」「スコープ外で見つけたこと」が漏れなく集約されている（根拠: ）
- [ ] フェーズ 6（設計反映）で扱う対象が、作業項目の粒度で一覧化されている（根拠: ）
- [ ] 本 issue で扱わない項目が、別 issue 起票か見送りかの判断と理由つきで一覧化されている（根拠: ）
- [ ] フィードバック計画書と HTML ビューが wip/20_plans/ にある（根拠: ）
- [ ] 設計反映計画チケットと後続チケットが起票されている（根拠: ）

## 作業内容

- 完了したチケットの作業ログを読み、フェーズ 6 の対象と別 issue の候補に振り分ける

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
