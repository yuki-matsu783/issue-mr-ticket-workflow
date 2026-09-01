---
type: ticket
ticket_type: ai-asset-implementation-plan
predecessors: ["0028", "0029", "0030"]
executor: main
human_review: {required: true, reason: "許可範囲とロックアウト対策を実装前に見る（work-defaults の既定。承認④により opus 自己レビューで代替）"}
adversarial_review: {required: false, reason: "計画書（work-defaults の既定）"}
allow:
  write: ["wip/**"]
  ops: ["read"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0031 AI アセット実装計画（設計 0028〜0030 で仕様に書いた実装 7 件）

## 目的

設計 0028〜0030 で仕様に書いた実装を伴う変更 7 件 — HK-T15 の ID 付け替え（test_scope.sh）、eval 定義 5 本の SC-E 改名、CP007 / RV008 / TK008 の出力（commit.sh / push.sh / check-html.sh / ticket.sh）、test-lib の hook_payload --session、skill.template.md のガイド、20-common-step-shell-script SKILL.md の make_counting_path、ticket.sh complete の重複見出し検査 — を対象に、固定順・テスト ID の割付・提供コマンドの切り替え境目（既に切り替え済み）・ロックアウト対策（フック未登録のため経路なし）を計画し、実装チケット群と全体まとめチケット（overall-summary）を起こす

## DoD

- [ ] AI アセット実装計画書 wip/20_plans/0031-ai-asset-implementation-plan.md（+ HTML、check-html.sh OK）があり、7 件の変更をステップ順（設定・定義 → 中核 → 中核のテスト → スキル・ルール → 参照更新）に置き、テスト ID × ステップ表（HK-T15・SC-E・CP007 / RV008 / TK008 の観点）と許可範囲・ロックアウト対策（フック未登録で経路なし。提供コマンドの変更は自分自身でコミットするので、壊した場合の復旧手順を書く）がある（根拠: ）
- [ ] 実装チケット群が未着手にあり、DoD が実装チケットの型（テスト先行・run-tests.sh --ids 全通過・プレースホルダ / frontmatter 検査・実装結果レポートの節）で書かれている（根拠: ）
- [ ] 全体まとめチケット（overall-summary）が 1 枚だけ未着手にあり、predecessors に実装チケット群の番号が入っている（根拠: ）

## 作業内容

- 設計 0028〜0030 の結果（仕様の該当節）と 0011 の実装計画書の形式を読み、同じ節構成で書く

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
