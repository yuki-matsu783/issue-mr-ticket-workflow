---
type: ticket
ticket_type: ai-asset-design
predecessors: []
executor: main
human_review: {required: true, reason: "全体計画の方針: 正史（要件・仕様）の変更（承認④により opus の敵対的自己レビューで代替）"}
adversarial_review: {required: true, reason: "基準どおり（正史の変更）"}
allow:
  write: [".claude/docs/**"]
  ops: ["read", "remote-read"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0013 案内側フック 5 本の判定の決定（WF801 の経路 / post-push の成功判定 / session-start のテスト）

## 目的

subagent-start-check・subagent-stop-check・post-push-compact-prompt・post-push-usage-report・session-start の 5 本について、公式リファレンスで結論の出た事実を仕様に落とす（決定 5・6・7・8）

## DoD

- [ ] subagent-start-check の要件と仕様が「SubagentStart の入力に model は来ない」前提で書き直され、WF801 の本線（PreToolUse Agent か事後通知か）と、model 省略時は比較できない限界が明記されている（根拠: ）（根拠: ）
- [ ] subagent-stop-check の仕様で WF801 の位置づけ（事後の保険か本線か）が本線の決定と矛盾なく書かれている（根拠: ）（根拠: ）
- [ ] post-push-compact-prompt と post-push-usage-report の仕様から tool_response の終了コード読み（4 候補）が削除され、成功判定が「PostToolUse に来た = 成功」になっている（根拠: ）（根拠: ）
- [ ] session-start のテスト ID の接頭辞が run-tests.sh の抽出正規表現に一致する形に決まり、仕様のテスト観点に反映されている（根拠: ）（根拠: ）
- [ ] boundary.sh に依存して本 issue で通せないテスト（8 本 + SS-H05 の前半、SS-H09 の無意味な通過を含む）の扱いが決まり、受け入れ条件 1 の解釈とあわせて仕様に書かれている（根拠: ）（根拠: ）
- [ ] 受け入れ条件 1 と 5 が仕様のテスト観点（テスト ID）に落ちている（根拠: ）（根拠: ）
- [ ] 横断文書との整合を確認し、更新が要る箇所は 0014 へ送るか自分で直したかを明記した（根拠: ）（根拠: ）
- [ ] 決定の経緯が DDR i0009-05〜09 の範囲に残っている（根拠: ）（根拠: ）
- [ ] 各フックのヘッドレス実行の帰結（案内側は判定できなければ無出力・終了 0）が仕様に書かれている（根拠: ）（根拠: ）

## 作業内容

- 0008 計画書の文書一覧と骨子に従って 5 本の要件・仕様を更新する
- WF801 の案 (c) を採る場合は §1 の登録表が 17 行になるので、0014 への申し送りとして作業ログと結果報告に明記する（§1 自体は触らない）
- DDR は i0009-05〜09 の範囲だけを使う

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
