# 類似 issue の判定基準と CLI コマンド集

正は `.claude/docs/10_spec/skills/20-common-step-issue.md`（検索の手順）と `.claude/docs/10_spec/skills/10-task-overall-plan.md`（承認①の選択肢）。

## 判定区分

| 判定 | 基準 | 扱い |
|------|------|------|
| **類似** | 同じ機能領域 **かつ** 同じ問題・要望（言い換えや粒度違いを含む） | 承認①で「この issue で対応するか」を確認する候補 |
| **関連** | 同じ機能領域だが別の問題・要望、または依存関係がある | 候補表に載せるが、対応先にはしない。新規 issue の「関連する Issue」にリンクする |
| **無関係** | 機能領域も問題も異なる | 提示しない |

判定のコツ:

- タイトルだけで決めない。本文（`body`）の「概要」「期待動作」を読む
- 依頼が「バグ」で issue が「機能追加」のように種別が違っても、同じ箇所の同じ振る舞いなら類似
- closed な類似 issue は「再オープンして対応するか」を承認①の選択肢に加える。再発バグは再オープン、仕様変更は新規が目安
- 迷ったら「関連」に倒し、ユーザーに判断を委ねる

## 検索コマンド（GitHub）

```bash
# open を keywords で検索（まずこれ）
gh issue list --state open --search "<keywords>" --limit 20 --json number,title,state,labels,url,body

# closed も含める（open で 0 件のとき）
gh issue list --state all --search "<keywords>" --limit 20 --json number,title,state,labels,url,body

# 検索語を変えて再検索（英語 / 日本語、同義語）
gh issue list --state open --search "login validation" --limit 20 --json number,title,url

# 件数が少ないリポジトリでは全件を眺める方が早い
gh issue list --state open --limit 50 --json number,title,url

# 候補の詳細
gh issue view N --json number,title,state,url,body,labels,comments
```

`--search` は GitHub の検索構文。`in:title`、`label:bug`、`author:` などの修飾子が使える。

## 検索コマンド（GitLab）

```bash
# open を検索語で
glab issue list --search "<keywords>" --per-page 20

# closed も含める
glab issue list --all --search "<keywords>" --per-page 20

# 候補の詳細
glab issue view N
```

## 候補の提示フォーマット

```
| # | タイトル | 状態 | 一致点 | 判定 |
|---|---------|------|--------|------|
| 12 | ログイン画面のバリデーション | open | ログイン / バリデーション | 類似 |
| 8  | パスワード強度チェック | closed | パスワード | 関連 |
```

「一致点」には keywords のどれが一致したかと、本文で確認した根拠を短く書く。
