---
name: 00-workflow-issue-mr-driven
description: >
  ユーザーの依頼を GitHub の issue と PR（MR）に紐づけてから、チケット駆動ワークフローで実作業を進める。
  既存 issue の検索 → 類似があればそれで対応するか確認 → 人間の承認 → issue の作成/修正（20-task-gh-issue）
  → feature ブランチと draft PR の作成（20-task-gh-feature）→ チケット駆動ワークフロー、の順で進める開発の振り分け。
  00-workflow-quick-request と対になる 2 つの振り分けの一方で、振る舞いが変わる変更（機能追加・バグ修正・リファクタリング）、
  複数モジュールや 4 ファイル以上に及ぶ変更、GitHub に経緯を残したい作業はこちら。
  質問・説明・typo 修正など振る舞いを変えない軽作業は 00-workflow-quick-request を使う。
  Use when the user mentions "issue 駆動で", "issue-MR 駆動", "MR 駆動", "PR 駆動", "issue から作業",
  "issue にしてから進めて", "issue-driven", "#12 をやって", or asks to start development work that
  should be tracked as a GitHub issue and pull request before any code is touched.
---

# 00-workflow-issue-mr-driven — issue と PR に紐づけてから作業する

依頼を受けたら**コードに触る前に** issue を確定し、issue に紐づく feature ブランチと draft PR を作り、その上でチケット駆動ワークフローを実施する。
このスキルは**順序と承認ポイントを司るオーケストレータ**であり、個々の操作は既存スキルに委譲する。

- 要件: `.claude/docs/00_requirement/skills/00-workflow-issue-mr-driven.md`
- 仕様（承認ポイント・命名規約・委譲内容の正）: `.claude/docs/10_spec/skills/00-workflow-issue-mr-driven.md`
- 振り分け実施済み判定の仕様（WF101 フックの正。`00-workflow-quick-request` と共有するメタ文書）: `.claude/docs/10_spec/ワークフロー振り分け実施済み判定.md`
- 類似 issue の判定基準と `gh` コマンド集: `references/issue-triage.md`
- 対になる振り分け: `00-workflow-quick-request`（issue / PR を作るまでもない軽作業。判定表は同スキルの手順 0 が正。依頼が軽作業に該当すると分かったら、そちらを Skill ツールで読み込んで切り替える）

```
依頼 ─→ 既存 issue を検索 ─┬─ 類似あり ─→ 承認①「#N で対応する？」─→ 追記案 ─→ 承認② ─→ 20-task-gh-issue（編集）─┐
                           └─ 類似なし ─→ 承認①「新規で作る？」  ─→ 本文案 ─→ 承認② ─→ 20-task-gh-issue（作成）─┤
                                                                                                          ▼
                                                                 20-task-gh-feature（ブランチ + draft PR）─→ 10-work-overall-plan（全体計画・最初の計画チケット）
                                                                                                          │
   ┌──────────────────────────────── ワークループ（チケット type ごとに繰り返す）────────────────────────────┘
   │  10-work-<phase>-plan / 10-work-<phase>-exec（1 ワーク実施）─→ push ─→ PR 本文更新 ─→ work-boundary.sh request ─→ 応答を終える
   │        ▲                                                                                    │
   │        └── 指摘あり: 同 type の追加チケット ◄── work-boundary.sh complete ◄── 承認④「レビュー完了」の連絡
   │                                                指摘なし: 次のワークへ ──────────────────────────┐
   └────────────────────────────────────────────────────────────────────────────────────────────────┘
                                                                                                          ▼
   完了処理: PR 本文の最終整形 ─→ 承認③ ─→ merge-prep.sh reset-wip ─→ check-conflicts ─(衝突あり: 承認⑤ → merge → 再実行)─┐
                                                                                                                    ▼
                                              停止（マージは人間） ◄── merge-prep.sh ready ◄── notify-issue ◄── 承認⑥（本文）┘
```

## 役割分担

| 担当 | やること | 呼び出し方 |
|------|---------|-----------|
| このスキル | 依頼の整理、候補の提示、承認の取得、各スキルへの引き継ぎ、完了処理 | — |
| `20-task-gh-issue` | issue の検索・作成・編集 | 「検索モード」「作成モード」「編集モード」を指定して手順に従う |
| `20-task-gh-feature` | feature ブランチの作成・push・draft PR の作成 | 「issue 連携モード」を指定して手順に従う |
| `10-work-overall-plan` | ワークループの初回。フェーズ列を決めて全体計画を書き、最初の計画チケットを起こす | issue / PR の文脈（番号・URL・受け入れ条件）を渡して実施する |
| `10-work-<phase>-plan` / `10-work-<phase>-exec` | 各フェーズ（調査 / 設計 / 実装・テスト / 設計反映 / AI アセット設計 / AI アセット実装）の計画と実施。1 つのワーク（チケット type）が完了するたびに制御を返す | `work-boundary.sh status` の `todo_head_type` から選ぶ（`<phase>-plan` → `10-work-<phase>-plan`、`<phase>` → `10-work-<phase>-exec`。対応表は `.claude/docs/10_spec/フェーズ別ワークスキル.md`） |
| `10-work-ticket-driven` | チケット運用の仕組み（着手・完了・境界判定・フックのブロック時の対処）、振り返り（`retrospective`）、レビュー指摘の追加チケット作成 | フェーズ別ワークスキルから手順番号で参照される。`todo_head_type` が `retrospective` のときと追加チケット作成時に直接使う |
| `work-boundary.sh` | ワーク境界の判定（`status`）、レビュー依頼（`request`）、レビュー完了の確認（`complete`）、インライン返信（`reply`）。レビュー状態ファイルを書き換える唯一の経路 | `bash .claude/hooks/work-boundary.sh <subcommand>` |
| `merge-prep.sh` | 完了処理のマージ前作業: wip のリセット（`reset-wip`）、default ブランチとの衝突判定（`check-conflicts`）、関連 issue へのコメント（`notify-issue`）、draft 解除（`ready`）。状態 `wip/merge-prep.json` を書き換える唯一の経路で、`ready` は先行ステップの記録と再検証を通ったときだけ `gh pr ready` を実行する | `bash .claude/hooks/merge-prep.sh <subcommand>` |

**GitHub 操作（`gh`、`git push`）はチケット作業の外でのみ行う**。`wip/10_tickets/10_doing/` にチケットがある間はフックが WF003 でブロックする。迂回しない。**状態ファイル（`wip/10_tickets/review-state.json`、`wip/merge-prep.json`）を Edit / Write / Bash で直接書き換えない**（フックが WF012 で拒否する）。レビューが完了していないのに次のワークへ着手する操作はフックが WF011 で拒否する。**`gh pr ready` を直接実行しない**（フックが WF015 で拒否する。draft の解除は `merge-prep.sh ready` 経由のみ）。**PR のマージは行わない**（`gh pr merge` は手順に含まれない。人間が行う）。

## 承認ポイント（人間の判断が必要な場所）

| # | タイミング | 確認内容 |
|---|-----------|---------|
| ① | 候補提示のあと | どの issue で対応するか（既存 #N / 新規作成 / 別の候補 / 依頼を分割） |
| ② | issue の本文案・追記案のあと | issue に書く内容。あわせてブランチ名と PR タイトル |
| ③ | 全チケット完了・PR 本文の最終更新のあと | マージ前作業（wip リセット → コンフリクト確認 → issue コメント → draft 解除）に進むか。承認されれば `merge-prep.sh ready` まで進む（ready 自体を改めて確認しない） |
| ④ | 各ワーク（チケット type）完了・push のあと | PR 上のレビュー。レビュー完了の連絡を受け、`work-boundary.sh complete` が通るまで次のワークに進まない（type の数だけ発生） |
| ⑤ | `check-conflicts` が衝突を検知したとき | 衝突ファイルを示し、default ブランチを取り込んで解消してよいか。解消方針が一意に決まらない衝突は両側の意図を要約して判断を仰ぐ |
| ⑥ | issue コメントの投稿前 | 通知先の issue 番号と**本文そのもの**（「投稿してよいか」だけを聞かない）。他人の issue への投稿は取り消せない外部への副作用のため |

①②③⑤⑥は `AskUserQuestion` で選択肢として提示する（「Other」で修正を受け取れる）。**承認を得るまで issue の変更・ブランチ作成・実作業・マージ前作業・issue への投稿に進まない**。ヘッドレス実行では⑤⑥の応答が得られないため、衝突内容または本文案を報告して停止する。

④は **`AskUserQuestion` で待たない**。`request` でレビューを依頼したらチャットで報告して応答を終え、次のユーザー発言（「レビュー完了」等）で再開する。人間が GitHub 上でレビューする時間は 1 ターンに収まらず、ヘッドレス実行では `AskUserQuestion` の応答が得られないためである。取得した指摘への対応要否の確認には `AskUserQuestion` を使ってよい。

## 手順 0: 状態確認（再開判定）

```bash
gh auth status
git branch --show-current
git status --short
gh pr view --json number,url,isDraft,state,body 2>/dev/null
ls wip/10_tickets/00_todo/ wip/10_tickets/10_doing/ wip/10_tickets/20_done/ 2>/dev/null
```

- `gh` が未導入・未認証 → `20-task-gh-install` スキルまたは `gh auth login` を案内して停止する
- **現在ブランチに open な PR があり、`wip/10_tickets/` に todo / doing のチケットがある** → 再開。手順 1〜4 を飛ばし、PR 本文の `Closes #N` から issue 番号を控えて手順 5 に進む。手順 5 に入る前に `bash .claude/hooks/work-boundary.sh status` を実行し、`at_boundary` と `review_state` で「ワークの途中」「レビュー依頼前」「レビュー待ち（`requested`）」「レビュー済み（`completed`）」のどこにいるかを確定する。`requested` ならレビュー完了の連絡を受けていない限り `complete` を実行せず、応答を終える
- 未コミットの変更がある → 下記「未コミットの変更があるとき」に従い、**必ずユーザーに確認する**
- ユーザーが `#N` を指定している → `gh issue view N --json number,title,state,url,body` で内容を取得し、手順 2 を飛ばして「既存 #N で対応」として手順 3A に進む

### 未コミットの変更があるとき

`git status --short` が空でなければ、手順 4（ブランチ作成）は進められない。**自分で判断して stash・コミット・破棄をしない**。変更内容（ファイル一覧と要約）を示した上で、`AskUserQuestion` で扱いを確認する:

| 選択肢 | その後の動き |
|--------|-------------|
| 今の変更をコミットしてから進む | ユーザーと合意したメッセージで現在のブランチにコミットし、手順 1 へ |
| stash に退避して進む | `git stash push -m "<依頼の要約>"` で退避し、手順 1 へ。完了報告で stash が残っていることを伝える |
| 変更を破棄して進む | ユーザーが明示的に選んだ場合のみ `git checkout -- <path>` / 未追跡ファイルの削除を行い、手順 1 へ |
| いったん中断する | 何もせず停止する |

確認は手順 0 の時点で行う（issue の検索・承認を済ませた後にブランチを切れないと分かる、という手戻りを避けるため）。issue の検索や案の作成だけなら未コミットの変更があっても進められるが、手順 4 に入る前に必ず解消されていること。

## 手順 1: 依頼の整理

依頼文から以下を抽出する。曖昧な点は**まとめて 1 回**だけ質問する。

| 項目 | 内容 |
|------|------|
| summary | 1〜2 行の要約 |
| kind | バグ / 機能追加 / タスク / 改善・最適化 / 質問 / その他（issue テンプレートの種別） |
| keywords | 検索語。日本語と英語の両方（例: `ログイン`, `login`, `validation`） |
| acceptance | 受け入れ条件。何ができたら完了か（後でチケットの DoD になる） |
| out_of_scope | 今回やらないこと |

依頼が独立した複数の問題を含む場合は、issue 1 件ずつに分割する案を提示し、ユーザーが選んだ 1 件で進める（1 issue = 1 PR = 1 ワークフロー）。

### 振り返りからの切り替え

次のいずれかで「issue を作って 00-workflow-issue-mr-driven で進める」と合意し、その場でこのスキルが読み込まれた場合は、依頼文からの抽出をやり直さない。

- `00-workflow-quick-request` 手順 5-3
- `10-work-ticket-driven` の retrospective チケットの振り返り合意（完了処理が終わった後。仕様: `.claude/docs/10_spec/10-work-ticket-driven.md`「retrospective の棚卸しと合意」）

- 引き継ぐ項目（切り替え元と項目名を一致させる）: `summary` / `acceptance` / `kind`（改善・最適化、または新規作成ならタスク）/ フェーズ列（AI アセットの標準: 調査 → AI アセット設計 → AI アセット実装 → 振り返り。`10-work-overall-plan` が全体計画に書く）
- 省略できる: 依頼の要約に関する曖昧点の質問（上記が既に確定しているため、まとめて 1 回質問するステップは不要）
- 省略できない: 手順 0 の未コミットの変更の確認、承認①②③④はすべてこの手順で改めて取る（切り替え元の合意は「このルートに進むこと」の合意であり、issue の内容や PR の承認ではない）
- `keywords` は切り替え元から渡されないため、`summary` から自分で組み立てて手順 2（既存 issue の検索）に使う

## 手順 2: 既存 issue の検索（20-task-gh-issue 検索モード）

`20-task-gh-issue` スキルの検索モードに従い、open issue を keywords で検索する。0 件なら `--state all` で closed も含めて再検索する。

```bash
gh issue list --state open --search "<keywords>" --limit 20 --json number,title,state,labels,url,body
```

候補を `references/issue-triage.md` の基準で **類似 / 関連 / 無関係** に分類し、類似と関連だけを表で提示する:

```
| # | タイトル | 状態 | 一致点 | 判定 |
|---|---------|------|--------|------|
| 12 | ログイン画面のバリデーション | open | ログイン / バリデーション | 類似 |
```

類似が 0 件なら「類似する issue は見つからなかった」と、検索した語と件数を添えて報告する。

## 手順 3: 承認① と issue の確定

### 承認①: どの issue で対応するか

`AskUserQuestion` で確認する。

- 類似あり: 「既存 #N で対応する」「新規 issue を作る」「別の候補を見る」
- 類似なし: 「新規 issue を作る」「既存 issue を指定する」
- 候補が closed のみ: 「#N を再オープンして対応する」を選択肢に加える（再オープンは承認後に `gh issue reopen N`）

### 3A: 既存 issue で対応する場合

1. `gh issue view N --json body -q .body` で現在の本文を取得する
2. `assets/issue-addendum.template.md` を Read し、手順 1 の内容で埋めた**追記セクション**を作る
3. 追記案・ブランチ名・PR タイトル（命名規約は下記）をユーザーに提示し、**承認②**を得る
4. `20-task-gh-issue` スキルの**編集モード**に従い、既存本文の**末尾に追記**する。既存の記述は消さない・書き換えない

### 3B: 新規 issue を作る場合

1. `20-task-gh-issue` スキルの `assets/issue.template.md` を Read し、手順 1 の内容で本文案を作る（種別・概要・詳細・受け入れ条件・優先度）
2. タイトル・本文案・ブランチ名・PR タイトルをユーザーに提示し、**承認②**を得る。修正があれば反映してから進む
3. `20-task-gh-issue` スキルの**作成モード**に従い issue を作成する。作成後に修正を頼まれたら編集モードで反映する

### 命名規約（承認②で提示する案）

| 対象 | 規約 | 例 |
|------|------|-----|
| ブランチ | `<prefix>-<N>-<slug>`（区切りはすべてハイフン。スラッシュは使わない）。バグは `fix`、それ以外は `feature`。slug は英小文字・数字・ハイフンで 2〜4 語 | `fix-12-login-empty-password` |
| PR タイトル | `<prefix>: <issue タイトル> (#<N>)`。prefix は `feat` / `fix` / `chore` / `docs` / `refactor` | `fix: 空パスワードで送信できる (#12)` |

## 手順 4: feature ブランチと draft PR の作成（20-task-gh-feature issue 連携モード）

`20-task-gh-feature` スキルの **issue 連携モード**に従う。要点:

1. デフォルトブランチを取得して最新化する（承認②で合意済みならベースの再確認は不要）
2. `git checkout -b <branch> <default>` でブランチを作成する
3. PR に差分が必要なため、空コミットを作る: `git commit --allow-empty -m "chore: start #N <slug>"`
4. `git push -u origin <branch>`
5. `20-task-gh-feature` の `assets/pr.template.md` を土台に、`## 関連 Issue` に `- Closes #N` を書いた本文で **draft PR** を作成する

作成した PR の番号と URL を控え、ユーザーに報告する。

## 手順 5: チケット駆動ワークフロー（ワークループ）

**初回は `10-work-overall-plan`** を Skill ツールで読み込んで実施し、全体計画（フェーズ列）の作成と最初の計画チケットの起票まで進める。これが最初のワークであり、完了時にワーク境界（全体計画のレビュー）が発生する。引き継ぐ文脈:

- 全体計画の冒頭に `- 対象 issue: #N <url>` と `- PR: #M <url>` を書く
- issue の受け入れ条件（acceptance）を、全体計画の「受け入れ条件との対応」に書き、各計画ワークが実施チケットの DoD に落とす。振り返りチケットの確認項目にも使う
- 結果報告（`wip/30_reports/`）の「対象 issue」「PR」欄を埋める
- 対象が AI アセット（フック・スキル・ルール・エージェント・設定）の場合、フェーズ列の標準は 調査 → AI アセット設計（`.claude/docs/` の要件・仕様）→ AI アセット実装（フック・スキル・settings.json）→ 振り返り。ソフトウェア変更は 調査 → 設計 → 実装・テスト → 設計反映 → 振り返り。省略は全体計画に理由を書く（`10-work-overall-plan` 手順 4-2）。振り返りからの切り替え（上記）で引き継いだフェーズ列もこれに従う
- チケットは全件を最初に作らない。各計画ワークが「同フェーズの実施チケット群 + 次の計画チケット」を連鎖的に起こす（仕様: `.claude/docs/10_spec/フェーズ別ワークスキル.md`「ワークの連鎖規則」）

以降、todo と doing が両方空になるまで次を繰り返す。1 回のループが 1 ワーク（同じ type のチケット群）に対応する。

| # | やること | 補足 |
|---|---------|------|
| 5-1 | `bash .claude/hooks/work-boundary.sh status` の `todo_head_type` から次のスキルを選び、Skill ツールで読み込んで実施する: `overall-plan` → `10-work-overall-plan`、`<phase>-plan` → `10-work-<phase>-plan`、`<phase>` → `10-work-<phase>-exec`、`retrospective` → `10-work-ticket-driven`（手順 4 の retrospective）、null → ループ終了（手順 6 へ）。1 つのワークが完了すると、完了報告とともに制御が戻る | 境界かどうかは同コマンドの `at_boundary` で確認する。目視で type を比べない。`todo_head_type` に対応するスキルが無ければ type 定義とスキルの不整合として報告して停止する |
| 5-2 | `git push` | doing が空なのでフックは働かない |
| 5-3 | PR 本文を更新する: `20-task-gh-feature` の `assets/pr.template.md` の「変更点」に完了したワークの要約を追記し、Write で一時ファイルに書いて `gh pr edit M --body-file <path>` | 各ワークの要約が積み上がる形にする |
| 5-4 | レビューを依頼する: レビュー観点を書いた一時ファイルを用意し、`bash .claude/hooks/work-boundary.sh request --body-file <path>` を実行する | スクリプトが `gh pr comment` を投稿し、レビュー状態を `requested` にしてコミット・push する。`gh pr comment` を直接叩かない。前提未充足（未コミット・未 push・PR なし・境界でない）は WF013 で止まるので、条件を解消してから再実行する |
| 5-5 | チャットで「ワーク X を push しレビューを依頼した。完了したら知らせてほしい」と報告し、**応答を終える**（承認④の待機） | `AskUserQuestion` で待たない |
| 5-6 | レビュー完了の連絡（次のユーザー発言）を受けたら `bash .claude/hooks/work-boundary.sh complete` を実行する | スクリプトがコメント・レビューを取得し、`CHANGES_REQUESTED` または返信の無いインラインスレッドがあれば WF014 で止まる。通れば `completed` にしてコミットし、`request` 以降の指摘（自分の投稿を除く）を JSON で返す |
| 5-7 | 返された指摘が 0 件なら、そのまま次のワークへ（5-1）。1 件以上なら内容を提示し、対応要否を `AskUserQuestion` で確認する。インラインスレッドへの返信は `bash .claude/hooks/work-boundary.sh reply <id> "<対応内容>"` | 対応要否の判断は人間に残す。スクリプトは「取得した」ことを保証するだけ |
| 5-8 | 対応が必要なら、`10-work-ticket-driven` 手順 2 の要領で**同じ type の追加チケット**（指摘内容を DoD に落とす）を todo に作り、5-1 に戻る（計画ワークの差し戻しなら計画 type、実施ワークなら実施 type の追加チケット）。追加チケットが done になると境界の状態は失効するので、再度 5-2〜5-6 を回す | done 済みチケットを doing に戻さない。同じ type の追加チケットは `completed` でなくても着手できる（フックが例外として許可する）。計画ワークが次の計画チケットを起こし忘れていた場合は、追加チケットではなく次の計画チケットを直接 todo に起こす |

WF014 で `complete` が止まった場合（`CHANGES_REQUESTED` のまま／未返信スレッドあり）は、理由を報告して指摘対応（5-7・5-8）に進む。レビュアーが approve / dismiss しない限り状態は進まないので、状態ファイルを直して通そうとしない。

ワークの途中（同じ type のチケットが todo に残っている）でも、done コミット直後なら `git push` してよい（PR に進捗が反映される）。レビュー依頼はワーク境界でのみ行う。

## 手順 6: 完了処理（全ワーク done 後）

ループを抜けた時点で push とレビュー（最後のワークの `complete`）は済んでいる。ここからマージ前作業を `merge-prep.sh` で順に実行し、記録と再検証を通ったときだけ draft を解除する（仕様: `.claude/docs/10_spec/10-work-ticket-driven.md`「マージ前作業の判定と状態」）。各サブコマンドは前提未充足を WF016 で返すので、状態ファイル `wip/merge-prep.json` を直接直して通そうとしない。

| # | やること | 補足 |
|---|---------|------|
| 6-1 | PR 本文を最終整形する: 「変更内容の概要」「動作確認」を `wip/30_reports/` の要約で埋め、`- Closes #N` を確認して `gh pr edit M --body-file <path>` | **6-3 より前に行う**。結果報告・計画・チケットはリセットで削除され main に残らないため、残したい要約は PR 本文に書く |
| 6-2 | **承認③**: 「マージ前作業（wip リセット → コンフリクト確認 → issue コメント → draft 解除）に進む」「draft のまま」「追加作業がある」を確認する | 承認されたら 6-6 まで進む。ready 自体を改めて確認しない |
| 6-3 | `bash .claude/hooks/merge-prep.sh reset-wip --dry-run` で削除対象を提示し、続けて `bash .claude/hooks/merge-prep.sh reset-wip` を実行する | wip の成果物（全体計画・チケット・計画書・結果報告・`review-state.json`）を削除し、最後のワークのレビュー完了の証跡を `wip/merge-prep.json` へ写してコミット・push する。前提（todo / doing が空・`review_state: completed`・未コミット無し・PR あり）を満たさなければ WF016 |
| 6-4 | `bash .claude/hooks/merge-prep.sh check-conflicts` を実行する | 衝突なしなら 6-5 へ。衝突あり（WF016 + ファイル一覧）なら**承認⑤**を取り、`git merge origin/<default>`（**`git rebase` は使わない**）→ 解消 → コミット → `git push` → `check-conflicts` を再実行する。解消方針が一意でない衝突は両側の意図を要約して `AskUserQuestion` で判断を仰ぐ |
| 6-5 | `assets/issue-notify.template.md` を Read し、issue コメントの本文案（対象 PR・変更の要約・受け入れ条件との対応・成果物・マージ後の扱い）を作って**承認⑥**を取る。承認後、本文を一時ファイルに Write して `bash .claude/hooks/merge-prep.sh notify-issue --body-file <path>` | 通知先は PR 本文の `Closes #N`。他に通知すべき issue があれば `--issue N` を添える（追加先の判断は人間）。`gh issue comment` を直接叩かない |
| 6-6 | `bash .claude/hooks/merge-prep.sh ready` | reset / conflicts（衝突なし）/ notify の記録と再検証（wip が空・未コミット無し・push 済み・fetch して衝突なし）を通ったときだけ `gh pr ready` が実行される。**`gh pr ready` を直接実行しない**（フックが WF015 で拒否する） |
| 6-7 | 手順 7 の報告をして**停止する**。マージは人間が行う（`gh pr merge` を実行しない） | |

承認③で「draft のまま」「追加作業がある」が選ばれたら 6-3 以降に進まない（追加作業は同じ type の追加チケットとして手順 5 に戻る）。承認⑤で「解消しない」、承認⑥で「投稿しない」が選ばれたら、その時点で報告して停止する（`ready` は前提未充足で実行できない）。途中で止まった後に再開するときは `bash .claude/hooks/merge-prep.sh status` の `merge_state`（`reset` / `checked` / `notified`）を見て、次のサブコマンドから続ける。

## 手順 7: 報告

- issue: `#N <url>`（新規 / 追記）と、`notify-issue` が投稿したコメントの URL
- ブランチと PR: `<branch>` / `#M <url>`（ready 済み or draft のまま。draft のままなら理由）
- マージ前作業の結果: `reset-wip` の削除件数、`check-conflicts` の結果（衝突の有無・解消した場合はその内容）、`merge_state`
- 成果物: コード変更の要約（`wip/` の計画・報告はリセット済みのため、PR 本文の要約を指す）
- 振り返りから得られた改善提案

## エラーハンドリング

| 状況 | 対処 |
|------|------|
| `gh` 未導入 / 未認証 | `20-task-gh-install` または `gh auth login` を案内して停止 |
| `origin` が GitHub でない | 対象外として報告する（`20-task-gh-feature` 自体は GitHub/GitLab 両対応だが、本ワークフローの issue 検索・作成・編集は `20-task-gh-issue` に依存しており、`20-task-gh-issue` が GitHub 専用の間は本ワークフロー全体として GitLab には未対応） |
| 未コミットの変更がある | 手順 0「未コミットの変更があるとき」に従い、扱いをユーザーに確認する。勝手に stash / コミット / 破棄しない |
| 検索が 0 件 | closed を含めて再検索。それでも 0 件なら 3B へ |
| `gh pr create` が「差分なし」で失敗 | 空コミットを作って再試行 |
| ブランチ名が衝突 | `20-task-gh-feature` の手順に従い別名を提案 |
| `gh issue edit` / `gh pr create` の失敗 | コマンドと出力を報告して停止。別コマンドで代替しない |
| チケット作業中に `gh` が必要になった | WF003 でブロックされる。迂回せず、チケット完了後に行う |
| 承認①②③で却下 | その段階に留まり、修正案を作り直すか停止する。先の段階に進まない |
| `work-boundary.sh request` が WF013 で止まった | 未充足の条件（未コミット / 未 push / PR なし / 境界でない / 既に requested）を解消して再実行する。境界でないなら次のチケットに着手する |
| `work-boundary.sh complete` が WF014 で止まった | `requested` でないなら `request` から。`CHANGES_REQUESTED` なら同じ type の追加チケットで対応して再度 `request`。未返信スレッドは `reply` で返信してから再実行 |
| 次のチケットへの `git mv` が WF011 で止まった | 前のワークのレビューが未完了。メッセージの対処（`request` または `complete`）に従う。状態ファイルを直接編集しない（WF012） |
| `gh pr ready` が WF015 で止まった | 直接実行は常に拒否される。`bash .claude/hooks/merge-prep.sh ready` に切り替える（手順 6-6）。迂回しない |
| `merge-prep.sh reset-wip` が WF016 で止まった | 未充足（todo にチケットが残っている / doing あり / 最後のワークが `completed` でない / 未コミット / PR なし）を解消する。残りのチケットは手順 5 へ、レビュー未完了は `request` → `complete` へ戻る |
| `merge-prep.sh check-conflicts` が WF016（衝突あり）で止まった | 手順 6-4 のとおり承認⑤を取り、`git merge origin/<default>` で取り込んで解消する。`git rebase` や `git checkout --ours/--theirs` でのファイル丸ごと片側採用はしない（もう一方の変更を無言で捨てる）。解消後に `check-conflicts` を再実行する |
| `merge-prep.sh notify-issue` が WF016 で止まった | `checked` でない（先に `check-conflicts`）/ 本文ファイルが空 / 通知先なし（`--issue N` を指定）/ 既に `notified`（二重投稿はしない。`ready` へ）のいずれか。`gh issue comment` の失敗なら投稿済みの issue（stderr）を確認し、未投稿分だけ `--issue` で指定して再実行する |
| `merge-prep.sh ready` が WF016 で止まった | 未充足（`notified` でない / wip に成果物が残っている / 未コミット / 未 push / default ブランチが進んで衝突）を列挙どおりに解消する。衝突は 6-4 からやり直す。状態ファイルを直接編集しない |
| ヘッドレス実行で承認⑤⑥が必要になった | 衝突内容または通知本文案を報告してセッションを終える。続きは次回セッションで `merge-prep.sh status` から再開する |
| `gh` CLI が使えない環境（`command -v gh` が失敗する） | 各サブコマンドの `--pr <N>`（PR 番号の明示指定）と `--external`（呼び出し元が MCP ツールで実際の GitHub 操作を代行し、結果をフラグで渡す）で代替する。`work-boundary.sh request` は `--external --pr <N> --comment-url <url>`（`mcp__github__add_issue_comment` 等で投稿したコメントの URL を渡す）、`complete` は `--external --report-file <path>`（`mcp__github__pull_request_read` の `get_reviews`/`get_comments`/`get_review_comments` から仕様書のスキーマに整形した JSON）、`merge-prep.sh notify-issue` は `--external --pr <N> --pr-body-file <path> --posted "N:url"`、`ready` は `--external --pr <N>`（先に `mcp__github__update_pull_request(draft:false)` で draft を解除しておく）を渡す。`reply` は gh 不在時には使わず `mcp__github__add_reply_to_pull_request_comment` で直接返信する。詳細は `.claude/docs/10_spec/チケット駆動ワークフロー.md`「gh CLI 不在時のフォールバック」を参照。状態ファイルには `via: "gh" \| "local" \| "external"` が記録され、`external` は `local` と異なり実在する PR/コメント URL を伴うが、いずれも呼び出し元の申告を信頼する点は同じで、gh 自身が GitHub に問い合わせて確認する強度より劣る |
| レビュー完了の連絡がないまま「続けて」と言われた | `complete` を実行し、通れば次のワークへ。通らなければ理由を報告して応答を終える |
| ヘッドレス実行（`claude -p` 等）でワーク境界に達した | `request` を実行した時点でそのセッションの応答を完了とする。レビュー結果の反映と次のワークは次回セッション（手順 0 の再開判定）で行う。1 セッションで全ワークを完走することは想定しない |

## ベストプラクティス

- 1 issue = 1 PR = 1 ワークフロー。大きな依頼は issue を分ける
- 承認なしで issue / ブランチ / PR を作らない。承認②でブランチ名と PR タイトルも一緒に確認して往復を減らす
- 既存 issue の本文は追記のみ。過去の経緯を消さない
- issue の受け入れ条件を先に固め、チケットの DoD と結果報告に一貫して使う
- `--body-file` 用の一時ファイルはリポジトリ外（例: `/tmp/`）に置き、残さない
- レビュー依頼（`request --body-file`）には「対象の差分範囲」「見てほしい観点」「次のワーク」を書く。後段のワークで確定したい判断があれば、そこで指摘してもらえるよう明示する
- ワークの粒度が細かすぎてレビュー往復が多いと感じたら、type をまとめるのではなく、レビュー依頼に「軽微なので approve のみで可」と添える。計画 → 実施で必ず 2 回の境界が発生するため、小さな依頼では全体計画でフェーズを省略する（`10-work-overall-plan` 手順 4-2 の目安）
- レビュー依頼の観点は、各フェーズ別ワークスキルの「5. レビュー観点」を元にする
- `reset-wip` で消える情報（結果報告の「うまくいかなかったこと」「改善提案」「残課題」）は、6-1 の PR 本文と 6-5 の issue コメントに要約して残す。`wip/` は PR の作業領域であり、main に残す記録ではない
- issue コメントの本文は「受け入れ条件との対応」を表にし、根拠（ファイル・テスト ID）を添える。後から issue だけを読んでも何が満たされたか分かるようにする
- 完了処理はできるだけ 1 つの応答内で 6-1〜6-7 を通す。リセット後は `wip/10_tickets/` が空になり入口ガードの継続判定が効かないため、別プロンプトで再開すると振り分けの再宣言が必要になる（issue #28 と同種の既知の制約）
