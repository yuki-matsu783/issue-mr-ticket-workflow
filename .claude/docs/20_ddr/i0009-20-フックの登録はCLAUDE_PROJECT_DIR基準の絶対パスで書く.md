---
type: ddr
title: i0009-20. フックの登録は CLAUDE_PROJECT_DIR 基準の絶対パスで書く
description: 相対パス登録ではカレントディレクトリがリポジトリルート以外のとき拒否側フックが終了 127 になり、fail-closed ラッパーが全操作を deny してロックアウトするため、絶対パス登録に変えた判断
tags: [ddr, hooks, settings.json, 登録, ロックアウト]
keywords: [CLAUDE_PROJECT_DIR, 絶対パス, cwd, 127, ラッパー, ロックアウト, HK-T01]
---

# i0009-20. フックの登録は `${CLAUDE_PROJECT_DIR}` 基準の絶対パスで書く

## 背景

§1 の登録の雛形は `"command": "bash .claude/hooks/<NN-Event>/<name>.sh"` という**リポジトリルート相対パス**だった。あわせて拒否側 5 登録は fail-closed のラッパー（`bash <パス> || printf '{… deny WFx09 …}'`）で登録することになっている。

設計ワークの境界レビュー（付録 A の R10）で、公式の 2 つの記述が突き合わされた。

- 「**Handlers run in the current directory** with Claude Code's environment.」（cwd が消えていた場合は、起動ディレクトリ → プロジェクトルート → ホーム → temp の順でフォールバックする）
- 「**Use absolute paths**: specify full paths for scripts. In exec form, use `${CLAUDE_PROJECT_DIR}` and the path needs no quoting. **In shell form, wrap it in double quotes**」

つまり cwd はリポジトリルートとは限らない。Claude が `cd` した後、worktree、サブディレクトリで起動した場合はルート以外になる（フォールバックは cwd が**消えた**ときにしか働かず、存在する別ディレクトリなら発動しない）。

## 決定

- 登録の `command` を **`bash "${CLAUDE_PROJECT_DIR}/.claude/hooks/<NN-Event>/<name>.sh"`** の形にする（シェル形式なのでダブルクォート必須）
- 相対パス（`bash .claude/hooks/...`）にしてはならないことを §1 に明記し、理由（ロックアウト）を書く
- 拒否側 5 登録のラッパーも同じ形にする
- HK-T01 の照合対象に `command` 文字列そのものを含める

## 理由

- 相対パスが解決できないと `bash` は終了 **127** で落ちる。ラッパーの `||` はまさにこれを拾って deny を出す設計なので、**拒否側 5 本すべてが同時に deny を返し、書き込み・実行・プランモード・起動のすべてが止まる**
- この状態から AI 側でできることは無い（ファイルを直そうにも書き込みが deny される）。回復は「新しいセッションで `WORKFLOW_ENFORCE=0`」だけで、実装計画がロックアウト対策として一番避けたい形
- 案内側 6 本は同じ状況で**静かに動作停止**する。deny が出ないので誰も気づかない
- 公式が明示的に推奨している形なので、独自の工夫ではなく素直な選択

## 却下した案

- **フック本体の先頭で `cd` する**: 本体が起動できないのが問題なので、本体の中身では解決しない
- **ラッパーを `|| exit 0`（fail-open）にする**: フェイルクローズドの原則そのものを捨てることになる。127 と「フックが判定できなかった」を区別できない以上、原因を潰す方が正しい
- **`CLAUDE_PROJECT_DIR` が未設定の環境に備えて相対パスをフォールバックに残す**: `command` に条件分岐を書くと HK-T01 の照合が複雑になる。未設定なら `${CLAUDE_PROJECT_DIR}` が空に展開されて `/.claude/hooks/...` を探し 127 になるが、これは「登録が壊れている」という正しい失敗で、cwd 依存の不定な失敗より扱いやすい

## 影響

- `10_spec/フック共通仕様.md` §1（登録の雛形・ラッパー・HK-T01）
- **フェーズ 4b へ**: `settings.json` への登録（人間の操作）は必ずこの形で行う
- **0016 へ**: HK-T01 の期待値に 17 行分の `command` 文字列を持たせる
