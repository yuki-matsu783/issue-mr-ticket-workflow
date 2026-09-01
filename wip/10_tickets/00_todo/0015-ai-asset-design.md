---
type: ticket
ticket_type: ai-asset-design
predecessors: ["0014"]
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

# 0015 共通ライブラリと提供コマンドの仕様（HOOK_DENY_ID / scope.sh のポリシー / tool_class / ID 正規表現 / D5・D6）

## 目的

0014 が確定した §6 台帳と §12 T8 を受けて、20-common-step-shell-script と 20-common-step-ticket の要件・仕様を更新し、D5・D6 の方針を決める（決定 3・4・7・13・15・16 の残り）

## DoD

- [ ] 20-common-step-shell-script の仕様で HOOK_DENY_ID の既定の扱いが §6 台帳の決定と一致し、SS-T04 の期待値が更新されている（根拠: ）（根拠: ）
- [ ] scope.sh の読み込みポリシー（deny のままか nop か）が決まり、nop にする場合は機構の破損（WF209）とチケットの記載不正（WF211）を区別する方法が仕様に書かれている（根拠: ）（根拠: ）
- [ ] tool_class の責務が「ツールの種類の分類まで」と定義され、振り分けスキル名の照合を含まないことが書かれている（根拠: ）（根拠: ）
- [ ] run-tests.sh のテスト ID の抽出正規表現の制約が仕様に明記され、session-start の新しい接頭辞が一致することが確認できる（根拠: ）（根拠: ）
- [ ] G8 の提供コマンド側（next と run-tests.sh が 1 枚目しか見ない）の方針が仕様に書かれている（根拠: ）（根拠: ）
- [ ] D5（investigation 以外の実施タスクの ops 上限に宣言必須の考え方を適用するか）と D6（shellcheck を CI で回す方針）の結論が方針として書かれている（scope-limits.json と CI 設定は変えない）（根拠: ）（根拠: ）
- [ ] 受け入れ条件 2 が run-tests.sh --ids に現れる形として仕様に落ちている（根拠: ）（根拠: ）
- [ ] 決定の経緯が DDR i0009-16〜19 の範囲に残っている（根拠: ）（根拠: ）
- [ ] ヘッドレス実行の帰結（提供コマンドは確認を求めず終了コードで返す）が書かれている（根拠: ）（根拠: ）

## 作業内容

- 0014 の §6 台帳と §12 T8 の決定を先に読む
- scope-limits.json と CI 設定の実体は変えない（方針まで）

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
