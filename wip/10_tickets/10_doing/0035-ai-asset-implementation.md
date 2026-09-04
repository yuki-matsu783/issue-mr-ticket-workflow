---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0037"]
executor: main
human_review: {required: false, reason: "承認③により人間レビューは敵対的レビューで代替する"}
adversarial_review: {required: true, reason: "実装フェーズ 2 回目の敵対的レビューを、0028〜0035 の差分に対してここでまとめて行う"}
allow:
  write: [".claude/skills/10-task-overall-summary/**", ".claude/skills/20-common-step-ticket/**", "logs/**", "wip/**"]
  ops: ["read", "build-test", "hook-test", "remote-read"]
started_at: "2026-09-04T13:07:26+09:00"
completed_at: ""
base_sha: "11f735d"
---

# 0035 S11 敵対的レビュー指摘の反映（finalize.sh 7 件）

## 目的

中核 3 枚の敵対的レビューで出た finalize.sh の指摘 7 件を直し、中断・再実行で詰まらないようにする

## DoD

- [ ] 段階 5（片付け）が削除の前に対象一覧を記録し、commit.sh が失敗した後の再実行でも未コミットの削除を取りこぼさない（根拠: ）（根拠: ）
- [ ] 段階 3（記録）で commit.sh 成功・push.sh 失敗の後に再実行しても recorded に到達できる（差分が無ければコミットを省く、または中間状態を持つ）（根拠: ）（根拠: ）
- [ ] --linked が F_STATE を検査せずに linked を書かない。recorded 以外で渡されたら FN001 か引数の誤りで拒否する（根拠: ）（根拠: ）
- [ ] is_draft の判定不能（CLI 不在・ホスト不明・API 失敗）が ready ではなく拒否側に倒れる（根拠: ）（根拠: ）
- [ ] 統括レポートの探索が「番号一致が無ければ種類名で探す」フォールバックに実際に到達する（1 要素目を -f で確かめる）（根拠: ）（根拠: ）
- [ ] merge-state.json の state が未知の値のときは終了 2 で止めず、再導出に回す（根拠: ）（根拠: ）
- [ ] DoD 節にチェックボックス行が 0 件でも、パイプの途中の失敗で結果行を出さずに終わらない（根拠: ）（根拠: ）
- [ ] test_finalize.sh に上記 7 件の再現テストを足し、run-tests.sh --filter で全件通る（根拠: ）（根拠: ）

## 作業内容

- 段階ごとの再入を「その段階の成果が既にあるか」で判定する形に統一する
- 判定不能と false を区別し、判定不能は拒否側に倒す

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
