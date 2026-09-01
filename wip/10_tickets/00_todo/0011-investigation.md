---
type: ticket
ticket_type: investigation
predecessors: []
executor: main
human_review: {required: true, reason: "全体計画の方針: 調査の結論が実装計画を左右する（承認④により opus の敵対的自己レビューで代替。2 巡目まで実施済みのため本チケットでレビューは打ち止め）"}
adversarial_review: {required: false, reason: "ユーザー指示によりタスクごとの敵対的レビューは最大 2 回。本チケットは 2 巡目の反映であり 3 巡目は行わない"}
allow:
  write: ["wip/**"]
  ops: ["read", "remote-read", "web"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0011 調査 3 本の 2 巡目レビュー指摘の反映（S1〜S13）

## 目的

調査ワークの 2 巡目（最終）敵対的レビューが出した 13 件のうち confidence 0.5 以上の 12 件を反映し、0.4 の 1 件は判断を記録する

## DoD

- [ ] S1・S2: 公式 hooks リファレンスの PreToolUse decision table（allow / deny / ask / defer の各行）を原文で確認し、確認できた場合は 0007 f3・f7・検証表・設計への反映を訂正した。確認できなかった場合は「未確認」として残課題に記録した（根拠: ）（根拠: ）
- [ ] S3: 0007 f7 の timeout の引用に限定句（async: true の除外）を戻し、公式の既定値（command / http / mcp_tool は 600、UserPromptSubmit などで 30）を本文に載せて残課題から外した（根拠: ）（根拠: ）
- [ ] S4: 0007 f8 の T5 の問いを共通仕様 §12 の原文（session_id / cwd / permission_mode の共通フィールド）に合わせて直し、4c の検証項目を差し替えた。あわせて hook-common.sh の PowerShell 吸収（CR 除去）を実施条件と本文に加えた（根拠: ）（根拠: ）
- [ ] S5・S7・S8・S9・S10・S12 の事実の誤りを訂正した（空ディレクトリ 3 つ・HTML の CP_GITLIKE の逆転・scope.sh の行番号・参考実装の登録本数と新規 7 本の列挙・assets の置き場の断定・行範囲と引用の改変）（根拠: ）（根拠: ）
- [ ] S6・S11・S13 を反映した（f2 の案 (c) の波及の明記・0007 検証表への出典列の追加・0005 サマリの件数の整合）（根拠: ）（根拠: ）
- [ ] 3 本の md と HTML を同期し、check-html.sh が OK を返した（根拠: ）（根拠: ）

## 作業内容

- S1・S2 の原文を公式ドキュメントで再取得する。取れなければ未確認として扱い、レポートには反映しない
- 0005 / 0006 / 0007 の md を訂正し、HTML をテンプレートから作り直す
- confidence 0.4 の S13 の扱い（反映するか見送るか）を作業ログに記録する

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
