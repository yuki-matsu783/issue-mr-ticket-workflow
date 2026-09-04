---
type: report
title: 0004 調査結果 — worktree 上での機構の健全性（観点 A: フックの作業ツリー解決 / 観点 B: 提供コマンドと logs/ 状態ファイル）
description: issue #50 の調査フェーズの結果。観点 A では、フックの HOOK_ROOT / HOOK_WORKTREE の全参照 81 件を判定つきで一覧にし、6 本のフックが worktree 側と本流側のどちらで判定するかを行番号つきで確定した。観点 B では、提供コマンド 5 本の状態ファイル依存 17 行を「無いときの振る舞い」つきで表にし、__ss_load が cwd ではなくスクリプトの置き場で LOGGER_ROOT を決めることと、そのずれる 3 条件を特定し、本 issue の実施中に実際に踏んだ 3 件の根本原因を行番号で押さえた。人間が実行するための実測手順（コマンド列 + 予測）を観点ごとに残した。
tags: [report, investigation, issue-50]
keywords: [worktree, HOOK_WORKTREE, HOOK_ROOT, LOGGER_ROOT, __ss_load, 作業ツリー解決, 静かな無効化, workflow-guard, workflow-diff-check, hc_lock, HK-T18, 提供コマンド, merge-state, mr.json, 実測手順]
---

# 0004 調査結果 — worktree 上での機構の健全性（観点 A: フックの作業ツリー解決 / 観点 B: 提供コマンドと `logs/` 状態ファイル）

- 対象 issue: [#50](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/50)
- MR: [#51](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/pull/51)（draft）
- ブランチ: `feature-50-worktree-parallel-tickets`
- チケット: 0004（観点 A）
- 作成日: 2026-09-04

## サマリ

0004 まで（観点 A）。

観点 A の問い「Claude が worktree に入ったとき、フックは worktree 側の `wip/` と `logs/` を見て判定するか」への答えは **「入力 JSON の `cwd` が worktree を指しており、かつその worktree が `HOOK_ROOT` との相互参照を保っているかぎり、6 本すべてが worktree 側の `wip/` と `logs/` で判定する」**。DDR `i0009-55` の言う「静かな無効化」は、`.claude/hooks/lib/hook-common.sh` の `__hc_resolve_worktree`（319〜331 行）と `hook_read_input` からの呼び出し（369 行）で塞がれている。ただし塞がり方には条件と穴があり、それを e2・e4・e5・e6 に分けた。

- `HOOK_ROOT` / `HOOK_WORKTREE` の参照は **81 行（`grep -rn` の行数。同一行に 2 つ現れるものを数えると 90 箇所）**。内訳は 作業ツリーの状態を指すもの 55 行 / スクリプト・設定の置き場を指すもの 8 行 / 定義とコメント 4 行 / **取り違え（および疑い）4 行** / テストの設定 10 行。取り違え 4 行のうち、いま誤判定を生むものは 0 件で、4 件とも「原則と不一致」または「潜在」である（e2）
- 6 本のフック（`workflow-guard` / `workflow-diff-check` / `workflow-entry` / `workflow-state-guard` / `session-start` / `subagent-stop-check`）は**すべて worktree 側で判定する**。ただし `session-start` は SessionStart 時点の `cwd` しか見ないため、実質的には「セッションを開始したディレクトリ」で固定される（e3）
- `logs/` は `.gitignore` の `logs/` 行で丸ごと除外されており worktree に複製されない。その結果、worktree に入ると**宣言の記録・承認の記憶・MR / レビュー / マージの進行状態がすべて `missing` に落ちる**。落ち方は「拒否側に倒れる」ので無効化ではないが、`workflow-entry` は WF102 を出し、承認は取り直しになる（e4）
- **作業ツリーをまたぐ絶対パスの書き込みは、常時効くはずの進行状態ファイル保護（`workflow-state-guard` の WF301 / WF302 / WF303）をすり抜ける**。`workflow-guard` の WF209 が二重の守りとして効くのは「その作業ツリーに作業中チケットが 1 枚あるとき」だけで、チケットの無い worktree からは本流の `wip/10_tickets/20_done/` や `logs/*.json` に書ける（e5）
- 仕様書とコードに食い違いが 2 件ある。フック共通仕様 §13 の「`workflow-diff-check` は `HOOK_ROOT` の作業ツリーだけを見る」は実装（`git -C "$HOOK_WORKTREE"`）と逆で、DDR `i0009-64` の決定「2 経路のどちらか片方でよい」も実装（相互参照の双方向を要求）より緩い（e6）
- 既存テストは `test_hook_common.sh` の `case_worktree`（`HK-T18` を借用）1 か所だけで、**`__hc_resolve_worktree` と `__hc_winpath` の単体は厚く固定されているが、実際の `git worktree add` が作る作業ツリーも、6 本のフックの端から端までの挙動も、1 件も固定されていない**（e7）
- ◎良 3 件 / △注意 4 件（e2・e4・e6・e7）/ ✕問題 1 件（節は e5 の 1 件）

0005 まで（観点 A・B）。ここから下の段落・箇条書きが 0005（観点 B）で足した分で、上の 0004 の記述は書き換えていない。**表題だけは観点 A 専用から観点 A・B を含む形に広げた**（0004 時点の表題は「0004 調査結果 — worktree 上でのフックの作業ツリー解決と、WIP・宣言範囲・差分判定の健全性」。以後の言及はこれと読み替える）。

観点 B の問い「提供コマンド 5 本と `logs/` 配下の状態ファイルは worktree ごとに分かれるか」への答えは **「分かれる。ただし『何を基準に分かれるか』がフックと提供コマンドで違い、提供コマンドは `cwd` ではなく起動したスクリプトの置き場で作業ツリーを決める」**。フックは `HOOK_ROOT`（スクリプトの置き場）と `HOOK_WORKTREE`（`cwd` から解決した作業ツリー）を分けて持つが、提供コマンドが持つ根は `LOGGER_ROOT` 1 本だけで、`__ss_load` が `BASH_SOURCE[1]` から上向きに決め（`ticket.sh:16` ほか 5 本に同じ 1 行）、本体は最初に `cd "$LOGGER_ROOT"` して以後すべて相対パスで触る（`ticket.sh:342` / `commit.sh:96` / `push.sh:65` / `boundary.sh:664` / `finalize.sh:538`）。

- 5 本のうち `logs/` の進行状態を読む・書くのは **`boundary.sh`（5 種）・`finalize.sh`（3 種）・`push.sh`（1 種）の 3 本**で、`ticket.sh` と `commit.sh` は logger が書く `logs/sh/<名前>.log` 以外に `logs/` へ**一切依存しない**（`grep -c 'logs/'` が 0 件）。全 17 行の表が e9-1（e9）
- `LOGGER_ROOT` が worktree とずれるのは **3 条件**。①本流の絶対パスで起動して `cwd` が worktree（およびその逆）、②worktree 側の `.claude` に共通ライブラリが無く `CLAUDE_PROJECT_DIR` に落ちる、③`.claude` を持つ別ディレクトリを起点にする。フックが持つ相互参照の検査（`__hc_is_worktree_of`）に当たるものは `__ss_load` に**無い**（e10）
- **フックの実体は常に「セッションの `CLAUDE_PROJECT_DIR`」の側**（`settings.json` が `bash "${CLAUDE_PROJECT_DIR}/.claude/hooks/…"` と絶対パスで起動する）、**提供コマンドの実体はスキルが指示する相対起動なら worktree の側**。`.claude/` を変えるブランチを worktree で開発すると、機構が自分自身の 2 つのバージョンを混ぜて動く（e11）
- **`logs/` が無い worktree で壊れるコマンドは 1 本も無い**。logger が `mkdir -p <root>/logs/sh` で作り（`logger.sh:16-18`）、`boundary.sh` は `ensure_logs`（`:176`）で作り、進行状態はどれも「無ければ既定値か再導出」の経路を持つ。最初に実害が出るのは `finalize.sh release` の段階 1（`logs/mr.json` と `logs/review-state.json` が両方無いと FN001 で停止）で、`--pr` と `boundary.sh skip --final` で回避できる（e12）
- 壊れるのは「無い」ほうではなく **「残る」ほう**。本 issue の実施中に実際に踏んだ 3 件（`push.sh` 項目 4 が前 issue の `merge-state` で永久に落ちる / `resolve_mr` が古い MR を掴む / `mr.json` の `issue` が常に null）はいずれも、`logs/` の**置き場の粒度が作業ツリー**なのに**中身の意味の粒度がブランチ・MR・issue** であることの帰結で、**worktree を使うとむしろ減る**（e13・e14）
- 提供コマンドには**排他制御が 1 つも無い**（5 本に `lock` の語が 0 件。`hc_lock` はフック専用）。同じ作業ツリーでの並列は `.git/index.lock` と採番で衝突し、worktree に分ければ index は分かれるが `logs/` は別々になる（e15）
- 件数（**タスク全体の合計。ここが唯一の合計で、他の節はここを指す**）: **◎良 6 件 / △注意 8 件 / ✕問題 2 件 = 16 件**（内訳: 0004 が ◎3 / △4 / ✕1 = 8 件、0005 が ◎3 / △4 / ✕1 = 8 件）

### ◆特に見てほしい（判断に困っている）

- e5 の位置づけ。「作業ツリーをまたぐ絶対パス指定で進行状態ファイル保護がすり抜ける」ことは、フック共通仕様 §13「意図的な緩和」が約束している「機構が守るのは進行状態・コミット / push・`chmod`（常時フック）まで」に反する。**issue #50 の受け入れ条件 A1 の「動かない箇所」として扱うか、全体計画書の保留 P2（機構の不具合として別 issue）へ回すか**を決めきれていない。並列実施を採らなくても worktree を使えば踏むので前者に寄せたが、判断は 0009 と 0010 に委ねる
- e2 の `session-start.sh:74`（`boundary.sh` のパスを `HOOK_WORKTREE` から取る）。仕様 §2 の「スクリプトの置き場は常に `HOOK_ROOT`」に反するが、`boundary.sh` は自分の `BASH_SOURCE` からルートを決めるので、本流の実体を呼ぶと本流の `wip/` を読んでしまい、かえって間違った現在地が出る。**「原則が例外を必要としている」のか「原則の書き方が粗い」のか**を設計フェーズで決めてほしい

- （0005）e13 の 3 件の位置づけ。`push.sh` 項目 4・`resolve_mr`・`write_mr_json` の 3 件は、全体計画書の保留 P2 に「`logs/` の進行状態が issue をまたいで残る」「`mr.json` の `issue` が誰にも書かれない」として既に挙がっている。一方で 3 件とも**受け入れ条件 A1 の「動かない箇所」でもある**（worktree を使えば緩和されるという意味で、本 issue の判断材料そのもの）。**P2 として別 issue に切り出すのか、A1 の一覧に載せて本 issue の設計フェーズで直すのか**を決めきれていない。0004 の e5 と同じ判断で、まとめて 0009 / 0010 に委ねる
- （0005）e11 の「フックは本流の実体、提供コマンドは worktree の実体」を**正とするか**。正とするなら「機構が自分自身の 2 バージョンで動く」ことを仕様に明記して、`.claude/` を変えるブランチを worktree で開発するときの手順（本流へ戻ってから機構を使う等）を決める必要がある。正としないなら提供コマンドも `CLAUDE_PROJECT_DIR` 起動に寄せることになるが、そうすると worktree で作業しても本流の `wip/` を触ってしまい、worktree の意味が消える。**どちらも一長一短で、調査の範囲では決めない**

### ◇判断が欲しい（決めた方針の承認 / 決められない点の判断）

- 取り違えの判定基準を「その参照が指しているものが、①スクリプト・設定の実体（= `HOOK_ROOT` が正）か、②`wip/` `logs/` `git` の状態（= `HOOK_WORKTREE` が正）か」の 2 択に固定し、定義行・コメント・テストの設定は判定の対象外とした（e2 の表の `C` と `T`）。この線引きで 81 行を 5 群に割った
- 実測手順は **「Claude を worktree に入れる」実測と「`cwd` を worktree にしたフックの単体実行」の 2 段に分け、後者を主にした**（e8）。前者は `git worktree add` も `cd` も機構が WF204 で拒否するため AI からは組み立てられず、人間の手数も多い。後者は同じ判定経路を stdin から直接叩けて、識別子（W1 = チケット 0 枚の作業ツリー）を置けば「worktree 側で判定したか」を一意に切り分けられる
- 実測の識別子として **`main` を基点にした作業ツリー W1（`wip/10_tickets/10_doing/` が `.gitkeep` だけ = チケット 0 枚）** を使う設計にした。本流と同じ内容の作業ツリーでは「worktree 側を見た」と「本流を見た」が同じ出力になり区別できないため

- （0005）「無いときの振る舞い」を **既定値 / 再導出 / 停止 / 依存なし** の 4 値に固定して分類した（e9-1）。「既定値」は無いことを正常として続けるもの、「再導出」は無いことを検知して別の情報源から作り直すもの、「停止」は未充足として止まるもの。この線引きで 17 行を割った
- （0005）`LOGGER_ROOT` のずれは **`__ss_load` の 1 行を読んだ静的解析**であって実測ではない。`CLAUDE_PROJECT_DIR` は本セッションの Bash ツールの環境では**未設定**（`echo "${CLAUDE_PROJECT_DIR:-未設定}"` で確認）なので条件②は実運用では起きにくいと判断したが、フックは `settings.json` がこの変数で起動するので**フック経由では必ず設定されている**。経路によって結論が変わる
- （0005）実測手順（e16）は **本流だけでできる 2 件（B1・B2）と worktree が要る 4 件（B3〜B6）** に分けた。B1・B2 は 0004 の実測手順 P0（worktree の作成）より前に単独で実行できるので、worktree を作れない環境でも先に片付く

### ・細かいレビューは不要（ほぼ確実）

- 参照の総数 81 行・90 箇所（`grep -rn ... | wc -l` と `grep -rno ... | wc -l`）は機械的に数えた値である
- `logs/` が `.gitignore` されていること（`.gitignore` の `logs/` 行、`git ls-files logs/` が 0 件）と、`wip/` が追跡されていること（`git ls-files wip/` が 19 件）
- `hc_lock` / `hc_unlock` / `__hc_unlock_all` のロックの置き場が `"$HOOK_WORKTREE/logs/locks/<name>.lock"` であること（`hook-common.sh:604` / `624` / `634`）

- （0005）5 本の `grep -c 'logs/' <スクリプト>` の件数（`ticket.sh` 0 / `commit.sh` 0 / `push.sh` 1 / `boundary.sh` 7 / `finalize.sh` 6。コメント行を含む）は機械的に数えた値である
- （0005）5 本すべてが本体の先頭で `cd "$LOGGER_ROOT"` すること（`ticket.sh:342` / `commit.sh:96` / `push.sh:65` / `boundary.sh:664` / `finalize.sh:538`）。`check-html.sh:61` と `run-tests.sh:62` も同じ形
- （0005）提供コマンド 5 本に `lock` の語が 1 件も無いこと（`grep -rn lock` が 0 件。`blocked` を除く）
- （0005）現物の `logs/mr.json` の `.issue` が `null` であること（`cat logs/mr.json`）

## 確かめられなかったこと

| 対象 | 確かめられなかった理由 | 引き取り先 |
|---|---|---|
| Claude が worktree に入ったとき、`cwd` が本当に各イベント（SessionStart / UserPromptSubmit / PreToolUse / PostToolUse / SubagentStart / SubagentStop）で worktree を指すか | 公式ドキュメントの原文を読むには `web` が要るが、0004 の `allow.ops` は `read` / `remote-read` のみ。本レポートは DDR `i0009-55` が引用した原文（`hooks.md:598-601`）を二次資料として使った。原文が言及しているのは `cwd` フィールド一般で、イベントごとの明示は引用の範囲に無い | 0006（観点 C。`allow.ops` に `web` あり）と 0009（実測） |
| `EnterWorktree` / `ExitWorktree` というツールが実在するか、Claude が worktree に入る手段は何か | 同上（外部仕様）。リポジトリ内の根拠はフック共通仕様 §13 の記述だけで、これは自プロジェクトの文書であり一次資料ではない | 0006 / 0009 |
| Skill ツールが読み込む `SKILL.md` は本流と worktree のどちらの実体か | 外部仕様。これが決まらないと `session-start.sh:140`（`__se_has_skill`）の正誤が確定しない | 0006 / 0010（AI アセット設計） |
| `git worktree add` が実際に書く `.git` ファイルと `.git/worktrees/<名前>/gitdir` の中身（絶対 / 相対、Windows でのパス表記） | `git worktree` は `scope.sh` の git 分類に無く、どの `allow.ops` を宣言しても WF204 で拒否される（全体計画書の差分 2）。実行は人間に回す | 0009（実測手順 P0） |
| 6 本のフックを `cwd` = worktree で走らせたときの実際の出力 | 同上。作業ツリーを作れないため | 0009（実測手順 P1〜P7） |
| `logs/` が無い worktree で提供コマンド 5 本（`ticket.sh` ほか）が何を読み、どう振る舞うか | 観点 B（0005）の担当範囲。本レポートはフック側の `logs/` 依存だけを見た | 0005 |
| （0005）worktree で `bash .claude/skills/…/ticket.sh` を実際に走らせたときの `LOGGER_ROOT` の実値 | `git worktree add` も `cd` もどの `allow.ops` を宣言しても WF204 で拒否されるため、`__ss_load` を読んだ静的解析までしか進めない。本チケットでも `cd` を含むコマンドが 1 回拒否された | 0009（実測手順 B3） |
| （0005）`CLAUDE_PROJECT_DIR` がフック以外の経路（Skill が起動した Bash、サブエージェントの Bash）で設定されるか | 本セッションの Bash ツールでは未設定だったが、他の起動経路を自分で切り替えられない。設定されると `__ss_load` の 2 段目が効き、`LOGGER_ROOT` がセッションの起点に倒れる | 0006（外部仕様）／0009（実測手順 B2） |
| （0005）`logs/usage/<branch>.json` の集計が作業ツリーをまたいで分断されたときの実害の大きさ | 実際に 2 つのツリーで push しないと測れない。読み取りでは「別ファイルになる」ところまでしか言えない | 0009（実測手順 B6） |
| （0005）前 issue の `logs/mr.json` を掴んだ `boundary.sh status`（`logs/sh/boundary.log` の 2026-09-04T22:09:45）の**出力そのもの** | `boundary.sh` は `status` の出力をログに残さない（`start subcommand=status` と結果行だけ）。当時の会話ログは本ブランチの `wip/` に無い | 実測不要（コードの経路で説明できる。e13-2） |
| （0005）`logs/mr.json` の `.issue` が **いつから** null なのか（過去の issue でも null だったのか） | `logs/` は追跡外なので履歴が無く、現物の 1 世代しか読めない | 追えない（`write_mr_json` に書き手が無いことから、初回作成時は常に null と言える。e13-3） |

## 実施条件（測った対象・環境）

- 対象コミット: `feature-50-worktree-parallel-tickets` の `65d908e`（チケット 0004 の基準点は `9721416`）
- 実行したのは読み取りのコマンドだけ（`grep -rn` / `sed -n` / `git ls-files` / `git ls-tree` / `git rev-parse` / `git log -S`）。ファイルの作成は `wip/30_reports/` と `wip/tmp/` のみ
- 参照の数え方: `grep -rn "HOOK_ROOT\|HOOK_WORKTREE" .claude/hooks/ | wc -l` = 81（行数）、`grep -rno ... | wc -l` = 90（箇所数。内訳 `HOOK_ROOT` 28 / `HOOK_WORKTREE` 62）、テストを除いた本体 = 71 行
- （0005）対象コミット: `feature-50-worktree-parallel-tickets` の `f83cdfd`（チケット 0005 の基準点は `719c098`）
- （0005）実行したのは読み取りのコマンドだけ（`grep -rn` / `sed -n` / `cat` / `ls` / `find` / `wc` / `jq`（ローカルの `logs/*.json` を読むだけ）／ `git ls-files` / `git log -S` / `echo` による環境変数の確認）。ファイルの作成は `wip/30_reports/` と `wip/tmp/` のみ
- （0005）`cd` を含むコマンドが WF204 で 1 回拒否されたため、以後はすべて絶対パスと `git -C` で読んだ
- （0005）`CLAUDE_PROJECT_DIR` は本セッションの Bash ツールでは**未設定**、`PWD` は MSYS 形式（`/c/Users/…`）だった。フック側の `HOOK_WORKTREE` は `__hc_winpath` で `C:/…` に正規化されるので、同じディレクトリでも 2 つの根は**文字列としては別表記**になる

## 実施した内容と結果

### e1. 作業ツリーは `cwd` から上向きに解決され、相互参照の検査を通ったときだけ worktree 側になる ◎良

`hook-common.sh` の該当箇所は次の 4 つで、これがすべての判定の入口である。

| 行 | 内容 |
|---|---|
| `hook-common.sh:17-19` | `HOOK_ROOT` は `BASH_SOURCE` から `lib → hooks → .claude → ルート` と 3 段上がって決まる（環境変数 `HOOK_ROOT` / `LOGGER_ROOT` があればそれを優先）。フックは `settings.json` に `${CLAUDE_PROJECT_DIR}` 基準の絶対パスで登録されている（`tests/fixtures/settings-hooks.expected.tsv` 全 16 行）ので、**`HOOK_ROOT` は常にセッション開始時のプロジェクトルート = 本流**になる |
| `hook-common.sh:31` | 初期値は `HOOK_WORKTREE="$HOOK_ROOT"`（= 解決に失敗したら本流に倒れる） |
| `hook-common.sh:319-331` | `__hc_resolve_worktree`。`HOOK_CWD` が空、または `HOOK_ROOT` と同じなら即戻る。違えば `cwd` から上向きに `[[ -d "$d/.claude" ]]` を探し、見つかった候補が `__hc_is_worktree_of` を通ったときだけ `HOOK_WORKTREE` に採る。`git` を呼ばない（DDR `i0009-22`） |
| `hook-common.sh:369` | 呼び出しは `hook_read_input` の末尾 1 か所だけ。**`hook_read_input` を呼ぶフックはすべて自動的にこの解決を通る**（6 本とも呼んでいる） |

`__hc_is_worktree_of`（`hook-common.sh:293-316`）が要求するのは**相互参照の双方向**である。

1. 候補直下の `.git` が**ファイル**で、その `gitdir:` が正規化後に `<HOOK_ROOT>/.git/worktrees/` 配下を指し、その先が実在してディレクトリで `gitdir` ファイルを持つこと
2. その `<...>/gitdir` の中身が候補の `.git` を指し返すこと

したがって次の 3 つは worktree として採られず、本流に倒れる（= 安全側）。

- `.claude` を持つだけの別ディレクトリ（`参考ディレクトリ/agent-workflow/` など。DDR `i0009-64` の背景そのもの）
- `git worktree add` の後に作業ツリーを消した stale な登録だけが残っている場所
- ディレクトリを移動した後で `git worktree repair` を掛けていない作業ツリー（片方向が古い）

3 つ目は DDR `i0009-64` が「両方を要求すると正しい worktree を本流に倒してしまう」として明示的に**却下した副作用**であり、実装は却下したはずの側になっている（e6 で扱う）。倒れる先は本流なので無効化にはならない。

答え（観点 A の主文）: **フックは worktree 側の `wip/` と `logs/` を見て判定する。ただし「`cwd` が worktree を指していること」と「相互参照が双方向に成立していること」の 2 条件が要り、どちらかが欠けると黙って本流側の状態で判定する。**

### e2. `HOOK_ROOT` / `HOOK_WORKTREE` の全参照 81 行の判定 △注意

`grep -rn "HOOK_ROOT\|HOOK_WORKTREE" .claude/hooks/` の全出力を、次の 5 群に割った。

- **W**: 作業ツリーの状態（`wip/` / `logs/` / `git -C`）を指す = `HOOK_WORKTREE` が正。現状も `HOOK_WORKTREE` → 一致
- **R**: スクリプト・設定の実体を指す = `HOOK_ROOT` が正。現状も `HOOK_ROOT` → 一致
- **C**: 変数の定義行・コメント（判定の対象外）
- **X**: 取り違え、またはその疑い
- **T**: テストが検査のために設定している行（判定の対象外）

| 群 | 件数 |
|---|---|
| W（作業ツリーの状態。一致） | 55 |
| R（置き場。一致） | 8 |
| C（定義・コメント） | 4 |
| **X（取り違え・疑い）** | **4** |
| T（テストの設定） | 10 |
| 合計 | **81** |

#### 全参照の一覧

| ファイル:行 | 参照 | 指しているもの | 正 | 判定 |
|---|---|---|---|---|
| `00-SessionStart/session-start.sh:47` | `HOOK_WORKTREE` | `logs/sessions` の掃除 | 作業ツリー | W |
| `00-SessionStart/session-start.sh:66` | `HOOK_WORKTREE` | `logs/<状態ファイル>` の破損検査 | 作業ツリー | W |
| `00-SessionStart/session-start.sh:74` | `HOOK_WORKTREE` | `boundary.sh` のパス | 置き場（原則は `HOOK_ROOT`） | **X** |
| `00-SessionStart/session-start.sh:113` | `HOOK_WORKTREE` | `git branch --show-current` | 作業ツリー | W |
| `00-SessionStart/session-start.sh:115` | `HOOK_WORKTREE` | `logs/mr.json` の存在 | 作業ツリー | W |
| `00-SessionStart/session-start.sh:116` | `HOOK_WORKTREE` | `logs/mr.json` の issue | 作業ツリー | W |
| `00-SessionStart/session-start.sh:117` | `HOOK_WORKTREE` | `logs/mr.json` の url | 作業ツリー | W |
| `00-SessionStart/session-start.sh:120` | `HOOK_WORKTREE` | `logs/merge-state.json` の存在 | 作業ツリー | W |
| `00-SessionStart/session-start.sh:121` | `HOOK_WORKTREE` | 同 JSON の検査 | 作業ツリー | W |
| `00-SessionStart/session-start.sh:122` | `HOOK_WORKTREE` | 同 state の取り出し | 作業ツリー | W |
| `00-SessionStart/session-start.sh:140` | `HOOK_WORKTREE` | `.claude/skills/<名前>/SKILL.md` の存在 | 置き場（`HOOK_ROOT` が正） | **X** |
| `10-UserPromptSubmit/workflow-entry.sh:38` | `HOOK_ROOT` | `config/entry-skills.txt` | 置き場 | R |
| `10-UserPromptSubmit/workflow-entry.sh:143` | `HOOK_WORKTREE` | `wip/10_tickets/<状態>` の有無 | 作業ツリー | W |
| `12-SubagentStart/subagent-start-check.sh:41` | `HOOK_WORKTREE` | `10_doing/*.md` | 作業ツリー | W |
| `12-SubagentStart/subagent-start-check.sh:42` | `HOOK_WORKTREE` | `00_todo/*.md` | 作業ツリー | W |
| `12-SubagentStart/subagent-start-check.sh:67` | `HOOK_ROOT` | `config/model-aliases.txt` | 置き場 | R |
| `13-SubagentStop/subagent-stop-check.sh:53` | `HOOK_WORKTREE` | `10_doing/*.md` | 作業ツリー | W |
| `13-SubagentStop/subagent-stop-check.sh:83` | `HOOK_WORKTREE` | `git rev-parse --git-dir` | 作業ツリー | W |
| `13-SubagentStop/subagent-stop-check.sh:97` | `HOOK_WORKTREE` | `git status --porcelain` | 作業ツリー | W |
| `13-SubagentStop/subagent-stop-check.sh:211` | `HOOK_WORKTREE` | `logs/hooks/decisions.jsonl` | 作業ツリー | W |
| `13-SubagentStop/subagent-stop-check.sh:225` | `HOOK_ROOT` | `config/model-aliases.txt` | 置き場 | R |
| `20-PreToolUse/block-chmod.sh:33` | `HOOK_ROOT` | `config/blocked-commands.txt` | 置き場 | R |
| `20-PreToolUse/workflow-guard.sh:84` | `HOOK_WORKTREE` | WF209 の文面に出す作業ツリー | 作業ツリー | W |
| `20-PreToolUse/workflow-guard.sh:133` | `HOOK_WORKTREE` | `10_doing/*.md` の一覧 | 作業ツリー | W |
| `20-PreToolUse/workflow-guard.sh:145` | `HOOK_WORKTREE` | 作業中チケットの実体 | 作業ツリー | W |
| `20-PreToolUse/workflow-state-guard.sh:123` | `HOOK_WORKTREE` | チケットの実在確認（WF302） | 作業ツリー | W |
| `22-PostToolUse/post-push-compact-prompt.sh:34` | `HOOK_WORKTREE` | `logs/push-state.json` | 作業ツリー | W |
| `22-PostToolUse/post-push-compact-prompt.sh:47` | `HOOK_WORKTREE` | `git rev-parse --abbrev-ref HEAD` | 作業ツリー | W |
| `22-PostToolUse/post-push-compact-prompt.sh:56` | `HOOK_WORKTREE` | `push_detect` の第 5 引数 | 作業ツリー | W |
| `22-PostToolUse/post-push-compact-prompt.sh:63` | `HOOK_WORKTREE` | `git remote get-url origin` | 作業ツリー | W |
| `22-PostToolUse/post-push-compact-prompt.sh:82` | `HOOK_WORKTREE` | `git symbolic-ref` | 作業ツリー | W |
| `22-PostToolUse/post-push-compact-prompt.sh:88` | `HOOK_WORKTREE` | `logs/mr.json` の存在 | 作業ツリー | W |
| `22-PostToolUse/post-push-compact-prompt.sh:90` | `HOOK_WORKTREE` | 同 JSON の読み取り | 作業ツリー | W |
| `22-PostToolUse/post-push-compact-prompt.sh:133` | `HOOK_WORKTREE` | `git diff --name-only` | 作業ツリー | W |
| `22-PostToolUse/post-push-usage-report.sh:47` | `HOOK_WORKTREE` | `git rev-parse --abbrev-ref HEAD` | 作業ツリー | W |
| `22-PostToolUse/post-push-usage-report.sh:51` | `HOOK_WORKTREE` | `logs/usage/<branch>.json` | 作業ツリー | W |
| `22-PostToolUse/post-push-usage-report.sh:167` | `HOOK_WORKTREE` | `push_detect` の第 5 引数 | 作業ツリー | W |
| `22-PostToolUse/post-push-usage-report.sh:245` | `HOOK_WORKTREE` | `logs/mr.json` | 作業ツリー | W |
| `22-PostToolUse/post-push-usage-report.sh:283` | `HOOK_WORKTREE` | `logs/usage` の作成 | 作業ツリー | W |
| `22-PostToolUse/post-push-usage-report.sh:284` | `HOOK_WORKTREE` | レポートの書き出し先 | 作業ツリー | W |
| `22-PostToolUse/workflow-diff-check.sh:49` | `HOOK_WORKTREE` | 作業中チケットの実体 | 作業ツリー | W |
| `22-PostToolUse/workflow-diff-check.sh:201` | `HOOK_WORKTREE` | `git rev-parse --git-dir` | 作業ツリー | W |
| `22-PostToolUse/workflow-diff-check.sh:244` | `HOOK_WORKTREE` | `git status --porcelain=v2` | 作業ツリー | W |
| `22-PostToolUse/workflow-diff-check.sh:249` | `HOOK_WORKTREE` | 基準点の解決 | 作業ツリー | W |
| `22-PostToolUse/workflow-diff-check.sh:262` | `HOOK_WORKTREE` | `git diff --name-status` | 作業ツリー | W |
| `22-PostToolUse/workflow-diff-check.sh:293` | `HOOK_WORKTREE` | `20_done/<先行>*.md` | 作業ツリー | W |
| `22-PostToolUse/workflow-diff-check.sh:306` | `HOOK_WORKTREE` | `git show <base>:<チケット>` | 作業ツリー | W |
| `lib/hook-common.sh:19` | `HOOK_ROOT` | `HOOK_ROOT` の決定 | 置き場 | R |
| `lib/hook-common.sh:20` | `HOOK_ROOT` | 区切りの正規化 | 置き場 | R |
| `lib/hook-common.sh:21` | `HOOK_ROOT` | `LOGGER_ROOT` へ代入・export | 置き場（実行ログの出力先も本流に固定される） | **X** |
| `lib/hook-common.sh:30` | 両方 | 節のコメント | — | C |
| `lib/hook-common.sh:31` | 両方 | `HOOK_WORKTREE` の初期値 | — | W |
| `lib/hook-common.sh:255` | 両方 | `__hc_resolve_worktree` のコメント | — | C |
| `lib/hook-common.sh:256` | `HOOK_ROOT` | 同上のコメント | — | C |
| `lib/hook-common.sh:291` | `HOOK_ROOT` | `__hc_is_worktree_of` のコメント | — | C |
| `lib/hook-common.sh:321` | `HOOK_ROOT` | 比較用に正規化 | 置き場 | R |
| `lib/hook-common.sh:322` | 両方 | 既定値の代入（本流に倒す） | 作業ツリー | W |
| `lib/hook-common.sh:327` | `HOOK_WORKTREE` | 候補の採用 | 作業ツリー | W |
| `lib/hook-common.sh:347` | `HOOK_ROOT` | `config/scope-limits.json` | 置き場 | R |
| `lib/hook-common.sh:412` | `HOOK_WORKTREE` | `logs/review-state.json` | 作業ツリー | W |
| `lib/hook-common.sh:413` | `HOOK_WORKTREE` | `logs/merge-state.json` | 作業ツリー | W |
| `lib/hook-common.sh:414` | `HOOK_WORKTREE` | `logs/sessions/<sid>/approvals.json` | 作業ツリー | W |
| `lib/hook-common.sh:415` | `HOOK_WORKTREE` | `logs/sessions/<sid>/entry.json` | 作業ツリー | W |
| `lib/hook-common.sh:478` | `HOOK_WORKTREE` | `10_doing/*.md`（`hook_doing_ticket`） | 作業ツリー | W |
| `lib/hook-common.sh:604` | `HOOK_WORKTREE` | `logs/locks/<name>.lock` の取得 | 作業ツリー | W |
| `lib/hook-common.sh:624` | `HOOK_WORKTREE` | 同ロックの解放 | 作業ツリー | W |
| `lib/hook-common.sh:634` | `HOOK_WORKTREE` | 同ロックの一括解放 | 作業ツリー | W |
| `lib/hook-common.sh:654` | `HOOK_WORKTREE` | `logs/hooks/decisions.jsonl` | 作業ツリー | W |
| `lib/hook-common.sh:744` | `HOOK_WORKTREE` | `logs/sessions/<sid>`（`hook_session_dir`） | 作業ツリー | W |
| `lib/hook-common.sh:758` | `HOOK_WORKTREE` | `hook_rel_path` の基準 | 作業ツリー | W |
| `lib/push-detect.sh:29` | `HOOK_ROOT` | `root` の既定値（`git -C` に使う） | 作業ツリー | **X** |
| `lib/tests/test_hook_common.sh:17` | `HOOK_ROOT` | テストの一時リポジトリ | — | T |
| `lib/tests/test_hook_common.sh:253` | 両方 | 同上 | — | T |
| `lib/tests/test_hook_common.sh:415` | 両方 | 解決の呼び出し | — | T |
| `lib/tests/test_hook_common.sh:417` | `HOOK_ROOT` | 退避 | — | T |
| `lib/tests/test_hook_common.sh:418` | `HOOK_ROOT` | 差し替え | — | T |
| `lib/tests/test_hook_common.sh:499` | `HOOK_ROOT` | 復帰 | — | T |
| `lib/tests/test_push_detect.sh:21` | `HOOK_ROOT` | テストの一時リポジトリ | — | T |
| `lib/tests/test_push_detect.sh:30` | `HOOK_ROOT` | `push_detect` の第 5 引数 | — | T |
| `lib/tests/test_scope.sh:48` | `HOOK_ROOT` | 偽のルート | — | T |
| `tests/test_config_integrity.sh:32` | `HOOK_ROOT` | 偽のルート | — | T |

#### 取り違え 4 件の内訳

| # | 箇所 | 何が起きるか | いま誤判定を生むか |
|---|---|---|---|
| X1 | `session-start.sh:140` `__se_has_skill` | 次に読み込むスキルの `SKILL.md` の**存在**を worktree 側で見る。Skill ツールが実際に読むのが本流の実体なら、worktree の分岐元に無いスキルは「無い」と案内され、逆に worktree にしか無いスキルは読めないのに案内される | いいえ（案内文の分岐だけ。判定・拒否には効かない）。ただし Skill の読み込み元が未確定（「確かめられなかったこと」） |
| X2 | `session-start.sh:74` `boundary.sh` のパス | 仕様 §2「スクリプトの置き場は常に `HOOK_ROOT`」に反する。ただし `boundary.sh` は `__ss_load` で自分の `BASH_SOURCE` からルートを決めるため、本流の実体を呼ぶと本流の `wip/` を読み、worktree の現在地が出せない。**原則どおりに直すと壊れる**。worktree に `.claude/` の実体が無い場合（分岐元にスキルが無い等）は「boundary.sh が無い」として現在地を出さずに終了する（`session-start.sh:75-79`） | いいえ（現在の運用では `.claude/` は追跡されており worktree にも実体がある） |
| X3 | `hook-common.sh:21` `LOGGER_ROOT="$HOOK_ROOT"` | 実行ログ（`logger.sh` が書く `<LOGGER_ROOT>/logs/sh/hook-*.log`。`logger.sh:5,11,17`）は**常に本流側**に出る。一方 `hook_record` の `decisions.jsonl` は worktree 側（`hook-common.sh:654`）。**同じ 1 回の判定の記録が 2 つの作業ツリーに割れる** | いいえ（記録の分散であって判定は変わらない）。ただし調査時に片方しか見ないと事実を取り違える |
| X4 | `push-detect.sh:29` `root="${5:-${HOOK_ROOT:-$PWD}}"` | `root` は `git -C "$root" rev-parse`（52・54・56・58 行）に使われる = 作業ツリーの状態なので `HOOK_WORKTREE` が正。既定値だけが `HOOK_ROOT` | いいえ（呼び出し 2 か所はどちらも `HOOK_WORKTREE` を渡している。`post-push-compact-prompt.sh:56` / `post-push-usage-report.sh:167`）。第 5 引数を省く呼び手が増えた瞬間に本流を見る潜在的な取り違え |

### e3. 6 本のフックはすべて worktree 側で判定する（`session-start` だけ実質「開始したディレクトリ」）◎良

| フック | 判定に使う状態 | 根拠（ファイル:行） | 結論 |
|---|---|---|---|
| `workflow-guard` | 作業中チケットの枚数と実体、書き込み先のルート相対化 | `hook-common.sh:478`（`hook_doing_ticket` が `$HOOK_WORKTREE/wip/10_tickets/10_doing/*.md`）、`workflow-guard.sh:145`（チケットの実体）、`workflow-guard.sh:133`（2 枚以上の一覧）、`hook-common.sh:758`（`hook_rel_path` の基準）、`workflow-guard.sh:84`（作業ツリー外を WF209） | **worktree 側** |
| `workflow-diff-check` | 作業中チケット、`git status` / `git diff` / `git show`、先行チケットの完了 | `workflow-diff-check.sh:49, 201, 244, 249, 262, 293, 306`（すべて `$HOOK_WORKTREE` / `git -C "$HOOK_WORKTREE"`） | **worktree 側**（仕様 §13 の記述と逆。e6） |
| `workflow-entry` | 継続条件（`00_todo` / `10_doing` / `20_done` にチケットがあるか）、宣言・レビュー・マージの記録 | `workflow-entry.sh:143`（3 つの置き場を `$HOOK_WORKTREE` で走査）、`hook-common.sh:412-415`（`logs/` の 4 状態）。設定 `entry-skills.txt` だけ `HOOK_ROOT`（`workflow-entry.sh:38`） | **worktree 側** |
| `workflow-state-guard` | 進行状態ファイル・`10_doing` / `20_done` の置き場・draft 解除 | `workflow-state-guard.sh:63-67`（`__sg_rel` → `hook_rel_path` → `hook-common.sh:758`）、`workflow-state-guard.sh:123`（チケットの実在確認）。保護対象の一覧は `scope-limits.json`（`HOOK_ROOT`。`hook-common.sh:347`） | **worktree 側**（ただし作業ツリーの外を指す絶対パスは保護対象と照合されない。e5） |
| `session-start` | `logs/sessions` の掃除、`logs/` の状態ファイル、`git branch`、`boundary.sh status --offline` | `session-start.sh:47, 66, 74, 113, 115-122` | **worktree 側**。ただし SessionStart は `source` が `startup` / `resume` / `clear` / `compact` のときにしか走らず、その時点の `cwd` で固定される。セッション開始後に worktree へ入っても**再実行されない**ので、実質は「セッションを開始したディレクトリ」で判定される |
| `subagent-stop-check` | 作業中チケット、`git status`、`decisions.jsonl` | `subagent-stop-check.sh:53, 83, 97, 211`。`model-aliases.txt` だけ `HOOK_ROOT`（`225`） | **worktree 側** |

（参考。6 本の対象外だが同じ経路）`subagent-start-check` も worktree 側（`subagent-start-check.sh:41-42`）、`block-chmod` は作業ツリーに依存しない（設定のみ。`block-chmod.sh:33`）。

いずれも `hook_read_input`（`hook-common.sh:369` で `__hc_resolve_worktree` を呼ぶ）を通っているので、**フック側に個別の実装漏れは無い**。作業ツリーの決定は 1 か所に集約されている。

### e4. `logs/` は worktree に複製されず、宣言・承認・進行状態が `missing` に落ちる △注意

- `.gitignore` に `logs/`（ディレクトリ丸ごと）があり、`git ls-files logs/` は **0 件**。`git ls-files wip/` は **19 件**で `wip/tmp/*` だけが除外（`.gitignore` の `wip/tmp/*` と `!wip/tmp/.gitkeep`）
- したがって `git worktree add` で作った作業ツリーには **`wip/` は分岐元のコミットの内容で存在し、`logs/` は存在しない**

`logs/` が無いときの各状態の落ち方は次のとおり。

| 状態ファイル | 読む場所 | 無いときの振る舞い | 効き先 |
|---|---|---|---|
| `logs/sessions/<sid>/entry.json` | `hook-common.sh:415` | `HC_ENTRY_STATE=missing` → `workflow-entry.sh:205` が **WF102 で deny**（未宣言として扱う） | worktree に入った直後、チケットが 1 枚も無ければ書き込み・実行が止まる（拒否側なので無効化ではない） |
| `logs/sessions/<sid>/approvals.json` | `hook-common.sh:414` | 承認の記憶が空 → `workflow-guard` の WF202 / WF203 を**取り直し** | 同じパスに何度も確認が出る |
| `logs/review-state.json` / `logs/merge-state.json` | `hook-common.sh:412-413` | `missing` → 継続条件のレビュー待ち・マージ前作業の緩和が効かない | 切れ目の運用が worktree では成立しない |
| `logs/mr.json` | `session-start.sh:115` | issue / MR の行が出ない | 現在地の案内が痩せる |
| `logs/locks/<name>.lock` | `hook-common.sh:604, 624, 634` | 作業ツリーごとに別のロック（`mkdir -p` で作られる） | **本流と worktree で同じ名前のロックが同時に取れる**。`usage-<branch>.lock` のように「同じブランチの記録」を守るロックは、作業ツリーをまたぐと排他にならない |
| `logs/hooks/decisions.jsonl` | `hook-common.sh:654` | `hc_append_jsonl` が `mkdir -p` で作る（`hook-common.sh:580`） | 判定記録は worktree 側に貯まる。一方、実行ログは本流側（X3） |

書き込み側は `hc_append_jsonl` / `hc_json_write` がどちらも `mkdir -p "${f%/*}"` を行うので（`hook-common.sh:580` / `590`）、**`logs/` は初回の判定で自動的に作られる**。「無いと落ちる」のではなく「無いところから始まる」。ただし何を初期値にするかは決まっていない（調査計画書の保留 P2 のとおり）。

### e5. 作業ツリーをまたぐ絶対パスの書き込みは、進行状態ファイル保護をすり抜ける ✕問題

`workflow-state-guard` の照合は次の順で行われる。

1. `__sg_rel`（`workflow-state-guard.sh:63-67`）→ `hook_rel_path`（`hook-common.sh:757-770`）。**`HOOK_WORKTREE` の配下のときだけ**先頭を落としてルート相対にする。配下でなければ**絶対パスのまま返す**
2. `__sg_is_state_file`（69-76 行）は `scope-limits.json` の `common.state_files`（`logs/mr.json` など）と glob で照合
3. `__sg_in_dir`（78-82 行）は `wip/10_tickets/20_done` / `10_doing` と**前方一致**で照合

絶対パス（`C:/…/issue-mr-ticket-workflow/logs/mr.json`）は 2 でも 3 でも一致しないので、**`hook_allow` に落ちる**。つまり Claude が worktree W にいるとき、本流の

- `logs/mr.json` / `logs/review-state.json` / `logs/merge-state.json`（WF301 の対象）
- `wip/10_tickets/20_done/*.md`（WF303 の対象）
- `wip/10_tickets/10_doing/*.md` の新規作成（WF302 の対象）

を絶対パスで直接書き換えても、`workflow-state-guard` は止めない。逆向き（本流のセッションから worktree の同じ場所へ）も同じである。

二重の守りである `workflow-guard` は、`__wg_rel`（`workflow-guard.sh:70-96`）が作業ツリー外を **WF209 で deny** するので、この経路を塞ぐ。ただし `workflow-guard` は **作業中チケットが 1 枚あるときしか働かない**（`workflow-guard.sh:59`「`[[ -n "$__WG_NAME" ]] || exit 0`」）。したがって:

- **W に作業中チケットが 1 枚あるとき** → WF209 で止まる（守りは 1 枚だけ効いている）
- **W に作業中チケットが無いとき**（分岐元にチケットが無い / 切れ目）→ `workflow-guard` は即座に抜け、`workflow-state-guard` も一致しない。残るのは `workflow-entry` の宣言だけで、宣言済みのセッションなら**本流の進行状態ファイルと完了済みチケットを自由に書き換えられる**

フック共通仕様 §13 は「作業中チケットが無い切れ目でも、機構が守るのは進行状態・コミット / push・`chmod`（常時フック）まで」と約束している。**作業ツリーをまたぐ絶対パス指定では、この「常時」の約束が成立しない**。

なお、これは「worktree を使うと壊れる」ではなく「作業ツリーが 2 つ以上あると、他方の保護対象は自分の保護の外にある」という構造的なもので、`hook_rel_path` が 1 つの作業ツリーしか基準に持たない設計の帰結である。

### e6. 仕様書・DDR とコードの食い違いが 2 件 △注意

| # | 文書の記述 | コードの実際 | どちらが正か |
|---|---|---|---|
| D1 | フック共通仕様 §13「**worktree の中の差分の事後検査**: `workflow-diff-check`（WF601）は `HOOK_ROOT` の作業ツリーだけを見る。worktree の中で起きた書き込みは事後の差分検査に現れない」（`10_spec/フック共通仕様.md:389`）。DDR `i0009-64`「残る穴」も同じことを書く | `workflow-diff-check.sh` は 201・244・249・262・306 行で `git -C "$HOOK_WORKTREE"`、49・293 行で `$HOOK_WORKTREE` を使う。`git log -S` で追うと初版（`7cf83a2`）からこの形 | **コードが正**（=「穴」は最初から無かった可能性が高い）。文書が古い。ただし 0031 の実測がなぜ「現れない」と結論したのかは追えていない（残課題 R2） |
| D2 | DDR `i0009-64`「判定は fork ゼロの 2 経路のどちらかが成り立つこと。**片方でよい**」「両方を要求すると正しい worktree を本流に倒してしまう」 | `__hc_is_worktree_of`（`hook-common.sh:293-316`）は**相互参照の双方向**を要求し、登録側だけから探す経路を明示的に置かないと書いている。仕様 §2（`:99`）も「相互参照が成立すること」と双方向で書かれている | **コードと仕様 §2 が正**。DDR の「決定」節が古い（「影響」節に「相互参照を双方向にしたのは 0036」とだけ書かれている）。帰結として、DDR が守ろうとした「ディレクトリ移動後（`git worktree repair` 前）の作業ツリー」は本流に倒れる |

DDR は経緯の記録なので後から書き換えない運用だが、**「決定」節だけを読むと現在の実装を誤解する**。設計フェーズが `i0009-55` / `i0009-64` を根拠に使うときは仕様 §2 を正とすること。

### e7. 既存テストが検証済みの範囲と、実測でしか確かめられない残余 △注意

`grep -rln worktree` を `.claude/hooks/**/tests/` に掛けると **`lib/tests/test_hook_common.sh` の 1 本だけ**が当たる（`worktree` の出現 31 回）。該当は `case_worktree`（405〜502 行）で、コメントに「専用の ID は無いので `HK-T18` に付ける」とある。フック共通仕様 §11 のテスト一覧（`:356-375`）に **作業ツリー解決のテスト ID は無い**（`HK-T18` は「副入力の縮退」として定義されている。`:373`）。

**検証済み（`case_worktree`）**

| # | 固定していること | 行 |
|---|---|---|
| 1 | `cwd` がルート自身・その配下 → ルート | 419-421 |
| 2 | 相互参照が成立する作業ツリー・その配下 → worktree 側 | 423-425 |
| 3 | `.claude` を持つだけの別ディレクトリ（参考実装） → ルート | 427 |
| 4 | `.git` が普通のディレクトリ（別クローン） → ルート | 429-430 |
| 5 | `gitdir:` の指す先が実在しない偽の `.git` ファイル → ルート | 432-434 |
| 6 | 指す先はあるが `gitdir` が無い（片方向） → ルート | 436-437 |
| 7 | 指す先の `gitdir` が別の作業ツリーを指す（なりすまし） → ルート | 439-440 |
| 8 | 相互参照が揃えば拾う（3〜7 の対照） | 442-443 |
| 9 | 本流の配下の `.claude` は拾わない / 相互参照が成立する内側の worktree は拾う / 片方向に崩すと拾わない | 445-453 |
| 10 | `gitdir:` が `..` で `worktrees/` の外を指す traversal → ルート | 455-462 |
| 11 | `.` や余分な `/` を含む正当な指し先は畳んで受け入れる | 464-466 |
| 12 | 負のコントロール（本物の worktree でも参照を両方消すと拾わない） | 467-469 |
| 13 | stale な登録だけが残っている場所 → ルート、候補側に正しい `.git` を置けば拾う | 470-482 |
| 14 | `__hc_winpath` の正規化 7 ケース（`/c/…` → `C:/…`、`\` → `/`、末尾の `/`、`.`、`..`、traversal、相対） | 484-491 |
| 15 | 存在しない `cwd` → ルート | 493 |

**検証されていない（= 実測が要る残余）**

| # | 残余 | なぜテストで代えられないか |
|---|---|---|
| A | `git worktree add` が実際に書く `.git` / `gitdir` の中身で `__hc_is_worktree_of` が通るか | `case_worktree` はファイルを**手で書いて**相互参照を作っている。実物のパス表記（絶対 / 相対、Windows のドライブ表記、改行コード）が同じである保証はコードの中に無い |
| B | 6 本のフックを `cwd` = worktree で端から端まで走らせた結果 | フックのテスト（`test_workflow_guard.sh` ほか）は `HOOK_ROOT` と `HOOK_WORKTREE` を同じ一時リポジトリに固定して走る（`test_hook_common.sh:253` と同型）。worktree を分けたケースが 1 件も無い |
| C | `logs/` が無い作業ツリーでの通し（WF102 が出るか、`decisions.jsonl` が作られるか） | 同上。`logs/` の不在は単体テストでは作れているが、フック 6 本の通しでは固定されていない |
| D | Claude が worktree に入ったとき、各イベントの `cwd` が実際に worktree になるか | 外部（Claude Code 本体）の挙動。リポジトリ内のテストでは原理的に検査できない |
| E | 作業ツリーをまたぐ絶対パス書き込み（e5）が実際にすり抜けるか | 同 B。読み取りでは「照合に一致しない」ところまでしか言えない |

### e8. 実測手順（人間が実行する。コマンド列 + 観点ごとの予測）◎良

**前提**

- 実行は**人間**が行う。`git worktree add` / `git checkout -b` / `git switch` / `cd` はどの `allow.ops` を宣言しても機構が WF204 で拒否するため、AI からは実行できない（全体計画書の差分 2。本チケットでも `cd` と `git worktree list` を含むコマンドが WF204 で拒否された）
- 実行結果は **`wip/tmp/worktree-probe/`** に置く（`.gitignore` の `wip/tmp/*` により追跡されない。同一作業ツリーなので後続チケット 0009 が読める）
- Git Bash で、本流のリポジトリルートを `cwd` にして実行する。`bash <スクリプト>` の形で**フックを直接叩く**のが主で、Claude を worktree に入れる実測（P8）は補助
- 副作用: フックを叩くと作業ツリー側の `logs/`（`decisions.jsonl` / `sessions/`）と本流の `logs/sh/` にログが増える。どちらも `.gitignore` の対象

**P0. 準備と、相互参照の実物の記録**

```bash
cd /c/Users/taniyama/Desktop/git/issue-mr-ticket-workflow
mkdir -p wip/tmp/worktree-probe
MAIN="$(pwd)"
git worktree add --detach ../imtw-probe-main main    # W1: チケット 0 枚（main の 10_doing は .gitkeep のみ）
git worktree add --detach ../imtw-probe-head HEAD    # W2: 0004 が 10_doing にある
W1="$(cd ../imtw-probe-main && pwd)"; W2="$(cd ../imtw-probe-head && pwd)"
{
  echo "== MAIN=$MAIN W1=$W1 W2=$W2"
  echo "== W1/.git";            cat "$W1/.git"
  echo "== worktrees/*/gitdir"; cat .git/worktrees/imtw-probe-main/gitdir
  echo "== W2/.git";            cat "$W2/.git"
  echo "== doing in W1";        ls -1 "$W1/wip/10_tickets/10_doing/"
  echo "== doing in W2";        ls -1 "$W2/wip/10_tickets/10_doing/"
  echo "== logs in W1";         ls -d "$W1/logs" 2>&1
  echo "== logs in W2";         ls -d "$W2/logs" 2>&1
} > wip/tmp/worktree-probe/00-setup.txt 2>&1
```

予測: `W1/.git` は `gitdir: <MAIN>/.git/worktrees/imtw-probe-main` の 1 行、`worktrees/imtw-probe-main/gitdir` は `<W1>/.git`（相互参照が双方向に成立）。`W1` の `10_doing` は `.gitkeep` のみ、`W2` は `.gitkeep` と `0004-investigation.md`。`logs` は W1・W2 とも存在しない。
外れたとき: パスが相対や別表記で書かれていれば `__hc_is_worktree_of`（`hook-common.sh:293-316`）の前方一致が成立するか怪しく、e1 の結論の前提が崩れる。

**P1. 作業ツリー解決そのもの（`__hc_resolve_worktree` 単体）**

```bash
for D in "$MAIN" "$MAIN/wip" "$W1" "$W1/wip" "$W2" "$MAIN/参考ディレクトリ/agent-workflow"; do
  printf '%s -> ' "$D"
  HOOK_ROOT="$MAIN" bash -c '. "$1/.claude/hooks/lib/hook-common.sh"; HOOK_CWD="$2"; __hc_resolve_worktree; printf "%s\n" "$HOOK_WORKTREE"' _ "$MAIN" "$D"
done > wip/tmp/worktree-probe/01-resolve.txt 2>&1
```

（`HOOK_CWD` は `hook-common.sh:25` で空に初期化されるので、**source した後に代入する**こと。）

予測: `MAIN` と `MAIN/wip` → `MAIN`。`W1` と `W1/wip` → `W1`。`W2` → `W2`。`参考ディレクトリ/agent-workflow` → `MAIN`（DDR `i0009-64` の全面バイパス対策が効く）。
外れたとき: 参考ディレクトリが自分自身に解決されるなら `i0009-64` の対策が実環境で効いていない（重大）。W1・W2 が `MAIN` に落ちるなら実物の `.git` 表記が P0 の予測と違う。

**P2. `workflow-guard`（作業中チケットをどちらのツリーで数えるか）**

```bash
gp() { printf '{"session_id":"probe","transcript_path":"","cwd":"%s","hook_event_name":"PreToolUse","permission_mode":"default","tool_name":"Write","tool_input":{"file_path":"%s/apl/probe.txt","content":"x"}}' "$1" "$1"; }
{ echo "== cwd=W1"; gp "$W1" | bash .claude/hooks/20-PreToolUse/workflow-guard.sh; echo "exit=$?"
  echo "== cwd=W2"; gp "$W2" | bash .claude/hooks/20-PreToolUse/workflow-guard.sh; echo "exit=$?"
  echo "== cwd=MAIN（負のコントロール）"; gp "$MAIN" | bash .claude/hooks/20-PreToolUse/workflow-guard.sh; echo "exit=$?"
} > wip/tmp/worktree-probe/02-guard.txt 2>&1
```

予測: **cwd=W1 は出力なし・exit 0**（W1 は作業中チケット 0 枚なので `workflow-guard.sh:59` で抜ける）。cwd=W2 と cwd=MAIN は `permissionDecision` が `deny`（WF201）か `ask`（WF202）の JSON が 1 行（`apl/probe.txt` は 0004 の `allow.write: wip/**` の外）。
判定: **W1 だけ無音**なら worktree 側で数えている。W1 でも deny / ask が出たら本流のチケットで判定している（= 解決の失敗）。

**P3. `workflow-state-guard`（進行状態ファイル保護と、作業ツリーをまたぐ書き込み。e5 の裏取り）**

```bash
sp() { printf '{"session_id":"probe","transcript_path":"","cwd":"%s","hook_event_name":"PreToolUse","permission_mode":"default","tool_name":"Write","tool_input":{"file_path":"%s","content":"x"}}' "$1" "$2"; }
{ echo "== 自ツリーの 20_done（cwd=W2 / 対象=W2）"
  sp "$W2" "$W2/wip/10_tickets/20_done/0003-investigation-plan.md" | bash .claude/hooks/20-PreToolUse/workflow-state-guard.sh; echo "exit=$?"
  echo "== 他ツリーの 20_done（cwd=W2 / 対象=MAIN）"
  sp "$W2" "$MAIN/wip/10_tickets/20_done/0003-investigation-plan.md" | bash .claude/hooks/20-PreToolUse/workflow-state-guard.sh; echo "exit=$?"
  echo "== 他ツリーの進行状態ファイル（cwd=W2 / 対象=MAIN/logs/mr.json）"
  sp "$W2" "$MAIN/logs/mr.json" | bash .claude/hooks/20-PreToolUse/workflow-state-guard.sh; echo "exit=$?"
} > wip/tmp/worktree-probe/03-state-guard.txt 2>&1
```

予測: 1 つ目は **WF303 の deny**（相対化が効く）。2 つ目・3 つ目は **出力なし**（絶対パスのまま照合され一致しない = e5 のとおり保護が効かない）。
判定: 2 つ目・3 つ目で deny が出れば e5 は誤りなので、その旨を 0009 で訂正する。

**P4. `workflow-entry`（宣言の記録が worktree 側で `missing` になるか）**

```bash
{ echo "== cwd=W1（チケット無し・logs 無し）"
  gp "$W1" | bash .claude/hooks/10-UserPromptSubmit/workflow-entry.sh; echo "exit=$?"
  echo "== cwd=W2（チケット有り）"
  gp "$W2" | bash .claude/hooks/10-UserPromptSubmit/workflow-entry.sh; echo "exit=$?"
} > wip/tmp/worktree-probe/04-entry.txt 2>&1
```

予測: cwd=W1 は **WF102 の deny**（`workflow-entry.sh:205`。継続条件のチケットも `entry.json` も無い）。cwd=W2 は**出力なし**（`workflow-entry.sh:143` の継続条件が成立）。
判定: W1 が無音なら本流のチケットを見ている（解決の失敗）。W2 が WF102 なら継続条件が worktree 側で見えていない。

**P5. `workflow-diff-check`（worktree の中の差分が事後検査に現れるか。e6/D1 の裏取り）**

```bash
printf 'x' > "$W2/apl/probe.txt"
dp() { printf '{"session_id":"probe","transcript_path":"","cwd":"%s","hook_event_name":"PostToolUse","tool_name":"Write","tool_input":{"file_path":"%s/apl/probe.txt"},"tool_response":{"status":"success"}}' "$1" "$1"; }
{ echo "== cwd=W2"; dp "$W2" | bash .claude/hooks/22-PostToolUse/workflow-diff-check.sh; echo "exit=$?"
  echo "== cwd=MAIN（負のコントロール）"; dp "$MAIN" | bash .claude/hooks/22-PostToolUse/workflow-diff-check.sh; echo "exit=$?"
} > wip/tmp/worktree-probe/05-diff-check.txt 2>&1
```

予測: cwd=W2 は `additionalContext` に **WF601** と `apl/probe.txt`（W2 の未追跡ファイル。基準点は 0004 の `base_sha` = `9721416`）。cwd=MAIN では `apl/probe.txt` は現れない（本流には無い）。
判定: W2 で WF601 が出れば**仕様 §13 の記述（D1）が古いことが確定**する。出なければ仕様どおりで、コードの読みが誤っている。

**P6. `session-start`（現在地の導出がどちらのツリーか）**

```bash
ss() { printf '{"session_id":"probe","transcript_path":"","cwd":"%s","hook_event_name":"SessionStart","source":"startup"}' "$1"; }
{ echo "== cwd=W1"; ss "$W1" | bash .claude/hooks/00-SessionStart/session-start.sh; echo "exit=$?"
  echo "== cwd=W2"; ss "$W2" | bash .claude/hooks/00-SessionStart/session-start.sh; echo "exit=$?"
  echo "== cwd=MAIN"; ss "$MAIN" | bash .claude/hooks/00-SessionStart/session-start.sh; echo "exit=$?"
} > wip/tmp/worktree-probe/06-session-start.txt 2>&1
```

予測: cwd=W1 は「進行中の作業は無い」を含む（W1 にチケットも `logs/mr.json` も無い）。cwd=W2 は 0004 を含むが issue / MR 行は出ない（`logs/mr.json` が無い）。cwd=MAIN は 0004 と issue #50 / MR #51 の両方が出る。
判定: W2 で MR #51 が出たら本流の `logs/` を読んでいる（解決の失敗）。

**P7. 記録の分かれ方（X3 の裏取り）**

```bash
{ echo "== W2 の logs"; find "$W2/logs" -type f 2>&1
  echo "== W1 の logs"; find "$W1/logs" -type f 2>&1
  echo "== 本流の logs/sh の更新時刻"; ls -l logs/sh/hook-*.log 2>&1 | tail -20
} > wip/tmp/worktree-probe/07-logs.txt 2>&1
```

予測: W1・W2 に `logs/hooks/decisions.jsonl`（と W1 には `logs/sessions/probe/`）が**新しく作られている**。同時に本流の `logs/sh/hook-*.log` の更新時刻が P1〜P6 の実行時刻になっている（= 判定記録は作業ツリー側、実行ログは本流側に割れる）。

**P8（補助・任意）. 実セッションでの確認**

W2 の中で `claude` を起動し（= `${CLAUDE_PROJECT_DIR}` が W2 になる経路）、または既存セッションから worktree に入って、次を観察する。

- `wip/**` の外への `Write` が WF201 / WF202 になるか（P2 と同じ結論になるか）
- `logs/hooks/decisions.jsonl` がどちらのツリーに増えるか
- SessionStart の現在地が W2 のものになるか

予測: W2 で起動した場合は `HOOK_ROOT` も W2 になるため、`HOOK_WORKTREE == HOOK_ROOT` で矛盾なく動く（この経路は「worktree に入る」問題を回避する）。既存セッションから入る場合だけが e1 の条件に当たる。
注意: この観察だけが「Claude が worktree に入ったとき `cwd` が追随するか」に答えられる。P1〜P7 は `cwd` を与えた場合の挙動しか答えない。

**片付け**

```bash
rm -f "$W2/apl/probe.txt"
git worktree remove --force ../imtw-probe-main
git worktree remove --force ../imtw-probe-head
git worktree prune
git status --porcelain    # 空であること（wip/tmp/ は .gitignore 対象）
```

万一本流が壊れたら、チケット 0004 の基準点 `9721416` を基準に戻す（`git checkout 9721416 -- <path>`）。

### e9. 提供コマンド 5 本 × 依存する状態ファイル × 無いときの振る舞い ◎良

前提として、5 本はすべて**本体の先頭で `cd "$LOGGER_ROOT"` してから相対パスで状態ファイルを触る**。したがって「どの作業ツリーの `logs/` を触るか」は `LOGGER_ROOT` 1 本で決まり、`cwd` は `__ss_load` が相対パス起動を解決するときにしか効かない（e10）。フックのように「置き場（`HOOK_ROOT`）」と「作業ツリー（`HOOK_WORKTREE`）」を分けて持つ仕組みは、提供コマンドには**無い**。

| コマンド | `cd "$LOGGER_ROOT"` の行 | `grep -c 'logs/'` の件数 |
|---|---|---|
| `ticket.sh` | `:342` | 0 |
| `commit.sh` | `:96` | 0 |
| `push.sh` | `:65` | 1（`:19`） |
| `boundary.sh` | `:664` | 7（`:28`〜`:31`・`:138`（注釈）・`:399`・`:400`） |
| `finalize.sh` | `:538` | 6（`:22`〜`:24`・`:168`（注釈）・`:191`（注釈）・`:257`） |

#### e9-1. 「コマンド × 状態ファイル × 無いときの振る舞い」（全 17 行）

分類は **既定値**（無いことを正常として続ける）／**再導出**（無いことを検知して別の情報源から作り直す）／**停止**（未充足として止まる）／**依存なし**の 4 値。

| # | コマンド | 状態ファイル | R/W | 無いときの振る舞い | 分類 | 根拠（ファイル:行） |
|---|---|---|---|---|---|---|
| 1 | `ticket.sh` | `logs/sh/ticket.log` | W | logger が `mkdir -p <root>/logs/sh` で作る。作れなければ `LOGGER_DIR=""` になり**黙って書かない**（標準出力・標準エラーには何も出さない） | 既定値 | `logger.sh:15-18, 31`／`ticket.sh:17` |
| 2 | `ticket.sh` | `logs/` の進行状態（`mr.json` ほか） | — | 参照しない。`wip/10_tickets/**`・`git`・`ticket.template.md`（`:23`）・`task-types.tsv`（`:25`）・`commit.sh`（`:24`）だけで動く | 依存なし | `grep -c 'logs/' ticket.sh` = 0 件 |
| 3 | `commit.sh` | `logs/sh/commit.log` | W | 1 と同じ | 既定値 | `logger.sh:15-18`／`commit.sh:12` |
| 4 | `commit.sh` | `logs/` の進行状態 | — | 参照しない。`assets/exclude-patterns.txt`（`:15`）が無ければ除外なしで続行（`:48` が `return 1`） | 依存なし | `grep -c 'logs/' commit.sh` = 0 件／`commit.sh:48` |
| 5 | `push.sh` | `logs/merge-state.json` | R | **無ければ項目 4 は「draft 解除前のため対象外」で ✓**。あって `.state == "ready"` なら `wip/` に `.gitkeep` 以外が残っていないかを検査し、残っていれば CP005 で停止（項目 4 はスキップ不可）。**ブランチ・MR での絞り込みが無い**ので、前 issue の記録でも `ready` と読む（e13-1） | 既定値（無いほうが安全側）／残っていると停止 | `push.sh:19, 133-151` |
| 6 | `push.sh` | `wip/push-check-skip.md`（`HEAD` にある版） | R | 無ければスキップ指定なしとして全項目を検査 | 既定値 | `push.sh:17, 41-` |
| 7 | `push.sh` | `logs/sh/push.log` | W | 1 と同じ | 既定値 | `logger.sh:15-18`／`push.sh:13` |
| 8 | `boundary.sh` | `logs/mr.json` | R→W | 無ければ CLI（`gh pr view --json number,url,state` / `glab mr list --source-branch`）で特定し、取れたら `write_mr_json` で書く。`--offline` か CLI 不在なら `B_MR="null"` のまま続行し、`status` は `mr: null` を返す。`request` は BD001「MR が無い」で**停止**（`--standalone` を除く） | 再導出（できなければ `request` は停止） | `boundary.sh:28, 225-257, 472` |
| 9 | `boundary.sh` | `logs/review-state.json` | R/W | 無ければ `R_STATE="none"`。`status` はリモートの依頼マーカー（`<!-- boundary:request … -->`）から再導出する（`--offline` では再導出しない）。**あっても現在の切れ目（`task_type` / `last_done`）と一致しなければ `none` 扱い**（`review_valid`） | 再導出 | `boundary.sh:29, 119-136, 340-` |
| 10 | `boundary.sh` | `logs/review-history.jsonl` | append | 無ければ追記で作られる。読み手は無い（監査用の積み上げ） | 既定値 | `boundary.sh:30, 178-187` |
| 11 | `boundary.sh` | `logs/merge-state.json` | R | 無ければ `""`。**あっても `.mr` か `.branch` が現在のものと違えば「無い」扱い**（別 issue の `ready` が残っていても毎回 BD005 で止まらないための明示の対策。`:138` の注釈） | 既定値 | `boundary.sh:31, 138-147, 160-166` |
| 12 | `boundary.sh` | `logs/usage/<branch>.json` | W（上書き） | `note --usage-report` の投稿に成功したときだけ `{posted, since_sha, url}` で**上書き**する。無ければ `mkdir -p logs/usage` で作る | 既定値 | `boundary.sh:393-406` |
| 13 | `boundary.sh` | `logs/sh/boundary.log` | W | 1 と同じ | 既定値 | `logger.sh:15-18`／`boundary.sh:22` |
| 14 | `finalize.sh` | `logs/mr.json` | R | 無ければ `F_MR` は `--pr` で渡した値だけ。両方無いと `F_MR=""` になり、段階 1 の `fetch_body` が失敗して「MR 本文を取得できない」で**停止**（FN001） | 停止（`--pr` で回避可） | `finalize.sh:22, 51-58, 240-245` |
| 15 | `finalize.sh` | `logs/review-state.json` | R | 無ければ `rstate=""` → 段階 1 が「レビューが記録されていない」で**停止**（人間レビュー要なら `completed`、不要なら `skipped` を要求する） | 停止（`boundary.sh complete --final` / `skip --final` で作る） | `finalize.sh:23, 253-262` |
| 16 | `finalize.sh` | `logs/merge-state.json` | R/W | 無ければ `rederive_state` が `wip/` の中身・統括レポートの完了検査の節・MR 本文の `<!-- finalize:linked <sha> -->` マーカー・`is_draft` の結果から状態を作り直す。draft を判定できないときは**拒否側**（`pushed`）に倒す。`pre_cleanup_sha` は片付けコミットの親から復元する（`:168` の注釈「`logs/` を唯一の正にしない」） | 再導出 | `finalize.sh:24, 105-112, 141-173` |
| 17 | `finalize.sh` | `logs/sh/finalize.log` | W | 1 と同じ | 既定値 | `logger.sh:15-18`／`finalize.sh:15` |

**読み取り**: 進行状態への依存は `boundary.sh`（5 種）と `finalize.sh`（3 種）に集中し、`push.sh` は 1 種、`ticket.sh` と `commit.sh` は 0 種。**チケットを回すだけなら `logs/` は要らない**。

### e10. `__ss_load` の解決先と、`LOGGER_ROOT` が worktree とずれる 3 条件 △注意

`__ss_load` は 5 本すべてに**同一の 1 行**として置かれている（`ticket.sh:16` / `commit.sh:11` / `push.sh:12` / `boundary.sh:21` / `finalize.sh:14`。スキル `20-common-step-shell-script` が「中身を改変しない」と定める共通の読み込み行）。処理の順は次の 3 段。

1. **`BASH_SOURCE[1]` から上向き**: 呼び出し元スクリプトのパスの親を取り、相対なら `$PWD/` を前置し、`-d "$d/.claude"` が成り立つ最初の祖先まで `${d%/*}` で遡って `r` にする
2. **`CLAUDE_PROJECT_DIR`**: 1 で決めた `r` の下に `.claude/skills/20-common-step-shell-script/scripts/<lib>.sh` が**無いとき**だけ、`CLAUDE_PROJECT_DIR`（`\` を `/` に置換）を `r` にし直す
3. **`git rev-parse --show-toplevel`**: 2 でも見つからないときだけ、`$PWD` を基準にした git のトップレベルを `r` にする

見つかれば `LOGGER_ROOT="$r"` を export して lib を source する。見つからなければ方針（`nop` / `deny` / `fatal`）に落ちる。**`commit.sh` だけは `logger nop` の 1 本しか読まない**ので lib が欠けても動き続けるが、他の 4 本は `frontmatter fatal` を読むので、その作業ツリーに `frontmatter.sh` が無ければ `FATAL: …` と出して終了 2 で落ちる。

#### e10-1. 起動の形ごとの解決先（`MAIN` = 本流、`W` = worktree）

| # | 起動の形 | `PWD` | `BASH_SOURCE[1]` | 1 段目の上向き探索 | `LOGGER_ROOT` | 同時刻の `HOOK_WORKTREE` | 一致 |
|---|---|---|---|---|---|---|---|
| 1 | `bash .claude/skills/…/ticket.sh`（スキルが指示する形） | `MAIN` | 相対 | `$PWD/.claude/…` → `MAIN` | `MAIN` | `MAIN` | 一致 |
| 2 | 同上 | `W` | 相対 | `$PWD/.claude/…` → `W`（`.claude` は追跡されているので worktree にも実体がある） | `W` | `W` | 一致 |
| 3 | `bash "$MAIN/.claude/skills/…/ticket.sh"` | `W` | **絶対（MAIN）** | `MAIN` | **`MAIN`** | `W` | **ずれる（条件①）** |
| 4 | `bash "$W/.claude/skills/…/ticket.sh"` | `MAIN` | **絶対（W）** | `W` | **`W`** | `MAIN` | **ずれる（条件①の逆向き）** |
| 5 | 相対だが `W/.claude` に共通ライブラリが無い（`.claude/` の構成が違うコミットから `worktree add` した場合） | `W` | 相対 | `W`（`.claude` はあるが lib が無い）→ 2 段目へ | `CLAUDE_PROJECT_DIR` が設定されていれば **その値（＝セッションの起点。多くは `MAIN`）**、未設定なら 3 段目の `git rev-parse` で `W` に戻るが lib は見つからず方針に落ちる | `W` | **ずれる（条件②）** |
| 6 | `bash ../<別ツリー>/.claude/skills/…/ticket.sh` | 任意 | 相対（`..` を含む） | `..` を畳まずに `-d` で判定するため、実体としては目的のツリーに解決する（`LOGGER_ROOT` は `…/x/../y` のような未正規化の文字列になる） | 目的のツリー | `PWD` 側 | 場合による |
| 7 | `cwd` が `.claude` を持つ別ディレクトリ（`参考ディレクトリ/agent-workflow` など）で、そこを起点に相対起動 | 別ディレクトリ | 相対 | その `.claude` が最初に当たるが、`20-common-step-shell-script` を持たないので 2 段目・3 段目に落ちる | 2 段目の `CLAUDE_PROJECT_DIR` または 3 段目の git トップレベル | `MAIN`（`__hc_is_worktree_of` が弾く） | **ずれうる（条件③）** |

（7 の「別ディレクトリ」は実在する: `参考ディレクトリ/MR-driven-workflow/.claude/skills/` と `参考ディレクトリ/agent-workflow/.claude/skills/` はあるが、どちらにも `20-common-step-shell-script` は無い。`.gitignore` の `参考ディレクトリ/` 行で追跡外。）

#### e10-2. ずれる条件の要約と、フックとの落差

| 条件 | 内容 | 効き先 | 現状の起きやすさ |
|---|---|---|---|
| ① | 起動に**絶対パス**を使い、その置き場と `cwd` の作業ツリーが違う | 提供コマンドが**別の作業ツリーの `wip/` と `logs/` を書き換える**。`cd "$LOGGER_ROOT"` の後は全部相対なので、コマンドは最後まで気づかない | スキル・SKILL.md・チケットの手順はすべて相対起動なので、通常経路では起きない。人間が絶対パスで叩くと起きる |
| ② | worktree 側の `.claude` に共通ライブラリが無く、2 段目の `CLAUDE_PROJECT_DIR` が拾う | 同上。加えて「どのツリーに落ちたか」がコマンドの出力に現れない | `CLAUDE_PROJECT_DIR` は本セッションの Bash ツールでは未設定だったが、フック起動時は必ず設定されている。設定される経路から提供コマンドを起動すると起きうる |
| ③ | `.claude` を持つ別ディレクトリを起点にする | 同上 | `参考ディレクトリ/` が実在するので経路はある |

**フックとの落差**は 2 点。

- フックの `__hc_resolve_worktree`（`hook-common.sh:319-331`）は、候補が `.claude` を持つだけでは採らず、`__hc_is_worktree_of`（`:293-316`）で **`.git` ファイルと `worktrees/<名前>/gitdir` の相互参照**まで確かめる。`__ss_load` の 1 段目は **`-d "$d/.claude"` だけ**で、相互参照の検査も `..` の畳み込み（`__hc_winpath` 相当）も無い
- フックは `HOOK_ROOT`（置き場）と `HOOK_WORKTREE`（作業ツリー）を分けて持つが、提供コマンドは `LOGGER_ROOT` 1 本で両方を兼ねる。**「どこのスクリプトを実行したか」がそのまま「どこの `wip/` と `logs/` を触るか」になる**

なお `hook-common.sh:19` は `HOOK_ROOT="${HOOK_ROOT:-${LOGGER_ROOT:-$__hc_root}}"` と**環境の `LOGGER_ROOT` を尊重する**が、`__ss_load` は環境の `LOGGER_ROOT` を見ずに必ず上書きする。向きは逆だが、提供コマンドから子スクリプトを呼ぶ経路（`ticket.sh:78` の `bash "$COMMIT"`、`finalize.sh:25-27`）はすべて `cd` 後の**相対パス**で呼ばれており、子も同じ `LOGGER_ROOT` に解決する。**親子でツリーが割れることはない**。

### e11. フックの実体は本流、提供コマンドの実体は worktree — 機構が 2 つのバージョンで動く △注意

- `settings.json` はフックの起動 **16 個所すべて**（スクリプトは 11 本）で `bash "${CLAUDE_PROJECT_DIR}/.claude/hooks/…"` と**絶対パス**で起動する（`:16, 26, 36, 45, 49, 58, 69, 79, 88, 97, …`）。したがって `hook-common.sh:16-19` の上向き探索は必ず `CLAUDE_PROJECT_DIR` の側に着き、**`HOOK_ROOT` はセッションの起点で固定**される
- 一方、提供コマンドはスキルと SKILL.md が `bash .claude/skills/…/xxx.sh` と**相対パス**で呼ぶよう定めている（`ticket.sh:4` の「使い方」ほか）。したがって `cwd` が worktree なら **worktree 側の実体**が動く

帰結:

| 対象 | どのツリーの実体が動くか | どのツリーの状態を見るか |
|---|---|---|
| フック 11 本（登録は 16 個所） | セッションの起点（`CLAUDE_PROJECT_DIR`） | `cwd` から解決した作業ツリー（`HOOK_WORKTREE`） |
| `scope-limits.json`・`task-types.tsv`（フックが読む設定） | セッションの起点（`hook-common.sh:347` ほか。0004 の R5） | — |
| 提供コマンド 5 本 | `cwd`（相対起動なら worktree） | 同じ（`LOGGER_ROOT`） |
| `task-types.tsv`（`ticket.sh` が読む `:25`） | `cwd`（相対起動なら worktree） | — |

つまり `.claude/` を変えるブランチ（**本 issue がまさにそれ**）を worktree で開発すると、**新しい提供コマンドと古いフック**、あるいは**新しい `task-types.tsv`（`ticket.sh` 側）と古い `task-types.tsv`（フック側）** の組み合わせで動く。これは 0004 の R5（設定は常に本流）と対になる同じ構造の問題で、AI アセット開発というこのリポジトリの性質上、無視できない。

### e12. `logs/` が無い worktree で壊れるコマンドは無い ◎良

`git worktree add` は追跡されているファイルだけを展開するので、`.gitignore` の `logs/` 行により **worktree に `logs/` は存在しない**（0004 の e4 で確認済み。`git ls-files logs/` = 0 件）。この状態で 5 本を順に当てると:

| 順 | コマンド | `logs/` が無い worktree での挙動 | 壊れるか | 根拠 |
|---|---|---|---|---|
| 1 | 最初に走る 1 本（どれでもよい） | logger が `mkdir -p "<root>/logs/sh"` するので、**`logs/` はその場で作られる** | 壊れない | `logger.sh:16-18` |
| 2 | `ticket.sh next` / `start` / `complete` | `logs/` を読まない。`wip/10_tickets/**` と git だけで完結する | 壊れない | e9-1 の 2 |
| 3 | `commit.sh` | 同上 | 壊れない | e9-1 の 4 |
| 4 | `push.sh` | `logs/merge-state.json` が無い ＝ 項目 4 が「draft 解除前のため対象外」で ✓。項目 1〜3 は git と `wip/` から判定 | 壊れない（むしろ安全側） | `push.sh:149` |
| 5 | `boundary.sh status` | `mr.json` 無し → CLI で再導出して書く。`review-state.json` 無し → `none` にしてリモートのマーカーから再導出。`merge-state.json` 無し → `""` | 壊れない（CLI が要る） | `boundary.sh:225-257, 119-136` |
| 6 | `boundary.sh request` / `complete` | `resolve_mr` が CLI で MR を取れれば通る。**CLI が無い・`--offline` だと BD001「MR が無い」で停止** | CLI 次第 | `boundary.sh:472` |
| 7 | `finalize.sh release` | 段階 1 で `logs/mr.json`（MR 番号）と `logs/review-state.json`（レビューの記録）を要求する。**`logs/` が空だと FN001 で停止**。`--pr <M>` で MR は渡せるが、レビューの記録は `boundary.sh complete --final` / `skip --final` で作り直すしかない | **ここが最初の実害** | `finalize.sh:240-245, 253-262` |

**結論**: 「壊れる」と言えるのは 7（`finalize.sh release`）の 1 か所だけで、それも停止（拒否側）であって誤動作ではなく、`--pr` と `boundary.sh` の再記録で回復できる。`logs/` の不在は**機構を静かに無効化しない**。

ただし、無いことによる**損失**は 2 つある。

- `logs/usage/<branch>.json`（対応工数の集計）は再導出の経路が無く、worktree を作った時点から**別の集計が始まる**。同じブランチの作業を 2 ツリーに割ると数字が割れる（`post-push-usage-report.sh:51` が `HOOK_WORKTREE/logs/usage/…` を見るため）
- `logs/review-history.jsonl`（レビューの履歴）も再導出の経路が無い。読み手が無いので運用上の実害は小さい

### e13. 本 issue の実施中に実際に踏んだ 3 件の根本原因 ✕問題

3 件とも「`logs/` が作業ツリー粒度で残るのに、中身の意味はブランチ・MR・issue 粒度である」ことの帰結である。全体計画書の保留 P2 に 2 件（`logs/` の進行状態が issue をまたいで残る / `mr.json` の `issue` が誰にも書かれない）として挙がっている。

#### e13-1. 前 issue の `merge-state.json` が `ready` のまま残り、`push.sh` 項目 4 が永久に落ちた

- `push.sh` の項目 4 は `logs/merge-state.json` の `.state` だけを見る。**`.mr` も `.branch` も見ない**（`push.sh:134-138`）
- 同じファイルを読む `boundary.sh` の `merge_state()` は、`.mr` が現在の MR と違う／`.branch` が現在のブランチと違うときに **`""`（無い扱い）に落とす**（`boundary.sh:141-147`）。しかもその直前の `:138-140` に「`logs/` はブランチに紐づかないローカルの記録なので、別の issue で `ready` まで終えた記録がそのまま残る。（中略）そうしないと、同じ clone で次の issue を始めた瞬間から `status` が毎回 BD005 で止まる」と**同じ失敗の対策が明記されている**。`push.sh` にはこの対策が入っていない
- 書き手の `finalize.sh` は `.branch` を必ず書く（`finalize.sh:127-133` の注釈「`branch` は `boundary.sh` が『この記録は今のブランチのものか』を見るために要る」）。**書き手は分離のためのキーを用意しているのに、`push.sh` だけが使っていない**
- 症状: 項目 4 は**スキップできない**（`push.sh:26, 151`）ので、`wip/` に成果物がある限り新しい issue の最初の push が必ず CP005 で落ちる。回復には `logs/merge-state.json` の削除が要るが、これは `workflow-state-guard` の WF301 と `workflow-guard` の WF205 の対象なので **AI からは消せず、人間の手が要る**
- 実際の記録: `logs/sh/push.log:264` — `2026-09-04T22:04:29 start branch=feature-50-worktree-parallel-tickets` の直後に `22:04:30 CP005: push できない。未充足 1 件`。同ブランチの次の push は `22:08:39` に成功しており、その間に人間が記録を消したことと整合する。現在 `logs/merge-state.json` は存在しない
- 仕様も同じ穴を持つ: `10_spec/skills/20-common-step-commit-push.md:99` は項目 4 の条件を「`logs/` の記録が draft 解除済みを示すとき」としか書いておらず、**どの MR・どのブランチの記録かを問うていない**
- テストが現状を固定している: `test_push.sh:46` は `{"state":"ready"}` という **`mr` も `branch` も無い記録**を置いて項目 4 の不成立を期待する（`:55`）。同じ形が `:100` と `:127` にもある。直すならテストの期待値も変わる

#### e13-2. `logs/mr.json` が前 issue の MR 番号を保持し、`resolve_mr` が CLI より記録を優先して古い MR を掴んだ

- `resolve_mr()` は `logs/mr.json` に `.mr` があればその場で `return 0` し、**CLI を一切見ない**（`boundary.sh:227-236`）。CLI へ行くのは記録が無いか `.mr` が空のときだけ（`:237` 以降）
- これは仕様どおりの順序である（`10_spec/skills/00-workflow-issue-mr-driven.md:218`「MR を `logs/mr.json` から読み、無ければ CLI（…）で特定して書く」）。**問題は順序ではなく、`logs/mr.json` に「どのブランチの記録か」を表すキーが無いこと**。正の形は `{"host","issue","mr","url"}`（同仕様 `:194`）で、`branch` が無い
- 同じ `boundary.sh` の中で、`review-state.json` には `review_valid()`（`:136`。`task_type` と `last_done` の一致を要求）、`merge-state.json` には `.mr` / `.branch` の照合（`:141-147`）がある。**`mr.json` だけが素通し**である
- 回復手段が無い: `boundary.sh` に `--refresh` / `--pr` に当たる引数は無く（`status` は `--offline` だけ。`:309-317`）、記録を捨てる以外に再導出させる方法が無い。その削除は WF301 / WF205 で AI からは不可
- 実際の記録: `logs/sh/boundary.log` に `2026-09-04T18:18:21` と `18:25:25` の `note` が **PR #35**（前 issue #10）へ投稿された行が残り、`22:09:45 start subcommand=status` は**新ブランチ `feature-50-worktree-parallel-tickets` に切り替わった後**（最初の push は `22:08:39`）である。その後 `22:17:37` の `note` は PR #51 に入っている。`logs/review-history.jsonl` にも `mr:35` の 2 件（`archived_at` `18:24:12` / `18:43:35`）と `mr:51` の 3 件が**同じファイルに連続して**積まれている
- 危険度: `status` で気づけたが、気づかずに `boundary.sh request` / `note` を打てば**前 issue の MR にレビュー依頼を投稿する**。リモートへの書き込みなので取り消しが効かない

#### e13-3. `write_mr_json` が `issue` を既存値からしか引き継がず、常に null になる

- `write_mr_json()` は `issue` を **`logs/mr.json` が既にあるときにその `.issue` を読む**だけで、引数にも CLI にも issue 番号の入り口が無い（`boundary.sh:211-218`。引数は `$1=host $2=mr $3=url` の 3 つ）
- 呼び手は `resolve_mr` の 1 か所だけ（`boundary.sh:257`）で、そこも host / mr / url しか渡さない
- リポジトリ全体で `logs/mr.json` に書き込むコードは `write_mr_json` の 1 か所だけ（`grep -rn "mr\.json"` の結果、書き込みは `boundary.sh:211-217` のみ。`finalize.sh:132` が書くのは `merge-state.json` の `.issue`）。したがって **初回作成時の `.issue` は必ず `null` になり、以後も null が引き継がれる**
- 現物がそうなっている: `logs/mr.json` は `{"host":"github","issue":null,"mr":51,"url":"…/pull/51"}`
- 仕様との食い違い: `10_spec/skills/00-workflow-issue-mr-driven.md:194` は正の形を `{"host": "github"|"gitlab", "issue": N, "mr": M, "url": …}` と定めており、**`issue: N` が入る前提で書かれている**。実装がこれを満たしていない
- 実害: 読み手は 2 か所。`session-start.sh:116` は現在地の案内から **issue の行が落ちる**（`session-start.sh:160` は MR 行だけ出す）。`finalize.sh:55` は `F_ISSUE` に空を入れ、`write_state`（`:132`）が `merge-state.json` の `.issue` に null を書く。`.issue` の読み手は無いので、実害は「現在地の案内が痩せる」ことに留まる
- ブランチ名からは復元できる（`feature-<N>-*` / `fix-<N>-*`。`session-start` 仕様 `:58` の WF703 が同じ規約を使う）ので、直し方の候補は「`resolve_mr` がブランチ名から拾う」「`boundary.sh` に `--issue` を足す」「MR 本文の `Closes #N` から拾う」の 3 通りある（決めない）

### e14. `logs/` の置き場の粒度と、中身の意味の粒度が合っていない △注意

e13 の 3 件はどれも同じ形をしている。整理すると:

| 状態ファイル | 置き場の粒度 | 中身の意味の粒度 | 現在の照合 | 一致しないと何が起きるか |
|---|---|---|---|---|
| `logs/mr.json` | 作業ツリー | **MR（＝ブランチ、＝issue）** | 無し | 前 issue の MR を掴む（e13-2） |
| `logs/review-state.json` | 作業ツリー | 切れ目（`task_type` + `last_done`） | `review_valid()`（`boundary.sh:136`） | — |
| `logs/merge-state.json` | 作業ツリー | MR + ブランチ | `boundary.sh:141-147` にはあり、**`push.sh:134-138` には無し** | 項目 4 が永久に落ちる（e13-1） |
| `logs/review-history.jsonl` | 作業ツリー | 追記のみ（意味の粒度なし） | 不要 | issue をまたいで 1 本に積まれるが読み手が無い |
| `logs/push-state.json` | 作業ツリー | **ブランチ**（キーがブランチ名） | キーで分離済み | — |
| `logs/usage/<branch>.json` | 作業ツリー | **ブランチ**（ファイル名がブランチ名） | ファイル名で分離済み | ツリーを分けると集計が割れる（e12） |
| `logs/sessions/<sid>/` | 作業ツリー | **セッション** | ディレクトリ名で分離済み | ツリーを分けると宣言・承認が空から始まる（0004 の e4） |
| `logs/locks/` | 作業ツリー | ロックの名前ごと | 名前で分離済み | ツリーをまたぐと排他にならない（0004 の e4） |

**worktree はこのズレを縮める方向に働く**。git は同じブランチを 2 つの作業ツリーで checkout させないので、「1 ブランチ = 1 作業ツリー」を守るかぎり、ブランチ・MR 粒度の記録（`mr.json` / `merge-state.json` / `push-state.json` / `usage/`）は**自然に 1 つのツリーに閉じ**、e13-1 と e13-2 は起きなくなる。逆に**セッション粒度の記録**（`sessions/<sid>/entry.json` と `approvals.json`）は新しいツリーで空から始まるので、宣言のやり直しと承認の取り直しが増える（0004 の e4 のとおり、拒否側に倒れるので危険ではない）。

この観点は、保留 P1（並列の採否）に対して **「worktree を採ると得られるもの」の 1 つ**として数えてよい材料である（決めるのは 0010）。

### e15. 提供コマンドに排他制御が無い △注意

- 5 本に `lock` の語が **0 件**（`grep -rn lock` を 5 本に当てて `blocked` を除くと出力なし）。`hc_lock` / `hc_unlock`（`hook-common.sh:604, 624, 634`）は**フック専用**で、提供コマンドからは呼ばれない
- したがって同じ作業ツリーで 2 つのプロセスが同時に提供コマンドを叩くと、次が競合する。
  - **`.git/index.lock`**: `ticket.sh` は状態を変えた後に `commit.sh` を呼ぶ（`ticket.sh:78`）。`commit.sh` は `git add` → `git commit` を行うので、同時実行は `index.lock` の取得失敗で片方が落ちる
  - **チケットの採番**: `ticket.sh create` は `wip/10_tickets/**` の既存ファイルから次の番号を決めるため、同時に 2 枚作ると同じ番号になりうる
  - **`logs/*.json` の読み書き**: `write_review` / `write_mr_json` / `write_state` は `.tmp` に書いて `mv` するので、**単一ファイルとしては壊れない**（アトミック）が、read-modify-write の間に挟まれた更新は失われる
- **worktree に分ければ** `.git/index` は作業ツリーごとに別（`.git/worktrees/<名前>/index`）になるので index の競合は消え、`logs/` も別なので JSON の競合も消える。残るのは**採番**（`wip/10_tickets/` は各ツリーのチェックアウトなので、合流時に同じ番号が 2 枚できる）で、これは観点 D（0007）の合流コストの話に接続する

### e16. 実測手順（観点 B。人間が実行する。コマンド列 + 予測）◎良

**前提**（0004 の e8 と共通）

- 実行は**人間**が行う。`git worktree add` / `cd` はどの `allow.ops` を宣言しても WF204 で拒否される
- 結果は **`wip/tmp/worktree-probe/`** に置く（`.gitignore` の `wip/tmp/*` により追跡されない。同一作業ツリーなので 0009 が読める）
- **B1・B2 は本流だけで完結する**（worktree を作る前に単独で実行できる）。**B3・B4・B6 は 0004 の P0 で作った `W1` / `W2` を前提にする**ため、0004 の P0 の後に続けて実行する。**B5 は `wip/tmp/` の下に作った使い捨てのリポジトリの中だけで完結する**（本流の `logs/` と `wip/` には触らない）
- 副作用: `logs/sh/*.log` が増える

**B1. `__ss_load` の解決先（本流のみ。相対 / 絶対 / 別ディレクトリ起点）**

```bash
cd /c/Users/taniyama/Desktop/git/issue-mr-ticket-workflow
mkdir -p wip/tmp/worktree-probe
MAIN="$(pwd)"
# __ss_load と同じ探索を再現して解決先を印字する（本体は改変しない）
probe_root() { # $1=起動に使うパス（BASH_SOURCE[1] の代わり） $2=PWD
  ( cd "$2" 2>/dev/null || exit 9
    bash -c 'set -u
      d="${1%/*}"; [ "$d" = "$1" ] && d="."
      case "$d" in /*|[A-Za-z]:/*) ;; *) d="$PWD/$d" ;; esac
      while [ -n "$d" ] && [ ! -d "$d/.claude" ]; do case "$d" in */*) d="${d%/*}" ;; *) d="" ;; esac; done
      r="$d"; f="$r/.claude/skills/20-common-step-shell-script/scripts/logger.sh"
      if [ ! -f "$f" ] && [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then r="${CLAUDE_PROJECT_DIR//\\//}"; f="$r/.claude/skills/20-common-step-shell-script/scripts/logger.sh"; fi
      if [ ! -f "$f" ]; then r="$(git rev-parse --show-toplevel 2>/dev/null || true)"; f="$r/.claude/skills/20-common-step-shell-script/scripts/logger.sh"; fi
      printf "r=%s found=%s\n" "$r" "$([ -f "$f" ] && echo yes || echo no)"' _ "$1" )
}
{ echo "== 相対 / PWD=MAIN";     probe_root ".claude/skills/20-common-step-ticket/scripts/ticket.sh" "$MAIN"
  echo "== 絶対 / PWD=MAIN";     probe_root "$MAIN/.claude/skills/20-common-step-ticket/scripts/ticket.sh" "$MAIN"
  echo "== 絶対 / PWD=/tmp";     probe_root "$MAIN/.claude/skills/20-common-step-ticket/scripts/ticket.sh" "/tmp"
  echo "== 参考ディレクトリ起点"; probe_root "$MAIN/参考ディレクトリ/agent-workflow/.claude/x/y.sh" "$MAIN"
} > wip/tmp/worktree-probe/B1-ssload.txt 2>&1
```

予測: 1・2・3 とも `r=<MAIN> found=yes`（絶対起動は `PWD` に依存しない）。4 は 1 段目が `参考ディレクトリ/agent-workflow` に当たるが `found=no` になり、`CLAUDE_PROJECT_DIR` が未設定なら 3 段目の `git rev-parse` で `MAIN`（`PWD=MAIN` のため）に落ちて `found=yes`。
判定: 3 が `MAIN` になれば **条件①（絶対起動は `cwd` を見ない）が確定**する。4 が `参考ディレクトリ/agent-workflow` のまま `found=yes` になったら、`__ss_load` に相互参照の検査が無いことの実害が本流の中にもある。

**B2. `CLAUDE_PROJECT_DIR` が設定される経路の確認**

Claude のセッションから `echo "CLAUDE_PROJECT_DIR=[${CLAUDE_PROJECT_DIR:-未設定}]"` を 1 回実行し、結果を `wip/tmp/worktree-probe/B2-projectdir.txt` に貼る（0005 の実行では**未設定**だった）。あわせて、フックが動いた直後の `logs/hooks/decisions.jsonl` の末尾 1 行を同じファイルに貼る（フック側では `settings.json` が `${CLAUDE_PROJECT_DIR}` を展開できている以上、設定されているはずである）。

予測: Bash ツールでは未設定、フック経由では設定されている。
判定: Bash ツールでも設定されていれば、条件②（2 段目に落ちたとき本流へ倒れる）は実運用の経路になる。

**B3. worktree での `LOGGER_ROOT`（相対起動 / 絶対起動）**

```bash
# 0004 の P0 で作った W1 / W2 を前提にする
W1="$(cd ../imtw-probe-main && pwd)"; W2="$(cd ../imtw-probe-head && pwd)"
{ echo "== 相対 / PWD=W2";     ( cd "$W2" && bash .claude/skills/20-common-step-ticket/scripts/ticket.sh next )
  echo "== 絶対(MAIN) / PWD=W2"; ( cd "$W2" && bash "$MAIN/.claude/skills/20-common-step-ticket/scripts/ticket.sh" next )
  echo "== 相対 / PWD=W1";     ( cd "$W1" && bash .claude/skills/20-common-step-ticket/scripts/ticket.sh next )
  echo "== logs の生え方";      ls -d "$W1/logs" "$W2/logs" 2>&1
} > wip/tmp/worktree-probe/B3-logger-root.txt 2>&1
```

予測: 「相対 / `PWD=W2`」は W2 のチケット状態を反映した JSON。「絶対(MAIN) / `PWD=W2`」は**本流の状態**を返す。「相対 / `PWD=W1`」は W1（`main` 基点でチケット 0 枚）なので `{"current":null,"next":null,…}` に近い形。`logs` は W1・W2 とも**この時点で作られている**（`logs/sh/ticket.log` だけ）。
判定: 「相対 / `PWD=W2`」と「絶対(MAIN) / `PWD=W2`」の出力が**違えば条件①が実測で確定**する。同じなら `__ss_load` の読みが誤っている。

**B4. `logs/` が無い worktree での `boundary.sh status`（再導出が働くか）**

```bash
{ echo "== PWD=W2 / logs 無し / --offline"
  ( cd "$W2" && bash .claude/skills/00-workflow-issue-mr-driven/scripts/boundary.sh status --offline ); echo "exit=$?"
  echo "== W2 に生えた logs"; find "$W2/logs" -type f 2>&1
} > wip/tmp/worktree-probe/B4-boundary.txt 2>&1
```

予測: `--offline` なので CLI を見ず、`logs/mr.json` も無いので **`"mr": null`** を含む JSON が返る。レビューの `state` は `none`。`W2/logs/sh/boundary.log` が新しくできている（`logs/mr.json` は書かれない）。
判定: `mr` に **51** が入っていたら本流の `logs/` を読んでいる（＝ `LOGGER_ROOT` が本流に倒れている）。`--offline` を外すと `gh pr view` が走るので、**detached HEAD の worktree では MR を再導出できない**ことも同時に見える（R8）。

**B5. e13-1 の再現（前 issue の `merge-state` で項目 4 が落ちる）— 使い捨てのリポジトリで行う**

```bash
T="$MAIN/wip/tmp/worktree-probe/b5"; rm -rf "$T"; mkdir -p "$T"
( cd "$T" && git init -q . && printf 'logs/\n' > .gitignore \
  && mkdir -p .claude/skills/20-common-step-shell-script/scripts .claude/skills/20-common-step-commit-push/scripts \
             .claude/skills/20-common-step-commit-push/assets wip/30_reports wip/10_tickets/10_doing logs \
  && cp "$MAIN"/.claude/skills/20-common-step-shell-script/scripts/*.sh .claude/skills/20-common-step-shell-script/scripts/ \
  && cp "$MAIN"/.claude/skills/20-common-step-commit-push/scripts/*.sh .claude/skills/20-common-step-commit-push/scripts/ \
  && cp "$MAIN"/.claude/skills/20-common-step-commit-push/assets/exclude-patterns.txt .claude/skills/20-common-step-commit-push/assets/ \
  && echo x > wip/30_reports/dummy.md && echo r > README.md \
  && git add -A && git commit -q -m "chore: init" \
  && printf '{"state":"ready","mr":35,"branch":"feature-9-old"}\n' > logs/merge-state.json \
  && bash .claude/skills/20-common-step-commit-push/scripts/push.sh; echo "exit=$?" ) \
  > "$MAIN/wip/tmp/worktree-probe/B5-push-item4.txt" 2>&1
```

予測: **`✗ 項目 4`** と `項目 4: draft 解除後（merge-state ready）なのに wip/ に成果物が残っている` を含み、最終行が `CP005: …` で `exit=1`（上流が無いので項目 1〜3 も何か出るが、項目 4 が落ちることが要点）。`mr` も `branch` も現在のリポジトリと無関係なのに `ready` と読まれることが確認できる。
判定: 項目 4 が ✓ になったら e13-1 の読みが誤っている。なお前チェックで落ちるので `git push` には到達せず、リモートには何も起きない。

**B6. 記録の分かれ方（`usage` / `push-state` / `mr.json`）**

```bash
{ echo "== 本流"; ls -1 "$MAIN/logs" "$MAIN/logs/usage" 2>&1
  echo "== W1";  find "$W1/logs" -type f 2>&1
  echo "== W2";  find "$W2/logs" -type f 2>&1
} > wip/tmp/worktree-probe/B6-split.txt 2>&1
```

予測: 本流には `mr.json` / `review-state.json` / `review-history.jsonl` / `push-state.json` / `usage/*.json` / `sessions/` / `hooks/` / `sh/` が揃い、W1・W2 には **B3・B4 で走らせた分の `sh/*.log`（と、フックを叩いていれば `hooks/decisions.jsonl`）しか無い**。
判定: 予測どおりなら「`logs/` は作業ツリーごとに分かれ、新しい worktree は空から始まる」が実測で確定する。

**片付け**

```bash
rm -rf "$MAIN/wip/tmp/worktree-probe/b5"
# W1 / W2 の削除は 0004 の e8「片付け」に従う
git -C "$MAIN" status --porcelain   # 空であること（wip/tmp/ は .gitignore 対象）
```

## 検証の結果

| 検証 | 結果 |
|---|---|
| 参照の総件数 | `grep -rn "HOOK_ROOT\|HOOK_WORKTREE" .claude/hooks/ \| wc -l` = **81**（箇所数は `grep -rno` で 90。`HOOK_ROOT` 28 / `HOOK_WORKTREE` 62） |
| 一覧の行数が総件数と合う | e2 の一覧は 81 行。群の内訳 W 55 + R 8 + C 4 + X 4 + T 10 = **81** で一致 |
| テストを除いた本体の件数 | `grep -rn ... \| grep -v "/tests/" \| wc -l` = **71**。81 − T 10 = 71 で一致 |
| ファイルごとの件数 | `grep -rc` の出力（session-start 11 / workflow-entry 2 / subagent-start 3 / subagent-stop 5 / block-chmod 1 / workflow-guard 3 / workflow-state-guard 1 / compact-prompt 8 / usage-report 6 / diff-check 7 / hook-common 23 / push-detect 1 / test_hook_common 6 / test_push_detect 2 / test_scope 1 / test_config_integrity 1）の合計 = **81** で一致 |
| 6 本すべてに結論と根拠がある | e3 の表は 6 行、各行にファイル:行が 2 つ以上 |
| `logs/` が追跡されていない | `.gitignore` に `logs/`、`git ls-files logs/` が **0 件** |
| `wip/` が追跡されている | `git ls-files wip/` が **19 件**（`wip/tmp/.gitkeep` を含む） |
| `main` の作業中チケットが 0 枚（実測 P2 の識別子が成立する） | `git ls-tree --name-only main wip/10_tickets/10_doing/` = `.gitkeep` の **1 件のみ** |
| 作業ツリー解決のテスト ID が仕様にあるか | 仕様 §11 の `HK-T01`〜`HK-T20` に該当なし。`HK-T18` は「副入力の縮退」（`10_spec/フック共通仕様.md:373`）で、`case_worktree` はコメントどおり ID を借りている |
| worktree に触れるテストの本数 | `grep -rln worktree` を `hooks/**/tests/` に掛けて **1 ファイル**（`lib/tests/test_hook_common.sh`） |
| `workflow-diff-check` が `HOOK_WORKTREE` を使うのは初版からか | `git log --oneline -S'git -C "$HOOK_WORKTREE" status --porcelain=v2' -- <該当ファイル>` = `7cf83a2` の **1 件のみ** |
| （0005）5 本の `logs/` 依存の件数 | `grep -c 'logs/' <5 本>` = `ticket.sh` **0** / `commit.sh` **0** / `push.sh` **1** / `boundary.sh` **7** / `finalize.sh` **6**（コメント行を含む） |
| （0005）e9-1 の表が 5 コマンド分ある | 表は 17 行。コマンド別の内訳は `ticket.sh` 2 / `commit.sh` 2 / `push.sh` 3 / `boundary.sh` 6 / `finalize.sh` 4 = **17** で一致し、5 本すべてが 1 行以上ある |
| （0005）各セルに根拠が添えられている | e9-1 の「根拠」列 17 行すべてに `ファイル:行` がある（依存が 0 件の 2 行は、その `grep -c` 自体を根拠として明記） |
| （0005）`__ss_load` が 5 本すべてに置かれている | `grep -c '__ss_load'` = `ticket.sh` 3 / `commit.sh` 2 / `push.sh` 3 / `boundary.sh` 3 / `finalize.sh` 3（定義 1 + 呼び出し 1〜2。`commit.sh` だけ `logger nop` の 1 本しか読まない） |
| （0005）5 本すべてが `cd "$LOGGER_ROOT"` する | `grep -n 'cd "$LOGGER_ROOT"'` = **7 件**（提供コマンド 5 本 + `check-html.sh:61` + `run-tests.sh:62`） |
| （0005）`logs/mr.json` の書き手が 1 か所だけ | `grep -rn "mr\.json" .claude/` の結果、書き込みは `boundary.sh:211-217`（`write_mr_json`）のみ。読み手は `session-start.sh:115-117, 160`／`post-push-compact-prompt.sh:88-90`／`post-push-usage-report.sh:245`／`finalize.sh:55` |
| （0005）`logs/mr.json` の `.issue` が現に null | `cat logs/mr.json` = `{"host":"github","issue":null,"mr":51,"url":"…/pull/51"}` |
| （0005）`push.sh` 項目 4 に絞り込みが無い / `boundary.sh` にはある | `push.sh:134-138` は `.state` のみ。`boundary.sh:141-147` は `.mr` と `.branch` を照合。書き手 `finalize.sh:127-133` は両方を書いている |
| （0005）e13-1 の実際の発生 | `logs/sh/push.log:264`（`2026-09-04T22:04:30 CP005: push できない。未充足 1 件`。直前の行が `start branch=feature-50-worktree-parallel-tickets`）。同ブランチの次の push は `22:08:39` に成功 |
| （0005）e13-2 の状況証拠 | `logs/sh/boundary.log` の `18:18:21` / `18:25:25` が PR **#35** への `note`、`22:09:45 status` が新ブランチ切り替え後（最初の push は `22:08:39`）、`22:17:37` の `note` が PR **#51**。`logs/review-history.jsonl` に `mr:35` 2 件と `mr:51` 3 件が同じファイルに積まれている |
| （0005）提供コマンドに排他制御が無い | `grep -rn lock` を 5 本に当てて `blocked` を除くと **0 件**。`hc_lock` は `hook-common.sh:604, 624, 634` のみ |
| （0005）提供コマンドのテストに worktree のケースが無い | `grep -rln worktree .claude/skills/*/scripts/tests/` = **0 ファイル**。各テストは一時リポジトリに `.claude` を**コピーして相対パスで叩く**形（`test_ticket.sh:12-23`）なので、絶対パス起動のケースも 1 件も無い |
| （0005）テストが `push.sh` 項目 4 の現状を固定している | `test_push.sh:46, 100, 127` が `{"state":"ready"}`（`mr` / `branch` 無し）を置き、`:55` / `:104-105` で項目 4 の不成立を期待する |
| （0005）フックが絶対パスで起動される | `grep -c 'CLAUDE_PROJECT_DIR}/.claude/hooks/' .claude/settings.json` = **16**（スクリプトは重複を除いて 11 本）。相対パスで起動する登録は 0 件 |
| （0005）`CLAUDE_PROJECT_DIR` は Bash ツールでは未設定 | `echo "CLAUDE_PROJECT_DIR=[${CLAUDE_PROJECT_DIR:-未設定}]"` → `未設定`。`PWD` は `/c/Users/…`（MSYS 形式） |

## 設計への反映

| # | 反映すること | 引き取り先 |
|---|---|---|
| 1 | 作業ツリーをまたぐ絶対パスの書き込みで進行状態ファイル保護が効かない（e5）。`hook_rel_path` が 1 つの作業ツリーしか基準に持たないことの帰結で、直し方は「他ツリーの絶対パスを拒否側に倒す」「同一リポジトリの全作業ツリーを基準集合として持つ」などの候補がある（本チケットでは決めない） | 0010（AI アセット設計計画）／受け入れ条件 A1 の「動かない箇所」 |
| 2 | `logs/` が worktree に無いときの初期化を決める（調査計画書の保留 P2）。現状は `mkdir -p` で空から始まり、宣言 = WF102・承認 = 取り直し・レビュー / マージ状態 = `missing` になる（e4） | 0010／0005（観点 B が提供コマンド側を見る） |
| 3 | `logs/locks/` が作業ツリーごとに分かれるため、同じブランチの記録（`usage-<branch>.json` など）に対する排他が作業ツリーをまたぐと成立しない（e4） | 0010 |
| 4 | 判定記録（`decisions.jsonl` = 作業ツリー側）と実行ログ（`logs/sh/` = 本流側）が割れる（e2 X3）。並列実施を採るなら、どちらに寄せるかを決める必要がある | 0010 |
| 5 | 作業ツリー解決に固有のテスト ID が無く、`HK-T18`（副入力の縮退）を借りている（e7）。フック 6 本の worktree 通しテストも無い | 0010（AI アセット設計で ID を新設）／AI アセット実装 |
| 6 | 仕様 §13 の D1 と DDR `i0009-64` の D2 の記述が実装と食い違う（e6）。仕様は書き戻しの対象、DDR は経緯なので「決定が後に変わった」ことが分かる形の追補が要る | 0010／設計反映 |
| 7 | `session-start.sh:74` が `boundary.sh` を `HOOK_WORKTREE` から取る（e2 X2）。仕様 §2 の「スクリプトは常に `HOOK_ROOT`」という原則の書き方を、状態を自分で解決する提供コマンドの扱いを含めて見直す | 0010 |
| 8 | （0005）提供コマンドは `LOGGER_ROOT` 1 本で「置き場」と「作業ツリー」を兼ねており、フックのような `HOOK_ROOT` / `HOOK_WORKTREE` の分離が無い（e9・e10）。worktree 運用を正とするなら、①相対起動を明文の前提にする、②`__ss_load` に相互参照の検査を足す、③提供コマンドにも作業ツリーの解決を持たせる、の 3 系統の候補がある（本チケットでは決めない） | 0010（AI アセット設計計画） |
| 9 | （0005）`push.sh` 項目 4 が `logs/merge-state.json` を MR・ブランチで絞り込まない（e13-1）。`boundary.sh:141-147` に既にある照合を移すか共通化するかを決める。仕様 `20-common-step-commit-push.md:99` とテスト `test_push.sh:46, 100, 127` も同時に変わる | 0010／全体計画書の保留 P2（別 issue にするなら） |
| 10 | （0005）`logs/mr.json` に「どのブランチ・どの issue の記録か」を表すキーが無く、`resolve_mr` が記録を無条件に優先する（e13-2）。`branch` キーの追加、`boundary.sh` への再導出の入り口（`--refresh` 等）、ブランチ名（`feature-<N>-*`）との突き合わせが候補 | 0010／保留 P2 |
| 11 | （0005）`write_mr_json` に issue 番号の入り口が無く `.issue` が常に null（e13-3）。仕様 `00-workflow-issue-mr-driven.md:194` の正の形と実装が食い違っている。読み手は `session-start.sh:116` と `finalize.sh:55` | 0010／保留 P2 |
| 12 | （0005）フックは本流の実体、提供コマンドは worktree の実体で動く（e11）。`.claude/` を変えるブランチを worktree で開発するときの前提を仕様に書くか、起動の形を揃えるかを決める。0004 の R5（設定は常に本流）と同じ根 | 0010 |
| 13 | （0005）提供コマンドに排他制御が無い（e15）。同一ツリーでの並列は `.git/index.lock` と採番で衝突する。worktree に分ければ index の競合は消えるが採番は残る | 0010／0007（観点 D の合流コスト） |
| 14 | （0005）提供コマンドのテストに worktree のケースが 1 件も無く、絶対パス起動のケースも無い（既存テストは一時リポジトリへ**コピーして相対起動**する形）。作業ツリー解決のテスト ID を提供コマンド側にも新設する必要がある | 0010（テスト ID の新設）／AI アセット実装 |
| 15 | （0005）`logs/usage/<branch>.json` は再導出の経路が無く、作業ツリーを分けると対応工数の集計が割れる（e12）。`boundary.sh:399-403` が投稿後に**上書き**する形も、フック側の積み上げ（`post-push-usage-report.sh:51`）と噛み合っているか確かめる必要がある | 0010 |

## 想定と異なった点

| 計画時の見込み | 実際 | どう扱ったか |
|---|---|---|
| 調査計画書は「`HOOK_ROOT` を使うべき箇所と `HOOK_WORKTREE` を使うべき箇所が取り違えられていないか」を主な問いに置いていた | 明確な取り違えは 0 件で、疑い・潜在が 4 件。より効くのは「1 つの作業ツリーしか基準にできない」ことの帰結（e5）だった | 観点は書き換えず、e2 で取り違えを 4 件として報告したうえで、重心を e5 に置いた |
| フック共通仕様 §13 と DDR `i0009-64` の「`workflow-diff-check` は worktree の差分を見ない」は現状の記述として使えると見込んでいた | 実装は初版から `git -C "$HOOK_WORKTREE"` で、記述と逆 | e6 の D1 として記録し、実測 P5 で確定させることにした |
| 実測は「Claude を worktree に入れる」形でしか取れないと見込んでいた | フックは stdin の `cwd` だけで作業ツリーを決めるので、`cwd` を与えて直接叩けば大半の観点が確かめられる（P1〜P7）。Claude 本体の挙動に依存するのは「`cwd` が追随するか」だけ | 実測手順を 2 段に分け、人間の手数を P8 に閉じ込めた |
| `git worktree list` は読み取りなので通ると見込んでいた | `git worktree` は `_SC_GIT_READ_SUBCMDS` に無く WF204。同じコマンド行に混ぜた他の `git` 読み取りも巻き添えで拒否された | 迂回せず、`ls-tree` / `rev-parse` に分けて取り直した。観点 E（0008）の材料として記録 |
| （0005）調査計画書は「`logs/` が worktree に無い状態で各コマンドがどう振る舞うか」を主な問いに置き、DoD も「最初に壊れるコマンドを特定する」と書いていた | **壊れるコマンドは実質 1 本（`finalize.sh release`）だけ**で、それも停止であって誤動作ではない。実害が大きいのは逆方向、つまり前 issue の記録が**残る**ことだった（e13） | 観点は書き換えず、e12 で「壊れない」ことを根拠付きで書いたうえで、重心を e13・e14 に置いた |
| （0005）`LOGGER_ROOT` は `cwd` から決まると見込んでいた（フックの `HOOK_WORKTREE` と同じ形だと思っていた） | `__ss_load` は **`BASH_SOURCE[1]`（起動に使ったスクリプトのパス）** から決める。`cwd` が効くのは相対パス起動のときだけで、絶対パス起動では `cwd` を一切見ない | e10 に対応表として書き、ずれる条件を 3 つに分けた |
| （0005）`CLAUDE_PROJECT_DIR` は常に設定されていると見込んでいた | 本セッションの Bash ツールでは**未設定**だった。`settings.json` がフックの起動に使っている以上フック経由では設定されているので、経路によって `__ss_load` の 2 段目が効いたり効かなかったりする | 「確かめられなかったこと」に上げ、実測手順 B2 に落とした |
| （0005）提供コマンドのテストは worktree を扱っていないだろうと見込んでいた（0004 のフック側と同じ想定） | そのとおり 0 件だったが、**既存テストが一時リポジトリに `.claude` をコピーして相対起動する形**（`test_ticket.sh:12-23`）であることが、`__ss_load` の読み（相対起動なら `$PWD` のツリーに解決する）の裏取りになっていた | e10 の根拠として使い、e16 の B5 でも同じ形を使う設計にした |
| （0005）`boundary.sh` の `merge_state()` の絞り込みは、汎用の作りだろうと見込んでいた | `:138-140` に「別の issue で `ready` まで終えた記録がそのまま残る」という**同じ失敗の再発防止のコメント**が明示されていた。つまり 1 度踏んで直した箇所で、`push.sh` にだけ横展開されていない | e13-1 の根拠にした。設計への反映 9 で共通化の候補として挙げた |

## 残課題

| # | 残課題 | 引き取り先 |
|---|---|---|
| R1 | Claude が worktree に入ったとき、各イベントの `cwd` が実際に worktree を指すか。本レポートは DDR `i0009-55` が引用した公式原文を二次資料として使っただけで、原文の確認も実測もしていない | 0006（`web` あり）／0009（実測 P8） |
| R2 | 仕様 §13 と DDR `i0009-64`「残る穴」の根拠になった **0031 の実測**が、なぜ「worktree の差分は事後検査に現れない」と結論したのか。当時の作業ログ・レポートは本ブランチの `wip/` に無い（別 issue の作業領域は片付け済み） | 0009（実測 P5 で現在の挙動を確定）／必要なら過去 MR の履歴を読む |
| R3 | `git worktree repair` 前の作業ツリー（相互参照が片方向）が本流に倒れることの実害。DDR `i0009-64` が却下した副作用が実装では起きている（e6 D2）。安全側ではあるが、worktree を移動する運用があるなら気づけない静かな縮退になる | 0010（AI アセット設計） |
| R4 | Skill ツールが読み込む `SKILL.md` が本流と worktree のどちらの実体か。これが決まるまで `session-start.sh:140`（X1）の正誤は確定しない | 0006／0010 |
| R5 | 本流と worktree で `scope-limits.json` の内容が食い違う場合（worktree が古い / 新しいブランチ）、フックは常に本流の設定で判定する（`hook-common.sh:347`）。設定を変えるブランチを worktree で開発すると、そのブランチの設定はテストされない | 0010 |
| R6 | e5 を受け入れ条件 A1 の「動かない箇所」として扱うか、全体計画書の保留 P2（機構の不具合として別 issue）へ回すか | 0009／0010（人間の判断） |
| R7 | （0005）`LOGGER_ROOT` が worktree とずれる 3 条件（e10-2）が実環境で本当に起きるか。とくに条件②（`CLAUDE_PROJECT_DIR` に落ちる）は、この変数がどの経路で設定されるかに依存する | 0009（実測 B1・B2・B3） |
| R8 | （0005）`boundary.sh status` を detached HEAD の worktree で走らせたとき、`gh pr view` が MR を特定できるか（`gh` はブランチから PR を引くので、detached では失敗する見込み）。並列で detached HEAD を使う案（観点 D）の成否に効く | 0009（実測 B4）／0007 |
| R9 | （0005）`logs/usage/<branch>.json` について、`boundary.sh:399-403` の**上書き**（`{posted, since_sha, url}` の 3 キーだけ）が、フック側の積み上げ（`post-push-usage-report.sh:51` が持つ `sessions` / `subagents` / `last_offset`）を消していないか。本チケットの担当範囲（worktree 分離）を超えるが、読んだ範囲で疑いが出た | 保留 P2 の別 issue（スコープ外で見つけたこと） |
| R10 | （0005）e13 の 3 件を受け入れ条件 A1 の「動かない箇所」に載せるか、全体計画書の保留 P2 として別 issue に切り出すか。R6 と同じ判断 | 0009／0010（人間の判断） |
| R11 | （0005）`__ss_load` の 1 段目は `..` を畳まずに `-d` で判定するため、`LOGGER_ROOT` に `…/x/../y` のような未正規化の文字列が入りうる（e10-1 の 6）。フック側は `__hc_winpath` で畳むので、同じディレクトリでも 2 つの根が別表記になる。比較する箇所は今は無いが、将来「本流と同じツリーか」を判定するなら効く | 0010 |
