---
type: ticket
ticket_type: implementation
predecessors: ["0019"]
executor: main
human_review: {required: true, reason: "振る舞いが変わる（置き場の移動）"}
adversarial_review: {required: true, reason: "フェーズ 4 の敵対的レビューをこのチケットの完了後に 1 回実施する"}
allow:
  write: ["apl/**", "src/**"]
  ops: ["read", "build-test", "hook-test", "remote-read"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0021 実装: 拡張のソースとビルド設定を apl/vscode-ticket-board/ へ移す

## 目的

src/vscode-ticket-board/ の 18 ファイルをディレクトリごとアプリルートへ移し、拡張のテストが移動前と同じ結果になることを確かめる（0017・0020 の再起票）

## DoD

- [ ] apl/vscode-ticket-board/ に 18 ファイルがあり、src/ が消えている（V1・V2）（根拠: ）
- [ ] git log --follow が移動前のコミットを含む（git mv で履歴が保たれている）（根拠: ）
- [ ] apl/vscode-ticket-board/README.md の置き場の記述が apl/vscode-ticket-board/ になっている（根拠: ）
- [ ] apl/vscode-ticket-board/ で npm install のあと npm test が 47 件 pass する（V3。移動前に取った基準と同じ件数）（根拠: ）
- [ ] grep -rn 'src/vscode-ticket-board' apl/ が 0 件（V4）（根拠: ）
- [ ] run-tests.sh --ids が 14 本すべて PASS する（V5）（根拠: ）

## 作業内容

- git mv で移す。README を直す。npm install → npm test。V1〜V5 を順に実行する

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
