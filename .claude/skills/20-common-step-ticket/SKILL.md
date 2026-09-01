---
name: 20-common-step-ticket
description: >
  チケット（wip/10_tickets/ 配下の Markdown 1 枚）の作成・着手・完了・取り消し・次の提示を、提供コマンド
  ticket.sh 経由でだけ行う共通ステップ。状態はディレクトリ（00_todo / 10_doing / 20_done / 30_cancelled）で表し、
  ticket.sh が時刻・差分基準点の記録・完了検査（DoD・作業ログ・未コミット）・状態変更のコミットを担う。
  Use when a task skill needs to create a ticket, start or complete one, cancel one, or ask which ticket comes
  next ("次のチケット", "チケットを起こして", "着手", "完了にして"), and when resuming a session with a ticket in 10_doing/.
---

# 20-common-step-ticket — チケットの状態遷移は ticket.sh でだけ行う

チケットは `wip/10_tickets/<状態>/<連番 4 桁>-<種類>.md`。手で移動・改名して状態を変えない（フックが拒否する）。機械可読の正は frontmatter（`ticket_type` 等）で、ファイル名の種類は表示用。

- 要件: `.claude/docs/00_requirement/skills/20-common-step-ticket.md`
- 仕様（正。サブコマンドの手順・完了検査の項目・エラー識別子 TK001〜008・テンプレートの節）: `.claude/docs/10_spec/skills/20-common-step-ticket.md`

## 手順

すべて `bash .claude/skills/20-common-step-ticket/scripts/ticket.sh <subcommand>` で行う。最終行が `OK:` か `TKxxx:`（`next` は JSON）。

1. **次の提示**: `ticket.sh next` → `{"current": <作業中の番号 or null>, "next": <着手できる最小連番 or null>, "type": ..., "skill": ...}`。`next` は先行チケット（`predecessors`）がすべて `20_done/` にあるものだけを返し、全部が待ちなら `next: null` に `blocked: [...]` を添える。`00_todo/` も空なら `{"current": null, "next": null}`（呼び出し元はループ終了）。種類 → スキル名の解決はこのコマンドだけが行う（`.claude/hooks/config/task-types.tsv`）
2. **作成**: `ticket.sh create <種類> --title "<見出し>" --purpose "<目的>" --dod "<項目>" [--dod ...] [--work "<手順>"]... [--predecessors "0001,0002"] [--executor main|<モデル>] [--human-review true|false] [--human-review-reason "<理由>"] [--adversarial-review true|false] [--adversarial-review-reason "<理由>"] [--allow-write "a/**,b/**"] [--allow-ops "read,build-test"]`。テンプレート `assets/ticket.template.md` を埋めて `00_todo/` に置き、`chore: チケット NNNN を作成` でコミットする（`overall-plan` だけはコミットしない）。DoD の各項目には根拠欄 `（根拠: ）` が付く。不明な引数・`task-types.tsv` に無い種類・必須引数の欠落は TK008（終了 2）。理由や glob に `"` / `\` / `&` / `|` を含めてもよい（YAML エスケープはコマンドが行う）。記載事項はテンプレートにある項目だけ（独自の項目を足さない。必要性は作業ログ「AI アセットに反映すべき内容」へ）
3. **着手**: `ticket.sh start NNNN`。作業中が他にあれば TK002、未着手に無ければ TK004、先行が未完了なら TK006。開始時刻（ISO 8601）と差分基準点（HEAD の SHA）を frontmatter に記録して `10_doing/` へ移し、コミットする。以後、作業ログはその都度追記する（`現在地` は必須）
4. **完了**: 成果物を `20-common-step-commit-push` の `commit.sh` で先にコミットしてから `ticket.sh complete NNNN`。検査（未充足を全件列挙して TK003）: DoD の `- [ ]` が 0 件 / チェック済み DoD の根拠欄が空でない（根拠欄そのものが無い `- [x]` も未充足）/ 作業ログの固定見出し 10 項目がすべてあり、重複していない（テンプレートの空の見出しを残したまま追記しない）/ 「現在地」に未完了が残っていない（行頭 `- 次`・行頭 `- 未着手`・節内の `未着手` の語、の 3 条件。「済」「完了」の言い方で書く）/ 「AI アセットに反映すべき内容」が空でない（0 件なら 0 件である根拠）/ チケット以外に未コミットの変更が無い。通れば完了時刻を記録して `20_done/` へ移し、コミットする。全体まとめ（`overall-summary`）は `complete` を使わない（TK005。片付けの提供コマンドが完了を内包する）
5. **取り消し**: `ticket.sh cancel NNNN --reason "<理由>"`（理由が空なら TK007）。`30_cancelled/` へ移し、理由と時刻を frontmatter に記録してコミットする。完了済み・取り消し済みを作業中に戻さない（誤りは追加チケットで対応）
6. **再開**: `ticket.sh next` の `current` があるチケットの作業ログ「現在地」を読み、続きから進める（状態を動かし直さない）

状態変更のコミットが `commit.sh` に拒否されたときは、その最終行（`CPxxx:`）がそのまま返り、チケットは元の置き場・元の内容に戻る（作成なら残らない）。拒否の理由を解消して再実行する。

## 参照

- テンプレート: `assets/ticket.template.md`（frontmatter の項目・DoD・作業内容・作業ログの固定見出し 10 項目。一覧の正は要件書）
- 提供コマンド: `scripts/ticket.sh`（create / start / complete / cancel / next）
- 種類 → スキル名の対応表: `.claude/docs/10_spec/skills/00-workflow-issue-mr-driven.md`（実体 `.claude/hooks/config/task-types.tsv`）
- frontmatter の読み取り・sh の規約: `20-common-step-shell-script`（`frontmatter.sh`）
- 状態変更・成果物のコミット: `20-common-step-commit-push`
- 種類ごとの宣言の上限・既定判断基準: `.claude/hooks/config/scope-limits.json`、`.claude/rules/work-defaults.md`

## エラー時の対処

| 状況 | 対処 |
|------|------|
| `TK001:` プレースホルダ残存 | `create` の引数（`--title` / `--purpose` / `--dod`）を埋め直す |
| `TK002:` 作業中が既にある | 先にそのチケットを `complete` か `cancel` する。同時に作業中は 1 枚 |
| `TK003:` 完了検査の未充足 | 列挙された全件を実態で満たす（形だけの記入をしない）。未コミットは `commit.sh` で先にコミット |
| `TK004:` 対象が見つからない・状態が違う | 表示された実際の置き場を確認する。手で動かさず、必要なら追加チケットを作る |
| `TK005:` 全体まとめの完了 | 片付けの提供コマンド（`10-task-overall-summary`）に任せる |
| `TK006:` 先行チケット未完了 | 先行を先に完了する。`next` は先行未完了のチケットを飛ばす |
| `TK007:` 取り消し理由が空 | `--reason` を付ける |
| `TK008:` 引数・環境の誤り（終了 2） | 出力の `usage` に合わせて呼び方（サブコマンド・種類・必須引数・番号 4 桁）を直す。テンプレート・`commit.sh`・`jq` の不在やルートに移れないときは環境を直す |
| `CPxxx:` で返った | `commit.sh` の拒否。理由（件名規約・除外・差分なし）を解消して再実行。チケットは元に戻っている |
| `ticket.sh` 自体が壊れている | 手作業で代替しない。報告して停止する |
