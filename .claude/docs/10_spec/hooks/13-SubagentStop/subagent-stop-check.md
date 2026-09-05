---
type: spec
title: subagent-stop-check フック 仕様
description: サブエージェント終了時に、作業中のまま残ったチケット・未コミットの差分・許可範囲外の差分と、実行者の不一致を検知してメインエージェントに実態として伝えるフックの内部仕様。SubagentStop での記録と PostToolUse(Agent) での通知経路、対象チケットを採る作業ツリー（PostToolUse は呼び出し元 / SubagentStop は起動された側）、縮退判定（session_id 単位）、scope.sh の共有、WF801 と WF81x を定める
tags: [spec, hook, subagent-stop-check]
keywords: [SubagentStop, PostToolUse Agent, 作業中のまま, 未コミット, 未追跡, 許可範囲外, scope.sh, 結果報告との突き合わせ, 勝手に完了しない, 実行者の不一致, 縮退判定, 作業ツリー, 一意, WF801, WF811, WF812, WF813, WF814, WF815]
---

# subagent-stop-check フック 仕様

## 概要・禁止事項

対応する要件は [00_requirement/hooks/13-SubagentStop/subagent-stop-check.md](../../../00_requirement/hooks/13-SubagentStop/subagent-stop-check.md)。共通事項は [フック共通仕様](../../フック共通仕様.md)（§3 通知経路、§8 scope.sh）。

案内側のフック。同じスクリプトを 2 つのイベントに登録する: SubagentStop（検査して `logs/` に記録）と PostToolUse `Agent`（メインエージェント側へ additionalContext で伝える）。検査はいずれも同じ関数。**PostToolUse `Agent` は既定では起動直後に発火する**（サブエージェントは既定で background。§2・DDR i0009-50）ので、この経路の振る舞いは `tool_response.status` で分かれる。

**実行者の不一致（WF801）はこのフックが判定して伝える**。`subagent-start-check` は SubagentStart にだけ登録されており（同フック仕様。共通仕様 §1）、起動前に伝える経路が無いため、この検知は起動後のこちらに寄せている。ただし判定は無条件ではなく、`subagent-start-check` が PreToolUse `Agent` の経路で先に通知していれば出さない（同じ不一致を 2 回通知しない。DDR i0009-31）。出すときは**再掲ではなく、このフックが自分で判定する**（先に通知が無い＝再掲する元の記録が存在しないため。DDR i0009-52）。

**縮退かどうかの判定は `session_id` 単位**で行う: `subagent-start-check` は PreToolUse `Agent` の経路を通ったとき、その事実をセッション内の印（`logs/sessions/<session_id>/subagent-start-check.json`）として残す。**同じセッションにこの印が無い**ときが縮退である。`agentId` 単位では引けない — `subagent-start-check` が走る PreToolUse `Agent` の時点では `agentId` がまだ発行されておらず、記録に載せられないため。縮退は「登録行が外れている」というセッション横断の条件なので、単位としてもセッションのほうが実態に合う。`decisions.jsonl` の `subagent-start-check` の記録は**判定材料にしない**（SubagentStart の注入でも残るため、経路の有無を区別できない）。

**現在の登録に PreToolUse `Agent` の行は無い**（共通仕様 §1 の登録表が明記し、`HK-T01` が負のコントロールで固定している）ので、印は生じず、実運用では**常に縮退の側**で判定する。印の有無を見る分岐は、その登録が将来足されたときに同じ不一致を 2 回通知しないためのもので、いまは常に「印なし」に落ちる。`SP-T05` / `SP-T08` の「印がある」ケースは、この分岐が生きていることを確かめる負のコントロールであり、**テストが印を自分で置いて作る**（実運用の登録に依存しない）。

**実行者照合の対象チケットは、作業ツリーごとに一意に決まる**（受け入れ条件 A5）。対象は `HOOK_WORKTREE`（§2 の解決順が入力 JSON の `cwd` から決める作業ツリー）の作業中チケット 1 枚だけで、他の作業ツリーへ回らない。経路ごとに `cwd` が誰のものかが違うので、次で確定させる（`subagent-start-check` 仕様の経路の表と同じ読み方）。

| 経路 | 入力 `cwd` は誰のものか | 見る作業ツリー | 用途 |
|---|---|---|---|
| PostToolUse `Agent` | **呼び出し元**（Agent ツールを呼んだ側のツール呼び出しであり、隔離した作業ツリーはこの時点でまだ存在しない） | 呼び出し元の作業ツリー | 実行者の不一致（WF801）・background 起動（WF814） |
| SubagentStop | **起動された側**（サブエージェントの中で発火する） | 起動された側の作業ツリー | 作業後の検査（WF811〜813） |

作業ツリーを確定できないとき（`cwd` からの解決に失敗した・作業ツリーの集合を読めない）は、代わりに本流のチケットを見て判定することを**しない**。案内側のフックは deny を出せないので、**判定していないことを伝える側に倒す**（**WF815**。§2「判定できないときの倒し方」）。

禁止事項:

- チケットの移動・完了、差分の巻き戻し
- 異常の断定（実態の報告として書き、判断は AI に委ねる）
- 結果報告の真偽の判定
- 独自の許可範囲（`scope.sh` を使う）

## 呼出条件（イベント・matcher・登録）

- SubagentStop（全サブエージェント）: 検査 → `logs/sessions/<session_id>/subagent-<agent_id>.json` に結果を記録（この経路の出力はメインエージェントに届かない。§12 T1）
- PostToolUse、matcher `Agent`: **`tool_response.status` で分岐する**（§2・DDR i0009-51）
  - `completed`（foreground で走り終わった）: 直近の記録（`tool_response.agentId` に対応するもの。無ければ最新）を読み、該当があれば additionalContext で伝える。記録が無ければその場で検査する
  - `async_launched`（background へ移った＝**まだ作業していない**）: **作業後の検査（WF811〜813）を行わない**。行うと作業前の作業領域を見ることになる。代わりに **WF814** で「background 起動なので完了後の検査は届かない」ことを伝える。WF801 の縮退判定（下記）はこの経路でも行う

## 入出力

- 入力: SubagentStop では `agent_id`・`agent_transcript_path`（使わない）/ PostToolUse では `tool_input`（`subagent_type`・`model`）と `tool_response`（**`status`**・**`agentId`**。camelCase。§2・DDR i0009-53）。参照: `wip/10_tickets/10_doing/`、`git status --porcelain -z`、作業中（または直近で完了）チケットの frontmatter、`scope-limits.json`、`logs/sessions/<session_id>/subagent-start-check.json`（PreToolUse `Agent` の経路が使えたかの印。有無だけを見る）、`.claude/hooks/config/model-aliases.txt`（縮退時の実行者の比較に使う）
- 出力: PostToolUse `Agent` の additionalContext（WF801 / 811 / 812 / 813 / 814）

## 制御方式

1. 停止中 → `disabled` を記録して何もしない
2. **WF801 の縮退判定**（PostToolUse `Agent` のときだけ。`status` を問わない）: このセッションに `subagent-start-check` の印（`logs/sessions/<session_id>/subagent-start-check.json`）が**無い**とき、このフックが自分で判定する — `tool_input.subagent_type` が `task-executor` で、**呼び出し元の作業ツリー**（`HOOK_WORKTREE`）の作業中チケットの `executor` が `main` 以外で、`tool_input.model` が特定でき、`model-aliases.txt` で正規化して不一致なら **WF801**。印があるときは何もしない（DDR i0009-52）。作業ツリーを確定できないときは、本流で代用せず **WF815**（判定していないことの通知）を出して比較を行わない
3. 検査（SubagentStop 時、または PostToolUse で `status` が `completed` かつ記録が無いとき）。見るのは `HOOK_WORKTREE` の作業領域と差分で、SubagentStop の経路では**起動された側の作業ツリー**になる（概要の経路の表）。確定できないときは **WF815** を出して検査しない:
   - `10_doing/` に `.md` がある → **WF811**（番号・種類・作業ログ「現在地」の有無）
   - `git status` に未コミットの変更・未追跡がある（`logs/**`、`wip/tmp/**` を除く）→ **WF812**（パス一覧。件数が 20 を超えれば先頭 20 件 + 件数）
   - 作業中チケットがあり、その差分に `scope.sh` で deny / 未承認 ask となるパスがある → **WF813**
   - いずれも無ければ「該当なし」を記録し、何も伝えない
4. PostToolUse `Agent` で伝えるとき、文面に必ず含める: 「サブエージェントの結果報告と突き合わせること」「完了していれば `ticket.sh complete` で完了の手続きを行うこと（サブエージェントが完了まで行う運用なら作業中のまま残るのは異常）」「失敗・中断なら作業中のまま残ったチケットをユーザーに報告し、勝手に完了にしないこと」
5. 作業領域・差分の取得に失敗 → 何も伝えない
6. 入力不正 → 何もしない（終了処理を止めない）

## エラー識別子とメッセージ

| ID | 種別 | 内容 |
|----|------|------|
| WF801 | 通知 | **実行者の不一致**（縮退時にこのフックが判定して出す。識別子の持ち主は `subagent-start-check` — 共通仕様 §6）: チケットの `executor` / 起動したモデル / 対象チケット。続けるか起動し直すかは AI がチケットの実行者に従って判断する |
| WF811 | 通知 | 作業中のまま残ったチケット（番号・種類・現在地の有無）+ 対処 3 点 |
| WF814 | 通知 | サブエージェントが **background で起動された**（`tool_response.status` が `async_launched`）ため、完了後の検査（WF811〜813）はメインエージェントに届かない。タスクの実施者は `run_in_background: false` で起動し直すか、完了を確かめてから自分で作業領域を確認すること |
| WF812 | 通知 | 未コミットの差分・未追跡（パス一覧）+ 対処 |
| WF813 | 通知 | 許可範囲外のパスに残る差分（パス一覧）+ 復旧は `workflow-diff-check` の指示と同じ |
| WF815 | 通知 | **作業ツリーを確定できないため、実行者照合と作業後の検査を行っていない**（案内側なので拒否ではなく「判定していない」の通知。§2）: 解決に失敗した `cwd` と、本流のチケットで代用していないこと。AI は自分でチケットの `executor` と起動したモデルを突き合わせ、作業中のまま残ったチケットの有無を確かめること |

## 回復手順

- 結果報告と突き合わせ、完了なら `ticket.sh complete`、失敗・中断なら `00-workflow-issue-mr-driven` 手順 2-6（報告して指示を待つ）。範囲外の差分は基準点へ戻す
- WF801: サブエージェントを止めて正しいモデルで起動し直す（`00-workflow-issue-mr-driven` 手順 2-3）。実行者を変えたいなら未着手チケットの見直しで `executor` を直す

## 記録（logs/）

- `logs/sessions/<session_id>/subagent-<agent_id>.json`: 検査結果（`checked_at`、`findings[]`）
- `decisions.jsonl`: `notify`（WF801・WF811〜815）/ `skip`（該当なし・取得失敗）
- 実行ログ: `logs/sh/hook-subagent-stop-check.log`

## テスト観点

| テスト ID | 種別 | 固定する振る舞い |
|-----------|------|----------------|
| SP-T01 | 正常系 | 作業中なし・差分なしで何も伝えない |
| SP-T02 | 異常系 | `10_doing/` に 1 枚残ると WF811 と対処 3 点 |
| SP-T03 | 異常系 | 未コミット 3 件（うち `logs/` 1 件）で WF812 に 2 件だけ列挙 |
| SP-T04 | 異常系 | 禁止範囲のパスに差分があると WF813 |
| SP-T07 | 正常系 | `tool_response.status` が **`async_launched`** のとき、`10_doing/` にチケットが残り未コミット差分があっても **WF811〜813 を出さず**、代わりに **WF814** を出す。`completed` のときは従来どおり WF811〜813 を出す（同じ作業領域での対照） |
| SP-T08 | 正常系 | **縮退時に自分で判定する**: セッションに `subagent-start-check` の印が無く、`tool_input.subagent_type` が `task-executor`・チケットの `executor` が `opus`・`tool_input.model` が `sonnet` のとき **WF801** が出る。同じセッションに印があるときは**出ない**（負のコントロール）。判定は `session_id` 単位で、`decisions.jsonl` の `subagent-start-check` の記録（SubagentStart の注入でも残る）を材料にしないこと |
| SP-T05 | 正常系 | SubagentStop で記録し、PostToolUse(Agent) で同じ内容が additionalContext に出る。**WF801 を出すのは縮退時だけ**: 同じセッションに `subagent-start-check` の印が**ある**とき（PreToolUse の経路が生きている）は出**さない**、**無い**とき（縮退）だけ出す |
| SP-T06 | 正常系 | `git` 不在で無出力・終了 0 |
| SP-T09 | 正常系（機械） | **実行者照合が呼び出し元の作業ツリーのチケットで行われる**（受け入れ条件 A5）。一時リポジトリの本流から worktree を切り、**本流と worktree に `executor` の違うチケットを 1 枚ずつ**置く（テストは判定を呼ぶ前に両方の枚数と `executor` を assert して前提を自分で作る）。`cwd` を本流にした PostToolUse `Agent` の入力で `tool_input.model` が本流側の `executor` と一致すれば **WF801 は出ず**、worktree 側の `executor` と一致するときは **WF801 が出る**（呼び出し元のチケットで判定していることの対照）。`cwd` を worktree にすると判定が worktree 側のチケットに切り替わる。`.git/worktrees/` を読めない状態にすると **WF815** が出て、本流のチケットで代用しない |

## 要件との対応

| 要件（受け入れ基準） | 実現箇所 |
|--------------------|---------|
| メイン: 作業中残り・未コミット・範囲外差分の検知と通知 | 制御方式 3、WF811〜813 |
| メイン: 該当なしは何も伝えない | 制御方式 3 |
| メイン: 対処 3 点を含める | 制御方式 4 |
| メイン: 実態の報告として書く | 禁止事項、制御方式 4 |
| メイン: 破壊的操作をしない | 禁止事項 |
| メイン: 記録（振り返り用）・識別子・対象の明記 | 記録、エラー識別子 |
| 代替: 緊急停止 | 制御方式 1 |
| 例外: 取得失敗・入力不正は通す | 制御方式 5・6 |
| 前提: メインエージェント側で動かす | 呼出条件（PostToolUse Agent） |
| （`subagent-start-check` 要件）メイン: executor と起動モデルの比較・通知・記録 / 事後の通知への縮退 | 制御方式 2、WF801 |
| （`subagent-start-check` 要件）メイン: 不一致の検知は呼び出し元の作業ツリーのチケットで一意に決まる | 概要の経路の表、制御方式 2、SP-T09 |
| （共通仕様 §2）判定できないときは案内側として「判定していない」を伝える | 概要（代用しない）、制御方式 2、WF815、SP-T09 |
