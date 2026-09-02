---
type: ticket
ticket_type: ai-asset-design
predecessors: []
executor: main
human_review: {required: true, reason: "正史（要件・仕様）の変更"}
adversarial_review: {required: false, reason: "敵対的レビューエージェントが未作成。差分は 1 スキルの要件・仕様に閉じる"}
allow:
  write: ["wip/**"]
  ops: ["read"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0001 削除を含むコミットの扱いを要件定義書と仕様書に定める

## 目的

commit.sh が削除済み（index にも無い）パスで CP001 を返す問題について、正しい振る舞いを正史（要件定義書・仕様書）に定義し、実装とテストが推測なしに作れる粒度まで決める

## DoD

- [ ] 20-common-step-commit-push の要件定義書に、削除を含むコミットの受け入れ基準が追加されている（根拠: ）
- [ ] 同スキルの仕様書の commit.sh 手順 4 に、ステージ済みの削除の扱いと判定順が書かれている（根拠: ）
- [ ] CP001 のメッセージ要件が、ステージ済みの削除と綴り誤り・.gitignore 対象を区別できる形に更新されている（根拠: ）
- [ ] テスト観点に削除の 3 経路（rm のみ / rm + git add / git rm）と混在ケースの CP-Txx が追加されている（根拠: ）
- [ ] 要件との対応表に追加分が反映され、実装漏れ・過剰仕様が無い（根拠: ）

## 作業内容

- 20-common-step-requirement に従って要件定義書を更新する
- 20-common-step-spec に従って仕様書を更新する
- commit.sh の現状の判定順を読み、仕様との差分を洗い出す

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
