---
type: ticket
ticket_type: implementation
predecessors: ["0009"]
executor: main
human_review: {required: false, reason: "全体計画の方針の差分 4 により、人間レビューはワークごとの敵対的レビューに置き換える"}
adversarial_review: {required: true, reason: "振る舞いが変わるため基準どおり要。担い手は差分 4 により汎用サブエージェント"}
allow:
  write: ["src/**", "wip/**"]
  ops: ["read", "build-test"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0010 中核層の実装とテスト（frontmatter / ticket / scan / board / render）

## 目的

VS Code に依存しない層を仕様書のとおりに実装し、テスト TB-T01〜TB-T14 を先に書いて通す

## DoD

- [ ] src/vscode-ticket-board/ にプロジェクトの土台（package.json / tsconfig.json / .gitignore）があり、開発依存が typescript・@types/node・@types/vscode の 3 つに限られている（根拠: ）
- [ ] core/frontmatter.ts・ticket.ts・scan.ts・board.ts・render.ts が仕様書「モジュール構成」「データの形」「処理フロー」のとおりに実装され、いずれも vscode を import していない（根拠: ）
- [ ] テスト TB-T01〜TB-T14 が失敗ケース（境界値・異常系）を含めて通る（実行方法: cd src/vscode-ticket-board && npm test）（根拠: ）
- [ ] npx tsc -p . が警告なく通る（strict 有効）（根拠: ）
- [ ] チケット由来の文字列が escapeHtml を通ることを TB-T14 が確かめている（根拠: ）
- [ ] 仕様からの逸脱があれば作業ログに記録されている（根拠: ）

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
