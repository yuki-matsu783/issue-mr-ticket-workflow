---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0032"]
executor: main
human_review: {required: false, reason: "承認③により人間レビューは敵対的レビューで代替する"}
adversarial_review: {required: false, reason: "実装フェーズの敵対的レビューは上限 2 回に達している（0036 の指摘への対応そのもの）"}
allow:
  write: [".claude/hooks/20-PreToolUse/**", "logs/**", "wip/**"]
  ops: ["read", "build-test", "hook-test", "remote-read"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0038 S13 中核: 削除の許可判定を締める（敵対的レビュー 2 回目の指摘 3 件）

## 目的

0036 で開けた削除の経路が、ディレクトリごとの削除・展開前の文字列・宣言外の共通許可範囲で許可範囲の外に届く穴を塞ぐ

## DoD

- [ ] 対象の配下に共通の保護範囲・毎回確認・種類の禁止範囲が入り得るときは削除を WF205 で拒否する（rm -rf .claude/hooks/config が通らない）（根拠: ）（根拠: ）
- [ ] 展開前の文字列（* ? [ { $ バッククォート ~ , を含む語）は対象を読み取れないものとして WF205 で拒否する（rm -rf .claude/hooks/* が通らない）（根拠: ）（根拠: ）
- [ ] 削除が通るのは wip/tmp/** と logs/** か、チケットの allow.write に明示された範囲だけ。common.allow だけで通る範囲（wip/10_tickets/** など）は宣言が無ければ消せない（根拠: ）（根拠: ）
- [ ] 進行状態ファイル（logs/review-state.json など）はコマンドで消せない（根拠: ）（根拠: ）
- [ ] 0036 で通した削除（rm .claude/hooks/20-PreToolUse/x.sh・git rm -r --cached .claude/hooks/old/）は今までどおり通る（退行なし）（根拠: ）（根拠: ）
- [ ] WG-T18 に上記の再現テストが足され、run-tests.sh --filter '*workflow_guard*' が全通過（根拠: ）（根拠: ）

## 作業内容

- DoD の各項目を順に満たす

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
