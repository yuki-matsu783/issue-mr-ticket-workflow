---
name: 20-common-step-issue
description: >
  リポジトリのホスト（GitHub / GitLab）を origin の URL から判定して gh / glab を選び、issue の検索（open → 0 件なら
  closed も、1 ページ目のみ）・閲覧・作成（承認済み本文をファイル経由）・追記（既存本文の末尾のみ、送信直前に再取得して
  一致確認）を行う共通ステップ。状態変更・コメント・既存記述の書き換えはしない。
  Use when 10-task-overall-plan needs to find, read, create or append to an issue ("issue を探して", "#N を見せて",
  "issue を起こして", "#N に追記して"), when feedback-plan / overall-summary files a separate issue, or when another
  step needs the host detection or GitLab long-body sending procedure.
---

# 20-common-step-issue — issue は CLI で、書き込みは承認済み本文の作成と末尾追記だけ

スクリプトは持たず、CLI コマンドの組み立てを手順で固定する。ホスト判定の手順はこのスキルが正で `20-common-step-feature-mr` からも参照される。issue の close / reopen・タイトル変更・既存記述の書き換え・削除・コメント投稿はしない。承認されていない本文で作成・追記しない。CLI が使えないときに Web へ直接リクエストしない。長い本文はコマンドライン引数に埋め込まず必ずファイル経由で渡す。書き込みは作業中チケットの「やってよいこと」に issue の起票・追記が宣言されていることが前提（宣言外はフックが拒否する）。

- 要件: `.claude/docs/00_requirement/skills/20-common-step-issue.md`
- 仕様（正。処理フロー・GitLab の長文送信・eval ID IS-E01〜03）: `.claude/docs/10_spec/skills/20-common-step-issue.md`

## 手順

呼び出し元はモード（ホスト判定 / 検索 / 閲覧 / 作成 / 追記）を指定する。番号や URL が指定されていれば検索を省略する。

1. **ホスト判定**: `git remote get-url origin` の URL に `gitlab` を含めば `glab`、`github` を含めば `gh`。どちらでもない（セルフホスト等）ならユーザーに確認し、推測で選ばない。`gh auth status` / `glab auth status` が通らなければ導入・認証の手順を返して停止する
2. **検索**: キーワードは日本語と英語の両方を空白区切りで。open を対象に 1 ページ目だけ取得し（gh `--limit 21` / glab `--per-page 21 --page 1`）、0 件なら closed を含めて再検索する（gh `--state all` / glab `--all`）。21 件目があれば「上位 20 件に絞った」と条件を明記する。結果は 番号・タイトル・状態・URL の表と、使った検索語・件数を返す（類似 / 関連 / 無関係の分類は呼び出し元の基準）
   ```bash
   gh issue list --state open --search "ログイン login" --limit 21 --json number,title,state,url
   glab issue list --search "ログイン login" --per-page 21 --page 1
   gh issue list --state all --search "ログイン login" --limit 21 --json number,title,state,url   # 0 件なら
   glab issue list --all --search "ログイン login" --per-page 21 --page 1
   ```
3. **閲覧**: `gh issue view <N> --json number,title,state,url,body` / `glab issue view <N>` で本文を取得し、タイトル・状態・目的・受け入れ条件・スコープ外を呼び出し元に返す
4. **作成**: `assets/issue.template.md` を `wip/tmp/issue-body-<連番または slug>.md` にコピーして承認済みの内容で埋める（種別 / 概要 / 詳細 / 受け入れ条件は後で DoD に落とせる粒度の箇条書き / スコープ外 / 優先度）。GitHub は `gh issue create --title "<タイトル>" --body-file <ファイル>`、GitLab は `glab api projects/:id/issues -X POST --raw-field "title=<タイトル>" --raw-field "description=@<ファイル>"`。成功したら番号と URL を報告し、一時ファイルを削除する。失敗したらコマンドと出力を返して停止し、再試行しない（二重投稿防止）
5. **追記**: 現在の本文を取得（`gh issue view <N> --json body -q .body` / `glab api "projects/:id/issues/<iid>" | jq -r .description`）→ `wip/tmp/` のファイルに「現在の本文 + 空行 + `assets/issue-addendum.template.md` を埋めた追記セクション」を組み立てる（取得した本文のバイト列は変えない。末尾追加のみ）→ **送信直前に本文を再取得**し、組み立ての元にした本文と一致しなければ組み立て直す → GitHub は `gh issue edit <N> --body-file <ファイル>`、GitLab は `glab api "projects/:id/issues/<iid>" -X PUT --raw-field "description=@<ファイル>"`。送信後に本文を取得し「旧本文 + 追記」になっていることを確認して、番号と URL を報告し、一時ファイルを削除する
6. **報告**: 実行した操作（検索条件と件数 / 閲覧した番号 / 作成・追記した番号と URL）を、作業ログに残せる形で呼び出し元に返す

全件が必要な一覧取得（レビュー指摘の取得など）は `gh api --paginate` / `glab api --paginate` を使い、1 ページ目で打ち切らない。

## 参照

- テンプレート: `assets/issue.template.md`（新規 issue の本文）、`assets/issue-addendum.template.md`（追記セクション。区切り・日付・追記の経緯・追記内容）
- 類似 / 関連 / 無関係の判定基準と検索コマンド集: `references/issue-triage.md`（検索モードで候補を分類するときに使う。分類そのものの決定は呼び出し元）
- GitLab の長文送信（正。`glab api --raw-field key=@file`）: 仕様の同名の節。`20-common-step-feature-mr` の MR 本文と、タスクの切れ目の MR 本文更新からも参照される
- ホスト判定の利用元: `20-common-step-feature-mr`
- issue の受け入れ条件の書き方と DoD への対応: `10-task-overall-plan` の要件書
- リモート書き込みの宣言と強制: `.claude/docs/10_spec/hooks/20-PreToolUse/workflow-guard.md`

## エラー時の対処

| 状況 | 対処 |
|------|------|
| CLI 未導入・未認証 | 導入・認証の手順を返して停止する。API 直叩き・スクレイピングで代替しない |
| ホストを判別できない | ユーザーに確認する。推測で `gh` / `glab` を選ばない |
| 検索が 0 件 | closed を含めて再検索。それでも 0 件なら「該当なし」と検索語・件数を添えて返す |
| 作成・追記のコマンドが失敗した | コマンドと出力を返して停止する。再試行しない（二重投稿防止） |
| 承認前の本文で作成・追記を求められた | 実行しない。承認を呼び出し元に返す |
| 送信直前の再取得で本文が変わっていた | 送らずに組み立て直す（末尾追加を新しい本文に対して行う） |
| close / reopen・タイトル変更・コメント投稿を求められた | 範囲外として断り、呼び出し元に返す |
| フックに拒否された（宣言外の書き込み） | 迂回しない。作業中チケットの「やってよいこと」に issue の起票・追記が宣言されているか確認し、計画側に返す |
| glab のサブコマンドにファイル渡しのフラグがあると分かった | 仕様の「GitLab の長文送信」を先に更新してから移行する（SKILL.md だけ変えない） |
