---
type: spec
title: 20-common-step-feature-mr スキル 仕様
description: feature ブランチと draft MR 作成の内部仕様。default ブランチの特定と最新化、ブランチ命名、空コミット、draft MR の作成コマンドと本文テンプレート、冪等動作（既存があれば返す）を定める
tags: [spec, skill, common-step]
keywords: [feature ブランチ, draft MR, default ブランチ, 空コミット, Closes, mr-body テンプレート, 冪等, glab, gh]
---

# 20-common-step-feature-mr スキル 仕様

## 概要・禁止事項

feature ブランチと draft MR 作成の共通ステップの内部仕様。対応する要件は [00_requirement/skills/20-common-step-feature-mr.md](../../00_requirement/skills/20-common-step-feature-mr.md)。

スクリプトは持たず手順で固定する。コミットと push は `20-common-step-commit-push` の提供コマンドを使う（`git` 直接実行はフックに拒否される）。

禁止事項:

- 既存ブランチ・既存 MR の上書き（同名ブランチ・open な MR があれば作らない）
- draft でない MR の作成、`gh pr ready` 相当の draft 解除（解除は全体まとめの手順のみ）
- 未コミットの変更がある状態でのブランチ作成（扱いの確認は呼び出し元）・stash による退避
- マージコンフリクトや進行中のマージ・リベースの自動解消
- `git commit` / `git push` の直接実行（提供コマンドを使う）

## 呼出条件

- `10-task-overall-plan` の「ブランチと draft MR の作成」から、issue・ブランチ名・MR タイトルが承認済みの状態で読み込まれる
- 前提: 未コミットの変更の扱いが解消済み、マージ方式（squash）の確認済み（いずれも呼び出し元の手順）

## IN / OUT

| IN | OUT |
|----|----|
| issue 番号、承認済みのブランチ名（`feature-<N>-<slug>` / `fix-<N>-<slug>`）、承認済みの MR タイトル | 作成されたブランチ名、draft MR の番号と URL（既存 MR があった場合はその番号と URL） |

## IN / OUT サンプル

```bash
git fetch origin
git checkout -b feature-12-login-validation origin/main
bash .claude/skills/20-common-step-commit-push/scripts/commit.sh -m "chore: #12 login-validation の作業を開始" wip/10_tickets/10_doing/0001-overall-plan.md
bash .claude/skills/20-common-step-commit-push/scripts/push.sh
gh pr create --draft --title "feat: ログイン検証の不備 (#12)" --body-file wip/tmp/mr-body.md
# => https://github.com/<owner>/<repo>/pull/13 （番号と URL を呼び出し元に返す）
```

## 処理フロー

1. **ホスト判定と前提確認**: `20-common-step-issue` 仕様の手順 1 と同じ判定で CLI を選ぶ。`git status --porcelain` の出力から `wip/` 配下の未追跡ファイル（全体計画チケットなど、開始コミットに載せる持ち越し分）を除いた残りが空でなければ、停止して呼び出し元に返す（確認手順は呼び出し元）。`.git/MERGE_HEAD`・`rebase-merge/` 等が存在する（マージ・リベース途中）、origin が無い・複数リモートで push 先が曖昧、のときも停止して状態を返す
2. **default ブランチの特定と最新化**: `gh repo view --json defaultBranchRef` / `glab repo view`（取れなければ `git remote show origin` の HEAD branch）。`git fetch origin` で最新を取得する
3. **ブランチ作成**: 同名ブランチが既にあれば作らず、別の slug 案を添えて呼び出し元に返す。無ければ `git checkout -b <ブランチ名> origin/<default>` で作成する（ローカル default の状態に依存しない）
4. **開始コミット**: 持ち越した作業中チケットの「差分の基準点」を作成元コミット（`origin/<default>` の SHA）に書き換えてから（default 上で記録した HEAD が作成元と異なる場合の差分検知の誤検知を防ぐ）、持ち越した `wip/` 配下の未追跡ファイル（全体計画チケット等）を `commit.sh -m "chore: #<N> <slug> の作業を開始" wip/...` でコミットする（コミットを保留した全体計画チケットの記録がここで feature ブランチに載る — `20-common-step-ticket` 仕様）。載せるファイルが無い場合のみ `--allow-empty` で空コミットを作る。続けて `push.sh` で push する（上流設定はコマンドが行う）
5. **draft MR の作成**: 現在ブランチに open な MR が既にあるか確認し（`gh pr view --json number,url,state` / `glab mr list --source-branch <ブランチ> --per-page 20`）、あればその番号と URL を返して終える。無ければテンプレートから本文を `wip/tmp/mr-body.md` に作り、GitHub は `gh pr create --draft --title <タイトル> --body-file ...`、GitLab は `glab mr create --draft --title ... --description "$(cat wip/tmp/mr-body.md)"` で作成する（glab に本文のファイル渡しフラグが無いため。作成時の本文は短いテンプレート骨格なので文字列渡しを許す。以後の本文更新は長くなるため `20-common-step-issue` 仕様「GitLab の長文送信」の API 経由で行う）。失敗したらコマンドと出力を返して停止し、別の手段で再試行しない
6. **報告**: ブランチ名・MR の番号と URL を呼び出し元に返し、一時ファイルを削除する

## OUT ひな形

`assets/mr-body.template.md`:

| 節 | 内容 |
|----|------|
| 概要 | issue の要約（1〜3 行） |
| 変更点 | タスクの切れ目ごとに要約が積み上がる箇条書き（作成時は空の見出しのみ） |
| 動作確認 | チェックリスト（作成時は「MR 上のレビュー完了」のみ） |
| 関連 Issue | `- Closes #<N>`（GitLab では `Closes #<N>`。マージで issue が閉じる形式） |

- ブランチ名の規約: `feature-<issue番号>-<slug>` / 不具合修正は `fix-<issue番号>-<slug>`。slug は英小文字・数字・ハイフンで 2〜4 語。区切りはすべてハイフン（スラッシュ不可）
- MR タイトルの規約: `<prefix>: <issue タイトル> (#<N>)`（prefix はコミットと同じ一覧）

## 参照ナレッジ

- ホスト判定: `10_spec/skills/20-common-step-issue.md` 手順 1（正）
- 空コミット・push: `10_spec/skills/20-common-step-commit-push.md`（`--allow-empty` が許される唯一の場面）
- ブランチ名・MR タイトルの承認: `10-task-overall-plan` の承認ポイント（呼び出し元）

## Script 処理

なし。git / CLI の単発呼び出しの列で、状態はブランチと MR 自体が持つため（冪等性は手順 3・5 の存在確認で実現）。

## 要件との対応

| 要件（受け入れ基準） | 実現箇所 |
|--------------------|---------|
| メイン: ホスト判定・判定不能時は確認 | 処理フロー 1（issue 仕様の参照） |
| メイン: default の特定と最新化・命名規約・承認済みの名前 | 処理フロー 2・3、OUT ひな形（規約） |
| メイン: 開始コミット（持ち越し分を載せ、無ければ空コミット。許可場面はここ） | 処理フロー 4 |
| メイン: テンプレート本文・Closes 形式・必ず draft | 処理フロー 5、OUT ひな形 |
| メイン: ブランチ名・番号・URL を返す | 処理フロー 6 |
| 代替: 同名ブランチは上書きせず別 slug 提案 | 処理フロー 3 |
| 代替: 既存の open MR があればそれを返す（1 ブランチ = 1 MR） | 処理フロー 5 |
| 例外: CLI 未導入・未認証は停止 | 処理フロー 1 |
| 例外: 未コミットの変更があれば作らない | 処理フロー 1・禁止事項 |
| 例外: 最新化・衝突の解消が要る状態は自動で解消しない | 処理フロー 1（マージ・リベース途中の検出）・禁止事項 |
| 例外: MR 作成失敗は停止・再試行しない | 処理フロー 5 |
| 例外: 安全に進められない状態（追跡切れ・複数リモート・保護ブランチ） | 処理フロー 1（停止して状態を返す）、push 拒否は commit-push の CP006 |
| 整合: push と空コミットは commit-push に従う | 処理フロー 4、参照ナレッジ |
| 整合: 宣言が前提 | 呼出条件 |
| 整合: 手順の再掲禁止 | 参照ナレッジ |
