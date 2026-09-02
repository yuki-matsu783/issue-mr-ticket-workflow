---
type: ticket
ticket_type: implementation
predecessors: ["0010"]
executor: main
human_review: {required: false, reason: "全体計画の方針の差分 4 により、人間レビューはワークごとの敵対的レビューに置き換える"}
adversarial_review: {required: true, reason: "振る舞いが変わるため基準どおり要。担い手は差分 4 により汎用サブエージェント"}
allow:
  write: ["src/**", "wip/**"]
  ops: ["read", "build-test"]
started_at: "2026-09-02T06:19:38+00:00"
completed_at: ""
base_sha: "7d207ae"
---

# 0011 拡張ホスト層の実装と README（extension / board-panel）

## 目的

コマンド登録・Webview パネル・FileSystemWatcher を仕様書のとおりに実装し、ビルドとテストの手順と実機確認の手順を README に書く

## DoD

- [ ] src/extension.ts と src/board-panel.ts が仕様書「起動と入口」「表示と更新」のとおりに実装されている（根拠: ）
- [ ] package.json の contributes.commands に ticketBoard.open と ticketBoard.refresh があり、engines.vscode が ^1.90.0、activationEvents が空配列である（根拠: ）
- [ ] README.md にビルド・テストの実行方法と、単体テストにできない受け入れ条件（カードの選択・ワークスペースが無い場合）の手動確認の手順が書かれている（根拠: ）
- [ ] npm test（tsc -p . と node --test）が通り、TB-T01〜TB-T14 が全通過する（根拠: ）
- [ ] node_modules と out が git status に現れない（入れ子の .gitignore が効いている）（根拠: ）
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
