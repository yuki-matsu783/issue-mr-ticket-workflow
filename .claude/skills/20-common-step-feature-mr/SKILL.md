---
name: 20-common-step-feature-mr
description: >
  承認済みの issue 番号・ブランチ名・MR タイトルから、default ブランチを最新化して feature ブランチを切り、持ち越した
  wip/ の未追跡ファイル（無ければ空コミット）を開始コミットとして commit.sh / push.sh で積み、テンプレート本文の
  draft MR（PR）を gh / glab で作る共通ステップ。同名ブランチ・open な MR があれば作り直さず既存を返す。
  Use when 10-task-overall-plan reaches "ブランチと draft MR の作成" with an approved issue, branch name and MR title
  ("ブランチを切って", "draft PR を作って"), or when resuming and the branch / MR may already exist.
---

# 20-common-step-feature-mr — ブランチと draft MR を 1 回だけ作る

スクリプトは持たず、git / CLI の単発呼び出しの列で進める。コミットと push は `20-common-step-commit-push` の提供コマンドを使う（`git commit` / `git push` の直接実行はフックが拒否する）。既存ブランチ・既存 MR を上書きしない。draft でない MR を作らず、draft の解除（`gh pr ready` 相当）はここでは行わない（全体まとめの手順のみ）。未コミットの変更がある状態でブランチを作らず、stash で退避もしない。マージ・リベースの途中状態や衝突を自動で解消しない。

- 要件: `.claude/docs/00_requirement/skills/20-common-step-feature-mr.md`
- 仕様（正。処理フロー・命名規約・MR 本文の節・eval ID FM-E01〜03）: `.claude/docs/10_spec/skills/20-common-step-feature-mr.md`

## 手順

IN: issue 番号 `<N>`、承認済みのブランチ名（`feature-<N>-<slug>` / 不具合修正は `fix-<N>-<slug>`。slug は英小文字・数字・ハイフンで 2〜4 語、区切りはすべてハイフン）、承認済みの MR タイトル（`<prefix>: <issue タイトル> (#<N>)`。prefix はコミットと同じ一覧）。

1. **ホスト判定と前提確認**: `20-common-step-issue` の手順 1 と同じ判定で CLI（`gh` / `glab`）を選び、認証を確認する。`git status --porcelain` から `wip/` 配下の未追跡ファイル（持ち越す全体計画チケット等）を除いた残りが空でなければ停止して呼び出し元に返す（扱いの確認は呼び出し元）。`.git/MERGE_HEAD` / `.git/rebase-merge` / `.git/rebase-apply` があれば進行中として停止する。リモートが複数・追跡切れなど安全に進められない状態も状態を添えて返す
2. **default ブランチの特定と最新化**: `gh repo view --json defaultBranchRef -q .defaultBranchRef.name` / `glab repo view`（取れなければ `git remote show origin` の HEAD branch）。`git fetch origin`
3. **ブランチ作成**: `git branch --list <ブランチ名>` と `git ls-remote --heads origin <ブランチ名>` で同名が既にあれば作らず、別の slug 案を添えて呼び出し元に返す。無ければ `git checkout -b <ブランチ名> origin/<default>`（ローカル default の状態に依存しない）
4. **開始コミット**: 持ち越した作業中チケットの `base_sha` を作成元コミット（`git rev-parse --short origin/<default>`）に書き換えてから、持ち越した `wip/` 配下の未追跡ファイルを `bash .claude/skills/20-common-step-commit-push/scripts/commit.sh -m "chore: #<N> <slug> の作業を開始" <パス>...` でコミットする。持ち越し分が無ければ `commit.sh --allow-empty -m "chore: #<N> <slug> の作業を開始"`（空コミットが許される唯一の場面）。続けて `bash .claude/skills/20-common-step-commit-push/scripts/push.sh`（上流は自動で設定される）
5. **draft MR の作成**: 現在ブランチに open な MR が既にあるか確認し（`gh pr view --json number,url,state` / `glab mr list --source-branch <ブランチ名> --per-page 20`）、あればその番号と URL を返して終える。無ければ `assets/mr-body.template.md` を `wip/tmp/mr-body.md` にコピーして埋め（概要 / 変更点は空の見出し / 動作確認は「MR 上のレビュー完了」のみ / `- Closes #<N>`）、GitHub は `gh pr create --draft --title "<タイトル>" --body-file wip/tmp/mr-body.md`、GitLab は `glab api projects/:id/merge_requests -X POST --raw-field "source_branch=<ブランチ名>" --raw-field "target_branch=<default>" --raw-field "title=Draft: <タイトル>" --raw-field "description=@wip/tmp/mr-body.md"`（長文送信の正は `20-common-step-issue` 仕様「GitLab の長文送信」）。失敗したらコマンドと出力を返して停止し、再試行しない
6. **報告**: ブランチ名・MR の番号と URL（既存を再利用した場合はその旨）を呼び出し元に返し、`wip/tmp/mr-body.md` を削除する

## 参照

- テンプレート: `assets/mr-body.template.md`（概要 / 変更点 / 動作確認 / 関連 Issue。変更点はタスクの切れ目ごとに要約が積み上がる）
- ホスト判定・GitLab の長文送信（正）: `20-common-step-issue`（仕様の手順 1 と「GitLab の長文送信」）
- 開始コミット・空コミット・push: `20-common-step-commit-push`（`--allow-empty` が許される唯一の場面がここ）
- ブランチ名・MR タイトルの承認: `10-task-overall-plan` の承認ポイント（呼び出し元）
- MR 本文のその後の更新（タスクの切れ目）と draft 解除: `00-workflow-issue-mr-driven` / `10-task-overall-summary`

## エラー時の対処

| 状況 | 対処 |
|------|------|
| CLI 未導入・未認証 | 導入・`gh auth login` / `glab auth login` の手順を返して停止する。Web API を直接叩かない |
| origin が GitHub でも GitLab でもない | 対象外として報告して停止する。推測で CLI を選ばない |
| 未コミットの変更がある（`wip/` の持ち越し分を除く） | 作らない。一覧を添えて呼び出し元に返す（stash・破棄をしない） |
| マージ・リベースの途中 / 追跡切れ / 複数リモート / 保護ブランチ | 自動で解消しない。状態を返して停止する |
| 同名ブランチが既にある | 上書きしない。別の slug 案（`feature-<N>-<別 slug>`）を添えて返す |
| 現在ブランチに open な MR が既にある | 作らず、その番号と URL を返す（1 ブランチ = 1 MR） |
| `commit.sh` が `CPxxx:` / `push.sh` が `CP005:` `CP006:` | `20-common-step-commit-push` の表に従う。push のリモート拒否は force しない |
| MR 作成コマンドが失敗した | コマンドと出力を返して停止する。再試行・別コマンドでの代替をしない |
