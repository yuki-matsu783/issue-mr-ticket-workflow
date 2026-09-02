---
type: report
title: 既存機構との境界と成果物の置き場の調査結果
description: 上限設定と設計文書ルールが想定する置き場を確定し、push 前チェックとの衝突点（未追跡の node_modules）と、上限設定を変えずに済む逃げ道を実測で示した
tags: [report, investigation]
---

# 既存機構との境界と成果物の置き場の調査結果

## 対象

- 対象 issue: #13 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/13
- PR: #14 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/pull/14
- チケット: 0005-investigation
- 担当した問い: Q5（置き場）・Q6（push 前チェックとの衝突）

## サマリ

機構が想定する置き場は**ソースが `src/**`、設計文書が `docs/**`** で、issue #13 の詳細欄が書く `tools/vscode-ticket-board/` は上限設定のどの許可範囲にも入らない。`src/vscode-ticket-board/` に置き換えるのが素直で、受け入れ条件は場所を規定していないので条件は変わらない。

push 前チェック 4 項目のうち、ソース追加が直接触れるものは無い。ただし `node_modules/` と `out/` が未追跡のまま残ると項目 1（未コミットの変更が無い）と `ticket.sh complete` の検査に引っかかる。root の `.gitignore` は保護されていてどのフェーズでも変更できないが、**拡張ディレクトリ内の入れ子 `.gitignore` で解決できる**ことを実測で確認した。上限設定の変更は要らない。

- ◎良 3 件 / △注意 2 件 / ✕問題 0 件

### ◆特に見てほしい

- 置き場を `tools/vscode-ticket-board/` から `src/vscode-ticket-board/` に変えること。issue #13 の詳細欄と食い違うので、issue への追記の要否を設計計画で判断したい（章 1）

### ◇承認が欲しい

- 設計文書をトップレベル `docs/00_requirement/` と `docs/10_spec/` に新設すること。このリポジトリにトップレベル `docs/` はまだ無い（章 2）
- 入れ子 `.gitignore` で `node_modules/` と `out/` を除外する方針（章 5）

### ・細かいレビューは不要

- push 前チェック 4 項目の内容そのもの（章 3）

## 確かめられなかったこと

- 上限設定を実際にフックが評価する経路は確認していない。`.claude/settings.json` に `hooks` キーが無く、フックは登録されていない。本レポートの「許可される / されない」は上限設定の記述からの読み取りであって、実行時の挙動の実測ではない
- `docs/` を新設したときに設計文書検査（`design-docs` ルールが言及する機械的検査）が働くかは、その検査自体が未整備のため確認していない

## 実施条件

- リポジトリ `/home/user/issue-mr-ticket-workflow`
- 読んだもの: `.claude/hooks/config/scope-limits.json`、`.claude/rules/design-docs.md`、`.claude/rules/ai-asset-design-docs.md`、`.claude/skills/20-common-step-commit-push/scripts/push.sh`、同 `assets/exclude-patterns.txt`、`.claude/skills/20-common-step-ticket/scripts/ticket.sh`、`.gitignore`
- 実測: 使い捨ての `src/probe/` と `tools/probe/` を作って `git status --porcelain` の出方を見た。いずれも確認後に削除した

## 実施した内容と結果

### 1. ソースの置き場は `src/**` △注意

根拠: `.claude/hooks/config/scope-limits.json` の `types`

上限設定の該当行。

```json
"implementation": {"allow": ["src/**", "tests/**"], "deny": [".claude/**", "docs/**"],
                   "confirm": ["package.json"], "ops": ["read", "build-test", "remote-read"]},
"design":         {"allow": ["docs/**"], "deny": ["src/**", ".claude/**"], "ops": ["read", "remote-read"]},
```

`implementation` が書けるのは `src/**` と `tests/**` だけで、`tools/**` はどちらにも入らない。`common.allow` も `wip/` 配下だけなので、`tools/vscode-ticket-board/` は許可範囲の外になる。

`package.json` は `implementation.confirm` に挙がっており、追加のたびに確認が入る想定になっている。Node プロジェクトの追加自体は機構の想定内。

**結論**: ソースは `src/vscode-ticket-board/` に置く。テストも同ディレクトリ内（`src/vscode-ticket-board/test/`）に置けば `src/**` に収まり、npm プロジェクトとしての自然な形も保てる。issue #13 の詳細欄は `tools/vscode-ticket-board/` と書いているが、受け入れ条件 10 件は置き場を規定していないので条件は変わらない。issue への追記の要否は設計計画で判断する。

### 2. 設計文書の置き場はトップレベル `docs/` ◎良

根拠: `.claude/rules/design-docs.md` の frontmatter `paths` と「構造・配置」、`scope-limits.json` の `design`

`design-docs` ルールは適用範囲を `docs/**` と宣言し、置き場を 4 つに固定している。

| ディレクトリ | 内容 |
|---|---|
| `docs/00_requirement/` | 要件定義書 |
| `docs/10_spec/` | 仕様書 |
| `docs/20_ddr/` | DDR（設計上の決定） |
| `docs/90_glossary/` | 用語辞書 |

`.claude/docs/` は `ai-asset-design-docs` ルールの領分で、`design` type は `.claude/**` を deny しているため、アプリの設計文書をそこに置くことはできない。トップレベル `docs/` はこのリポジトリにまだ存在しないので新設になる。

**結論**: 要件定義書は `docs/00_requirement/vscode-ticket-board.md`、仕様書は `docs/10_spec/vscode-ticket-board.md`。DDR は設計上の決定が発生したときだけ `docs/20_ddr/i0013-NN-<タイトル>.md` として作る。用語辞書は今回のスコープでは作らない（プロジェクト固有語がほぼ無い）。これで全体計画の保留事項「設計文書の置き場」が解ける。

### 3. push 前チェック 4 項目はソース追加に触れない ◎良

根拠: `push.sh` の各項目の実装

| 項目 | 見ているもの | ソース追加の影響 |
|---|---|---|
| 1 未コミットの変更が無い | `git status --porcelain` の全行（**未追跡を含む**） | コミットすれば影響なし。ただし章 4 の問題がある |
| 2 作業中のチケットが無い | `wip/10_tickets/10_doing/*.md` の有無。`allow.ops` に `remote-write:push` があれば通す | 影響なし |
| 3 レポート・計画書の対 | `wip/30_reports/` と `wip/20_plans/` の md と html の対のみ（`*-appendix-*.md` は除外） | 影響なし。`src/` は対象外 |
| 4 draft 解除後の作業領域が空 | `logs/merge-state.json` が `ready` のときだけ `wip/` を見る | 影響なし |

**結論**: 拡張のソースをどこに置いても、項目 2〜4 には触れない。問題は項目 1 だけで、それは次の章。

### 4. 未追跡の `node_modules/` と `out/` が検査を止める △注意

根拠: `git status --porcelain` の実測、`push.sh` の項目 1、`ticket.sh` の complete 検査

`push.sh` の項目 1 も `ticket.sh complete` の「チケット以外に未コミットの変更がある」検査も、どちらも `git status --porcelain` を素で使っている。この出力には未追跡ファイルが含まれる。

```
$ mkdir -p src/probe/node_modules/foo src/probe/out
$ echo x > src/probe/node_modules/foo/a.js; echo z > src/probe/main.ts
$ git status --porcelain
?? src/
```

root の `.gitignore` は `node_modules` も `out` も無視していない。そして `scope-limits.json` の `common.protected` に `.gitignore` が挙がっており、`ai-asset-implementation` の allow（`.claude/skills/**`・`.claude/hooks/**`・`.claude/rules/**`・`.claude/agents/**`・`.claude/settings.json`・`.claude/evals/**`・`CLAUDE.md`・`.gitattributes`）にも入っていない。**どのフェーズでも root の `.gitignore` は変更できない**。

なお `commit.sh` の自動除外パターンには `node_modules/**` と `out/**` があるので、誤ってコミットする経路は塞がれている。問題は「コミットされること」ではなく「未追跡として残り検査を止めること」である。

**結論**: root の `.gitignore` を変えずに未追跡を消す手段が要る。

### 5. 逃げ道は拡張ディレクトリ内の入れ子 `.gitignore` ◎良

根拠: 実測

`src/vscode-ticket-board/.gitignore` のように、拡張ディレクトリの中に `.gitignore` を置けば git は正しく無視する。このパスは `.gitignore`（リポジトリルート相対）とは別物なので `common.protected` に当たらず、`implementation` の allow である `src/**` に収まる。

```
$ printf 'node_modules/\nout/\n' > src/probe/.gitignore
$ git status --porcelain
?? src/
$ git status --porcelain --untracked-files=all
?? src/probe/.gitignore
?? src/probe/main.ts
```

`node_modules/` と `out/` が消え、追跡すべきファイルだけが残った。

**結論**: 実装フェーズは `src/vscode-ticket-board/.gitignore` を最初のコミットに含める。上限設定の変更も root `.gitignore` の変更も要らない。

### 上限設定の変更が要る場合の扱い（敵対的レビューの指摘 10 への回答）

今回は変更が要らないが、要る場合の経路を明記しておく。

| 変更したいもの | どのフェーズで | どの承認で |
|---|---|---|
| `.claude/hooks/config/scope-limits.json`（許可範囲・`commands.build-test`） | `ai-asset-implementation`（allow に `.claude/hooks/**`） | `common.confirm` に `.claude/hooks/config/**` があるため毎回人間の確認。フィードバック計画で後続フェーズとして立てる |
| root の `.gitignore` | どのフェーズでも不可（`common.protected` にあり、どの type の allow にも無い） | 人間が直接変更するしかない。AI は変更しない |
| `.gitattributes` | `ai-asset-implementation`（allow にある） | 人間レビュー（またはワークごとの敵対的レビュー） |

## 想定と異なった点

| 計画時の見込み | 実際 | どう扱ったか |
|---|---|---|
| 置き場は issue #13 の詳細どおり `tools/vscode-ticket-board/` でよい | `tools/**` は上限設定のどの許可範囲にも入らない | `src/vscode-ticket-board/` を推奨し、issue への追記の要否を設計計画に回した（章 1） |
| `commit.sh` が `node_modules` を自動除外するので `.gitignore` は要らない | 除外はコミット時の話で、未追跡として残ると検査を止める | 入れ子 `.gitignore` で解決できることを実測した（章 4・5） |
| root の `.gitignore` を足せば済む | `common.protected` にあり、どのフェーズでも変更できない | 入れ子 `.gitignore` という別経路を見つけた（章 5） |

## 設計への反映

1. ソースは `src/vscode-ticket-board/`、テストはその中の `test/` に置く（章 1）
2. 設計文書はトップレベル `docs/00_requirement/vscode-ticket-board.md` と `docs/10_spec/vscode-ticket-board.md` を新設する（章 2）
3. `src/vscode-ticket-board/.gitignore` に `node_modules/` と `out/` を書き、最初のコミットに含める（章 5）
4. issue #13 の詳細欄と置き場が食い違うので、issue への追記の要否を設計計画で判断する（章 1）
5. `package.json` の追加は `implementation.confirm` に当たるので、実装計画でその旨を書いておく（章 1）
6. 上限設定・root `.gitignore` の変更は今回発生しない。将来必要になった場合の経路は本レポートの表を参照する

## 残課題

- 上限設定の評価はフックが `settings.json` に登録されて初めて働く。現状は登録が無く、本レポートの「許可される / されない」は記述からの読み取りである。フックが有効化されたときに実際に通るかは、その時点で確認が要る
- `docs/` 配下の設計文書に対する機械的検査（`design-docs` ルールが言及するもの）は未整備。整備されるまではセルフレビューとレビューで見る
