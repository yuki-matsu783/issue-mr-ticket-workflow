---
type: ticket
ticket_type: ai-asset-design
predecessors: ["0022"]
executor: sub-opus
human_review: {required: true, reason: "正史（要件・仕様）の変更（承認④により opus の敵対的自己レビューで代替）"}
adversarial_review: {required: true, reason: "基準どおり（中核の定義に触る）"}
allow:
  write: [".claude/docs/**"]
  ops: ["read", "remote-read"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0023 レビュー指摘: ホットパスの外部プロセス上限と読み取り経路の再設計（A1・A2・B11・B12）

## 目的

jq 1 回の上限が設定破損時のロックアウトを招き、session_id 依存の JSON も読めないことが実測で分かった。読み取り経路を実装できる形に決め直す

## DoD

- [ ] jq --slurpfile が副入力の破損・不在で呼び出しごと失敗し stdout が空になる事実（実測）が i0009-37 に書かれ、WF210 の復旧経路と i0009-29 のフォールバックが実装できる形に決め直されている（A1）（根拠: ）
- [ ] i0009-37 の背景から「残るのは上限設定だけ」が消え、session_id 依存の JSON（approvals.json / entry.json）と固定パスの JSON（review-state.json / merge-state.json）の読み方が決まっている。0019 f2 の ✕問題の状態が実態に合わせて更新されている（A2）（根拠: ）
- [ ] §8 の scope_load / scope_load_approvals の入力の形が §1 の hook_read_input と噛み合い、実装者がどちらが読むかを推測せずに済む（B11）（根拠: ）
- [ ] parse_errors の置き場が 1 つに決まり、§5 のロック失敗時の記述がそれと整合している。§1 の hc_append_jsonl / hc_json_write / hc_lock に引数・戻り値・タイムアウト・切り詰めの責任範囲が書かれている（B12）（根拠: ）
- [ ] 決定の経緯が DDR i0009-46〜49 の範囲に残っている（根拠: ）

## 作業内容

- 指摘の原文は wip/30_reports/0022-ai-asset-design-appendix-A.md を参照する
- A1 は実測済み（jq --slurpfile に壊れた JSON / 不在ファイルを渡すと終了 2 で stdout が空）。上限を改訂するなら i0009-22 の趣旨（fork をこれ以上増やさない圧力）を壊さない形にする

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
