---
type: ticket
ticket_type: investigation
predecessors: ["0041"]
executor: main
human_review: {required: true, reason: "結論が DDR i0009-22 の上書き可否を左右する（work-defaults 基準どおり）"}
adversarial_review: {required: false, reason: "基準どおり"}
allow:
  write: ["wip/**"]
  ops: ["read", "build-test"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0043 ホットパスの起動コストの実測と実行環境の前提

## 目的

cmdpos.sh を Python 実装に替えた場合にホットパスがどれだけ遅くなるかを実測し、Python を前提にするために .claude/ へ何が要るかを列挙する

## DoD

- [ ] 観点 B-1（Python 実装にした場合の 1 ツール呼び出しあたりの増分）への答えが wip/30_reports/0043-investigation.md に書かれている。bash 版との比較と、ホットパス 5 本ぶんの見積りを含む（根拠: ）
- [ ] 計測は各 50 回の中央値で、bash 版との差が測定の揺れより大きいことが示されている（根拠: ）
- [ ] 観点 B-2（Python 実装の前提。インタプリタの解決方法・起動オプション・import するモジュール・DDR i0001-14 を満たす条件）への答えが書かれている（根拠: ）
- [ ] 根拠（コマンドの出力）が添えられている（根拠: ）
- [ ] 答えが出なかった問いは理由付きで残課題に残っている（根拠: ）
- [ ] レポートと対の HTML があり check-html.sh が通っている（根拠: ）

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
