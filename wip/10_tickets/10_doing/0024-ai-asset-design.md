---
type: ticket
ticket_type: ai-asset-design
predecessors: []
executor: main
human_review: {required: false, reason: "テスト ID 2 件の追加のみ（差分 1 文書・数行）。実装の切れ目で一緒に見る"}
adversarial_review: {required: false, reason: "差分が 1 文書・50 行未満"}
allow:
  write: [".claude/docs/10_spec/**", "wip/**"]
  ops: ["read"]
started_at: "2026-09-01T13:53:09+09:00"
completed_at: ""
base_sha: "040e228"
---

# 0024 AI アセット設計実施（追加）— hooks/lib の push-detect / transcript にテスト ID を追加

## 目的

実装計画（0011・0023）で見つかった「`push-detect.sh` / `transcript.sh` に lib 単位のテスト ID が無い」を解消する。フック共通仕様 §11（共通のテスト観点）に HK-T13・HK-T14 を追加し、0015 がテスト ID の無いアセット変更にならないようにする。

## DoD

- [ ] `10_spec/フック共通仕様.md` §11 に HK-T13（`push-detect.sh`: fork ゼロの前置フィルタで push を含まないコマンドを即座に除外し、`tool_response` の成功判定と `@{upstream}` の縮退経路が `post-push-compact-prompt` 仕様の「push 検知」どおりに動く）と HK-T14（`transcript.sh`: カーソル以降の行だけを 1 回の jq で集計し、カーソルが進み、壊れた行を飛ばす）が追加されている（根拠: ）
- [ ] §6 の台帳の `HK-T` 行と、`post-push-compact-prompt` / `post-push-usage-report` 仕様の参照が矛盾していない（lib の観点はフック本体の PP-T / UR-T と重複しない）（根拠: ）
- [ ] プレースホルダ 0 件、履歴的表現なし（根拠: ）

## 作業内容

- §11 の表に 2 行追加し、必要なら §1 の lib 一覧の説明に観点の所在を添える

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
