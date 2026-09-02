---
type: ticket
ticket_type: investigation
predecessors: ["0002"]
executor: main
human_review: {required: false, reason: "全体計画の方針の差分 4 により、人間レビューはワークごとの敵対的レビューに置き換える"}
adversarial_review: {required: true, reason: "全体計画の方針の差分 4 により、ワークごとに 1 回の敵対的レビューを行う"}
allow:
  write: ["wip/**"]
  ops: ["read", "web"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0007 VS Code 拡張 API の外部技術調査

## 目的

設計・実装フェーズは allow.ops に web を持たず公式ドキュメントを引けないため、拡張の最小構成・Webview・FileSystemWatcher の API 事実を調査フェーズのうちに確定する

## DoD

- [ ] 観点「VS Code 拡張の最小構成（package.json の engines.vscode / activationEvents / contributes.commands、エントリの activate / deactivate）は何か」への答えが調査結果レポートに書かれている（根拠: ）
- [ ] 観点「Webview パネルの生成・HTML の与え方・拡張と Webview 間の postMessage の作法」への答えが調査結果レポートに書かれている（根拠: ）
- [ ] 観点「workspace.createFileSystemWatcher がファイルの追加・削除・編集・状態ディレクトリ間の移動をどのイベントで見せるか」への答えが調査結果レポートに書かれている（根拠: ）
- [ ] 各答えに参照した公式ドキュメントの URL または @types/vscode の型定義の該当箇所が根拠として添えられている（根拠: ）
- [ ] 答えが出なかった問いは理由付きで残課題に残っている（根拠: ）

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
