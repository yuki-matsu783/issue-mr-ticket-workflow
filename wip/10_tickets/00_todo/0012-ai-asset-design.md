---
type: ticket
ticket_type: ai-asset-design
predecessors: []
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

# 0012 拒否側フック 4 本の判定の決定（git 'commit' / mcp__.* / G8 / entry-skills.txt）

## 目的

block-direct-git・workflow-state-guard・workflow-guard・workflow-entry の 4 本について、調査で見つかった判定の穴と未定を仕様に落とす（決定 1・2・3・4）

## DoD

- [ ] block-direct-git の要件定義書と仕様書が更新され、bash 経路で第 1 サブコマンドが _（特定できない）ときに deny WF403 を出す判定が制御方式に入っている（根拠: ）（根拠: ）
- [ ] workflow-state-guard の仕様の呼出条件に matcher の mcp__.* が明記されている（根拠: ）（根拠: ）
- [ ] workflow-guard の要件と仕様に「作業中チケットが 2 枚以上は機構の異常」として WF207 で拒否する判定順の位置が書かれ、提供コマンドが 1 枚目しか見ない非対称への注記がある（根拠: ）（根拠: ）
- [ ] workflow-entry の仕様で、振り分けスキル名の正が assets/entry-skills.txt であることと、tool_class は分類のみを返すという役割分担が書かれている（根拠: ）（根拠: ）
- [ ] 受け入れ条件 1 が仕様のテスト観点に落ちている（BG-T01 に git 'commit' のケース、WG-T* に WF207、WE-T07 の期待値）（根拠: ）（根拠: ）
- [ ] 横断文書（自己改善ワークフロー機構.md・ルール体系.md・90_glossary/）との整合を確認し、更新が要る箇所は 0014 へ送るか自分で直したかを明記した（根拠: ）（根拠: ）
- [ ] 決定の経緯が DDR i0009-01〜04 の範囲に残っている（根拠: ）（根拠: ）
- [ ] 各フックのヘッドレス実行の帰結（deny は確認を伴わないので変わらない / WF207 は ask にせず deny）が仕様に書かれている（根拠: ）（根拠: ）

## 作業内容

- 0008 計画書の文書一覧と骨子に従って 4 本の要件・仕様を更新する
- フック共通仕様（§1・§6・§12）には触らない。触る必要が出たら 0014 への申し送りとして作業ログに書く
- DDR は i0009-01〜04 の範囲だけを使う

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
