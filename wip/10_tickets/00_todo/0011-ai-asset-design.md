---
type: ticket
ticket_type: ai-asset-design
predecessors: []
executor: main
human_review: {required: false, reason: "承認③により人間レビューは fable の敵対的レビューで代替する"}
adversarial_review: {required: false, reason: "設計フェーズの 2 回は 0011〜0016 完了時と指摘対応後に使う（全体計画）"}
allow:
  write: ["wip/**"]
  ops: ["remote-read"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0011 提供コマンド 2 本の置き場を仕様側に確定し、食い違い 5 件と release の段階順を解消する

## 目的

boundary.sh と finalize.sh をスキルの scripts 配下に置くと決め、仕様・フック仕様・ticket.sh 仕様の記述を揃えて、実装フェーズが直す対象を確定させる

## DoD

- [ ] 10_spec/skills/00-workflow-issue-mr-driven.md と 10-task-overall-summary.md の Script 処理に置き場が .claude/skills/<スキル名>/scripts/ であることが明記されている（根拠: ）（根拠: ）
- [ ] 実装フェーズで直す 7 行（session-start.sh のハードコード 1・workflow-state-guard.sh の案内文 2・テストの入力 4）が仕様の「現行アセットとの差分」に列挙されている（根拠: ）（根拠: ）
- [ ] 食い違い #3（session-start の注入形式・WF702/WF703）が session-start 仕様とフック共通仕様に書かれている（根拠: ）（根拠: ）
- [ ] 食い違い #6（TK005 で overall-summary の complete が拒否される）の代替経路が 20-common-step-ticket 仕様に書かれ、finalize.sh release 段階 2 の出力先と対応している（根拠: ）（根拠: ）
- [ ] 食い違い #7（finalize.sh の CLI 不在時の経路）が仕様に書かれている（根拠: ）（根拠: ）
- [ ] 受け入れ条件 B3 の段階順が release の段階として成立している（片付け直前の SHA 確定 → 本文のリンク一覧更新 → 片付け）（根拠: ）（根拠: ）
- [ ] 置き場を仕様側に寄せた判断と却下案が DDR に残っている（根拠: ）（根拠: ）
- [ ] 0004 の食い違い一覧に決着先の列が足されている（根拠: ）（根拠: ）

## 作業内容

- 0004 の食い違い一覧 8 行のうち #1・#2・#3・#6・#7 を仕様に書き戻す
- release の段階を B3 の順序に並べ直す
- DDR を 1 件書く

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
