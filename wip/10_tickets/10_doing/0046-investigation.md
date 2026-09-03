---
type: ticket
ticket_type: investigation
predecessors: ["0045"]
executor: main
human_review: {required: true, reason: "結論が置き場の決定を左右する（work-defaults 基準どおり）"}
adversarial_review: {required: false, reason: "基準どおり"}
allow:
  write: ["wip/**"]
  ops: ["read", "build-test"]
started_at: "2026-09-03T11:06:50+00:00"
completed_at: ""
base_sha: "6c87efb"
---

# 0046 shlex の守備範囲と現行 cmdpos.sh との差分（0042 の起こし直し）

## 目的

shlex が cmdpos.sh の出力 10 項目のどこまでを供給でき、どの構文で追加実装が残るかを、実際に動かして切り分ける

## DoD

- [ ] 観点 A-1（出力 10 項目のうち shlex が供給する範囲）への答えが wip/30_reports/0046-investigation.md に書かれている（根拠: ）
- [ ] 観点 A-2（ヒアドキュメント本文・サブシェル展開の入れ子・fd 複製・コメント・PowerShell の前処理の 5 構文）への答えが、構文ごとの最小入力と実際の出力の対で書かれている（根拠: ）
- [ ] 観点 A-3（現行実装と shlex 版の試作で差が出る入力の有無）への答えが、差が出た入力の一覧つきで書かれている（根拠: ）
- [ ] 根拠（ファイル・行・コマンドの出力）が添えられている（根拠: ）
- [ ] 答えが出なかった問いは理由付きで残課題に残っている（根拠: ）
- [ ] レポートと対の HTML があり check-html.sh が通っている（根拠: ）

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
