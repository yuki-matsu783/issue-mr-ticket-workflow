---
type: ticket
ticket_type: ai-asset-design
predecessors: ["0012", "0013"]
executor: main
human_review: {required: true, reason: "全体計画の方針: 正史（要件・仕様）の変更（承認④により opus の敵対的自己レビューで代替）"}
adversarial_review: {required: true, reason: "基準どおり（中核の定義に触る）"}
allow:
  write: [".claude/docs/**"]
  ops: ["read", "remote-read"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0014 フック共通仕様の横断決定（§1・§2・§3・§6・§8・§12 と登録表の行数の確定）

## 目的

0012・0013 の決定を受けて、フック共通仕様の横断部分を確定する（決定 9〜15）。登録表の行数がここで決まり、フェーズ 4b の段階登録の割り当ての入力になる

## DoD

- [ ] §1 の登録表の行数が確定し（WF801 の案と PostToolUseFailure の要否を反映）、assets/ の基準ディレクトリと各フックの timeout の既定が定義されている（根拠: ）
- [ ] 確定した assets/ の基準ディレクトリを、暫定で書かれている workflow-entry（entry-skills.txt）と subagent-start-check（model-aliases.txt）の仕様に反映した（block-chmod の blocked-commands.txt は仕様で config/ に確定済みなので対象外）（根拠: ）
- [ ] §2 に「model を受け取れるのは SessionStart のみ」が反映され、SubagentStart の model への依存が消えている（根拠: ）
- [ ] §3 に「command 型フックは timeout で打ち切られると fail-open（出力も破棄）」と、PreToolUse で additionalContext を返せることが書かれている（根拠: ）
- [ ] §6 の台帳で HOOK_DENY_ID の既定 WF009 の扱いが決まり、WF801〜809 の持ち主欄が本線の決定と一致している（根拠: ）
- [ ] §8 に web の強制の可否（D3）の結論が書かれている（根拠: ）
- [ ] §12 の T3・T4・T7・T8 のうち設計で閉じられるもの（T3 の defer の採否・T4 の model・T7・T8）が結論付きで閉じられ、実測が要る部分（T3 の「claude -p を入力から判別できるか」）はフェーズ 4c に残す旨が書かれている（根拠: ）
- [ ] 受け入れ条件 3 のうち設計で閉じられる分（T3 の defer・T4 の model）が §12 に結論として書かれている（根拠: ）
- [ ] 受け入れ条件 2（登録後に run-tests.sh --ids の全件と HK-T01 が通る）が §1 の登録表と HK-T01 の照合として書かれ、条件 4（HOOK_DENY_ID の既定が §6 に決まる）と条件 5（web の強制 / defer の扱いが仕様に書かれる）の担当分が §6・§8・§12 に落ちている（根拠: ）
- [ ] 横断文書（自己改善ワークフロー機構.md・ルール体系.md・90_glossary/）の更新要否を確認し、不要なものは「対象なし」と明記した（根拠: ）
- [ ] 決定の経緯が DDR i0009-10〜15 の範囲に残っている（根拠: ）
- [ ] ヘッドレス実行の帰結（打ち切りは fail-open でヘッドレスかどうかに関係なく通る）が §3 に書かれている（根拠: ）

## 作業内容

- 0012・0013 の結果報告と作業ログの申し送りを先に読む
- 登録表の行数が 16 から変わる場合、その旨を結果報告に明記して 0016（実装計画）の入力にする
- 20-common-step-shell-script の仕様には触らない（0015 の担当）。触る必要が出たら申し送りとして書く

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
