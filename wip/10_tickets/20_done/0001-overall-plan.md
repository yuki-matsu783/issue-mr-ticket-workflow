---
type: ticket
ticket_type: overall-plan
predecessors: []
executor: main
human_review: {required: true, reason: "フェーズ列・実行者・やってよいことの合意は人間が行う（work-defaults 基準どおり）"}
adversarial_review: {required: false, reason: "基準どおり（合意そのものが成果物で、敵対的レビューの対象にしない）"}
allow:
  write: ["wip/**"]
  ops: ["read", "remote-read", "remote-write:mr-create", "remote-write:push"]
started_at: "2026-09-02T03:19:58+09:00"
completed_at: "2026-09-02T03:49:35+09:00"
base_sha: "8f247f0"
---

# 0001 issue #9 の全体計画（自己改善ワークフロー機構の実装 2/3）

## 目的

issue #9（フック本体 11 本・settings.json 登録・TBD T1〜T4 の検証）のフェーズ列・実行者・レビュー要否・やってよいことの方針を人間と合意し、最初の計画チケットを起こす

## DoD

- [x] マージ方式（squash の可否・既定）を確認し、全体計画書に記載した（根拠: gh repo view --json squashMergeAllowed,mergeCommitAllowed,rebaseMergeAllowed → 3 つとも true。main の履歴が #2・#5・#7 とも squash の 1 コミットであることと合わせ、全体計画「対象」に squash 前提と記載（設定変更は行わない））
- [x] feature ブランチと draft MR を作成し、番号と URL を報告した（根拠: ブランチ feature-9-hook-bodies-settings（origin/main 058855e から分岐）を作成し、commit.sh --allow-empty で開始コミット 8f247f0 → push.sh（4 項目すべて通過）。20-common-step-feature-mr の手順で draft MR #12 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/pull/12 を作成（isDraft=true / OPEN））
- [x] 全体計画書 wip/00_overall_plan/overall-plan.md を作成し、対象・種別・フェーズ列・受け入れ条件との対応・方針（work-defaults との差分）・保留した点・合意の記録を書いた（根拠: wip/00_overall_plan/overall-plan.md（コミット c699e97）。対象・種別（AI アセット）・フェーズ列 7 段・受け入れ条件 6 件との対応・方針（work-defaults との差分表と ※1 の理由）・やってよいこと・settings.json の登録とロックアウト対策・判断が必要になりそうな点 7 項目・保留した点・合意の記録を収録）
- [x] 承認③（フェーズ列・実行者・レビュー要否・やってよいこと・settings.json 登録の扱い）をユーザーから取得し、合意の記録に残した（根拠: AskUserQuestion で 3 問（全体計画の合意 / 切れ目のレビューの扱い / settings.json の登録の段取り）を一度に確認し、「この計画で合意（推奨）」「#6 と同じ（推奨）」「2 段階で登録（推奨）」を取得（2026-09-02）。合意の記録の ③ ④ 行に反映）
- [x] 最初の計画チケット（investigation-plan）を 1 枚だけ未着手に作成した（根拠: ticket.sh create investigation-plan → wip/10_tickets/00_todo/0002-investigation-plan.md（コミット 2331582）。todo はこの 1 枚だけ）

## 作業内容

- issue #9 の本文と 1/3 の申し送り（0022 の D1〜D6・G7・G8）を読み、扱う範囲を確定する
- フック共通仕様 §1 の登録表・§11 のテスト観点・§12 の TBD 表から、この issue の作業単位を洗い出す
- work-defaults.md を基準に実行者・レビュー要否を組み、差分に理由を付ける
- settings.json 登録（人間の操作）とロックアウト対策の位置づけをフェーズ列に組み込む

## 作業ログ

### 現在地

- 済: issue #9 の確定（承認①②は前セッションで取得）→ マージ方式の確認 → ブランチ feature-9-hook-bodies-settings と draft MR #12 → 全体計画書の作成 → 承認③④ → 最初の計画チケット 0002-investigation-plan の起票
- 完了: 0002（investigation-plan）を todo に用意済み。このチケットの完了で全体計画タスクの切れ目に達する

### うまくいったこと

- 承認③（全体計画の合意）・承認④（切れ目のレビューの扱い）・settings.json の登録の段取りを 1 回の AskUserQuestion に束ねられた。#6 の全体まとめで得た「全体計画の承認は束ねてよい」の知見をそのまま使えた
- #6 で作った提供コマンド（ticket.sh / commit.sh / push.sh）が揃っているため、全体計画タスクの手作業代替が 0 件になった（#6 では状態遷移もコミットも手作業だった）

### うまくいかなかったこと

- 全体計画書のテンプレート（10-task-overall-plan の assets/overall-plan.template.md）が未作成（3/3 の範囲）のため、仕様の「OUT ひな形」の節の表と #6 の全体計画書を見ながら手で組んだ。テンプレートが無くても節は揃えられるが、3/3 でテンプレートを作るときに #6・#9 の 2 本を材料にする
- work-defaults の既定（サブエージェント）を初回から外すことになった。基準の使い始めでいきなり全行が差分になるのは、基準の側が「機構が完成した後の姿」で書かれているため。3/3 完了後に基準どおりへ戻す前提を全体計画に明記した

### 仕様からの逸脱

- 実行者を全種類メインエージェントにした（work-defaults の既定から外れる）。理由と戻す時期は全体計画「方針」の ※1 に記載
- 人間レビューを opus サブエージェントの敵対的自己レビューで代替する（承認④）。レビュー依頼コメントの投稿は証跡として続ける
- 10-task-overall-plan スキルの実体が未作成のため、仕様書（10_spec/skills/10-task-overall-plan.md）の処理フロー 1〜10 を手順書として直接使った

### 判断と根拠

- フェーズ列はテンプレートどおりで省略なし。AI アセット設計フェーズは「対象あり」を見込む（調査結果の仕様への書き戻しが必ず発生し、実装フェーズは scope-limits の deny で .claude/docs/** に書けないため）
- settings.json の登録は 2 段階（案内側 → 拒否側）。拒否側を先に入れると、誤りがあったときに切り分けと切り戻しの手数が増えるため
- プローブフックは wip/tmp/probe/ に置く。investigation の上限は .claude/** が deny で、プローブを .claude/hooks/ に置くと調査タスクの宣言と矛盾するため
- 調査を設計より前に置いたのは、T1〜T4 の実測結果が仕様（§2・§12）の書き戻し内容そのものになるため

### 拒否・確認・迂回の記録

- 承認①②（issue #9 / 追記なし・ブランチ名・MR タイトル）は前セッションで AskUserQuestion により取得
- 承認③④と登録の段取りを AskUserQuestion で取得。迂回・ブロックは無し（フックは未登録のため強制は働いていない）

### 使った AI アセットと効き目

- 00-workflow-issue-mr-driven（手順 0・4・5）: 状態確認と手順 4 の委譲先が明示されていたので、ブランチ〜draft MR まで迷わず進めた
- 20-common-step-feature-mr: 開始コミットの作り方（持ち越し無しなら --allow-empty）と MR 本文テンプレートが決まっており、判断が要らなかった
- 20-common-step-ticket / 20-common-step-commit-push: create / start / commit / push がすべて提供コマンドで通り、手作業代替なし
- 10_spec/skills/10-task-overall-plan.md（スキル未実装のため仕様書を直接）: 処理フロー 1〜10 と OUT ひな形の節構成をそのまま使えた

### スコープ外で見つけたこと

- 全体計画チケットの DoD は 5 項目とも「仕様の処理フローの段」に 1:1 で対応する。3/3 で 10-task-overall-plan スキルを作るとき、この 5 項目を DoD の型として assets に入れられる
- ticket.sh create の出力が「OK: ...（未着手。OK: 1 ファイルをコミットした（SHA）。除外: なし）」と OK 行を二重に含む。読みにくいので 3/3 の小改善候補（#10 の本文に既出の小改善と同じ扱い）

### AI アセットに反映すべき内容

- 3/3（#10）へ: 10-task-overall-plan の assets/overall-plan.template.md（#6・#9 の全体計画書 2 本を材料に、対象 / 種別 / フェーズ列 / 受け入れ条件との対応 / 方針 / 保留した点 / 合意の記録の 7 節）と、全体計画チケットの DoD の型 5 項目
- work-defaults.md へ（3/3 完了後）: 「機構が未完成の間は実行者をメインエージェントに倒す」という但し書き、または既定を段階（機構の完成度）で切り替える書き方。今回のように基準の全行が差分になる状態は、基準の側の想定が現実と合っていないことを示す
- ticket.sh の出力整形（OK 行の二重）は小改善として #10 の本文に追記済みの一覧に加える

### 備考

- 全体計画書: wip/00_overall_plan/overall-plan.md（c699e97）。MR #12 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/pull/12
- このチケット（overall-plan）はコミットされない。開始コミット 8f247f0 に載る扱い（DDR i0004-04）
