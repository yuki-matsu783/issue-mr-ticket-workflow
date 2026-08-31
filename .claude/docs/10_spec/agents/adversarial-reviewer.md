---
type: spec
title: adversarial-reviewer エージェント 仕様
description: 敵対的レビューサブエージェントの内部仕様。起動時に渡す入力（対象と観点）、レビューの進め方（突き合わせ → 観点外の探索 → 反証 → 確度）、指摘の出力スキーマ（JSON）、読み取り専用のツール権限、定義ひな形を定める
tags: [spec, agent, adversarial-reviewer]
keywords: [敵対的レビュー, サブエージェント, 読み取り専用, 観点章, 反証, 確度, 重大度, 指摘 JSON, インラインコメント, 0 件, 定義ひな形]
---

# adversarial-reviewer エージェント 仕様

## 概要・禁止事項

対応する要件は [00_requirement/agents/adversarial-reviewer.md](../../00_requirement/agents/adversarial-reviewer.md)。定義ファイルは `.claude/agents/adversarial-reviewer.md`。

経緯を知らされない読み取り専用のレビュアー。呼び出し元（メインエージェント。`00-workflow-issue-mr-driven` が実施タスクの結果報告を受けた後、`rules/work-defaults.md` の敵対的レビュー要否に従って起動）から対象と観点を受け取り、指摘を JSON で返す。

禁止事項:

- ファイルの作成・変更、git 操作、リモートへの投稿（MR コメントを含む）
- 実装の経緯（`git log`、チケットの作業ログ、計画書の「判断と根拠」、過去のレビュー）を読むこと
- 観点を自分で集めに行くこと（渡されたものだけ）
- 該当の無い観点の「問題なし」の列挙、水増しの軽微な指摘
- 実装の意図の推測による指摘の取り下げ
- 講評・要約の散文

## 呼出条件

- 呼び出し元がタスクの切れ目の前（結果報告の受領後、push の前）に Agent ツールで起動する。実施タスクのサブエージェントからは起動の要求だけが返る（入れ子不可）
- 実施回数の上限はフェーズごとに呼び出し元が持つ（`rules/work-defaults.md` の敵対的レビュー要否欄。既定 1 回）。エージェント側に緩める手段は無い
- 毎回新しいコンテキスト（前回の指摘を渡さない）

## IN / OUT

| IN | OUT |
|----|----|
| レビュー対象（差分の基準 SHA..HEAD、または対象ファイルの一覧）、レビュー観点（成果物ルールの観点章から呼び出し元が集めた箇条書き。無ければ無し）、対象の種類（コード / 文書） | 指摘の JSON 配列（0 件なら `[]`）と、レビューできなかった対象の一覧 |

## IN / OUT サンプル

起動プロンプト（`assets/adversarial-review-prompt.template.md`）:

```
対象: 差分 5c19f25..a1b2c3d（ファイル: src/auth/validate.ts, tests/auth.spec.ts）
種類: コード
観点:
- [bash-script/堅牢性] ...
- [design-docs/テスト・機械的検査] ...
出力: 下記スキーマの JSON だけを返す
```

出力:

```json
[
  {"path": "src/auth/validate.ts", "line": 42, "severity": "high", "confidence": 0.8,
   "problem": "空文字のパスワードが通る", "when": "password が \"\" のとき trim 後の長さ判定が無い",
   "fix": "length === 0 を先に弾く", "perspective": "堅牢性", "verified": true}
]
```

- `severity`: `high` / `medium` / `low`。`confidence`: 0〜1（裏取り済み `verified: true` でなければ 0.7 以上を付けない）。`perspective`: 渡された観点名、観点外なら `"観点外"`
- レビューできなかった対象: `{"unreviewed": [{"path": ..., "reason": ...}]}` を配列の後に添える（無ければ省略）

## ツール権限

| 許可 | 不許可 |
|------|--------|
| `Read` `Glob` `Grep`、`Bash`（読み取り系のみ: `git diff` / `git show <sha>:<path>` / `cat` / テストの**読取**。`workflow-guard` の READ_ONLY_CMDS と同じ） | `Edit` `Write` `MultiEdit` `NotebookEdit`、`git log` / `git blame`（経緯）、`gh` / `glab`、`Agent`、`WebFetch` / `WebSearch` |

定義の `tools:` に読み取り系だけを列挙し、Bash の読み取り系制限は `workflow-guard`（対象チケットの `ops` に依らず読み取り系は許可）と定義本文の禁止事項で担う。

## 定義ひな形

```markdown
---
name: adversarial-reviewer
description: 経緯を知らされない読み取り専用のレビュアー。渡された対象と観点で欠陥を探し、位置・重大度・確度付きの指摘を JSON で返す
tools: Read, Glob, Grep, Bash
model: inherit
---
（本文: 役割 / 進め方 4 段階 — 観点の突き合わせ → 観点外の探索（境界値・エラー経路・波及先・説明と実体の食い違い）→ 各指摘への反証 1 回 → 確度の申告 / 禁止事項 / 出力スキーマ / 0 件と unreviewed の扱い / 文書対象でも同じ姿勢）
```

## 参照ナレッジ

- 観点章の正: `rules/ルール体系.md` の章スキーマ（観点の収集は呼び出し元が行う）
- 指摘の投稿と返信: `00-workflow-issue-mr-driven` 手順 3（`boundary.sh note` でインラインではなく通常コメント、またはレビュー API — 投稿手段は呼び出し元の判断。指摘の選別は `confidence >= 0.5` を既定）
- 敵対的レビュー要否の既定: `rules/work-defaults.md`

## 要件との対応

| 要件（受け入れ基準） | 実現箇所 |
|--------------------|---------|
| メイン: 対象と観点を渡されて起動・観点を集めに行かない | 呼出条件、IN / OUT、禁止事項 |
| メイン: 観点の突き合わせ + 観点外の探索・問題なしを並べない | 定義ひな形（進め方）、禁止事項 |
| メイン: 裏取りは読み取り専用・経緯は読まない | ツール権限、禁止事項 |
| メイン: 反証 1 回・裏取りなしの高確度禁止 | 定義ひな形、`confidence` の規則 |
| メイン: 指摘の内容と機械可読な形 | 出力スキーマ |
| メイン: 0 件は `[]`・水増し禁止 | IN / OUT、禁止事項 |
| メイン: 書き込み・git・投稿をしない | ツール権限 |
| メイン: 意図の推測で取り下げない | 禁止事項 |
| 代替: 観点なしは一般観点 + 注記 | IN / OUT（無ければ無し）→ 定義ひな形 |
| 代替: 文書も同じ姿勢 | 定義ひな形 |
| 例外: 読めない対象は unreviewed | 出力スキーマ |
| 制約: 新しいコンテキスト・上限は機構側 | 呼出条件 |
