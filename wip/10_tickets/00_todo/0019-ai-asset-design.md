---
type: ticket
ticket_type: ai-asset-design
predecessors: ["0015"]
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

# 0019 レビュー指摘: 並列実行の前提と登録の書き方（R1・R2・R10・R11・R12・R19・R22）

## 目的

公式が「All matching hooks run in parallel」（hooks.md:414）と明記しているため、実行順を前提にした §1・各フック仕様の記述と、相対パス登録・git rev-parse 依存・並行書き込みの規則を直す

## DoD

- [ ] §1 の「順」列の定義が「settings.json の配列上の位置（実行順ではない）」に直り、§1 の「先に拒否したフックが理由を返す」「安価→高価の順序」と各フック仕様の「〜の後、〜の前」（block-chmod・block-direct-git・workflow-state-guard・workflow-guard・post-push-usage-report）が並列実行と矛盾しない記述になっている（R1・R19）（根拠: ）
- [ ] HK-T01 が照合する対象から「順序」の意味づけが直り、配列上の位置の一致として書かれている（R1）（根拠: ）
- [ ] 登録コマンドが cwd に依存しない形（${CLAUDE_PROJECT_DIR} 基準）に直り、§1 の雛形と HK-T01 の照合パターンが一致している。cwd がルート以外のとき拒否側 5 本のラッパーが全操作を deny するロックアウトの経路が塞がれている（R10）（根拠: ）
- [ ] §1 の登録表に実体のパス列（または command 文字列そのもの）が加わり、--accumulate 引数と「実体のディレクトリ ≠ 登録イベント」の 4 行が表現されている。§1 の「実体」の説明に <NN-Event> が主たるイベントであることが書かれている（R12）（根拠: ）
- [ ] §2 の「git rev-parse --show-toplevel を基準にする」が読み込み行の解決結果（LOGGER_ROOT / HOOK_ROOT）を使う形に直り、ホットパスの目安が測れる形（起動してよい外部プロセスの上限）になっている（R11）（根拠: ）
- [ ] §5 に並行書き込みの規則（JSONL 追記の 1 行サイズ上限、JSON ファイルの一時ファイル + mv、usage/*.json の直列化）が書かれ、対応するテスト観点がある（R22）（根拠: ）
- [ ] post-push-compact-prompt が push-state.json を更新することで post-push-usage-report の検知が偽になる問題の解決方針が仕様に書かれている（検知と状態更新の分離、または usage 側の進捗判定の分離）。HK-T13 と UR-T07 の観点が合わせて直っている（R2）（根拠: ）
- [ ] 決定の経緯が DDR i0009-20〜25 の範囲に残っている（根拠: ）

## 作業内容

- 指摘の原文は wip/30_reports/0016-adversarial-review.md（レビュー記録）を参照する
- 公式の確認は wip/tmp/hooks.md を grep -n で読む（WebFetch を使わない）

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
