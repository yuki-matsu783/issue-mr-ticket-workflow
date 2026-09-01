---
type: ticket
ticket_type: ai-asset-design
predecessors: ["0006"]
executor: main
human_review: {required: true, reason: "中核（フック）の仕様の変更。承認④により opus 自己レビューで代替"}
adversarial_review: {required: true, reason: "仕様は正史。設計実施の切れ目で 1 回（全体計画の方針）"}
allow:
  write: [".claude/docs/10_spec/**", ".claude/docs/20_ddr/**", "wip/**"]
  ops: ["read"]
started_at: "2026-09-01T02:37:38Z"
completed_at: ""
base_sha: "2d14abb"
---

# 0008 AI アセット設計実施 — フック共通仕様と post-push-compact-prompt 仕様の修正

## 目的

設計計画 0006 の採否表のうち、`10_spec/フック共通仕様.md`（§3・§6・§7・§8・§9・§12）と `10_spec/hooks/22-PostToolUse/post-push-compact-prompt.md` に反映する項目（D2・D3・D4・D5・D6・D8・D9 参照・D11・D14・D19 台帳・D20 §8・Q6 台帳）を現在の正史として書き換える。

## DoD

- [ ] フック共通仕様が D2（§8 glob 規則）・D4（§7-8 パス一致）・D11（§3 一次防御）・D14（§8 初期値 `.gitattributes`）・D20（§8 `investigation.ops` に `build-test`）のとおりに更新されている（根拠: ）
- [ ] §9 に `adversarial_review: {required, reason}` が追加され、WF208 の監視対象に含めるか否かが明記されている（根拠: ）
- [ ] §12 で T5 が確認済み（出典付き）、T3 が出典で補強され、D5（deny の JSON 経路）が TBD として追加されている（根拠: ）
- [ ] §6 採番台帳に `TR`（run-tests.sh）と frontmatter ライブラリのテスト ID 接頭辞、5 本の eval ID 接頭辞が追加され、既存と衝突していない（根拠: ）
- [ ] §7 の共有ライブラリ一覧に `frontmatter.sh`（shell-script スキル配下・`source` 専用）への参照が追加されている（根拠: ）
- [ ] post-push-compact-prompt 仕様の push 検知 2 に D3 の縮退経路が書かれ、テスト観点に対応する行がある（根拠: ）
- [ ] 各仕様書の「要件との対応」表と用語・インターフェースの整合が崩れておらず、プレースホルダが 0 件（根拠: ）
- [ ] 決定の経緯（採らなかった案）が 0010 の DDR に渡る形で作業ログ「判断と根拠」に残っている（根拠: ）
- [ ] ヘッドレス実行の帰結が計画書の表と矛盾しない（根拠: ）

## 作業内容

- 計画書 0006 の採否表・骨子に従い、該当節を Edit で書き換える（履歴は書かない）
- 変更箇所を作業ログに列挙する（0010 の DDR の材料）

## 作業ログ

### 現在地

- 済: 着手
- 次: 共通仕様 §3・§6・§7・§8・§9・§12 と post-push-compact-prompt の修正 → 完了

### うまくいったこと

### うまくいかなかったこと

### 仕様からの逸脱

### 判断と根拠

### 拒否・確認・迂回の記録

### 使った AI アセットと効き目

### スコープ外で見つけたこと

### AI アセットに反映すべき内容

### 備考
