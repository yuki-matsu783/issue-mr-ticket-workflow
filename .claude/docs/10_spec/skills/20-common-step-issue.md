---
type: spec
title: 20-common-step-issue スキル 仕様
description: issue の検索・閲覧・作成・追記の内部仕様。ホスト判定（glab / gh）の手順、CLI コマンドの組み立て、本文テンプレート、末尾追記の実現方法を定める。スクリプトは持たず手順で固定する
tags: [spec, skill, common-step]
keywords: [issue, glab, gh, ホスト判定, 検索, 閲覧, 作成, 末尾追記, body-file, テンプレート]
---

# 20-common-step-issue スキル 仕様

## 概要・禁止事項

issue 操作の共通ステップの内部仕様。対応する要件は [00_requirement/skills/20-common-step-issue.md](../../00_requirement/skills/20-common-step-issue.md)。

スクリプトは持たず、CLI コマンドの組み立てを処理フローの手順で固定する（操作が単発の CLI 呼び出しで、検査すべき内部状態を持たないため）。**ホスト判定の手順はこの仕様が正**で、`20-common-step-feature-mr` からも参照される。

禁止事項:

- issue の状態変更（close / reopen）・タイトル変更・既存記述の書き換え・削除
- コメントの投稿（作業中の issue へは一切書き込まない）
- 承認されていない本文での作成・追記
- CLI が使えないときの Web への直接リクエスト（API 直叩き・スクレイピング）
- 長い本文のコマンドライン引数への直接埋め込み（必ずファイル経由）

## 呼出条件

- `10-task-overall-plan`（issue の確定: 検索・閲覧・作成・追記）
- `10-task-feedback-plan`・`10-task-overall-summary`（別 issue の起票）
- 書き込み操作は、作業中チケットの「やってよいこと」に issue の起票・追記が宣言されていることが前提（宣言外はフックが拒否する）

## IN / OUT

| 操作 | IN | OUT |
|------|----|----|
| ホスト判定 | なし（origin の URL） | 使う CLI（`glab` / `gh`）。判定不能なら確認の質問 |
| 検索 | キーワード（日本語 + 英語） | 番号・タイトル・状態・URL の表、使った検索語と件数 |
| 閲覧 | issue 番号または URL | 本文（タイトル・状態・目的・受け入れ条件・スコープ外） |
| 作成 | 承認済みのタイトルと本文（`wip/tmp/` のファイル） | 作成された issue の番号と URL |
| 追記 | issue 番号、承認済みの追記内容 | 更新された issue の番号と URL（既存本文は不変） |

## IN / OUT サンプル

```bash
# ホスト判定
git remote get-url origin   # => https://github.com/... → gh / https://gitlab.com/... → glab

# 検索（1 ページ目だけを取得して判定する）
gh issue list --state open --search "ログイン login" --limit 21 --json number,title,state,url
glab issue list --search "ログイン login" --per-page 21 --page 1
# 0 件なら closed を含めて再検索
gh issue list --state all --search "ログイン login" --limit 21 --json number,title,state,url
glab issue list --all --search "ログイン login" --per-page 21 --page 1

# 作成（本文はファイル経由。glab はサブコマンドに本文のファイル渡しが無いため API 経由）
gh issue create --title "ログイン検証の不備" --body-file wip/tmp/issue-body.md
glab api projects/:id/issues -X POST --raw-field "title=ログイン検証の不備" --raw-field "description=@wip/tmp/issue-body.md"
# => https://github.com/<owner>/<repo>/issues/34 （番号と URL を報告し、一時ファイルを消す）
```

## 処理フロー

1. **ホスト判定**: `git remote get-url origin` の URL に `gitlab` を含めば `glab`、`github` を含めば `gh`。どちらでもない（セルフホスト等で判別不能）ならユーザーに確認し、推測で選ばない。CLI の導入・認証（`gh auth status` / `glab auth status`）が通らなければ導入手順を返して停止する
2. **検索**: open を対象にキーワード（日本語と英語の両方を空白区切りで）検索し、0 件なら closed を含めて再検索する（gh `--state all` / glab `--all`）。**取得は 1 ページ目のみ**（gh `--limit 21` / glab `--per-page 21 --page 1`。検索の絞り込みはサーバー側で行われるため、1 ページ目が 0 件なら該当なしと判定してよい）。結果は上位 20 件までの表 + 使った検索語と件数（21 件目が取得されたときだけ「20 件以上」と表現し、必要なら検索語を狭める。ページを繰らない）。番号・URL 指定があれば検索を省いて閲覧へ
3. **閲覧**: 番号で本文を取得して呼び出し元に返す（`--json number,title,state,url,body` 相当）
4. **作成**: 承認済みの本文を `wip/tmp/issue-body-<連番または slug>.md` に書き、GitHub は `gh issue create --body-file`、GitLab は下記「GitLab の長文送信」の API 経由で作成する。成功したら番号と URL を報告し、一時ファイルを削除する。失敗したらコマンドと出力を返して停止し、再試行しない（二重投稿防止）
5. **追記**: 現在の本文を取得 → `wip/tmp/` のファイルに「現在の本文 + 空行 + 区切り（`---`）+ 追記セクション」を組み立て → GitHub は `gh issue edit N --body-file`、GitLab は API 経由（PUT）で置き換える。取得した本文のバイト列は変更しない（末尾追加のみ）。**更新の送信直前に本文を再取得し**、組み立ての元にした本文と一致することを確かめてから送る（変わっていれば取得からやり直す — 他者の追記を上書きしない）。更新後にも先頭部分の一致を確認する

6. **報告**: 実行した操作（検索条件 / 番号と URL）を呼び出し元に返し、作業ログに残せる形にする

停止条件（エラー識別子は持たない。手順として停止する）: CLI 未導入・未認証 / 作成・追記の失敗 / 承認前の本文 / スコープ外の操作（状態変更・コメント）の要求。

### GitLab の長文送信（正）

glab の issue / mr 系サブコマンドは本文のファイル渡しフラグを持たない（`-d, --description` の文字列渡しのみ。glab 1.114 時点で確認）。コマンドライン引数への長文の埋め込みは禁止のため、本文は `glab api` の `--raw-field <key>=@<ファイル>` で送る（`@` はファイルから値を読む）:

- issue 作成: `glab api projects/:id/issues -X POST --raw-field "title=<タイトル>" --raw-field "description=@<ファイル>"`
- issue 本文更新（追記）: `glab api "projects/:id/issues/<iid>" -X PUT --raw-field "description=@<ファイル>"`
- `:id` は glab が現在のリポジトリに解決するプレースホルダ。実装時に glab のバージョンでフラグの有無を再確認し、ファイル渡しのフラグが追加されていればそちらへ移行してよい

この節は `20-common-step-feature-mr`（MR 本文）と、タスクの切れ目の MR 本文更新（`00-workflow-issue-mr-driven` の仕様）からも参照される。一覧取得を全件必要とする場面（レビュー指摘の取得など）では `gh api --paginate` / `glab api --paginate` を使う（1 ページ目で打ち切らない）。

## OUT ひな形

- `assets/issue.template.md`: 新規 issue の本文（種別 / 概要 / 詳細 / 受け入れ条件（後で DoD に落とせる粒度の箇条書き）/ スコープ外 / 優先度）
- `assets/issue-addendum.template.md`: 追記セクション（区切り・日付・追記の経緯・追記内容）

## 参照ナレッジ

- ホスト判定の利用元: `20-common-step-feature-mr`（この仕様の手順 1 を参照する）
- issue の受け入れ条件の書き方と DoD への対応: `10-task-overall-plan` の要件書
- リモート書き込みの宣言と強制: `hooks/20-PreToolUse/workflow-guard.md` の要件・仕様

## Script 処理

なし。単発の CLI 呼び出しのみで検査すべき内部状態を持たないため、スクリプト化しない（コマンドの組み立ては処理フローの手順が正）。将来、追記の「既存本文の不変」検査を機械化する場合はこの仕様に追加する。

### テスト観点（eval）

| eval ID | 入力（プロンプトと状況） | 期待する振る舞い | 判定方法 |
|---------|------------------------|-----------------|---------|
| IS-E01 | 検索モード（検索語あり） | open → 0 件なら closed も検索し、類似 / 関連 / 無関係に分類した表を返す | 検索の 2 段階と分類表 |
| IS-E02 | 作成モード（本文案あり） | 本文をファイル経由で渡して作成し、番号と URL を返す | 作成された issue の本文一致と報告 |
| IS-E03 | 編集モード（既存 issue に追記） | 既存本文の末尾に追記し、既存の記述を消さない。送信直前に再取得して一致を確認する | 追記後の本文が「旧本文 + 追記」であること |

## 要件との対応

| 要件（受け入れ基準） | 実現箇所 |
|--------------------|---------|
| メイン: ホスト判定・判定不能時は確認 | 処理フロー 1 |
| メイン: 検索（open→closed、表 + 検索語と件数） | 処理フロー 2 |
| メイン: 閲覧 | 処理フロー 3 |
| メイン: 承認済み本文をファイル経由で作成・番号と URL の報告 | 処理フロー 4 |
| メイン: 追記は末尾のみ・既存を消さない | 処理フロー 5（末尾追加 + 先頭一致の確認） |
| メイン: 操作の記録を呼び出し元に返す | 処理フロー 6 |
| 代替: 番号・URL 指定時は検索省略 | 処理フロー 2 |
| 代替: 結果が多いときは上位に絞る | 処理フロー 2（上位 20 件 + 条件明記） |
| 例外: CLI 未導入・未認証は停止、Web 直叩き禁止 | 処理フロー 1・禁止事項 |
| 例外: 失敗時は停止・再試行しない | 処理フロー 4 |
| 例外: 承認前の本文は実行しない | 処理フロー 4・停止条件 |
| 例外: 状態変更・コメントは範囲外 | 禁止事項・停止条件 |
| 整合: 書き込みは宣言が前提 | 呼出条件 |
| 整合: テンプレートの使用・DoD に落とせる受け入れ条件 | OUT ひな形 |
| 整合: 手順の再掲禁止 | 参照ナレッジ（呼び出し元はこの仕様を参照） |
