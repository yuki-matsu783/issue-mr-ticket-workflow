---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0029"]
executor: main
human_review: {required: true, reason: "振る舞いが変わる（承認④により opus の敵対的自己レビューで代替）"}
adversarial_review: {required: true, reason: "案内側フックの判定と記録の変更"}
allow:
  write: [".claude/hooks/**", "wip/10_tickets/**", "wip/30_reports/**", "wip/tmp/**"]
  ops: ["read", "remote-read", "hook-test", "build-test"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0038 0029 の敵対的レビュー指摘 6 件の反映

## 目的

0029（案内側フック 6 本）の敵対的セルフレビューで確度 0.5 以上と判断した 6 件を直す。実測プローブ wip/tmp/adv0029.sh で再現を確認済み

## DoD

- [ ] workflow-diff-check がリポジトリルート相対でないパス（絶対パス・リポジトリ外・.. を含む）を承認単位として approvals.json に記録しない。実測（/tmp/outside/evil.md への Write で C:/Users/.../Temp/outside が記録された）を再現するテストを DC-T03 に足した（根拠: ）
- [ ] workflow-diff-check が base_sha を解決できないとき、WF601 の本文に解決できない値をそのまま「基準点は X」と書かない。復旧指示の git checkout <base> が使えない旨を書くか、仕様の制御方式 7 に倣って黙って抜けるかを決め、根拠を作業ログに書いた。テストを DC-T06 に足した（根拠: ）
- [ ] 作業中チケットが 2 枚以上のときの扱いを workflow-diff-check（判定不能として黙って抜ける）と subagent-stop-check（先頭 1 枚で範囲判定する）で揃えた。どちらに揃えたかと理由を作業ログに書き、テストを DC-T06 / SP-T04 に足した（根拠: ）
- [ ] post-push-usage-report が posted:false の間は since_sha を進めない（初回 push で HEAD に進めると、集計値には push 前の分が入っているのに集計期間の起点だけが後ろへずれる）。テストを UR-T04 に足した（根拠: ）
- [ ] WF601 のパス列挙の上限（現在 30）と WF812 / WF813 の上限（20）の不整合を解消した。どちらに揃えたかを作業ログに書き、上限を超えたときの件数表示をテストで固定した（根拠: ）
- [ ] subagent-stop-check の縮退判定が decisions.jsonl の末尾 400 行に依存している点を直した（決め打ちの行数を超えると誤って縮退と判定し WF801 を二重に出す）。セッション状態など行数に依存しない引き方に変え、テストを SP-T08 に足した（根拠: ）
- [ ] 6 本の filter 実行と全件テストが 2 ロケールで FAIL 0。作業ログと結果報告（md + HTML）を書いた（根拠: ）

## 作業内容

- 指摘の出どころは wip/30_reports/0029-ai-asset-implementation.md のレビュー観点 r1〜r7 と、敵対的セルフレビューの実測プローブ
- 案内側なので fail-closed ラッパーは付けない。失敗は通す
- .claude/docs/** には書かない。仕様側を直すべきものは 0032 へ送る

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
