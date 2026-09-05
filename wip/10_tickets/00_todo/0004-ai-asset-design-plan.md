---
type: ticket
ticket_type: ai-asset-design-plan
predecessors: ["0003"]
executor: opus
human_review: {required: false, reason: "基準どおり（work-defaults.md: 計画書は設計結果と一緒に見れば足りる）"}
adversarial_review: {required: false, reason: "基準どおり"}
allow:
  write: ["wip/**"]
  ops: ["read", "remote-read"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0004 hook機構.md への取り込みの AI アセット設計計画

## 目的

調査結果（0003）と原文をもとに、.claude/docs/00_requirement/hook機構.md へ何をどの順で書き足すかを AI アセット設計計画書にまとめ、設計実施チケットと次の計画チケット 1 枚を起こす

## DoD

- [ ] AI アセット設計計画書（md + HTML）が wip/20_plans/ にあり check-html.sh を通過している（根拠: ）
- [ ] 計画書に、取り込む節の範囲（§0 からどこまでか）が確定して書かれている（issue #52 本文・追記コメント・原文のどれを根拠にしたかを明記する）（根拠: ）
- [ ] 計画書が issue #52 の受け入れ条件 A1・A2・A3・A4 それぞれに、どの設計チケットで満たすかを対応づけている（根拠: ）
- [ ] 中核（フック・settings.json）の変更要否が判断され「不要」の根拠が書かれている（変更先は .claude/docs/00_requirement/hook機構.md のみ）（根拠: ）
- [ ] AI アセット設計実施チケットが executor: main（メインエージェント）で起票されている（根拠: ）
- [ ] 次の計画チケット（ai-asset-implementation-plan）が 1 枚 00_todo/ にある（根拠: ）

## 作業内容

- wip/30_reports/0003-investigation.md（章番号の連続性・前方参照の全件）と wip/00_overall_plan/overall-plan.md を読む
- 【必須】取り込む原文はスクリーンショット画像としてメインエージェントのセッションにしか無いため、ai-asset-design の実施チケットは executor: main（メインエージェント）で起こすこと。サブエージェントには渡せない
- 上記は .claude/rules/work-defaults.md の ai-asset-design 行（既定の実行者 サブエージェント（opus））からの逸脱にあたる。逸脱の理由（原文がメインエージェントのセッションにのみ存在する）を計画書に明記すること
- 全体計画書「文書の型についての差分」の合意どおり、生写しの形式を保つ計画にする（章順の組み替え・EARS への書き換え・mermaid 図の追加・1:1 の仕様書の作成は計画しない）
- 0002 の計画書の保留 P1（取り込み範囲が §0〜§5 か §0〜補遺の全文か未確定）を、原文と issue #52 の追記コメントを見て決着させる
- 設計チケット群と次の計画チケット 1 枚を ticket.sh create で起こす

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
