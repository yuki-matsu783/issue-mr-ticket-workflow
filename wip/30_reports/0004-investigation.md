---
type: report
title: 0004 調査結果 — worktree 上での機構の健全性（観点 A: フックの作業ツリー解決 / 観点 B: 提供コマンドと logs/ 状態ファイル / 観点 C: サブエージェントの別 worktree 起動可否 / 観点 D: 1 issue = 1 ブランチとの両立と合流コスト）
description: issue #50 の調査フェーズの結果。観点 A では、フックの HOOK_ROOT / HOOK_WORKTREE の全参照 81 件を判定つきで一覧にし、6 本のフックが worktree 側と本流側のどちらで判定するかを行番号つきで確定した。観点 B では、提供コマンド 5 本の状態ファイル依存 17 行を「無いときの振る舞い」つきで表にし、__ss_load が cwd ではなくスクリプトの置き場で LOGGER_ROOT を決めることと、そのずれる 3 条件を特定し、本 issue の実施中に実際に踏んだ 3 件の根本原因を行番号で押さえた。観点 C では、サブエージェントを別 worktree で動かせること（isolation: worktree）を公式 18 引用つきで確定し、既定の分岐元が既定ブランチであるために機構が静かに無効化されることと、subagent-start-check が読む cwd が 2 経路で別物であることを押さえた。観点 D では、git の同一ブランチ制約を公式引用で確定し、ブランチ構成 4 案の比較表・合流手段 6 案のコスト・過去 issue の実データ（feature-10 の 247 コミット中 168 件が状態遷移コミット、rename 104 件）からの衝突見積もり（レポート 1 対あたり同一行の書き換え 13 行）を出し、DDR i0001-23 の却下文 3 主張を再評価した。人間が実行するための実測手順（コマンド列 + 予測）を観点ごとに残した。
tags: [report, investigation, issue-50]
keywords: [worktree, HOOK_WORKTREE, HOOK_ROOT, LOGGER_ROOT, __ss_load, 作業ツリー解決, 静かな無効化, workflow-guard, workflow-diff-check, hc_lock, HK-T18, 提供コマンド, merge-state, mr.json, 実測手順, isolation, worktree.baseRef, subagent-start-check, EnterWorktree, worktreeinclude, 隔離強制, decisions.jsonl, 同一ブランチ制約, detached HEAD, ignore-other-worktrees, 合流, rename検出, WF207, WF401, merge-base, i0001-23, squash merge, 採番]
---

# 0004 調査結果 — worktree 上での機構の健全性（観点 A: フックの作業ツリー解決 / 観点 B: 提供コマンドと `logs/` 状態ファイル / 観点 C: サブエージェントの別 worktree 起動可否 / 観点 D: 1 issue = 1 ブランチとの両立と合流コスト）

- 対象 issue: [#50](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/50)
- MR: [#51](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/pull/51)（draft）
- ブランチ: `feature-50-worktree-parallel-tickets`
- チケット: 0004（観点 A）／0005（観点 B）／0006（観点 C）／0007（観点 D）
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

0006 まで（観点 A・B・C）。ここから下の段落・箇条書きが 0006（観点 C）で足した分で、上の 0004・0005 の記述は書き換えていない。**表題は観点 A・B から観点 A・B・C を含む形に広げた**（読み替えの注記は 0005 の段落にある）。

観点 C の問い「サブエージェントを呼び出し元と別の worktree で動かせるか」への答えは **「動かせる。公式に専用の機能があり、Agent ツールの引数ではなくエージェント定義の frontmatter `isolation: worktree` で指定する。ただし現行の機構をそのまま載せると、サブエージェント側の worktree が既定ブランチから切られるため、機構が静かに無効化される」**。呼び出し元の起動プロンプトが前提に置いた「呼び出し元の作業ディレクトリは固定で、サブエージェントは既定でそれを引き継ぐ」は**既定としては正しく、前提は崩せる**（e17）。

- 公式の一次資料は 4 本（`sub-agents` / `worktrees` / `hooks` / `agents`）。取得日 2026-09-04。`docs.claude.com/en/docs/claude-code/*` は `code.claude.com/docs/en/*` へ 301 で移っている。DDR `i0009-55` が二次資料として引用していた `hooks.md:598-601` の原文は現在の `hooks` ページに**同じ文言で実在**し、引用は今も有効だった（e18）
- `subagent-start-check` が読む `cwd` は **2 つの経路で別物**。PreToolUse `Agent`（WF801 / WF803）は呼び出し元のツール呼び出しなので**呼び出し元の `cwd`**。SubagentStart（WF802）は公式が「フックが呼ばれた時点の作業ディレクトリ」としか書いておらず、`isolation: worktree` のとき worktree 作成の前か後かを**書いていない**ので **不明**（実測が要る）。どちらの経路でも対象チケットは `$HOOK_WORKTREE` から取る（`subagent-start-check.sh:41-42`）（e19）
- **サブエージェントは呼び出し元とセッション ID を共有する**。本セッションの 4 件（0003 / 0004 / 0005 / 0006 の起動）の SubagentStart 記録は 4 件とも `session_id` が `595e717b-…` で、本サブエージェントの `CLAUDE_CODE_SESSION_ID` と同一（`CLAUDE_CODE_CHILD_SESSION=1`）。公式の「Subagents work within a single session」と一致する（e19）
- **`decisions.jsonl` は `cwd` も `agent_id` も記録していない**（全 7506 行のキーが `ts, session_id, hook, event, decision, id, tool, target, ticket, note` の 10 個で一致）。SubagentStart の記録は **22 件**あり 22 件とも本流の `logs/hooks/decisions.jsonl` に落ちているが、本リポジトリで worktree を作ったことが 1 度も無いので、これは「worktree でも本流を見る」ことの証明にはならない（負のコントロールが無い）（e19）
- **サブエージェント worktree の既定の分岐元は「リポジトリの既定ブランチ」であって呼び出し元の `HEAD` ではない**。`main` の `wip/10_tickets/10_doing/` は `.gitkeep` のみ（0004 の検証済み）なので、隔離したサブエージェントから見るとチケットが 0 枚になり、`workflow-guard.sh:59` が即座に抜けて**すべての書き込みと実行が素通りする**（DDR `i0009-55` が言う「静かな無効化」がそのまま再現する）。回避には `worktree.baseRef: "head"` の設定が要るが、本リポジトリの `.claude/settings.json` に `worktree` キーは **0 件**（e20）
- worktree の既定の置き場は `.claude/worktrees/<名前>/` で、これは `scope-limits.json` の `common.protected` の `.claude/**` に含まれる。作業ツリーの解決が成功すれば書き込みは worktree ルート相対（`wip/…`）になって当たらず、失敗して本流に倒れると `.claude/worktrees/…` として硬く拒否される。加えて `.claude/worktrees/` は本リポジトリの `.gitignore` に**無い**（公式は Tip で入れることを勧めている）ので、本流の `git status --porcelain` に未追跡として現れ、`push.sh` 項目 1（`push.sh:78`）が落ちる（e21）
- Claude Code は隔離中のセッション・サブエージェントに 4 つの検査を掛ける。うち **command shape の検査は「引用符のないヒアドキュメント」「ブレース展開」を含む Bash コマンドを拒否し、公式が「You can't turn this check off」と明記している**。本プロジェクトは長い文面をヒアドキュメントで一時スクリプトに書いて実行する運用が常態なので、ここが正面から当たる。一方 git リダイレクト検査（`git -C` ほか）は、提供コマンド 5 本の本体に `git -C` が **0 件**（テストとテストヘルパのみ）なので当たらない（e22）
- 動かせない場合・採らない場合の代替は 6 通り挙げ、成立条件を書いた（e23）。うち機構と最も相性がよいのは「人間が `claude --worktree <名前>` で別セッションを開く」で、成立条件は ①`.claude/worktrees/` を `.gitignore` に入れる ②`logs/` を `.worktreeinclude` で複製するか worktree ごとに作る ③同じ feature ブランチを 2 つの作業ツリーで checkout できない git 制約を回避する（0007 の観点 D）④workspace trust を先に取る、の 4 つ
- 件数（**タスク全体の合計。0005 の合計行を 0006 分まで積み上げた最新の合計で、以後はこの行を指す。0005 の「◎良 6 件 / △注意 8 件 / ✕問題 2 件 = 16 件」は 0005 時点の合計として読む**）: **◎良 10 件 / △注意 11 件 / ✕問題 3 件 = 24 件**（内訳: 0004 が ◎3 / △4 / ✕1 = 8 件、0005 が ◎3 / △4 / ✕1 = 8 件、0006 が ◎4 / △3 / ✕1 = 8 件）

0007 まで（観点 A・B・C・D）。ここから下の段落・箇条書きが 0007（観点 D）で足した分で、上の 0004・0005・0006 の記述は書き換えていない。**表題は観点 A・B・C から観点 A・B・C・D を含む形に広げた**（読み替えの注記は 0005 の段落にある）。あわせて冒頭の「チケット」欄が `0004（観点 A）` のまま取り残されていたので 4 枚を列挙する形に直した（HTML 側は 0006 の時点で 3 枚を列挙しており、md が追随していなかった。結論の書き換えではなく見出し情報の同期）。

観点 D の問い「1 issue = 1 ブランチ = 1 MR を保ったまま複数 worktree を使えるか、合流コストはどれだけか」への答えは **「保ったまま使える。git の同一ブランチ制約は『サブブランチを切って後で合流する』形で回避でき、MR は squash merge されるので中間の履歴は `main` に残らない。合流コストの主体はファイルの衝突ではなく、①機構が『ブランチ間の合流』という操作を設計として拒否していること（DDR `i0004-07` が `merge-base` 分類で `origin/<default>` 以外の `merge` を拒否すると明記）と、②1 タスク 1 レポートの積み上げ運用が、追記のたびに md と HTML の同じ 13 行を必ず書き換えるため、並列の追記が確実に衝突することにある」**。

- **git の同一ブランチ制約は公式に明記されている**（`git worktree` の `--force` の説明が「`add` refuses to create a new worktree when *&lt;commit-ish&gt;* is a branch name and is already checked out by another worktree」、`git checkout` の `--ignore-other-worktrees` が「`git checkout` refuses when the wanted branch is already checked out or otherwise in use by another worktree」）。回避策は 3 つとも公式に口がある（`--detach` / 引数省略時の自動ブランチ作成 / `--force`・`--ignore-other-worktrees`）（e26）
- ブランチ構成は **4 案**（detached HEAD / サブブランチ + 合流 / `--force` で同一ブランチ共有 / 別 clone）を比較した。**成立するのはサブブランチ + 合流と別 clone の 2 案だけ**で、detached HEAD は `push.sh:68` が「現在ブランチを特定できない（detached HEAD。環境の誤り）」で必ず CP007 に落ちるため成立せず、`--force` は 2 つの作業ツリーが同じ ref を進めるため一方の commit が他方を「削除済み」状態にする（e27）
- **Claude Code のサブエージェント隔離（`isolation: worktree`）が作るのは `worktree-<名前>` というサブブランチ**（0006 の e18 の S9）で、これは案 2 そのものである。つまり「隔離を採る = サブブランチ + 合流を採る」であり、合流手順を決めないと成果が孤立したブランチに残る（e27・e28）
- **合流の手段は 6 案挙げたが、現行の機構が AI に通すのは 2 つだけ**。`cherry-pick` / `rebase` / `am` / `revert` / `commit-tree` は `block-direct-git` が WF401 で拒否する（`block-direct-git.sh:36, 98-100`）。`git merge` は WF401 の対象外だが、`scope.sh:392-393` が「引数に `origin/*` があれば `merge-base`、無ければ `unknown`」と分類するため、`git merge worktree-<名前>` は `unknown` → WF204 の既定拒否になる。**ただし作業中チケットが 0 枚なら `workflow-guard.sh:49` が即座に抜けるので素通りする** — 通るのは統制の抜けであって許容ではない（DDR `i0004-07` が「取り込み以外の `merge`（ブランチ間の統合）は `merge-base` 分類で `origin/<default>` 以外を拒否できる」と設計意図を明記している）（e28）
- **過去 issue の実データ**（`git log --diff-filter=R --name-status`）: 全ブランチ合計の rename は **235 件**（`00_todo→10_doing` 133 / `10_doing→20_done` 94 / `10_doing→30_cancelled` 6 / `00_todo→20_done` 2）。直近の完了 issue `feature-10` は **チケット 57 枚 / rename 104 件 / 全 247 コミット中 168 件（68%）が状態遷移コミット**で、**1 コミットあたりの rename はちょうど 1 件**（104 コミットすべてが 1 件）だった（e29）
- **衝突の見積もり**: `wip/10_tickets/` の rename は**チケットごとに別ファイル**なので、並列でも衝突は **0 件**（同じチケットを 2 つの worktree で動かさない限り）。一方 `wip/30_reports/` の**同一レポート 1 対への追記は、md 4 行 + HTML 9 行 = 13 行が毎回必ず同じ行の書き換え**になり、並列だと**必ず衝突する**。加えて挿入点も重なり、0005 と 0006 の追記を共通の基点から見ると **md の 11 か所の挿入のうち 6 か所が同一の挿入点、5 か所が 1 行違い**だった（e29・e30）
- **`ticket.sh` の連番の採番は衝突する**。`ticket.sh:154-159` は**自分の作業ツリーの `wip/10_tickets/*/` だけ**を見て最大 + 1 を採るので、2 つの worktree が同じ番号を採る。種類が同じなら同名ファイルで add/add 衝突、種類が違うと**衝突せずに同じ番号のチケットが 2 枚並び**、`find_ticket`（`ticket.sh:50-59`）が先勝ちで片方だけを返す（e30）
- **`ticket.sh` の「作業中は常に 1 枚」の前提は、作業ツリーごとには保たれるが合流後は破れる**。合流時に双方が作業中チケットを持っていると `10_doing/` が 2 枚になり、`workflow-guard.sh:128-138` の WF207 が提供コマンド以外のすべての操作を拒否し、`workflow-diff-check.sh:44-47` は黙って判定をやめる。**合流をタスクの切れ目（作業中 0 枚）に限れば起きない**（e31）
- **DDR `i0001-23` の却下文 3 主張の再評価**: 「分離は強い」= **今も成り立つ**（むしろ 0004 の e5 を Claude Code 側の隔離検査が塞ぐぶん強くなった）／「1 issue = 1 ブランチ = 1 MR の原則と衝突し」= **成り立たない**（原則は issue↔ブランチ↔MR の対応を言うもので、push しないローカルのサブブランチは MR を増やさない。加えて squash merge で中間履歴は `main` に残らない）／「統合のコストが利得を上回る」= **条件付きで成り立つ**（ファイル衝突は小さいが、合流の操作自体が機構の設計意図に反しており、レポート追記の衝突は毎回確実に出る）（e32）
- 件数（**タスク全体の合計。0006 の合計行を 0007 分まで積み上げた最新の合計で、以後はこの行を指す。0006 の「◎良 10 件 / △注意 11 件 / ✕問題 3 件 = 24 件」は 0006 時点の合計として読む**）: **◎良 15 件 / △注意 15 件 / ✕問題 4 件 = 34 件**（内訳: 0004 が ◎3 / △4 / ✕1 = 8 件、0005 が ◎3 / △4 / ✕1 = 8 件、0006 が ◎4 / △3 / ✕1 = 8 件、0007 が ◎5 / △4 / ✕1 = 10 件）

### ◆特に見てほしい（判断に困っている）

- e5 の位置づけ。「作業ツリーをまたぐ絶対パス指定で進行状態ファイル保護がすり抜ける」ことは、フック共通仕様 §13「意図的な緩和」が約束している「機構が守るのは進行状態・コミット / push・`chmod`（常時フック）まで」に反する。**issue #50 の受け入れ条件 A1 の「動かない箇所」として扱うか、全体計画書の保留 P2（機構の不具合として別 issue）へ回すか**を決めきれていない。並列実施を採らなくても worktree を使えば踏むので前者に寄せたが、判断は 0009 と 0010 に委ねる
- e2 の `session-start.sh:74`（`boundary.sh` のパスを `HOOK_WORKTREE` から取る）。仕様 §2 の「スクリプトの置き場は常に `HOOK_ROOT`」に反するが、`boundary.sh` は自分の `BASH_SOURCE` からルートを決めるので、本流の実体を呼ぶと本流の `wip/` を読んでしまい、かえって間違った現在地が出る。**「原則が例外を必要としている」のか「原則の書き方が粗い」のか**を設計フェーズで決めてほしい

- （0005）e13 の 3 件の位置づけ。`push.sh` 項目 4・`resolve_mr`・`write_mr_json` の 3 件は、全体計画書の保留 P2 に「`logs/` の進行状態が issue をまたいで残る」「`mr.json` の `issue` が誰にも書かれない」として既に挙がっている。一方で 3 件とも**受け入れ条件 A1 の「動かない箇所」でもある**（worktree を使えば緩和されるという意味で、本 issue の判断材料そのもの）。**P2 として別 issue に切り出すのか、A1 の一覧に載せて本 issue の設計フェーズで直すのか**を決めきれていない。0004 の e5 と同じ判断で、まとめて 0009 / 0010 に委ねる
- （0005）e11 の「フックは本流の実体、提供コマンドは worktree の実体」を**正とするか**。正とするなら「機構が自分自身の 2 バージョンで動く」ことを仕様に明記して、`.claude/` を変えるブランチを worktree で開発するときの手順（本流へ戻ってから機構を使う等）を決める必要がある。正としないなら提供コマンドも `CLAUDE_PROJECT_DIR` 起動に寄せることになるが、そうすると worktree で作業しても本流の `wip/` を触ってしまい、worktree の意味が消える。**どちらも一長一短で、調査の範囲では決めない**

- （0006）**観点 C の答えが肯定なので、保留 P1（並列を採るか）の重心が「できるか」から「載せ替える価値があるか」に移った**。手段は存在するが、そのまま載せると e20（既定ブランチから切られて機構が無効化される）・e21（`.claude/worktrees/` が protected かつ未 gitignore）・e22（ヒアドキュメント検査を無効化できない）の 3 つを同時に直すことになる。**この 3 つを直してでも 1 issue 内の並列を採るのか**を、0009 と 0010 で判断してほしい。調査の範囲では決めない
- （0006）**e20 を受け入れ条件 A1 の「動かない箇所」に載せるか**。「サブエージェントを `isolation: worktree` で起動すると機構が静かに無効化される」は、worktree 上の健全性（A1）の問題でもあり、並列採否（A4）の材料でもある。0004 の e5・0005 の e13 と同じ判断で、まとめて 0009 / 0010 に委ねる

- （0007）**DDR `i0001-23` の却下文のうち「1 issue = 1 ブランチ = 1 MR の原則と衝突する」を『成り立たない』と判定した**。根拠は ①原則の正文（`00_requirement/自己改善ワークフロー機構.md:163`）が言うのは issue とブランチと MR の 1:1:1 対応で、ローカルの中間ブランチを禁じてはいないこと ②同じ前提条件の次の行が「並行して作業する場合は git worktree または別の clone を使う」と**明示的に worktree を許している**こと ③「MR は squash merge され、ブランチ上の作業領域（`wip/`）の履歴は main に残らない」（同 :161）ので中間の合流コミットが正史を汚さないこと、の 3 点である。**この読み方でよいか**（原則を「feature ブランチ以外のブランチを作らない」と読むなら判定は逆になる）を判断してほしい。調査の範囲では原則の解釈を変更していない（e32）
- （0007）**合流の操作を機構がどう扱うかを決めきれていない**。`git merge worktree-<名前>` は作業中チケットが 0 枚なら現行でも素通りするが、DDR `i0004-07` は「取り込み以外の `merge`（ブランチ間の統合）は `merge-base` 分類で `origin/<default>` 以外を拒否できる」と、**拒否できることを利点として書いている**。並列を採るなら ①`merge-base` を「合流も含む」に広げる ②合流専用の提供コマンド（`merge.sh`）を足す ③合流は人間だけが行う、のいずれかを選ぶことになる。**この選択は設計判断なので 0010 に委ねた**が、③を選ぶと並列の利得が人間の手数で相殺されるおそれがある（e28・e33）

### ◇判断が欲しい（決めた方針の承認 / 決められない点の判断）

- 取り違えの判定基準を「その参照が指しているものが、①スクリプト・設定の実体（= `HOOK_ROOT` が正）か、②`wip/` `logs/` `git` の状態（= `HOOK_WORKTREE` が正）か」の 2 択に固定し、定義行・コメント・テストの設定は判定の対象外とした（e2 の表の `C` と `T`）。この線引きで 81 行を 5 群に割った
- 実測手順は **「Claude を worktree に入れる」実測と「`cwd` を worktree にしたフックの単体実行」の 2 段に分け、後者を主にした**（e8）。前者は `git worktree add` も `cd` も機構が WF204 で拒否するため AI からは組み立てられず、人間の手数も多い。後者は同じ判定経路を stdin から直接叩けて、識別子（W1 = チケット 0 枚の作業ツリー）を置けば「worktree 側で判定したか」を一意に切り分けられる
- 実測の識別子として **`main` を基点にした作業ツリー W1（`wip/10_tickets/10_doing/` が `.gitkeep` だけ = チケット 0 枚）** を使う設計にした。本流と同じ内容の作業ツリーでは「worktree 側を見た」と「本流を見た」が同じ出力になり区別できないため

- （0005）「無いときの振る舞い」を **既定値 / 再導出 / 停止 / 依存なし** の 4 値に固定して分類した（e9-1）。「既定値」は無いことを正常として続けるもの、「再導出」は無いことを検知して別の情報源から作り直すもの、「停止」は未充足として止まるもの。この線引きで 17 行を割った
- （0005）`LOGGER_ROOT` のずれは **`__ss_load` の 1 行を読んだ静的解析**であって実測ではない。`CLAUDE_PROJECT_DIR` は本セッションの Bash ツールの環境では**未設定**（`echo "${CLAUDE_PROJECT_DIR:-未設定}"` で確認）なので条件②は実運用では起きにくいと判断したが、フックは `settings.json` がこの変数で起動するので**フック経由では必ず設定されている**。経路によって結論が変わる
- （0005）実測手順（e16）は **本流だけでできる 2 件（B1・B2）と worktree が要る 4 件（B3〜B6）** に分けた。B1・B2 は 0004 の実測手順 P0（worktree の作成）より前に単独で実行できるので、worktree を作れない環境でも先に片付く

- （0006）「可否」を **「Claude Code の機能として存在するか」と「現行の機構を載せて成立するか」の 2 段に分けて答えた**。前者だけで答えると「動かせる」で終わり、後者だけで答えると「動かせない」になる。DoD が求めているのは観点 C の可否なので、結論は前者（動かせる）を主にし、後者を e20〜e22 の条件として並べた
- （0006）`subagent-start-check` が読む `cwd` について、**PreToolUse `Agent` 経路は「呼び出し元」と断定し、SubagentStart 経路は「不明」に留めた**。前者は Agent ツールの呼び出し自体がメイン側のツール呼び出しであることと、公式の `agent_id` の説明（「Present only when the hook fires inside a subagent call」）から断定できる。後者は worktree の作成時点と SubagentStart の発火時点の前後関係が公式に書かれていないため、推測で埋めずに実測（C2）へ落とした
- （0006）**`isolation: worktree` を実際に試していない**。試すには `.claude/agents/` に検査用のエージェント定義を置くか既存の `task-executor.md` の frontmatter を変えることになり、どちらも本チケットの `allow.write`（`wip/**`）の外である。書き込みを拒否されたわけではなく、**宣言の範囲外なので初めから試みなかった**。実測手順 C1〜C4 に落として人間に回した
- （0006）**フックは Claude Code の隔離検査（git リダイレクト・command shape）の対象外**と読んだ。公式が検査の対象を「a Bash, PowerShell, or Monitor command」と限っており、フックは Claude Code 自身が起動するプロセスでツール呼び出しではないためだが、これは**引用からの推論**であって明文ではない。外れると `git -C "$HOOK_WORKTREE"` を持つフック 4 本（`session-start` / `subagent-stop-check` / `post-push-compact-prompt` / `post-push-usage-report`）が隔離下で止まる

- （0007）**衝突の「件数」を、git を実際に走らせずに出した**。`git merge` も `git merge-tree` も `diff3` も `scope.sh` の分類に無く WF204 で拒否されるため（`merge-tree` は `_SC_GIT_READ_SUBCMDS` に無い）、**3-way マージを 1 度も実行していない**。代わりに「過去の追記コミットの hunk の位置を共通の基点に写して、両者が同じ行・同じ挿入点に当たるかを数える」という静的な方法を採った。同一行の書き換え 13 行は確実だが、挿入点の重なりが実際に conflict marker を生むかは **git のマージ規則（重なりの判定）に依存する**ので、実測手順 D3 に落とした（e29・e34）
- （0007）**ブランチ構成の選択肢を、計画書の 3 案（detached HEAD / サブブランチ + 合流 / `--force`）に「別 clone」を足して 4 案にした**。理由は、`00_requirement/自己改善ワークフロー機構.md:164` が並行の手段として worktree と並べて別 clone を明記しており、比較表に載せないと「原則が許している選択肢」が落ちるためである。計画書の 3 案は表の 1〜3 行目にそのまま残した（e27）
- （0007）**「合流コスト」を 3 つに分けて測った**: ①ファイルの衝突（git が自動で解けない箇所の数）②合流の操作そのものが機構で通るか ③合流後に機構の前提（作業中 1 枚・切れ目の判定）が壊れないか。計画書は ① だけを求めていたが、①が小さいことが分かった時点で ②③ が主コストになったため 3 分割した（e25・e28・e31）
- （0007）**サブエージェント隔離の worktree を、ブランチ構成の第 5 の案にはせず「案 2 の具体形」として表に併記した**。`worktree-<名前>` は `git worktree add <path>` が引数省略時に作るブランチと同じ性質（`$(basename <path>)` の新規ブランチ）で、案 2 と別立てにすると合流手順が二重になるためである（e27）

### ・細かいレビューは不要（ほぼ確実）

- 参照の総数 81 行・90 箇所（`grep -rn ... | wc -l` と `grep -rno ... | wc -l`）は機械的に数えた値である
- `logs/` が `.gitignore` されていること（`.gitignore` の `logs/` 行、`git ls-files logs/` が 0 件）と、`wip/` が追跡されていること（`git ls-files wip/` が 19 件）
- `hc_lock` / `hc_unlock` / `__hc_unlock_all` のロックの置き場が `"$HOOK_WORKTREE/logs/locks/<name>.lock"` であること（`hook-common.sh:604` / `624` / `634`）

- （0005）5 本の `grep -c 'logs/' <スクリプト>` の件数（`ticket.sh` 0 / `commit.sh` 0 / `push.sh` 1 / `boundary.sh` 7 / `finalize.sh` 6。コメント行を含む）は機械的に数えた値である
- （0005）5 本すべてが本体の先頭で `cd "$LOGGER_ROOT"` すること（`ticket.sh:342` / `commit.sh:96` / `push.sh:65` / `boundary.sh:664` / `finalize.sh:538`）。`check-html.sh:61` と `run-tests.sh:62` も同じ形
- （0005）提供コマンド 5 本に `lock` の語が 1 件も無いこと（`grep -rn lock` が 0 件。`blocked` を除く）
- （0005）現物の `logs/mr.json` の `.issue` が `null` であること（`cat logs/mr.json`）

- （0006）`decisions.jsonl` の全 **7506 行**のキーが 10 個（`ts, session_id, hook, event, decision, id, tool, target, ticket, note`）で一致すること（`jq -r 'keys|join(",")' | sort | uniq -c` が 1 行）と、`SubagentStart` の記録が **22 件**、うち本セッション（`595e717b-…`）が **4 件**であることは機械的に数えた値である
- （0006）提供コマンド 5 本の本体に `git -C` / `--git-dir` / `GIT_DIR` / `GIT_WORK_TREE` が **0 件**であること（`grep -rn` が拾ったのは `tests/test_push.sh:57` と `test-lib.sh:71-75` のテスト側のみ）
- （0006）`.claude/settings.json` に `worktree` キーが **0 件**であること、`.gitignore` に `.claude/worktrees/` の行が **0 件**であること
- （0006）`scope-limits.json` の `common.protected` が `[".claude/**", ".gitignore", "apl/*/.gitignore", ".gitattributes"]` の 4 件であること
- （0006）本サブエージェントの実行環境が `AI_AGENT=claude-code_2-1-259_agent` / `CLAUDE_AGENT_SDK_VERSION=0.3.259` / `CLAUDE_CODE_CHILD_SESSION=1` / `CLAUDE_PROJECT_DIR` 未設定 / `pwd` が本流のリポジトリルートであること（`env | grep -i claude` と `pwd`）

- （0007）全ブランチの `wip/10_tickets/` の rename が **235 件**、内訳が `00_todo→10_doing` **133** / `10_doing→20_done` **94** / `10_doing→30_cancelled` **6** / `00_todo→20_done` **2** であること（`git log --all --diff-filter=R --name-status --format='' -- wip/10_tickets/` を `awk` で集計）
- （0007）`feature-10-task-skills-agents-finalize` が **247 コミット / チケット 57 枚 / rename 104 件**で、状態遷移コミットが **168 件**（作成 56 / 着手 56 / 完了 53 / 取り消し 3）であること。**rename を含む 104 コミットはすべて 1 コミット 1 rename**（分布の集計が `104 1` の 1 行）
- （0007）`ticket.sh` の採番が自分の作業ツリーだけを見ること（`ticket.sh:154-159` の `for f in "$TICKETS"/*/[0-9][0-9][0-9][0-9]-*.md` と `max + 1`）
- （0007）`push.sh` が detached HEAD を拒否すること（`push.sh:67-68` の `[ "$branch" != "HEAD" ] || result_ng 007 "現在ブランチを特定できない（detached HEAD。環境の誤り）"`）
- （0007）`block-direct-git` が `merge` と `stash` を明示的に対象外にしていること（`block-direct-git.sh:35-36` のコメントと `__BG_COMMIT_SUBCMDS=' revert cherry-pick am rebase commit-tree '`）
- （0007）`scope.sh` の `merge` の分類が「引数に `origin/*` があれば `merge-base`、無ければ `unknown`」であること（`scope.sh:392-393`）と、`merge-base` を `ops` に持つ種類が `overall-summary` の **1 種類だけ**であること（`scope-limits.json:24`）
- （0007）`.gitattributes` が LF 固定にしているのは `*.sh` / `*.tsv` / `*.json` / `*.html` の 4 拡張子で、**`*.md` は含まれない**こと
- （0007）レポート 1 対への 1 回の追記が md **14 hunk** / HTML **17 hunk** であること（`git show <sha> -U0 -- <path> | grep -c '^@@'` が 0005 の追記・0006 の追記とも md 14 / HTML 17）

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

| （0006）`isolation: worktree` を書いたサブエージェントが実際に別 worktree で走るか、そのとき `pwd` と `git rev-parse --show-toplevel` が何を返すか | 試すには `.claude/agents/` にエージェント定義を置くか既存の frontmatter を変える必要があり、本チケットの `allow.write`（`wip/**`）の外。拒否されたのではなく宣言の範囲外なので試みていない | 0009（実測手順 C1）／人間 |
| （0006）SubagentStart フックの `cwd` が、`isolation: worktree` のときに worktree 作成の**前**の値か**後**の値か | 公式は `cwd` を「Current working directory when the hook is invoked」としか書かず、`WorktreeCreate` と `SubagentStart` の発火順を明示していない。書かれていないことを推測で埋めない | 0009（実測手順 C2） |
| （0006）Claude Code の隔離検査（git リダイレクト・command shape）がフックのプロセスにも及ぶか | 公式は検査の対象を「a Bash, PowerShell, or Monitor command」と限っているが、フックが対象外であることを明示した文はない。引用からの推論に留まる | 0009（実測手順 C3）／0010 |
| （0006）`worktree.baseRef: "head"` を設定したとき、サブエージェント worktree が呼び出し元の feature ブランチの `HEAD` から切られるか（公式は「Inside a worktree, `"head"` resolves to that worktree's `HEAD`」とだけ書き、サブエージェント worktree の分岐元がメイン会話の `HEAD` かどうかは明示していない） | 設定の変更は `.claude/settings.json` への書き込みで `allow.write` の外。加えて中核の設定なので調査で触らない | 0009（実測手順 C4）／0010 |
| （0006）`.worktreeinclude` で `logs/` を worktree へ複製したときに、進行状態（`merge-state.json` ほか）が二重になって何が起きるか | 複製を試すには worktree を作る必要があり、AI からは実行できない（`git worktree` も `--worktree` 起動も WF204 / 人間の操作） | 0009／0010（調査計画書の保留 P2） |
| （0006）`isolation` frontmatter が本環境の Claude Code 2.1.259 で実際に解釈されるか（公式は `isolation` の導入版を明記していない） | 実行して確かめるほかなく、上と同じ理由で試みていない | 0009（実測手順 C1） |

| （0007）2 つの作業ツリーの成果を実際に `git merge` したときに conflict marker が何件出るか | `merge` は `scope.sh` の `unknown`（引数が `origin/*` でないため）で WF204、`merge-tree` は `_SC_GIT_READ_SUBCMDS` に無く同じく WF204、`diff3` は `_SC_READ_ONLY_CMDS` に無い。**3-way マージを実行する手段が 1 つも無い**ので、過去の追記コミットの hunk 位置からの静的な見積もりに留めた | 0009（実測手順 D3）／人間 |
| （0007）`git worktree add --force` で同じブランチを 2 つの作業ツリーに置いたとき、片方の commit が他方の `git status` にどう見えるか | `git worktree` はどの `allow.ops` を宣言しても WF204。公式ドキュメントにも「共有した場合に他方がどうなるか」の明示的な記述が無い（`git-worktree` の BUGS 節は「Multiple checkout in general is still experimental」とだけ書く） | 0009（実測手順 D2） |
| （0007）`git worktree add` が同じブランチを拒否するときの**正確なエラー文言** | 公式ドキュメントは「refuses to create a new worktree when *&lt;commit-ish&gt;* is a branch name and is already checked out by another worktree」と振る舞いだけを書き、文言（`fatal: '<branch>' is already used by worktree at '<path>'` と伝えられているもの）は載っていない。実行して確かめるほかない | 0009（実測手順 D1） |
| （0007）サブエージェント worktree の `worktree-<名前>` ブランチが、サブエージェント終了後に**いつまで残るか** | 公式は「a worktree with changes stays on disk until the periodic sweep below can remove it without losing work」（0006 の e18 の S7）と書くが、sweep の周期も、**ブランチ ref を消すのか worktree ディレクトリだけを消すのか**も書いていない。ref が消えると未合流の成果が失われるため、合流手順の前提として確かめる必要がある | 0009（実測手順 D4）／0010 |
| （0007）並列で得られる**利得**（所要時間の短縮幅） | チケットの `started_at` / `completed_at` は記録されているが、**本ブランチ以外のチケットは `finalize.sh` の片付けで `wip/` ごと消えており、過去 issue の所要時間を後から読めない**（`git show` で復元はできるが、直列で実施した時間しか無く、並列にしたときの短縮幅は推定できない）。コスト側だけを測って利得側を測っていないので、「コストが利得を上回る」の判定は片側の根拠しか持たない | 0009 / 0010（保留 P1 の判断材料として明示） |

## 実施条件（測った対象・環境）

- 対象コミット: `feature-50-worktree-parallel-tickets` の `65d908e`（チケット 0004 の基準点は `9721416`）
- 実行したのは読み取りのコマンドだけ（`grep -rn` / `sed -n` / `git ls-files` / `git ls-tree` / `git rev-parse` / `git log -S`）。ファイルの作成は `wip/30_reports/` と `wip/tmp/` のみ
- 参照の数え方: `grep -rn "HOOK_ROOT\|HOOK_WORKTREE" .claude/hooks/ | wc -l` = 81（行数）、`grep -rno ... | wc -l` = 90（箇所数。内訳 `HOOK_ROOT` 28 / `HOOK_WORKTREE` 62）、テストを除いた本体 = 71 行
- （0005）対象コミット: `feature-50-worktree-parallel-tickets` の `f83cdfd`（チケット 0005 の基準点は `719c098`）
- （0005）実行したのは読み取りのコマンドだけ（`grep -rn` / `sed -n` / `cat` / `ls` / `find` / `wc` / `jq`（ローカルの `logs/*.json` を読むだけ）／ `git ls-files` / `git log -S` / `echo` による環境変数の確認）。ファイルの作成は `wip/30_reports/` と `wip/tmp/` のみ
- （0005）`cd` を含むコマンドが WF204 で 1 回拒否されたため、以後はすべて絶対パスと `git -C` で読んだ
- （0005）`CLAUDE_PROJECT_DIR` は本セッションの Bash ツールでは**未設定**、`PWD` は MSYS 形式（`/c/Users/…`）だった。フック側の `HOOK_WORKTREE` は `__hc_winpath` で `C:/…` に正規化されるので、同じディレクトリでも 2 つの根は**文字列としては別表記**になる

- （0006）対象コミット: `feature-50-worktree-parallel-tickets` の `fb981f6`（チケット 0006 の基準点は `436ecb0`）
- （0006）実行したのは読み取りのコマンドと Web の取得だけ（`grep -rn` / `sed -n` / `cat` / `ls` / `jq`（ローカルの `logs/*.json*` を読むだけ）／`wc` / `env` / `pwd` / `awk` / WebFetch）。ファイルの作成は `wip/30_reports/` と `wip/tmp/` のみ
- （0006）`cd` を含むコマンドが WF204 で **2 回**拒否された（`2026-09-04T23:48:12` と `23:48:24` の `decisions.jsonl` の記録）。以後はすべて絶対パスで読んだ。`for … do` を含むコマンドも 1 回 WF204（`_ はどの分類にも当たらない`）で拒否され、`grep` を並べる形に書き換えた。`bash wip/tmp/<スクリプト>.sh` も WF204（`bash はどの分類にも当たらない`）で拒否されたため、レポートの差し込みは `awk` の出力を `wip/tmp/` に書いて Edit ツールで反映する形に変えた（`cp` で `wip/30_reports/` を上書きしようとして WF205 も 1 回）
- （0006）Web の取得は 4 URL・取得日 **2026-09-04**（e18 の表）。`docs.claude.com/en/docs/claude-code/hooks` は `code.claude.com/docs/en/hooks` へ **301** で、リダイレクト先を明示して取り直した
- （0006）本サブエージェントの実行環境: `AI_AGENT=claude-code_2-1-259_agent`、`CLAUDE_AGENT_SDK_VERSION=0.3.259`、`CLAUDE_CODE_SESSION_ID=595e717b-bd51-4bf4-b049-a23fb8a2fae8`、`CLAUDE_CODE_CHILD_SESSION=1`、`CLAUDE_PROJECT_DIR` **未設定**、`pwd` は本流のリポジトリルート（`/c/Users/taniyama/Desktop/git/issue-mr-ticket-workflow`）

- （0007）対象コミット: `feature-50-worktree-parallel-tickets` の `2a3077d`（チケット 0007 の基準点は `85b90c4`）
- （0007）実行したのは読み取りのコマンドと Web の取得だけ（`grep -rn` / `sed -n` / `cat` / `awk` / `jq` / `wc` / `git log` / `git show` / `git for-each-ref` / `git merge-base` / `git rev-list` / `git config --get-regexp`）。`git worktree` / `git merge` / `git merge-tree` / `diff3` / `cd` は一切実行していない
- （0007）`cd` を含むコマンドが WF204 で **1 回**拒否された。以後はすべて絶対パスと `git -C <本流>` で読んだ
- （0007）Web の取得は 2 URL・取得日 **2026-09-05**（`git-scm.com/docs/git-worktree` を 2 回、`git-scm.com/docs/git-checkout` を 1 回。引用は e26 の表）
- （0007）過去 issue の実データは、`main` との `git merge-base` から各 feature ブランチの先端までを対象にした。対象は `feature-1` / `feature-4` / `feature-6` / `feature-8` / `feature-9` / `feature-10` / `feature-50` の 7 本

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

### e17. 観点 C の答え — サブエージェントは別 worktree で動かせる。口は Agent ツールではなくエージェント定義の frontmatter ◎良

**可否: 動かせる。**

公式は「サブエージェントを一時的な git worktree で走らせる」機能を持っている。指定の口は 2 つある。

| 口 | 書く場所 | 効き方 |
|---|---|---|
| `isolation: worktree` | エージェント定義の frontmatter（本プロジェクトでは `.claude/agents/task-executor.md`） | そのエージェントは**常に**自分の worktree で走る |
| 「エージェントに worktree を使って」と頼む | 会話（メインエージェントへの指示） | その場かぎりで有効になる |

**Agent ツールの引数には無い。** 調査計画書の観点 C は「Agent ツールに作業ディレクトリ／worktree を指定する手段があるか」と問いを立てていたが、探す場所が違っていた（想定と異なった点に記載）。裏取りは 2 つ。

- 本プロジェクトのフックが Agent の `tool_input` から拾っているのは `subagent_type` / `model` / `run_in_background` の 3 つだけで（`hook-common.sh:207-213`）、作業ディレクトリに当たるキーは無い
- 起動プロンプトのひな形（`00-workflow-issue-mr-driven/assets/subagent-prompt.template.md`）にも worktree を渡す欄は無く、`SKILL.md:85` の起動手順も「モデルはチケットの `executor`」までしか書いていない。**ひな形に口が無いのは正しく、口はエージェント定義側にある**

**既定の振る舞い**は、呼び出し元の起動プロンプトが前提に置いたとおりである。公式の原文（e18 の S1）:

> A subagent starts in the main conversation's current working directory. Within a subagent, `cd` commands don't persist between Bash or PowerShell tool calls and don't affect the main conversation's working directory. To give the subagent an isolated copy of the repository instead, set `isolation: worktree`.

つまり「呼び出し元の作業ディレクトリを引き継ぐ」は**既定**であって固定ではない。前提は `isolation: worktree` で崩せる。本サブエージェント自身も既定どおりで、`pwd` は本流のリポジトリルートを返した。

**ただし「動かせる」は「現行の機構がそのまま載る」を意味しない。** 載せたときに起きることを e20（分岐元）・e21（置き場と gitignore）・e22（隔離検査）に分けた。

### e18. 公式ドキュメントの出典（URL・引用・取得日 2026-09-04）◎良

取得はすべて WebFetch。`docs.claude.com/en/docs/claude-code/hooks` は `code.claude.com/docs/en/hooks` へ **301 Moved Permanently** で移っており、リダイレクト先で取り直した。以下の引用は取得したページの本文からの逐語で、訳は付けない（訳すと原文の条件が落ちるため）。

| # | URL | 節 | 引用（逐語） | 取得日 |
|---|---|---|---|---|
| S1 | `https://code.claude.com/docs/en/sub-agents` | Subagent working directory | 「A subagent starts in the main conversation's current working directory. Within a subagent, `cd` commands don't persist between Bash or PowerShell tool calls and don't affect the main conversation's working directory. To give the subagent an isolated copy of the repository instead, set `isolation: worktree`.」 | 2026-09-04 |
| S2 | 同上 | Supported frontmatter fields（`isolation` の行） | 「Set to `worktree` to run the subagent in a temporary git worktree, giving it an isolated copy of the repository branched by default from your default branch rather than the parent session's `HEAD`. The worktree is automatically cleaned up if the subagent makes no changes」 | 2026-09-04 |
| S3 | 同上 | Subagent working directory | 「A subagent with `isolation: worktree` runs its Bash and PowerShell commands inside its worktree. A command whose working directory resolves to your main checkout instead, for example because the worktree directory was removed while the subagent was running, fails with an error.」 | 2026-09-04 |
| S4 | 同上 | Subagent working directory | 「When the main conversation itself runs isolated in a worktree, Claude Code applies the same checks to the session and to every subagent it spawns, including subagents without `isolation: worktree`」 | 2026-09-04 |
| S5 | 同上 | Session scope | 「**Subagents work within a single session.**」／「**Subagents can run in parallel within a session.**」／「There is a concurrent subagent limit: by default, when 20 subagents are running in a session, spawning another with the Agent tool fails with `Concurrent subagent limit reached`.」 | 2026-09-04 |
| S6 | `https://code.claude.com/docs/en/worktrees` | Isolate subagents with worktrees | 「Subagents can run in their own worktrees so parallel edits don't conflict. Ask Claude to "use worktrees for your agents", or make the isolation permanent for a custom subagent by adding `isolation: worktree` to its frontmatter.」 | 2026-09-04 |
| S7 | 同上 | Isolate subagents with worktrees | 「Each subagent gets a temporary worktree that Claude Code removes automatically when the subagent finishes without changes; a worktree with changes stays on disk until the periodic sweep below can remove it without losing work.」／「Subagent worktrees use the same base branch as `--worktree`, so they branch from your repository's default branch unless `worktree.baseRef` is set to `"head"`.」 | 2026-09-04 |
| S8 | 同上 | Choose the base branch | 「`"fresh"` (default): branch from the repository's default branch on the remote, usually `main`, so the worktree starts from a clean tree matching the remote.」／「`"head"`: branch from your current local `HEAD`, so the worktree carries your unpushed commits and feature-branch state. Use this when isolating subagents that need to operate on in-progress work. Inside a worktree, `"head"` resolves to that worktree's `HEAD`, not the main checkout's.」 | 2026-09-04 |
| S9 | 同上 | Start Claude in a worktree | 「Pass `--worktree` or `-w` with a name to create an isolated worktree and start Claude in it. By default, the worktree is created under `.claude/worktrees/<name>/` at your repository root, on a new branch named `worktree-<name>`」／Tip:「Add `.claude/worktrees/` to your `.gitignore` so worktree contents don't appear as untracked files in your main checkout.」 | 2026-09-04 |
| S10 | 同上 | How Claude Code enforces isolation | 「**File edits**: Claude Code blocks an `Edit`, `Write`, or `NotebookEdit` that targets a path in the main checkout.」／「**Command working directory**: Claude Code blocks a Bash, PowerShell, or Monitor command whose working directory resolves to the main checkout, or whose working directory it can't verify stays outside it.」／「**Git redirects**: Claude Code blocks a Bash or Monitor command that redirects git into the main checkout. The redirect can come through `git -C`, `--git-dir`, a `GIT_DIR` or `GIT_WORK_TREE` variable, or a `cd` into the main checkout before running git.」／「**Command shape**: Claude Code blocks a Bash or Monitor command it can't verify stays inside the worktree, even when the command runs no git at all. Claude Code refuses shell constructs it can't trace without running them, such as brace expansion and heredocs with unquoted delimiters. … You can't turn this check off.」 | 2026-09-04 |
| S11 | 同上 | Copy gitignored files into worktrees | 「A worktree is a fresh checkout, so untracked files like `.env` or `.env.local` from your main repository are not present. To copy them automatically when Claude creates a worktree, add a `.worktreeinclude` file to your project root.」／「Only files that match a pattern and are also gitignored are copied, so tracked files are never duplicated.」 | 2026-09-04 |
| S12 | 同上 | Ask Claude to create a worktree | 「You can also ask Claude to "work in a worktree" during a session, and it creates one with the `EnterWorktree` tool.」 | 2026-09-04 |
| S13 | `https://code.claude.com/docs/en/hooks` | Common input fields | 「`cwd` \| Current working directory when the hook is invoked」 | 2026-09-04 |
| S14 | 同上 | Common input fields（subagent の追加フィールド） | 「`agent_id` \| Unique identifier for the subagent. Present only when the hook fires inside a subagent call. Use this to distinguish subagent hook calls from main-thread calls.」 | 2026-09-04 |
| S15 | 同上 | Reference scripts by path（Note） | 「**Worktrees are different.** If Claude enters a worktree during the session, Claude Code keeps `${CLAUDE_PROJECT_DIR}` where it was and passes the worktree path to your hooks a different way:」／「**`${CLAUDE_PROJECT_DIR}` stays put**: it still points at the project root where the session started…」／「**`cwd` follows Claude**: the `cwd` field in the hook's input JSON is the worktree root after Claude enters a worktree, and the new directory after Claude runs `cd`. Read it when a hook needs to know which directory Claude is working in.」 | 2026-09-04 |
| S16 | 同上 | Hooks in subagents | 「Hooks from settings files, managed policy settings, and plugins also run inside subagents. When a subagent calls a tool, tool events such as `PreToolUse` and `PostToolUse` fire the same configured hooks as in the main conversation, and the input carries the `agent_id` and `agent_type` common input fields that identify the subagent.」 | 2026-09-04 |
| S17 | 同上 | WorktreeCreate | 「When a worktree is being created via `--worktree`, `isolation: "worktree"`, or for a background session. Replaces default git behavior.」／event-specific fields は `worktree_path` と `base_ref`／「Any non-zero exit code aborts worktree creation」 | 2026-09-04 |
| S18 | `https://code.claude.com/docs/en/agents` | Run agents in parallel | 「Worktrees give each session a separate git checkout, so parallel sessions never edit the same files. Use them for sessions you run yourself. Agent view moves each dispatched session into its own worktree automatically, and subagents you spawn can each get one too.」／「Agent teams don't isolate teammates in worktrees, so partition the work so each teammate owns a different set of files.」 | 2026-09-04 |

**DDR `i0009-55` の引用の裏取り。** DDR は `hooks.md:598-601` として S15 と同じ文面を二次資料（取得済みの原本）から引いていた。今回 `hooks` ページの原文を直接読み、**同じ文言で実在すること**を確認した。したがって 0004 の e1・e3 が DDR の引用に依存して立てた結論（`cwd` を読むのが公式の指示どおりである）は、一次資料でも支持される。

なお `worktrees` ページ側にも同趣旨の Note があるが、**文言が違う**（「the `cwd` field … is the worktree root, and it moves again when Claude runs `cd`」）。意味は同じで、引用するなら DDR と同じ `hooks` ページ側を使うのが整合する。

### e19. `subagent-start-check` が読む `cwd` は 2 経路で別物。片方は「呼び出し元」、もう片方は「不明」 △注意

このフックは同じスクリプトを 2 つのイベントに登録している（`subagent-start-check.sh:4` のコメント、`settings.json` の `SubagentStart` と PreToolUse `matcher: Agent`）。対象チケットの決め方は共通で、`__sa_target`（`subagent-start-check.sh:36-49`）が `"$HOOK_WORKTREE"/wip/10_tickets/10_doing/*.md` → 無ければ `00_todo/*.md` の先頭を採る。`HOOK_WORKTREE` は `hook_read_input`（`hook-common.sh:369`）が入力 JSON の `cwd` から解決する（0004 の e1）。したがって**答えは「どちらの `cwd` が入力 JSON に載るか」に還元される**。

| 経路 | 発火 | 入力 JSON の `cwd` は誰のものか | 根拠 | 確度 |
|---|---|---|---|---|
| PreToolUse / matcher `Agent`（WF801 実行者の不一致・WF803 background）| メインエージェントが Agent ツールを呼ぶとき | **呼び出し元のもの** | Agent ツールの呼び出しはメイン側のツール呼び出しである。公式 S14 は `agent_id` を「Present only when the hook fires inside a subagent call」と定義しており、Agent の PreToolUse はサブエージェントの中ではないので `agent_id` が付かない。加えて `isolation: worktree` の worktree は `WorktreeCreate`（S17「when a worktree is being created via … `isolation: "worktree"`」）で作られ、Agent ツールの実行より後なので、この時点で worktree はまだ存在しない | **確定** |
| SubagentStart（WF802 要点の注入） | サブエージェントが spawn されるとき | **不明** | 公式は `cwd` を S13「Current working directory when the hook is invoked」としか書かず、`SubagentStart` 固有のフィールドとして挙げているのは `agent_type` だけである。`WorktreeCreate` と `SubagentStart` の**発火順が書かれていない**ため、「worktree に入る前の呼び出し元の `cwd`」か「入った後の worktree ルート」かを決められない | **不明**（実測 C2） |

**記録からの裏取り（件数付き）。**

- `logs/hooks/decisions.jsonl` は全 **7482 行**（`wc -l`。`jq` が読めた行は 7506 で、複数行にまたがる旧形式が混ざっている）。イベント別は PreToolUse 7101 / PostToolUse 249 / UserPromptSubmit 55 / SubagentStop 25 / SessionStart 25 / **SubagentStart 22** / 空 5
- **SubagentStart の 22 件はすべて本流の `logs/hooks/decisions.jsonl` に落ちている**。`hook_record` は `"$HOOK_WORKTREE/logs/hooks/decisions.jsonl"` に書く（`hook-common.sh:654`）ので、22 件とも `HOOK_WORKTREE` が本流に解決したことになる。**ただしこれは「worktree でも本流を見る」ことの証明にはならない。**本リポジトリでは worktree を 1 度も作っておらず、負のコントロール（worktree 側で走らせた記録）が 0 件だからである
- **サブエージェントは呼び出し元とセッション ID を共有する。** 本セッションの SubagentStart は **4 件**（`2026-09-04T22:19:00` = 0003、`22:38:16` = 0004、`23:06:28` = 0005、`23:47:16` = 0006）で、**4 件とも `session_id` が `595e717b-bd51-4bf4-b049-a23fb8a2fae8`**。これは本サブエージェントの環境変数 `CLAUDE_CODE_SESSION_ID` と同一で、環境には `CLAUDE_CODE_CHILD_SESSION=1` も立っている。別々のサブエージェント 4 体が同じ ID を持つ以上、この ID はサブエージェント固有のものではない。公式 S5「Subagents work within a single session.」と一致する
- **サブエージェントのツール呼び出しでもフックは同じように走る。** 本チケット着手後（`23:48` 以降、`session_id` = 上記）の記録は **37 件**で、内訳は `workflow-entry` と `workflow-guard` の PreToolUse が大半、うち **2 件が WF204 の deny**（`cd`）。すべて本流の `logs/` に落ちている。公式 S16 と一致する
- **`decisions.jsonl` は `cwd` も `agent_id` も記録していない。** 全 7506 行のキーが `ts, session_id, hook, event, decision, id, tool, target, ticket, note` の 10 個で一致する（`jq -r 'keys|join(",")' | sort | uniq -c` の出力が 1 行）。`HOOK_AGENT_ID` は `hook_read_input` が読んでいる（`hook-common.sh:360`）のに `hook_record` は落としている。**どの作業ツリーで判定したか・メインかサブエージェントかを記録から後追いできない**ので、並列を採るなら記録側に手当てが要る（設計への反映 16）

**帰結。** WF802 の注入（`isolation: worktree` を採ったときに最も効く経路）が呼び出し元のチケットを見るのか worktree 側のチケットを見るのかは、**読み取りだけでは確定しない**。ただしどちらであっても、`worktree.baseRef` が既定のままなら worktree 側にはチケットが無いので（e20）、結果は同じ方向に転ぶ。

### e20. サブエージェント worktree は既定ブランチから切られる — 機構の「静かな無効化」がそのまま再現する ✕問題

公式 S2 と S7 が明記している。

> giving it an isolated copy of the repository branched **by default from your default branch rather than the parent session's `HEAD`**

> Subagent worktrees use the same base branch as `--worktree`, so they **branch from your repository's default branch** unless `worktree.baseRef` is set to `"head"`.

本リポジトリに当てはめると次のようになる。

| # | 事実 | 根拠 |
|---|---|---|
| 1 | 既定ブランチは `main`。本 issue の作業は `feature-50-worktree-parallel-tickets` にある | `git branch --show-current` |
| 2 | `main` の `wip/10_tickets/10_doing/` は `.gitkeep` の **1 件のみ**（作業中チケット 0 枚） | 0004 の「検証の結果」（`git ls-tree --name-only main wip/10_tickets/10_doing/`） |
| 3 | よって既定設定のサブエージェント worktree には**このフェーズのチケットが 1 枚も存在しない** | 1 と 2 |
| 4 | `subagent-start-check` の `__sa_target` は `10_doing` → `00_todo` の順に探す。`main` の `00_todo` にもチケットは無いので、`hook_record skip "" "" "対象チケットが無い"` で `exit 0`。**WF802 の要点注入が起きない** | `subagent-start-check.sh:44-48, 83-86` |
| 5 | `workflow-guard` は作業中チケットが 0 枚のとき即座に抜ける。**書き込みも実行も全部通る** | `workflow-guard.sh:59`（0004 の e3・実測手順 P2 の予測と同じ経路） |
| 6 | `workflow-entry` の継続条件（`00_todo` / `10_doing` / `20_done` にチケットがあるか）も成立しないので、宣言の要求（WF102）が出る | `workflow-entry.sh:143`（0004 の e3・e4） |
| 7 | 回避には `worktree.baseRef: "head"` が要る。公式 S8 は「Use this when isolating subagents that need to operate on in-progress work」と、まさにこの用途を挙げている | S8 |
| 8 | **本リポジトリの `.claude/settings.json` に `worktree` キーは 0 件** | `grep -n "worktree" .claude/settings.json` |

DDR `i0009-55` は「worktree に入った瞬間に機構が消えることに、誰も気づかない」ことを避けるために `cwd` からの解決を入れた。その解決は効くのに（0004 の e1）、**分岐元が既定ブランチだと「解決には成功して、そこにチケットが無い」という別経路で同じ結末に落ちる**。0004 の実測手順 P2 が識別子として使っている W1（`main` を基点にした作業ツリー = チケット 0 枚で無音）は、**既定設定のサブエージェント worktree そのもの**である。

`worktree.baseRef: "head"` に変えた場合も、公式 S8 の「Inside a worktree, `"head"` resolves to that worktree's `HEAD`, not the main checkout's」は**呼び出し元セッションが worktree にいるとき**の話で、メイン会話が本流にいるときにサブエージェント worktree の分岐元がメイン会話の `HEAD` になるとは明示していない。そこは実測（C4）に落とした。

### e21. worktree の置き場が `.claude/worktrees/` であることの二重の当たり △注意

公式 S9 は「By default, the worktree is created under `.claude/worktrees/<name>/` at your repository root, on a new branch named `worktree-<name>`」と書き、Tip で「Add `.claude/worktrees/` to your `.gitignore`」と勧めている。本リポジトリの現状と突き合わせると 2 つ当たる。

**(1) `.claude/` 配下は機構の保護対象である。**

- `scope-limits.json` の `common.protected` は `[".claude/**", ".gitignore", "apl/*/.gitignore", ".gitattributes"]` の 4 件
- 作業ツリーの解決が**成功**すれば、隔離サブエージェントの書き込みは worktree ルート（`<本流>/.claude/worktrees/<名前>`）からの相対パス（`wip/…`）に落ちるので（`hook_rel_path` の基準は `HOOK_WORKTREE`。`hook-common.sh:758`）、`.claude/**` には当たらない
- 解決に**失敗**して本流に倒れると、同じ書き込みが `.claude/worktrees/<名前>/wip/…` として相対化され、`.claude/**` に当たって拒否される。**成功なら通り、失敗なら硬く止まる**（0004 の e5 のような「失敗しても素通り」ではない）ので、この点は安全側

解決が成功する見込みは高い。`__hc_is_worktree_of` は本流の配下にある worktree を明示的に許しており（`hook-common.sh:298-300` のコメント「本流の配下でも、相互参照が完全に成立するなら正当な worktree（`git worktree add ./sub-wt`）」）、既定ブランチのチェックアウトには `.claude/` が含まれるので上向き探索の 1 段目で当たる。ただし**実測していない**（実測 C1 で確かめる）。

**(2) `.claude/worktrees/` が `.gitignore` に無い。**

- 本リポジトリの `.gitignore` に `.claude/worktrees/` の行は **0 件**（`logs/`・`wip/tmp/*`・`参考ディレクトリ/`・`.claude/settings.json.bak-*` はある）
- 本流の `git status --porcelain` に未追跡として現れる
- `push.sh` の押し込み前チェック項目 1 は `git status --porcelain` の出力が空でないと落ちる（`push.sh:74-83`）。つまり**サブエージェント worktree が 1 つでも残っていると push できなくなる**
- 公式 S7 は「a worktree with changes stays on disk until the periodic sweep below can remove it without losing work」と書いており、**変更を伴うサブエージェント（= チケットを実施するサブエージェント）の worktree は必ず残る**

直し方は `.gitignore` に 1 行足すだけだが、`.gitignore` 自体が `common.protected` に入っているので調査では触らない（設計への反映 18）。

### e22. Claude Code 側の隔離強制 4 検査と、機構の Bash 依存の相性 △注意

公式 S10 の 4 検査を、本プロジェクトの実物と突き合わせた。S4 のとおり、**呼び出し元セッションが隔離されているときは `isolation: worktree` を持たないサブエージェントにも同じ検査が及ぶ**。

| 検査 | 内容（S10） | 本プロジェクトへの当たり | 判定 |
|---|---|---|---|
| File edits | 本流のパスを対象にした `Edit` / `Write` / `NotebookEdit` を拒否 | **0004 の e5（作業ツリーをまたぐ絶対パスの書き込みが進行状態ファイル保護をすり抜ける）を、Claude Code 側が外から塞ぐ**。ただし隔離下のときだけで、隔離していない worktree 運用では効かない | 追い風 |
| Command working directory | 作業ディレクトリが本流に解決する Bash / PowerShell / Monitor コマンドを拒否 | 提供コマンド 5 本は本体の先頭で `cd "$LOGGER_ROOT"` する（0005 の e9）。相対起動なら `LOGGER_ROOT` は worktree に解決するので当たらない。**本流の絶対パスで起動すると当たる**（0005 の e10-2 の条件①がそのまま拒否になる） | 条件付き |
| Git redirects | `git -C` / `--git-dir` / `GIT_DIR` / `GIT_WORK_TREE` / 本流への `cd` を経由して git を本流へ向けるコマンドを拒否 | **提供コマンド 5 本の本体に `git -C` は 0 件**（`grep -rn` が拾ったのは `tests/test_push.sh:57` と `test-lib.sh:71-75` のテスト側のみ）。本体は当たらない。フックには `git -C "$HOOK_WORKTREE"` が 4 本ある（`session-start.sh:113`、`subagent-stop-check.sh:83, 97`、`post-push-compact-prompt.sh:47, 63, 82, 133`、`post-push-usage-report.sh`）が、公式は検査の対象を「a Bash or Monitor command」と限っており、フックはツール呼び出しではないので**対象外と読める（引用からの推論であって明文ではない）** | 条件付き |
| Command shape | worktree の内側に留まると検証できない Bash / Monitor コマンドを拒否。ブレース展開や**引用符のないヒアドキュメント**を含むものが対象で、「**You can't turn this check off**」 | **正面から当たる。** 本プロジェクトは長い文面をヒアドキュメントで `wip/tmp/*.sh` に書いて `bash` で実行する運用が常態である。引用符付きの区切り（`<<'EOF'`）なら通る読みだが、書き分けを人が守る前提になる。既存のスキル・共通ステップの文面はこの書き分けを指示していない | 逆風 |

なお本チケットでは `cd` が **2 回**、`bash wip/tmp/<スクリプト>.sh` が **1 回** WF204 で拒否されており（機構側の理由。`scope.sh` の git 分類・コマンド分類の穴。観点 E）、`cd` は隔離検査（本流への `cd` を git リダイレクトとみなす）と機構の両方から制約される。塞ぎ方を決める 0008 は、**隔離下でも通る形**を条件に入れる必要がある。

### e23. 動かせない場合・採らない場合の代替と、成立条件 ◎良

観点 C の答えは肯定だが、e20〜e22 を直さずに使うことはできない。公式 S18（Run agents in parallel）の比較を土台に、本プロジェクトで成立する形を並べる。**どれを採るかは決めない**（0010 の判断）。

| # | 代替 | 何が分かれるか | 成立条件 | 出典・根拠 |
|---|---|---|---|---|
| A1 | `isolation: worktree` を `task-executor.md` に足す（本命） | サブエージェントごとの作業ツリーと**新ブランチ `worktree-<名前>`** | ①`worktree.baseRef: "head"` を設定し、実際に feature ブランチの `HEAD` から切られることを確かめる（e20）②`.claude/worktrees/` を `.gitignore` に足す（e21）③`logs/` を `.worktreeinclude` で複製するか worktree ごとに初期化する（0005 の保留 P2）④ヒアドキュメントの書き分けを共通ステップに書く（e22）⑤サブエージェントの成果を feature ブランチへ合流させる手順を決める（0007） | S2 / S7 / S8 / S9 / S10 |
| A2 | 人間が `claude --worktree <名前>` で別セッションを開く（機構との相性が最も良い） | セッションごとの作業ツリー・ブランチ・`logs/`・会話 | ①`.claude/worktrees/` を `.gitignore` に足す ②各 worktree に `logs/` を用意する ③**同じ feature ブランチを 2 つの作業ツリーで checkout できない git の制約**をどう回避するか（0007 の観点 D）④初回は workspace trust を対話で取る（`--worktree` は取っていないとエラーで終わる）⑤人間が 2 つの端末を見る | S9 / S18 |
| A3 | 人間が別 clone を開く | `.git` ごと分かれる（`logs/` も自動的に別） | ①同じリモートブランチへ双方が push すると取り合いになるので、ブランチを分けるか push の順序を人間が握る ②`.claude/` の実体が 2 つになり、機構自身を変えるブランチではドリフトする（0005 の e11 と同じ根）③git の同一ブランチ制約には当たらない | 一般的な git の性質（公式ページの対象外） |
| A4 | background agents / agent view（`claude agents`） | セッションごとの作業ツリー（自動で入る） | ①research preview である ②各セッションが自分の issue / MR を持つ形になり、1 issue 内のチケット並列という本 issue の狙いとはずれる | S18「Agent view moves each dispatched session into its own worktree automatically」 |
| A5 | agent teams | **worktree で隔離しない** | ①公式が「partition the work so each teammate owns a different set of files」と明記しており、同じ `wip/30_reports/<連番>-<種類>.md` に積み上げる本プロジェクトの運用とは正面から衝突する ②experimental で既定は無効 | S18 |
| A6 | `/batch` スキル | 5〜30 個の worktree 隔離サブエージェントが**それぞれ PR を開く** | ①1 issue = 1 ブランチ = 1 MR の原則（issue #50 のスコープ外）と正面から衝突する | `agents` ページの `/batch` の記述 |

**「動かせない場合」に相当するのはどれか。** 観点 C の答えが否定でなかったので、調査計画書のリスク欄が想定した「0006 の結論が否定的」は起きなかった。ただし A1 の成立条件 5 つのうち 1 つでも満たせないと分かった時点で、実質的には A2 か A3 に倒れる。**A2 と A3 は人間が 2 つ目のセッションを開く形なので、1 プロセス内でのチケット並列は成立せず、並列の単位は「issue」ではなく「人間のセッション」になる。**その場合でも、worktree 上で機構が健全に動くこと（受け入れ条件 A1）は依然として必要である。

### e24. 実測手順（観点 C。人間が実行する。コマンド列 + 予測）◎良

**前提**

- 実行は**人間**が行う。`.claude/agents/` と `.claude/settings.json` への書き込みは本チケットの `allow.write`（`wip/**`）の外で、`git worktree` と `cd` は機構が WF204 で拒否する
- 実行結果は **`wip/tmp/worktree-probe/`** に置く（0004 の e8・0005 の e16 と同じ置き場）
- **C1 の前に 0004 の実測手順 P0〜P7 を済ませておくと切り分けが楽**だが、依存はしない
- 後始末: `.claude/agents/probe-isolated.md` は消す。`.claude/settings.json` を触った場合は元に戻す（バックアップは `.claude/settings.json.bak-*` が `.gitignore` 済み）。残った worktree は `git worktree remove`（ロックされていたら `git worktree unlock` を先に）

**C1. `isolation: worktree` が効くか、効いたときサブエージェントは何を見るか**

`.claude/agents/probe-isolated.md` を人間が置く（frontmatter は次の 6 行、本文は下の指示）。

```markdown
---
name: probe-isolated
description: worktree 隔離の実測用。pwd とリポジトリの状態を報告するだけ
tools: Bash
model: haiku
isolation: worktree
---

次を 1 回の Bash で実行し、出力をそのまま最終メッセージに貼ること。判断や要約はしない。
pwd; git rev-parse --show-toplevel; git rev-parse --absolute-git-dir; git branch --show-current;
git log --oneline -1; ls -1 wip/10_tickets/10_doing/; ls -1 wip/10_tickets/00_todo/ | head -3;
ls -d logs 2>&1; cat .git 2>&1; echo "SID=$CLAUDE_CODE_SESSION_ID"
```

本流のセッションから「probe-isolated エージェントを起動して」と頼み、返ってきた出力を `wip/tmp/worktree-probe/c1-isolated.txt` に貼る。

予測: `pwd` は `<本流>/.claude/worktrees/<何か>`。`git branch --show-current` は `worktree-<何か>`。`git log --oneline -1` は **`main` の先端**（`feature-50-…` の先端ではない）。`wip/10_tickets/10_doing/` は `.gitkeep` のみ、`00_todo/` にも `0006`〜`0010` は無い。`logs` は存在しない。`.git` は `gitdir: <本流>/.git/worktrees/<何か>` の 1 行。`SID` は呼び出し元と同じ。
外れたとき: `pwd` が本流のままなら `isolation` が本環境の Claude Code 2.1.259 で解釈されていない（e17 の結論は「公式にはある」に留まり、本環境では使えないことになる）。`git log` が feature ブランチの先端なら S2 / S7 の「default branch」が当てはまらず、e20 の前提が変わる。

**C2. SubagentStart フックの `cwd` はどちらか**

C1 の直後に、本流で次を実行する。

```bash
MAIN=/c/Users/taniyama/Desktop/git/issue-mr-ticket-workflow
tail -40 "$MAIN/logs/hooks/decisions.jsonl" \
  | jq -c 'select(.event=="SubagentStart" or .event=="SubagentStop")' \
  > "$MAIN/wip/tmp/worktree-probe/c2-main-log.txt" 2>&1
ls -la "$MAIN"/.claude/worktrees/*/logs/hooks/ >> "$MAIN/wip/tmp/worktree-probe/c2-main-log.txt" 2>&1
cat "$MAIN"/.claude/worktrees/*/logs/hooks/decisions.jsonl >> "$MAIN/wip/tmp/worktree-probe/c2-main-log.txt" 2>&1
```

予測（2 通りのどちらか。**これが観点 C の DoD 3 番目を確定させる**）:
- (a) 本流の `decisions.jsonl` に `SubagentStart` の記録が 1 件増え、worktree 側に `logs/` が無い → **SubagentStart の `cwd` は呼び出し元のもの**。WF802 は呼び出し元のチケットの要点を注入していたことになる
- (b) worktree 側に `logs/hooks/decisions.jsonl` ができて記録がそこに落ち、本流には増えない → **SubagentStart の `cwd` は worktree のもの**。このとき `note` は「対象チケットが無い」の `skip` になっている見込み（e20 の 4）

`ticket` フィールドが空でも判断できる（`hook_doing_ticket` は作業中チケットが無ければ空を返す）。**判断の根拠は「どちらのファイルに落ちたか」1 点**である。

**C3. 隔離下で提供コマンドとヒアドキュメントが通るか**

`probe-isolated.md` の本文を次に差し替えて再度起動する（frontmatter はそのまま）。

```
次の 4 つを別々の Bash 呼び出しで実行し、各々の出力と、拒否されたならその文言をそのまま貼ること。
(1) bash .claude/skills/20-common-step-ticket/scripts/ticket.sh next
(2) 引用符のないヒアドキュメント（<<EOF）で /tmp/probe.txt に 1 行書く
(3) 引用符つきのヒアドキュメント（<<'EOF'）で /tmp/probe2.txt に 1 行書く
(4) git -C . status --porcelain | head -3
```

予測: (1) は通り、`{"current":null,"next":…}` か「チケットが無い」旨を返す（worktree 側の `wip/` を見るため、既定ブランチなら未着手も 0 枚）。(2) は **command shape 検査で拒否**（S10）。(3) は通る見込み。(4) は **git リダイレクト検査で拒否**（`git -C`。S10）だが、機構側の WF401（`block-direct-git`）が先に出る可能性もあるので、**どちらの文言が返るか**を記録する。
外れたとき: (2) が通るなら command shape 検査の対象が公式の記述より狭く、e22 の「逆風」の評価が下がる。(1) が拒否されるなら、隔離下では提供コマンドが一切使えず A1 は成立しない。

**C4. `worktree.baseRef: "head"` の効き**

`.claude/settings.json` に `{"worktree": {"baseRef": "head"}}` を人間が足し（バックアップを `.claude/settings.json.bak-c4` に取る）、C1 をもう一度実行する。

予測: `git log --oneline -1` が **`feature-50-worktree-parallel-tickets` の先端**になり、`wip/10_tickets/00_todo/` に `0007`〜`0010` が現れる。`10_doing/` には実行時点で作業中のチケットが現れる。
外れたとき: `main` の先端のままなら、「サブエージェント worktree の分岐元がメイン会話の `HEAD` になる」という読みが誤りで、A1 の成立条件 ① が満たせない（= 並列を採るなら別の道が要る）。
後始末: `.claude/settings.json` を `.bak-c4` から戻す。

**C5. 本流の `git status` が汚れるか**

C1〜C4 のいずれかの後に本流で実行する。

```bash
MAIN=/c/Users/taniyama/Desktop/git/issue-mr-ticket-workflow
git -C "$MAIN" status --porcelain > "$MAIN/wip/tmp/worktree-probe/c5-status.txt" 2>&1
git -C "$MAIN" worktree list >> "$MAIN/wip/tmp/worktree-probe/c5-status.txt" 2>&1
```

予測: `?? .claude/worktrees/` の行が出る（e21 の (2)）。`git worktree list` に本流 + サブエージェント worktree が並ぶ。
外れたとき: 出ないなら Claude Code が別の場所に worktree を作っているか、`WorktreeCreate` の既定が変わっている。`git worktree list` の出力で置き場を確定させる。
**この状態で `push.sh` を実行してはいけない**（項目 1 が落ちるのは予測どおりなので、確かめる必要が無い。落ちた記録だけが残って本流の進行が止まる）。

### e25. 観点 D の答え — 両立できる。合流コストの主体はファイルの衝突ではなく「合流という操作を機構が想定していないこと」◎良

**可否: 1 issue = 1 ブランチ = 1 MR を保ったまま複数 worktree を使える。**

理由は 3 段である。

| # | 段 | 根拠 |
|---|---|---|
| 1 | git の同一ブランチ制約は**回避できる**。同じブランチを 2 つの作業ツリーで checkout することは拒否されるが、公式が回避の口を 3 つ用意している（detached HEAD / 引数省略時の自動ブランチ作成 / `--force`・`--ignore-other-worktrees`） | e26 の G1〜G5 |
| 2 | 回避策のうち**サブブランチ + 合流だけが、機構を壊さずに成立する**。detached HEAD は `push.sh` が必ず落ち、`--force` は 2 つの作業ツリーが同じ ref を進めるので互いの成果を「消えた」と見る | e27 |
| 3 | サブブランチを**ローカルで合流して feature ブランチにだけ push すれば、issue↔ブランチ↔MR の 1:1:1 は保たれる**。MR は squash merge されるので中間の合流コミットは `main` に残らない | `00_requirement/自己改善ワークフロー機構.md:161, 163`。原則の正文は「1 issue = 1 ブランチ = 1 MR」であって「ブランチを 1 本しか作らない」ではない |

**ただし「両立できる」は「安く合流できる」を意味しない。** 合流コストを 3 つに分けて測った結果は次のとおりで、**主体は ① ではなく ②③ にある**。

| コストの種類 | 大きさ | 根拠 |
|---|---|---|
| ① ファイルの衝突（git が自動で解けない箇所） | **小〜中**。`wip/10_tickets/` は 0 件。`wip/30_reports/` の同一レポート 1 対は **13 行が必ず同一行の書き換え**で衝突し、挿入点も重なる。採番が当たると 1 件 | e29・e30 |
| ② 合流の操作そのものが機構で通るか | **大**。`cherry-pick` / `rebase` / `am` は WF401 で拒否。`git merge <ローカルブランチ>` は `unknown` → WF204（作業中チケットがあるとき）。作業中 0 枚なら素通りするが、DDR `i0004-07` は**それを拒否できることを利点として書いている**ので、素通りは統制の抜けである | e28 |
| ③ 合流後に機構の前提が壊れないか | **中**。`10_doing/` が 2 枚になると WF207 で全操作が止まり、`workflow-diff-check` は黙って抜ける。`boundary.sh` の「末尾から同じ種類が続く範囲」も、種類の違うチケットが交互に完了すると 1 タスクを取りこぼす | e31 |

**この節は決定をしない。** 「並列を採るか」（保留 P1）と「合流手順をどれにするか」（受け入れ条件 A6）は 0010 の AI アセット設計計画で決める。ここは選択肢とコストを並べるまでである。

### e26. git の同一ブランチ制約と回避策の根拠（公式の逐語引用。取得日 2026-09-05）◎良

取得は WebFetch。引用は原文の逐語で、訳は付けない（訳すと条件が落ちるため）。

| # | URL | 節 | 引用（逐語） |
|---|---|---|---|
| G1 | `https://git-scm.com/docs/git-worktree` | `add` の `--force` | 「By default, `add` refuses to create a new worktree when *&lt;commit-ish&gt;* is a branch name and is already checked out by another worktree, or if *&lt;path&gt;* is already assigned to some worktree but is missing (for instance, if *&lt;path&gt;* was deleted manually). This option overrides these safeguards. To add a missing but locked worktree path, specify `--force` twice.」 |
| G2 | 同上 | `add` の既定 | 「If *&lt;commit-ish&gt;* is omitted and neither `-b` nor `-B` nor `--detach` used, then, as a convenience, the new worktree is associated with a branch (call it *&lt;branch&gt;*) named after `$(basename <path>)`. If *&lt;branch&gt;* doesn't exist, a new branch based on `HEAD` is automatically created as if `-b` *&lt;branch&gt;* was given.」 |
| G3 | 同上 | `--detach` / DESCRIPTION | 「With `add`, detach `HEAD` in the new worktree.」／「if you just plan to make some experimental changes or do testing without disturbing existing development, it is often convenient to create a *throwaway* worktree not associated with any branch. For instance, `git worktree add -d <path>` creates a new worktree with a detached `HEAD` at the same commit as the current branch.」 |
| G4 | 同上 | BUGS | 「Multiple checkout in general is still experimental, and the support for submodules is incomplete. It is NOT recommended to make multiple checkouts of a superproject.」 |
| G5 | `https://git-scm.com/docs/git-checkout` | `--ignore-other-worktrees` | 「`git checkout` refuses when the wanted branch is already checked out or otherwise in use by another worktree. This option makes it check the branch out anyway. In other words, the branch can be in use by more than one worktree.」 |
| G6 | `https://git-scm.com/docs/git-worktree` | `remove` | 「Remove a worktree. Only clean worktrees (no untracked files and no modification in tracked files) can be removed. Unclean worktrees or ones with submodules can be removed with `--force`. The main worktree cannot be removed.」 |

**読み取れること。**

- 制約は「**ブランチ名**を指定したときに、それが既に別の作業ツリーで checkout されていれば拒否する」という形で、`add` と `checkout` の**両方**に掛かっている（G1・G5）。したがって「本流が `feature-50-…` にいるまま、worktree でも `feature-50-…` を開く」は既定では成立しない
- 引数を省略すると **`$(basename <path>)` という新しいブランチが `HEAD` から自動で作られる**（G2）。Claude Code のサブエージェント隔離が `worktree-<名前>` というブランチを作るのは、この既定の上に名前の規則を載せたものと読める（0006 の e18 の S9）
- **`--force` と `--ignore-other-worktrees` は「安全装置を外す」と明記されている**（G1「This option overrides these safeguards」、G5「In other words, the branch can be in use by more than one worktree」）。禁止ではないが、公式が safeguard と呼んでいるものを外す選択である
- **G4 は multiple checkout 全体を experimental と書いている。** 本リポジトリに submodule は無いので BUGS 節の主眼（superproject）には当たらないが、「実験的」という位置づけは合流手順を決めるときの前提に入れる
- **公式は「同じブランチを共有したときに他方の作業ツリーがどうなるか」を書いていない。** `--force` を選ぶ場合はここが実測項目になる（実測 D2）

### e27. ブランチ構成の選択肢 4 案 — 成立可否・合流手順・衝突の種類 ◎良

計画書は 3 案（detached HEAD / サブブランチ + 合流 / `--force`）を挙げていた。`00_requirement/自己改善ワークフロー機構.md:164` が並行の手段として worktree と並べて別 clone を明記しているので、**4 案目として別 clone を足した**（計画書の 3 案は 1〜3 行目にそのまま残した）。

| # | 案 | 成立可否 | 合流手順 | 衝突の種類 | 成立可否の根拠 |
|---|---|---|---|---|---|
| 1 | **detached HEAD**（`git worktree add -d <path>`） | **✕ 成立しない** | 合流には結局ブランチか SHA の指定が要る（`git merge <sha>` / `git branch <名前> <sha>` の後に merge） | ファイル衝突は案 2 と同じ。加えて worktree を消すと**到達不能なコミットになり得る**（ref が無いので `git gc` の対象） | `push.sh:67-68` が `git rev-parse --abbrev-ref HEAD` の結果が `HEAD` のとき **CP007「現在ブランチを特定できない（detached HEAD。環境の誤り）」で必ず落ちる**。`boundary.sh:467` の `git rev-list "origin/$br..HEAD"` も `br` が `HEAD` になり、`origin/HEAD`（既定ブランチへの symbolic ref）と比較して**別ブランチとの差分を「未 push」と誤判定する**。`ticket.sh` と `commit.sh` はブランチを見ないので動く |
| 2 | **サブブランチ + 合流**（`git worktree add <path>` の既定 = `$(basename <path>)` ブランチ。Claude Code の `isolation: worktree` が作る `worktree-<名前>` もこれ） | **◎ 成立する（推奨側）** | ①サブブランチで作業してコミット ②本流で `git merge <サブブランチ>`（または成果物をコピーして `commit.sh`）③衝突があれば解消して `commit.sh` ④`git worktree remove` と ref の後始末 | ・`wip/10_tickets/`: **0 件**（チケットごとに別ファイル）・`wip/30_reports/`: **同一行 13 行が確実に衝突**・採番: 同じ番号を採ると同名なら add/add、別種なら**衝突せず番号が重複**（e30） | G2。`push.sh` は feature ブランチにいるときだけ動かせばよく、サブブランチは push しないので MR は増えない。**ただし合流の操作が機構で通らない**（e28） |
| 3 | **`--force` で同一ブランチを共有**（`git worktree add --force <path> feature-50-…`） | **△ 成立するが割に合わない** | 合流は不要（同じ ref を進めるため）。ただし片方が commit するともう片方の作業ツリーは HEAD より古い状態になり、**追随の操作（`git checkout` / `reset`）が要る** — どちらも機構が拒否する | ファイルの衝突は起きないが、**`git status` の見え方が壊れる**。作業ツリー B が持つ「HEAD に無いファイル」は A の commit 後に「削除された」と見え、`push.sh` 項目 1（`push.sh:78`）と `boundary.sh:466` の未コミット判定が偽陽性で落ちる | G1・G5 が「safeguards を外す」と明記。`.git/index` は作業ツリーごとに分かれるが `refs/heads/<branch>` は 1 つなので、同じ ref を 2 プロセスが進める |
| 4 | **別 clone**（`git clone` で別ディレクトリ） | **◎ 成立する** | ①別 clone の側で feature ブランチと別名のブランチを作って push、②本流で `git fetch` して `git merge origin/<そのブランチ>`（この形なら `scope.sh:392-393` の `merge-base` 分類に当たる）、または成果物をコピーして `commit.sh` | 案 2 と同じファイル衝突。加えて **`.claude/` の実体が 2 つになる**（0005 の e11 と同じ根で、機構自身を変える issue では両者がドリフトする） | `00_requirement/自己改善ワークフロー機構.md:164`「並行して作業する場合は git worktree または別の clone を使う」。`logs/` が自動的に分かれる利点があるが、リモートを経由するので MR が増えない工夫（push 先のブランチ名）が要る |

**案 2 と案 4 の分かれ目は「合流をローカルで済ませるか、リモートを経由するか」である。** リモートを経由すると `git merge origin/<ブランチ>` の形になり、**現行の `scope.sh` の `merge-base` 分類にそのまま当たって通る**（`scope.sh:392-393` は「引数に `origin/*` があれば `merge-base`」としか見ていない）。ただし `merge-base` を `ops` に持つ種類は `overall-summary` だけ（`scope-limits.json:24`）なので、実施系のチケットでは結局宣言が要る。**この「`origin/` を前に付けるだけで分類が変わる」は、意図した統制というより分類の粗さである**（観点 E / 0008 の材料）。

**サブエージェント隔離を採ると、案 2 が自動的に選ばれる。** 0006 の e18 の S7 が「Subagent worktrees use the same base branch as `--worktree`」、S9 が「on a new branch named `worktree-<name>`」と書いており、**終了時に自動で合流する記述はどこにも無い**。したがって `isolation: worktree` を採る = 案 2 の合流手順を決める、である。

### e28. 合流の手段 6 案と、現行の機構がどれを通すか △注意

| # | 手段 | 履歴 | 現行の機構での可否 | 根拠 |
|---|---|---|---|---|
| M1 | `git merge <ローカルのサブブランチ>` | 残る（マージコミット） | **条件付きで通る**。`block-direct-git` は `merge` を明示的に対象外にしている（`block-direct-git.sh:35-36`）。`workflow-guard` は `scope.sh:392-393` が `unknown` を返すので **WF204 で拒否**するが、**作業中チケットが 0 枚なら `workflow-guard.sh:49`（`[[ -n "$__WG_NAME" ]] \|\| exit 0`）で即座に抜けるため素通りする** | `block-direct-git.sh:35-36, 98-100`、`scope.sh:392-393`、`workflow-guard.sh:47-49` |
| M2 | `git merge origin/<リモートに上げたサブブランチ>` | 残る | **通る**（`scope.sh:392-393` が `merge-base` を返す）。ただし `merge-base` を `ops` に持つのは `overall-summary` だけなので、他の種類では WF203 相当の宣言不足になる。加えてサブブランチを push する必要があり、リモートにブランチが増える | `scope.sh:392-393`、`scope-limits.json:24` |
| M3 | `git cherry-pick` | 残る（コミット単位） | **拒否**（WF401） | `block-direct-git.sh:36` の `__BG_COMMIT_SUBCMDS` に `cherry-pick` |
| M4 | `git rebase <サブブランチ>` | 残る（付け替え） | **拒否**（WF401） | 同上 |
| M5 | `git format-patch` + `git am` | 残る | **拒否**（`am` が WF401）。`format-patch` は `_SC_GIT_READ_SUBCMDS` にも無いので `unknown` → WF204 | 同上、`scope.sh:36` |
| M6 | 成果物のファイルをコピーして `commit.sh` でコミットし直す | **残らない**（サブブランチの履歴は捨てる） | **通る**。`cp` は `_SC_READ_ONLY_CMDS` に無いので `unknown` → WF204 だが、`Read` + `Write` ツールなら `allow.write` の範囲内で通る | `scope.sh:31`、`workflow-guard` の書き込み判定 |

**帰結。** 現行の機構が AI に通す合流の道は実質 **M1（作業中 0 枚のときだけ）と M6 の 2 つ**である。M6 は履歴を捨てるので、チケットの状態遷移コミット（feature-10 では全コミットの 68%）を作り直すことになり、`ticket.sh` を経由しない手作業のファイル移動になる — **`ticket.sh` は「手動で動かさない」ことを前提に置いている**（`ticket.sh:214-215` の TK004「手動で動かさず ticket.sh で扱う」）ので、M6 は機構の前提と正面から衝突する。

**M1 が「素通りする」ことを利点と読んではいけない。** DDR `i0004-07` の決定は次のとおりで、**ブランチ間の統合を拒否できることを明示的な利点として挙げている**。

> `git merge` は例外として拒否しない。default ブランチの取り込み（`git merge origin/<default>`）は `00-workflow-issue-mr-driven` の手順に組み込まれており、`workflow-guard` の `merge-base` 分類で「取り込みに限る」統制を行う。

> 取り込み以外の `merge`（ブランチ間の統合）は `merge-base` 分類で `origin/<default>` 以外を拒否できる

つまり **M1 が作業中 0 枚のときに通るのは、`workflow-guard` の「作業中チケットが無ければ何もしない」という制御方式 1 の帰結であって、`merge` を許した設計判断ではない**。並列を採るなら、①`merge-base` の定義を「合流も含む」に広げる ②合流専用の提供コマンドを足す ③合流は人間だけが行う、のいずれかを明示的に選ぶ必要がある（e33 でコストを比べた）。

### e29. 過去 issue の実データからの衝突件数の見積もり（コマンドと出力）△注意

**(1) チケットの移動（rename）の件数。**

```
git -C <本流> log --all --diff-filter=R --name-status --format='' -- wip/10_tickets/ | grep -c '^R'
→ 235

git -C <本流> log --all --diff-filter=R --name-status --format='' -- wip/10_tickets/ \
  | awk -F'\t' '/^R/{ split($2,a,"/"); split($3,b,"/"); print a[3]" -> "b[3] }' | sort | uniq -c | sort -rn
→ 133 00_todo -> 10_doing
   94 10_doing -> 20_done
    6 10_doing -> 30_cancelled
    2 00_todo -> 20_done
```

**(2) ブランチ（= issue）ごとの内訳。** `base=$(git merge-base main <branch>)` を起点にした。

| ブランチ | チケット枚数 | rename 件数 | コミット総数 |
|---|---|---|---|
| `feature-1-workflow-requirements` | 0 | 0 | 65 |
| `feature-4-workflow-basic-design` | 0 | 0 | 15 |
| `feature-6-workflow-foundation` | 39 | 36 | 109 |
| `feature-8-requirements-doc-standardize` | 0 | 0 | 0 |
| `feature-9-hook-bodies-settings` | 39 | 67 | 232 |
| `feature-10-task-skills-agents-finalize` | 57 | 104 | 247 |
| `feature-50-worktree-parallel-tickets`（本 issue、実施中） | 9 | 9 | 25 |

`feature-1` / `feature-4` が 0 件なのは、チケット運用（`wip/10_tickets/`）を導入する前の issue だからである（`feature-8` はコミットが 0 件で、`feature-9` の途中から分岐した名前だけのブランチ）。したがって**代表値には直近の完了 issue `feature-10` を使う**。

**(3) `feature-10` の詳細（見積もりの基礎）。**

```
git -C <本流> log --diff-filter=R --name-status --format='' <base>..feature-10 -- wip/10_tickets/ \
  | awk -F'\t' '/^R/{split($2,a,"/");split($3,c,"/"); print a[3]"->"c[3]}' | sort | uniq -c
→ 56 00_todo->10_doing
   45 10_doing->20_done
    3 10_doing->30_cancelled

git -C <本流> log --diff-filter=R --name-status --format='@@%h' <base>..feature-10 -- wip/10_tickets/ \
  | awk '/^@@/{if(n>0)print n; n=0; next} /^R/{n++} END{if(n>0)print n}' | sort | uniq -c
→ 104 1        # 1 コミットあたりの rename はちょうど 1 件（104 コミットすべて）

git -C <本流> log --format='%s' <base>..feature-10 | grep -o '^chore: チケット [0-9]* \(に着手\|を完了\|を作成\|を取り消し\)' | sed 's/[0-9]\{4\}/NNNN/' | sort | uniq -c
→ 56 chore: チケット NNNN に着手
   56 chore: チケット NNNN を作成
    3 chore: チケット NNNN を取り消し
   53 chore: チケット NNNN を完了

git -C <本流> rev-list --count <base>..feature-10
→ 247
```

**1 チケットあたりの rename 件数は 2 件**（`00_todo→10_doing` と `10_doing→20_done`）。完了に至ったチケット 45 枚に対し rename が 45 + 56 = 101、取り消し 3 を足して 104 で一致する。**状態遷移コミットは 168 件で、全 247 コミットの 68% を占める。**

**(4) 完了コミットの 15% は rename として検出されない。** 完了コミットは 53 件だが `10_doing→20_done` の rename は 45 件で、差の **8 件は delete + add として現れる**。原因は `ticket-check.sh` の未コミット検査が**チケットファイル自身を除外している**こと（`ticket-check.sh:62` の `awk -v p="${path#./}" 'substr($0, 4) != p'`）で、**作業ログの追記が完了コミットに相乗りする**ためである。実例:

```
git -C <本流> show --stat --format='%h %s' 21a89e5
→ 21a89e5 chore: チケット 0009 を完了
   wip/10_tickets/10_doing/0009-investigation.md | 63 ------
   wip/10_tickets/20_done/0009-investigation.md  | 95 ++++++++++

git -C <本流> show --name-status -M20% --format='' 21a89e5
→ D  wip/10_tickets/10_doing/0009-investigation.md
   A  wip/10_tickets/20_done/0009-investigation.md   # -M20% でも rename にならない
```

これは合流時の**衝突の型**を変える。rename として検出されれば rename/rename の判定に乗るが、delete + add だと「片方が消して片方が足した」形になり、`git merge` の rename 検出の閾値（既定 50%）に依存する。`.gitattributes` が LF を固定しているのは `*.sh` / `*.tsv` / `*.json` / `*.html` の 4 拡張子だけで **`*.md` は含まれない**ので、行末の混在も検出を揺らす要因になる。

**(5) 同一レポートへの追記回数。** 現行の運用（1 タスク 1 レポート）で最も積み上がったのは `feature-10` の 2 本である。

```
git -C <本流> log --name-only --format='' <base>..feature-10 -- 'wip/30_reports/*.md' | sed '/^$/d' | sort | uniq -c | sort -rn
→ 15 wip/30_reports/0024-ai-asset-implementation.md
   12 wip/30_reports/0011-ai-asset-design.md
    7 wip/30_reports/0050-ai-asset-implementation.md
    6 wip/30_reports/0006-investigation.md
    5 wip/30_reports/0005-investigation.md
    5 wip/30_reports/0004-investigation.md
   （以下省略。1 回だけのものは、1 チケット 1 レポートだった旧運用の名残）
```

**同一ファイルへの追記は最大 15 回**、現行の運用に沿ったものは 5〜15 回の範囲にある。本レポート（`0004-investigation.md`）はチケット 0004・0005・0006 の 3 コミットで、0007 が 4 回目である。

**(6) 1 回の追記が触る行の位置。** `git show <sha> -U0` の hunk ヘッダを数えた。

```
git -C <本流> show 9c201fc -U0 --format='' -- wip/30_reports/0004-investigation.md  | grep -c '^@@'  → 14
git -C <本流> show 9929a17 -U0 --format='' -- wip/30_reports/0004-investigation.md  | grep -c '^@@'  → 14
git -C <本流> show 9c201fc -U0 --format='' -- wip/30_reports/0004-investigation.html | grep -c '^@@' → 17
git -C <本流> show 9929a17 -U0 --format='' -- wip/30_reports/0004-investigation.html | grep -c '^@@' → 17
```

内訳（0006 の追記 `9929a17` の hunk ヘッダ）:

| ファイル | 同一行の**書き換え** | **挿入**のみ |
|---|---|---|
| `.md` | 4 行（`@@ -3,2 +3,2 @@` = `title` と `description`、`@@ -6 +6 @@` = `keywords`、`@@ -9 +9 @@` = H1 見出し） | 10 か所 |
| `.html` | 9 行（`@@ -130 +130 @@` = `<h1 id="title">`、`@@ -133,3 +133,3 @@` = chip の件数 3 行、`@@ -184 +184 @@` = 「チケット」欄、`@@ -197,3 +197,3 @@` = kpi の件数 3 行、`@@ -201 +201 @@` = 件数の注記） | 12 か所 |

**つまり 1 対のレポートに追記するたび、md 4 行 + HTML 9 行 = 13 行が必ず同じ行の書き換えになる。** 件数タイル（◎良 / △注意 / ✕問題）とサマリの積み上げ、表題の広げ方が、そういう作りだからである。

**(7) 挿入点も重なる。** 0005 の追記（`9c201fc`）が新しく足した行の範囲は、`git diff 199fd98 9c201fc -U0` の新側で `+31,12` / `+48,3` / `+57,4` / `+67,5` / `+82,5` / `+93,4` / `+490,286` / `+791,15` / `+818,8` / `+835,5` / `+851,5` の 11 か所。0006 の追記（`9929a17`）の挿入点（`9c201fc` 座標）は 42 / 50 / 60 / 71 / 87 / 97 / 775 / 806 / 826 / 840 / 855 の 11 か所である。突き合わせると:

| 0006 の挿入点 | 0005 が足した範囲との関係 | 共通の基点から見た位置 |
|---|---|---|
| 42 / 50 / 60 / 71 / 775 / 855 | **0005 の block の最終行**（31-42 / 48-50 / 57-60 / 67-71 / 490-775 / 851-855） | **同一の挿入点**（6 か所） |
| 87 / 97 / 806 / 826 / 840 | 0005 の block（82-86 / 93-96 / 791-805 / 818-825 / 835-839）の**直後の 1 行**の後 | 1 行だけ離れた挿入点（5 か所） |

**同一の挿入点 6 か所は、両側が同じ位置に別の内容を足す形なので、3-way マージでは順序を決められず衝突する見込み**である。1 行離れた 5 か所は git のマージ規則（変更範囲の重なり）次第で、自動で解ける可能性がある。**この判定は `git merge` を実行して確かめていない**（実行手段が無い。「確かめられなかったこと」を参照）ので、実測手順 D3 に落とした。

**(8) 見積もりのまとめ（1 タスクを 2 並列で 1 チケットずつ実施し、タスクの切れ目で合流する場合）。**

| 対象 | 自動で解ける | 手で解く | 根拠 |
|---|---|---|---|
| `wip/10_tickets/` の rename（1 チケット 2 件 × 2 = 4 件） | 4 件 | **0 件** | チケットごとに別ファイル。同じチケットを 2 つの作業ツリーで動かさない限り、rename の対象が重ならない |
| レポート `.md` の同一行の書き換え | 0 件 | **4 行** | (6) |
| レポート `.html` の同一行の書き換え | 0 件 | **9 行** | (6) |
| レポート `.md` の挿入点 | 5 か所（見込み） | **6 か所**（見込み） | (7) |
| レポート `.html` の挿入点 | 同様の比（12 か所中） | 見込み **6〜7 か所** | (6)(7)。HTML は md と同じ節構成に追記するため同じ形になるが、hunk 単位の突き合わせは行っていない |
| チケットの採番 | 0〜1 件 | **0〜1 件** | 種類が同じなら add/add で 1 件、違えば衝突せず**番号が重複したまま通る**（e30 の (1)。こちらのほうが悪い） |
| `logs/` の進行状態 | — | — | `.gitignore` されており git の合流の対象外。作業ツリーごとに分かれたまま（0005 の e9・e10） |

**合流 1 回あたり、手で解く箇所はおよそ 25 前後**（md 4 行 + HTML 9 行 + 挿入点 12〜13 か所）。回数は「合流の回数」に比例し、チケットごとに合流するなら `feature-10` 規模（57 枚）では数百箇所になる。**タスクの切れ目でだけ合流すれば、`feature-10` のタスク数（種類の切り替わり）ぶんに抑えられる。**

### e30. 採番・レポート追記・`ticket.sh` / `commit.sh` の状態遷移コミットの、並列時の衝突判定 ✕問題

計画書が名指しした 4 つを 1 つずつ判定した。

| # | 対象 | 並列時に衝突するか | 根拠（ファイル:行） |
|---|---|---|---|
| 1 | `wip/10_tickets/` の**連番の採番** | **衝突する（しかも黙って通る場合がある）** | `ticket.sh:151-159` は `for f in "$TICKETS"/*/[0-9][0-9][0-9][0-9]-*.md` で**自分の作業ツリーだけ**を走査して `max + 1` を採る。他の作業ツリーも他のブランチも見ない。2 つの worktree が同時に `create` すると同じ番号になり、**種類が同じなら同名ファイル（add/add で衝突して人が気づく）／種類が違えば別名ファイル（`0011-design.md` と `0011-investigation.md`）で衝突せずに合流し、番号だけが重複する**。重複すると `find_ticket`（`ticket.sh:50-59`）が `$TODO → $DOING → $DONE → $CANCELLED` の順で先に当たった 1 枚を返すため、`ticket.sh start 0011` がどちらを着手するかは glob の順（辞書順）で決まる |
| 2 | `wip/30_reports/` の**同一ファイルへの追記** | **必ず衝突する** | 1 回の追記が md 4 行・HTML 9 行を**同じ行で書き換える**（e29 の (6)）。表題・件数タイル（chip / kpi）・「チケット」欄・`description` / `keywords` はレポートが 1 本である以上、追記のたびに必ず更新される。加えて挿入点も 6 か所が一致する（e29 の (7)）。**`10-task-investigation-exec` の「1 タスクにつきレポートは 1 つ」「チケットごとにレポートを分けない」という指示が、そのまま並列時の衝突源になっている** |
| 3 | **`ticket.sh` の状態遷移コミット** | **ファイルとしては衝突しない。ただし合流後に前提が壊れる** | 移動は `mv "$T_PATH" "$new"`（`ticket.sh:232` / `:263` / `:287`）でチケット 1 枚ごとに閉じており、`feature-10` では **104 コミットすべてが 1 コミット 1 rename** だった（e29 の (3)）。別のチケットを動かす限り rename の対象が重ならないので git は自動で合流する。**壊れるのは合流後の状態**で、双方が作業中チケットを持ったまま合流すると `10_doing/` が 2 枚になる（e31） |
| 4 | **`commit.sh` の状態遷移コミット**（`ticket.sh` が内部で呼ぶ `do_commit`） | **衝突しない。ただし合流の操作は `commit.sh` を通らない** | `commit.sh` は対象パスを明示して `git add` → `git commit -- <パス>` するだけ（`commit.sh:133-140, 161-176`）で、ブランチも作業ツリーも見ない。detached HEAD でも動く（ブランチ名の検査は `push.sh` にしか無い）。**問題は逆側**で、`git merge` が作るマージコミットは `commit.sh` のメッセージ規約検査を通らない。DDR `i0004-07` は「マージコミットのメッセージは git 生成を受容する（`commit.sh` の規約検査を経ない唯一の経路として共通仕様 §13 に明記）」と、**`origin/<default>` の取り込みに限って**この例外を認めている。合流のためのマージコミットは、その例外の外にある |

**(1) の重複が最も悪い理由。** 2 と 3 は衝突として**目に見える**（マージが止まる）が、1 の「種類が違えば衝突しない」経路は**合流が成功したように見えて、番号が重複したチケットが 2 枚並ぶ**。以後 `ticket.sh` の `find_ticket` は先勝ちで片方だけを扱い、`boundary.sh` の `B_TASK_TICKETS`（`boundary.sh:88`）は番号だけを積むので **同じ番号が 2 回並んだ一覧**がレビュー依頼のコメントに載る。**気づく機会が無い。**

### e31. 「作業中は常に 1 枚」の前提と合流の関係 △注意

DDR `i0001-23` が並列を却下した最大の理由は「WIP リミット（同時に作業中のチケットは 1 枚）と両立しない」だった。worktree で分ければ**作業ツリーごとには**両立するが、**合流した瞬間に 1 つの作業ツリーに 2 枚が並ぶ**。何が起きるかを実装で確かめた。

| 箇所 | 作業中が 2 枚のときの振る舞い | 根拠 |
|---|---|---|
| `ticket.sh start` | **拒否**。`TK002「作業中のチケットが既にある（…）。先に complete か cancel する」` | `ticket.sh:210-213` |
| `ticket.sh next` | **`DOING_FILES[0]` だけを `current` として返す**（2 枚目は出力に現れない） | `ticket.sh:307-313` |
| `hook_doing_ticket` | `files[0]` を `REPLY` に、枚数を `HOOK_DOING_COUNT` に置く | `hook-common.sh:474-483` |
| `workflow-guard` | **WF207 で拒否**。「作業中チケットが N 枚ある（…）。1 枚だけの状態でしか判定できないので…1 枚を残して他を未着手に戻すこと」。**ただし提供コマンドだけは通す**（`__wg_all_provided` が真なら `hook_record allow` で抜ける） | `workflow-guard.sh:127-141` |
| `workflow-diff-check` | **黙って抜ける**（`log_debug` に落とすだけで、利用者には何も出ない） | `workflow-diff-check.sh:44-47` |
| `subagent-stop-check` | 一覧（WF811）と未コミット（WF812）は出すが、**許可範囲の判定（WF813）はしない** | `subagent-stop-check.sh:106-110` |
| `boundary.sh scan_tickets` | `B_AT_BOUNDARY` は `doing` が 0 枚のときだけ `true`。2 枚なら**切れ目と判定されない**ので、レビュー依頼も skip もできない | `boundary.sh:96-106` |

**したがって「合流はタスクの切れ目（作業中 0 枚）で行う」という制約を置けば、この問題は起きない。** 逆に、チケットの途中で合流すると WF207 が**提供コマンド以外のすべての操作を止める**ので、復旧には人が `ticket.sh` で片方を未着手に戻すしかない（そして戻すと作業ログと `base_sha` が失われる）。

**もう 1 つ、合流の順序が `boundary.sh` の切れ目判定を狂わせる経路がある。** `scan_tickets` は完了群を**番号の降順に見て、末尾から同じ種類が続く範囲**を「最後のタスク」とする（`boundary.sh:83-93`）。並列で**種類の違うチケットを同時に完了させて合流すると、完了群が `0011-investigation / 0012-design / 0013-investigation` のように交互になり得る**。このとき最後のタスクは `0013` の 1 枚だけと判定され、**`0011` はどのタスクの切れ目にも含まれずレビューを一度も受けないまま通過する**。並列を採るなら、この判定を「番号の連続」から「種類のまとまり」へ作り直す必要がある。

**差分の基準点（`base_sha`）については、DDR `i0001-23` の懸念は worktree で分ければ解消する。** `workflow-diff-check` は `git -C "$HOOK_WORKTREE" diff --name-status "$__dc_base"`（`workflow-diff-check.sh:262`）で自分の作業ツリーの差分だけを見るので、別 worktree の変更は**そもそも見えない**。ただし合流後に作業中チケットが残っていると、その `base_sha` は合流前の commit を指したままなので、**相手の worktree の変更が全部「自分の許可範囲外の差分」として現れる**。ここでも「合流は切れ目で」が効く。

### e32. DDR `i0001-23` の却下文の再評価 △注意

対象は「却下した案」の 3 行目である。

> **並列時だけ別ブランチ・別作業ツリーに分ける**: 分離は強いが、1 issue = 1 ブランチ = 1 MR の原則と衝突し、統合のコストが利得を上回る

これを 3 つの主張に分けて判定した。

| # | 主張 | 判定 | 根拠 |
|---|---|---|---|
| D-1 | **「分離は強い」** | **今も成り立つ（むしろ強くなった）** | 作業ツリーが分かれれば `.git/index` も `wip/` も `logs/` も分かれる（0005 の e9・e15）。加えて、DDR 執筆時には存在しなかった Claude Code の隔離強制（File edits 検査）が、**0004 の e5 で見つかった「作業ツリーをまたぐ絶対パスの書き込みが進行状態ファイル保護をすり抜ける」穴を外から塞ぐ**（0006 の e22）。分離の強さは当時の想定より上がっている |
| D-2 | **「1 issue = 1 ブランチ = 1 MR の原則と衝突し」** | **成り立たない** | ①原則の正文（`00_requirement/自己改善ワークフロー機構.md:163`）は「1 issue = 1 ブランチ = 1 MR。1 セッションが同時に扱う MR は 1 つ」であり、**ローカルの中間ブランチを禁じていない**。サブブランチを push しなければ MR は増えない（`20-common-step-feature-mr` の「1 ブランチ = 1 MR」も、MR を作る対象は feature ブランチだけである） ②**同じ前提条件の次の行（:164）が「同一 clone 上での並行セッションは想定しない。並行して作業する場合は git worktree または別の clone を使う」と、worktree を明示的に許している** ③「MR は squash merge され、ブランチ上の作業領域（`wip/`）の履歴は main に残らない」（:161）ので、合流のマージコミットが正史に残らない。**衝突するのは原則ではなく、原則の下で動く機構の実装（`scope.sh` の `merge` 分類・`ticket.sh` の採番・レポート 1 本の運用）である** |
| D-3 | **「統合のコストが利得を上回る」** | **条件付きで成り立つ（コスト側の内訳が当時の想定と違う）** | コストは e25 の 3 分類で測った。**① ファイルの衝突は当時想定されたより小さい**（`wip/10_tickets/` は 0 件、レポートは 1 合流あたり手作業 25 箇所前後）。**② 合流の操作が機構の設計意図に反する**（DDR `i0004-07` が「取り込み以外の `merge` を拒否できる」ことを利点に挙げている）。**③ 合流後の前提の破れ**（WF207・`scan_tickets` の取りこぼし）は、合流をタスクの切れ目に限れば消える。したがって「上回る」は**合流の頻度と、②に手を入れるかどうかで反転し得る**。ただし**利得の側を測る材料が無い**（過去 issue の所要時間は `finalize.sh` の片付けで `wip/` ごと消えている）ので、**「上回る／下回る」を数値で言えるのはコスト側だけ**である。この非対称は保留 P1 の判断材料としてそのまま残す |

**もとの指摘（DDR の「背景」にある敵対的レビュー指摘 A-1）についても、worktree の下でどうなるかを判定した。** 却下文そのものではないが、却下の土台なので併せて見た。

| # | 背景の主張 | worktree で分けたときの判定 | 根拠 |
|---|---|---|---|
| B-1 | 「WIP リミットにより 2 枚目の着手が拒否されて並列そのものが成立しない」 | **成り立たない**（作業ツリーが分かれれば `10_doing/` も分かれるので、各々が 1 枚を持てる）。ただし**合流時に復活する**（e31） | `ticket.sh:210-213` が見るのは `$DOING` = 自分の作業ツリー。`hook_doing_ticket` が見るのも `$HOOK_WORKTREE/wip/10_tickets/10_doing/` |
| B-2 | 「フックはステートレスなので、ある操作がどのチケットの宣言で判定されるべきかの帰属情報が無い」 | **成り立たない**。作業ツリーが帰属そのものになる（1 作業ツリー = 1 作業中チケット）。**帰属モデルを要件化しなくても、`cwd` から解決される `HOOK_WORKTREE` が帰属を決める**（0004 の e1） | `hook-common.sh:319-331, 369` |
| B-3 | 「差分検知の『着手時点の基準点』も並列では重なり合い、違反の誤帰属が起きる」 | **成り立たない（作業中は）／成り立つ（合流後にチケットが残っていれば）** | `workflow-diff-check.sh:262` の `git -C "$HOOK_WORKTREE" diff … "$__dc_base"` は自分の作業ツリーしか見ない。合流後については e31 |

**まとめると、DDR `i0001-23` の決定（並列の廃止）を支えていた 3 つの技術的理由（B-1〜B-3）は、worktree による分離のもとでは 2.5 個が成り立たなくなる。** 残るのは「合流のコスト」（D-3）と、DDR の「理由」に書かれた**統制の単純さ**（帰属モデルを作らずに済む）である。後者は worktree が帰属を与えるので理由としては弱まるが、**「作業ツリーが帰属である」ことを機構のどこにも書いていない**現状では、書き足す作業がそのまま新しい統制の複雑さになる。**この差し引きは調査では決めない。**

### e33. 合流手順の選択肢とコスト（受け入れ条件 A6 の材料）◎良

A6「合流手順が定まっている」の**手順そのものは決めない**（0010 の AI アセット設計）。ここでは選択肢と、各々のコストを並べる。

| # | 合流手順の案 | 誰が合流するか | 機構への変更 | 1 合流あたりの手数 | 残るリスク |
|---|---|---|---|---|---|
| J1 | **人間が合流する**（AI は worktree で作業してコミットするだけ。切れ目で人が `git merge` して衝突を解く） | 人間 | **無し**（現行のまま） | 人間: `merge` 1 回 + 衝突解消 25 箇所前後 + `git worktree remove` | 並列の利得を人間の手数が相殺する。合流の頻度が上がるほど不利。**人がレポートの衝突を解く = 内容の判断を人がすることになる**（機械的に解けない） |
| J2 | **`scope.sh` の `merge` 分類を「ローカルブランチの合流」まで広げる**（`merge-base` の意味を変えるか、新分類 `merge-local` を足す） | AI | `scope.sh:392-393`、`scope-limits.json` の `ops`、DDR `i0004-07` の決定の見直し、既存テスト（`test_scope.sh`） | AI: `merge` 1 回 + 衝突解消。人間: 0 | **`origin/<default>` 以外の merge を拒否できる」という統制を明示的に手放す**ことになる。マージコミットのメッセージが `commit.sh` の規約検査を通らない経路が増える |
| J3 | **合流専用の提供コマンド（`merge.sh`）を足す** | AI（コマンド経由） | 新規スクリプト 1 本 + 仕様 + テスト。`scope.sh` は `provided` 分類でそのまま通る | AI: `merge.sh` 1 回。衝突解消は AI が行うが、**コマンドが「解けない衝突は人へ返す」判定を持てる** | 提供コマンドが 1 本増える（DDR `i0004-07` が却下した案そのもの。ただし当時の文脈は「取り込み」で、合流ではない）。衝突解消は対話が要るのでスクリプトに閉じ込められない |
| J4 | **合流しない**（成果物を worktree から本流へコピーして `commit.sh` で積み直す。M6） | AI | 無し | AI: ファイルのコピー + `commit.sh`。ただし**チケットの移動を手で行うことになり `ticket.sh` の前提（TK004「手動で動かさず ticket.sh で扱う」）に反する** | 履歴が失われる。`base_sha` が意味を失う。**`ticket.sh` を迂回する運用を常態化させる** |
| J5 | **衝突源そのものを減らす**（レポートを「1 タスク 1 本」から「1 チケット 1 本 + タスクの索引 1 本」に変える） | — | `10-task-*-exec` の共通手順（レポートの積み上げ規約）と `20-common-step-report-view` のテンプレートの変更 | 合流の衝突が**レポートについてはほぼ 0** になる（別ファイルになるため） | **旧運用への逆戻り**（`feature-10` の前半がその形で、「レビュアーが 1 つのタスクの結論を読むのに複数のファイルを開くことになる」という理由で今の形になった）。索引の更新が新しい衝突源になる |
| J6 | **合流の単位をタスクの切れ目に固定する**（J1〜J5 のどれと組んでもよい制約） | — | `00-workflow-issue-mr-driven` の切れ目の手順に「合流」を足す | 合流回数が「タスク数」に減る（`feature-10` なら 57 → 10 前後） | 並列できる幅がタスク内に閉じる。タスクをまたぐ並列（調査と設計を同時に）はできない |

**コストの主要因は「合流の回数」である。** 1 合流あたり手作業 25 箇所前後という見積もり（e29 の (8)）は、チケットごとに合流すると `feature-10` 規模で 1000 箇所を超え、タスクの切れ目に限れば 250 箇所前後に収まる。**J6 は他のどの案とも組めるので、まず J6 を前提に置いてから J1〜J5 を選ぶのが素直である**（これは順序の提案であって決定ではない）。

**A6 が「定まっている」と言えるために、0010 が決める必要があるのは次の 5 点である。**

1. 合流の単位（チケットごと / タスクの切れ目 / issue の最後）
2. 合流の実行者（人間 / AI / 提供コマンド）と、それに応じた `scope.sh` の分類の手当て
3. 衝突が出たときの解消の担当（レポートの内容の衝突は誰が判断するか）
4. サブブランチと worktree の後始末（`git worktree remove` は AI から実行できない。ref をいつ消すか）
5. 合流したことをどこに記録するか（`decisions.jsonl` に `cwd` も `agent_id` も無いので、どの作業ツリーの成果かを後から追えない — 0006 の e19）

### e34. 実測手順（観点 D。人間が実行する。コマンド列 + 予測）◎良

**前提**

- 実行は**人間**が行う。`git worktree` / `git merge` / `git merge-tree` / `cd` はいずれも `scope.sh` の分類に無く WF204 で拒否される
- 実行結果は **`wip/tmp/worktree-probe/`** に置く（0004 の e8・0005 の e16・0006 の e24 と同じ置き場。`.gitignore` 対象）
- **D1〜D3 は 0004 の実測手順 P0（W1 / W2 の作成）と独立に実行できる。** D4 は 0006 の C1 の後に行う
- 後始末: 作った worktree は `git worktree remove`、作ったブランチは `git branch -D`、作った一時ファイルは削除する。**本流の `wip/` と `logs/` には触れない**

**D1. 同一ブランチ制約の実文言を取る**

```bash
MAIN=/c/Users/taniyama/Desktop/git/issue-mr-ticket-workflow
OUT="$MAIN/wip/tmp/worktree-probe"; mkdir -p "$OUT"
cd "$MAIN"
# 現在のブランチ（= 本流が checkout 済み）を、別の作業ツリーで開こうとする
git worktree add ../probe-same feature-50-worktree-parallel-tickets > "$OUT/d1.txt" 2>&1
echo "exit=$?" >> "$OUT/d1.txt"
git worktree list >> "$OUT/d1.txt" 2>&1
```

予測: 非 0 で終了し、`fatal:` で始まる 1 行が出る。文言は「`'feature-50-worktree-parallel-tickets' is already used by worktree at '<本流のパス>'`」の形（**この文字列そのものは公式ドキュメントに無いので、ここで初めて確定する**）。`git worktree list` には本流 1 行だけが残る。
外れたとき: 成功してしまうなら、この環境の git は G1 の safeguard を持っていない（`git --version` を併記して残す）。その場合、案 3（`--force`）と案 2 の差が消えるので e27 の表を書き換える必要がある。

**D2. `--force` で同じブランチを共有したときに何が起きるか**

```bash
cd "$MAIN"
git worktree add --force ../probe-force feature-50-worktree-parallel-tickets > "$OUT/d2.txt" 2>&1
cd ../probe-force && git branch --show-current >> "$OUT/d2.txt" 2>&1
git log --oneline -1 >> "$OUT/d2.txt" 2>&1
# 本流の側で 1 コミット進める（提供コマンドで。空コミットでよい）
cd "$MAIN" && bash .claude/skills/20-common-step-commit-push/scripts/commit.sh -m "chore: 実測用の空コミット" --allow-empty >> "$OUT/d2.txt" 2>&1
# 共有している側から見え方を確かめる
cd ../probe-force
git status --porcelain >> "$OUT/d2.txt" 2>&1
git log --oneline -1 >> "$OUT/d2.txt" 2>&1
cd "$MAIN"
```

予測: `probe-force` 側の `git branch --show-current` は `feature-50-worktree-parallel-tickets`（本流と同じ）。本流が 1 コミット進めた後、`probe-force` の `git log --oneline -1` は**新しいコミットを指す**（ref を共有しているため）が、作業ツリーの中身は古いままなので `git status --porcelain` に**大量の差分**が出る。
外れたとき: `git status` が空なら ref が共有されていないので、案 3 の評価（「一方の commit が他方を壊す」）が誤りになる。
**注意: この実測の後は必ず `git worktree remove --force ../probe-force` で片付ける。** 空コミットは本流に残るので、残したくないなら D2 を飛ばす。

**D3. 並列の追記を実際に合流させて、衝突の実件数を数える**

本レポートの実際の履歴を使って、0005 の追記と 0006 の追記を「並列に行われたもの」として合流させる。**本流のブランチには触れない**（一時ブランチだけを使う）。

```bash
cd "$MAIN"
BASE=199fd98   # 0004（観点 A）まで
A=9c201fc      # 0005（観点 B）の追記
B=9929a17      # 0006（観点 C）の追記
# B の変更を BASE の上に載せ直した木を作る（= A と B が並列だった場合の一方）
git worktree add --detach ../probe-merge "$BASE" > "$OUT/d3.txt" 2>&1
cd ../probe-merge
git checkout -b probe-b >> "$OUT/d3.txt" 2>&1
git diff "$A" "$B" -- wip/30_reports/0004-investigation.md wip/30_reports/0004-investigation.html \
  | git apply --3way >> "$OUT/d3.txt" 2>&1
git add -A && git -c user.name=probe -c user.email=probe@example.com commit -m "probe: 0006 の追記だけを BASE の上に載せる" >> "$OUT/d3.txt" 2>&1
# A（0005 の追記）を合流させる
git -c merge.conflictStyle=diff3 merge "$A" >> "$OUT/d3.txt" 2>&1
echo "exit=$?" >> "$OUT/d3.txt"
echo "--- conflict markers ---" >> "$OUT/d3.txt"
grep -c '^<<<<<<<' wip/30_reports/0004-investigation.md  >> "$OUT/d3.txt" 2>&1
grep -c '^<<<<<<<' wip/30_reports/0004-investigation.html >> "$OUT/d3.txt" 2>&1
git status --porcelain >> "$OUT/d3.txt" 2>&1
cd "$MAIN"
```

予測: `git merge` は非 0 で終わり、`CONFLICT (content)` が md と HTML の 2 ファイルに出る。conflict marker の数は **md が 6〜10 件、HTML が 8〜13 件**（同一行の書き換え md 4 行 + HTML 9 行が近接して 1 つの marker にまとまるため、行数より少なくなる）。`wip/10_tickets/` には 1 件も出ない。
外れたとき: 衝突が 0 件なら、git は「同じ位置への両側の挿入」を自動で解いていることになり、e29 の (7) と (8) の見積もりを下げる（合流コストの評価が変わり、D-3 の判定が「成り立たない」に寄る）。逆に marker が 20 件を超えるなら見積もりが甘く、J5（衝突源を減らす）の優先度が上がる。
後始末: `git worktree remove --force ../probe-merge`、`git branch -D probe-b`。

**D4. サブエージェント worktree の成果が、終了後にどこに残るか**

0006 の実測 C1（`isolation: worktree` の probe）を、**ファイルを 1 つ作らせる形**にして再実行する（`probe-isolated.md` の本文に「`wip/tmp/probe-artifact.txt` に 1 行書き、`git status --porcelain` を貼ること」を足す）。サブエージェントの終了後、本流で次を実行する。

```bash
cd "$MAIN"
git worktree list > "$OUT/d4.txt" 2>&1
git for-each-ref --format='%(refname:short) %(objectname:short) %(committerdate:iso)' refs/heads >> "$OUT/d4.txt" 2>&1
ls -la .claude/worktrees/ >> "$OUT/d4.txt" 2>&1
git log --oneline --all --not main -20 >> "$OUT/d4.txt" 2>&1
git status --porcelain >> "$OUT/d4.txt" 2>&1
```

予測: `refs/heads` に `worktree-<名前>` が現れ、`.claude/worktrees/<名前>/` が残る（公式 S7「a worktree with changes stays on disk」）。`git status --porcelain` に `?? .claude/worktrees/` が出る（0006 の e21）。`git log --all --not main` にサブエージェントのコミットが現れ、**`feature-50-…` には 1 件も入っていない**（自動では合流しない）。
外れたとき: `worktree-<名前>` が無いなら、Claude Code が終了時に ref ごと片付けている。そのときは**未合流の成果が失われる**ことを意味するので、合流手順は「サブエージェントの終了前に本流へ書き戻す」形に限定される（J1〜J3 が全部使えなくなり、J4 だけが残る）。
後始末: `git worktree remove --force .claude/worktrees/<名前>` と `git branch -D worktree-<名前>`。

**D5. 採番の重複が本当に黙って通るか**

```bash
cd "$MAIN"
# 2 つの作業ツリーを feature ブランチのサブブランチとして作る
git worktree add -b probe-wt1 ../probe-wt1 feature-50-worktree-parallel-tickets > "$OUT/d5.txt" 2>&1
git worktree add -b probe-wt2 ../probe-wt2 feature-50-worktree-parallel-tickets >> "$OUT/d5.txt" 2>&1
cd ../probe-wt1 && bash .claude/skills/20-common-step-ticket/scripts/ticket.sh create investigation \
  --title "probe1" --purpose "probe" --dod "probe" >> "$OUT/d5.txt" 2>&1
cd ../probe-wt2 && bash .claude/skills/20-common-step-ticket/scripts/ticket.sh create design \
  --title "probe2" --purpose "probe" --dod "probe" >> "$OUT/d5.txt" 2>&1
cd ../probe-wt1 && git merge probe-wt2 >> "$OUT/d5.txt" 2>&1
echo "exit=$?" >> "$OUT/d5.txt"
ls -1 wip/10_tickets/00_todo/ >> "$OUT/d5.txt" 2>&1
bash .claude/skills/20-common-step-ticket/scripts/ticket.sh next >> "$OUT/d5.txt" 2>&1
cd "$MAIN"
```

予測: 両方の `create` が**同じ番号**（本レポート作成時点なら `0011`）を採り、ファイル名は `0011-investigation.md` と `0011-design.md` になる。`git merge` は**衝突せずに成功**し、`00_todo/` に `0011-` が 2 枚並ぶ。`ticket.sh next` は辞書順で先の `0011-design.md` を返す（`next` の JSON の `type` が `design` になる）。
外れたとき: 番号がずれるなら `ticket.sh` の採番が作業ツリー外も見ていることになり、e30 の (1) の判定が変わる。`git merge` が衝突するなら、番号の重複は目に見える形で止まる（悪さが 1 段下がる）。
後始末: `git worktree remove --force ../probe-wt1 ../probe-wt2`、`git branch -D probe-wt1 probe-wt2`、`wip/10_tickets/00_todo/0011-*.md` を消す（**本流には作らない**ので、本流の `wip/` は触らない）。

**注意（全 D 共通）**: `wip/tmp/` は `.gitignore` 対象なので出力は追跡されない。`git status --porcelain` に `?? ../probe-*` が出ないこと（作業ツリーはリポジトリの外に作る）を各手順の最後に確認する。**`push.sh` は実測の途中で実行しない**（0006 の e24 の C5 と同じ理由）。

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

| （0006）`decisions.jsonl` の総行数とイベント別の件数 | `wc -l` = **7482**、`jq` が読めた行 = **7506**。イベント別は PreToolUse 7101 / PostToolUse 249 / UserPromptSubmit 55 / SubagentStop 25 / SessionStart 25 / **SubagentStart 22** / 空 5 で、合計 7482 |
| （0006）SubagentStart の記録がすべて本流に落ちている | `logs/hooks/decisions.jsonl`（本流）に **22 件**。`.claude/worktrees/` が存在しないので他の候補となるファイル自体が無い（負のコントロールが無いことを明記） |
| （0006）本セッションの SubagentStart が 4 件で session_id が同一 | `jq 'select(.event=="SubagentStart")\|.session_id' \| sort \| uniq -c` = `4 595e717b-… / 13 7d007b19-… / 4 843ef779-… / 1 c59ef0ce-…`。`595e717b-…` は本サブエージェントの `CLAUDE_CODE_SESSION_ID` と一致 |
| （0006）本チケット着手後の記録件数と deny | `session_id` = `595e717b-…` かつ `ts >= 2026-09-04T23:48` が **37 件**、うち `decision=="deny"` が **2 件**（両方 WF204 の `cd`） |
| （0006）`decisions.jsonl` にキー `cwd` / `agent_id` が無い | `jq -r 'keys\|join(",")' \| sort \| uniq -c` の出力が **1 行**（`7506 decision,event,hook,id,note,session_id,target,ticket,tool,ts`） |
| （0006）Agent の `tool_input` から機構が読むキー | `hook-common.sh:207-213` が拾うのは `subagent_type` / `model` / `run_in_background` の **3 つ**。作業ディレクトリに当たるキーは 0 件 |
| （0006）起動プロンプトのひな形に worktree の欄が無い | `00-workflow-issue-mr-driven/assets/subagent-prompt.template.md` に `worktree` / `cwd` / 作業ディレクトリ の語が **0 件** |
| （0006）`task-executor.md` の frontmatter のキー | `name` / `description` / `tools` / `model` の **4 個**。`isolation` は無い |
| （0006）`.claude/settings.json` に `worktree` キーが無い | `grep -n "worktree" .claude/settings.json` = **0 件** |
| （0006）`.gitignore` に `.claude/worktrees/` が無い | `cat .gitignore` に該当行 **0 件**（`logs/` / `wip/tmp/*` / `参考ディレクトリ/` / `.claude/settings.json.bak-*` はある） |
| （0006）`.claude/` 配下が保護対象である | `jq '.common.protected' .claude/hooks/config/scope-limits.json` = `[".claude/**", ".gitignore", "apl/*/.gitignore", ".gitattributes"]` の **4 件** |
| （0006）提供コマンド 5 本の本体に `git -C` が無い | `grep -rn "git -C\|GIT_DIR\|GIT_WORK_TREE\|--git-dir" .claude/skills/` が拾ったのは `20-common-step-commit-push/scripts/tests/test_push.sh:57` と `20-common-step-shell-script/scripts/test-lib.sh:71-75` の **テスト側のみ** |
| （0006）フック側の `git -C` の件数 | `grep -rn "git -C" .claude/hooks/` = 本体 4 ファイル（`session-start.sh:113`／`subagent-stop-check.sh:83, 97`／`post-push-compact-prompt.sh:47, 63, 82, 133`／`post-push-usage-report.sh`）とテスト 2 ファイル |
| （0006）`push.sh` 項目 1 が `git status --porcelain` の出力で落ちる | `push.sh:78`（`detail="$(git status --porcelain \| tr -d '\r' \| sed '/^$/d')"`）と `:79-81`（空でなければ `unmet` に積む） |
| （0006）公式の出典が 4 URL・18 引用ある | e18 の表が **18 行**、URL は `sub-agents` / `worktrees` / `hooks` / `agents` の **4 本**、取得日はすべて 2026-09-04 |
| （0006）DDR `i0009-55` の引用が一次資料に実在する | `hooks` ページの Note が DDR の引用文（`hooks.md:598-601`）と**同じ文言**（e18 の S15） |

| （0007）ブランチ構成の選択肢が 3 案以上あり、成立可否・合流手順・衝突の種類が並んでいる | e27 の表は **4 行**（detached HEAD / サブブランチ + 合流 / `--force` / 別 clone）。列は「成立可否」「合流手順」「衝突の種類」「成立可否の根拠」で、**4 行すべてに `ファイル:行` か公式の引用 ID がある** |
| （0007）同一ブランチ制約の根拠が公式の記述である | e26 の表が **6 行**（`git-worktree` 5 件 + `git-checkout` 1 件）。URL は `git-scm.com/docs/git-worktree` と `git-scm.com/docs/git-checkout` の **2 本**、取得日はすべて 2026-09-05 |
| （0007）衝突件数の見積もりに、使ったコマンドとその出力が添えられている | e29 の (1)〜(7) にコマンド **13 本**とその出力を貼った（`grep -n 'git -C <本流>'` で数えた行数 14 のうち、実施条件の 1 行を除く 13 行）。内訳は `git log --all --diff-filter=R` 2 / `feature-10` の集計 4 / `git show --stat` と `--name-status -M20%` 2 / `git log --name-only` 1 / `git show -U0 \| grep -c '^@@'` 4 |
| （0007）rename の総件数 | `git log --all --diff-filter=R --name-status --format='' -- wip/10_tickets/ \| grep -c '^R'` = **235**。内訳の合計 133 + 94 + 6 + 2 = **235** で一致 |
| （0007）`feature-10` の内訳が総数と合う | rename **104** = `00_todo→10_doing` 56 + `10_doing→20_done` 45 + `10_doing→30_cancelled` 3。状態遷移コミット **168** = 作成 56 + 着手 56 + 完了 53 + 取り消し 3。全コミット **247** |
| （0007）1 コミットあたりの rename 件数 | `awk` による分布の集計の出力が **`104 1` の 1 行**（104 コミットすべてが 1 件） |
| （0007）計画書が名指しした 4 対象すべてに判定がある | e30 の表は **4 行**（採番 / レポートの追記 / `ticket.sh` の状態遷移 / `commit.sh` の状態遷移）。各行に「衝突するか」と `ファイル:行` の根拠がある |
| （0007）DDR `i0001-23` の却下文の主張それぞれに判定がある | e32 の 1 つ目の表が **3 行**（D-1「分離は強い」= 今も成り立つ / D-2「1 issue = 1 ブランチ = 1 MR の原則と衝突し」= 成り立たない / D-3「統合のコストが利得を上回る」= 条件付きで成り立つ）。2 つ目の表（背景の指摘 B-1〜B-3）も **3 行** |
| （0007）合流手段の可否が全件判定されている | e28 の表が **6 行**（M1〜M6）。各行に「現行の機構での可否」と `ファイル:行` の根拠がある |
| （0007）合流手順の選択肢が並んでいる（A6 の材料） | e33 の表が **6 行**（J1〜J6）。列は「誰が合流するか」「機構への変更」「1 合流あたりの手数」「残るリスク」。加えて「0010 が決める必要があるのは次の 5 点」を列挙した |
| （0007）実測手順が「コマンド列 + 予測 + 外れたとき + 後始末」の形で揃っている | e34 の D1〜D5 の **5 件**すべてに、コマンドブロック・予測・外れたとき・後始末がある |
| （0007）観点 D が読み取りだけで完結していない箇所を残課題に落とした | 「確かめられなかったこと」に 0007 の行が **5 件**、「残課題」に 0007 の行が **5 件** |

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

| 16 | （0006）`decisions.jsonl` に `cwd` も `agent_id` も記録されていない（e19）。`HOOK_AGENT_ID` は `hook_read_input` が読んでいる（`hook-common.sh:360`）のに `hook_record`（`hook-common.sh:654` の直前で組み立てる行）が落としている。並列を採るなら「どの作業ツリーの、メインかサブエージェントか」を後から追えないと切り分けができない。キーを 2 つ足すか、作業ツリーごとに `decisions.jsonl` が分かれることを前提に読む側を作るかの候補がある | 0010（AI アセット設計計画） |
| 17 | （0006）`isolation: worktree` を採るなら `worktree.baseRef: "head"` の設定が必須で、これを欠くと機構が静かに無効化される（e20）。設定の追加は `.claude/settings.json`（`common.confirm` 対象）への変更なので、AI アセット設計 → 実装計画のレビューを通す | 0010／AI アセット実装 |
| 18 | （0006）`.claude/worktrees/` を `.gitignore` に足す（e21）。公式が Tip で勧めており、足さないとサブエージェント worktree が残るたびに `push.sh` 項目 1（`push.sh:78`）が落ちる。`.gitignore` は `common.protected` なので設計を通す | 0010／AI アセット実装 |
| 19 | （0006）隔離下では「引用符のないヒアドキュメント」を含む Bash コマンドが拒否され、この検査は無効にできない（e22）。本プロジェクトは長文をヒアドキュメントで一時スクリプトに書く運用が常態なので、`20-common-step-shell-script` などの共通ステップに書き分け（`<<'EOF'`）を明記するか、Write ツールで一時スクリプトを作る形に寄せる | 0010／AI アセット設計（共通ステップの文面） |
| 20 | （0006）`scope.sh` の分類の穴を塞ぐとき（観点 E / 0008）、**隔離下でも通る形**を条件に入れる。本流への `cd` は Claude Code 側の git リダイレクト検査にも当たるので、`cd` を許す方向で塞ぐと隔離下で別の理由で止まる。`bash wip/tmp/<スクリプト>.sh` が `unknown` に落ちる件（本チケットで踏んだ）も同じ表に載せる | 0008／0010 |
| 21 | （0006）`task-executor.md` の frontmatter は `name` / `description` / `tools` / `model` の 4 個で、公式が定義するフィールドのうち `isolation` のほか `skills` / `maxTurns` / `permissionMode` / `disallowedTools` / `effort` / `background` などを使っていない。並列の可否とは別に、エージェント定義の見直しの余地がある（本チケットでは調べていない） | 0010（材料として） |
| 22 | （0006）サブエージェント worktree は `worktree-<名前>` という**別ブランチ**に成果を積み、終了時に自動では合流しない（S7）。1 issue = 1 ブランチ = 1 MR を保つなら合流の手順が要る。合流コストの見積もりは観点 D の担当 | 0007（観点 D）／0010 |

| 23 | （0007）`ticket.sh` の採番が自分の作業ツリーしか見ない（`ticket.sh:151-159`）。並列を採るなら、①番号を作業ツリーに閉じない採り方（issue 番号 + 作業ツリー識別子の複合キー、ULID など）②採番を本流に一本化する（合流の直前に振り直す）③番号の重複を検知する検査を `ticket.sh` か合流の手順に足す、の 3 系統の候補がある。**種類が違うと衝突せずに重複したまま通る**のが最も危ない（e30 の (1)） | 0010（AI アセット設計計画） |
| 24 | （0007）レポートの「1 タスク 1 本に積み上げる」運用が、そのまま並列時の衝突源になっている（追記のたびに md 4 行 + HTML 9 行を同じ行で書き換える。e29 の (6)）。**この運用は `10-task-investigation-exec` の共通手順が明示的に定めたもの**（「チケットごとにレポートを分けない」）なので、並列を採るなら共通手順の側を見直すか、衝突を受け入れて解消の担当を決めるかを選ぶ（e33 の J5） | 0010／AI アセット設計（共通ステップの文面） |
| 25 | （0007）`scope.sh` の `merge` の分類が「引数に `origin/*` があるか」だけで決まる（`scope.sh:392-393`）。`git merge origin/feature-なんとか` も `merge-base` になるので、**取り込みに限る統制になっていない**。一方でローカルブランチの合流は一律 `unknown` に落ちる。観点 E（0008）の穴の一覧に載せ、塞ぎ方の案には「合流を通すか通さないか」を含める | 0008／0010 |
| 26 | （0007）`workflow-guard` の制御方式 1（作業中チケットが 0 枚なら何もしない。`workflow-guard.sh:47-49`）が、**タスクの切れ目ではあらゆる `git` 操作を素通しする**。合流を切れ目で行う運用にすると、この素通しに乗ることになる。意図した緩和なのか穴なのかを仕様で明示する必要がある（DDR `i0004-07` の「拒否できる」という記述と噛み合っていない） | 0010／0008 |
| 27 | （0007）`boundary.sh` の `scan_tickets` が「完了群の末尾から同じ種類が続く範囲」でタスクを切る（`boundary.sh:83-93`）。並列で種類の違うチケットを交互に完了させると**タスクを取りこぼしてレビューを受けないチケットが出る**（e31）。並列を採るなら、タスクの範囲を「番号の連続」ではなくチケット側の情報（`ticket_type` のまとまり、あるいはタスク ID）で決める必要がある | 0010／AI アセット実装 |
| 28 | （0007）`ticket-check.sh:62` の未コミット検査がチケットファイル自身を除外するため、**完了コミットに作業ログの追記が相乗りし、rename 検出が外れる**（`feature-10` の完了 53 件中 8 件。e29 の (4)）。合流時の衝突の型が変わるだけでなく、`git log --diff-filter=R` による運用の観測も歪む。`.gitattributes` に `*.md` の行末指定が無いことも同じ方向に効く | 0010（合流手順の前提として）／保留 P2 |
| 29 | （0007）`push.sh` が detached HEAD を CP007 で拒否する（`push.sh:67-68`）。これは**正しい振る舞い**だが、`boundary.sh:467` の `git rev-list "origin/$br..HEAD"` は `br` が `HEAD` のとき `origin/HEAD`（既定ブランチ）と比較して**誤った「未 push」判定**を出す。detached HEAD を採らないなら実害は無いが、防御の粒度が 2 か所で揃っていない | 0010／保留 P2 |
| 30 | （0007）**合流したことを記録する場所が無い**。`decisions.jsonl` に `cwd` も `agent_id` も無く（0006 の e19）、`logs/` は作業ツリーごとに分かれる（0005 の e9）。並列を採るなら「どの作業ツリーのどのチケットの成果を、いつ、どこへ合流したか」を残す先を決める必要がある（e33 の 5 点目） | 0010 |
| 31 | （0007）`git branch -d` / `-D` が `scope.sh` の `_SC_GIT_READ_SUBCMDS` の `branch` に当たって **`read` に分類される**（`scope.sh:36`）。合流後の後始末には都合がよいが、**ブランチを消す操作が読み取り扱いになっている**のは分類の穴である（`git worktree remove` は `unknown` で拒否されるのに、ref の削除は通る）。観点 E の一覧に載せる | 0008／0010 |

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

| （0006）調査計画書は「Agent ツールに作業ディレクトリ／worktree を指定する手段があるか」と問いを立てていた | 手段は Agent ツールの引数ではなく、**エージェント定義の frontmatter `isolation: worktree`** だった。ツールの引数を探していると「無い」という誤った結論に着く | 観点は書き換えず、e17 で「探す場所が違っていた」と明示した。`subagent-prompt.template.md` に口が無いのは正しいことも併記した |
| （0006）呼び出し元の起動プロンプトは「呼び出し元セッションの作業ディレクトリは固定であり、サブエージェントは既定でそれを引き継ぐ。この前提が崩せるのか」と前提を置いていた | 既定としては公式の記述どおりで正しい（S1）が、**前提は崩せる**。崩したあとに問題になるのは作業ディレクトリではなく**分岐元のブランチ**だった | e17 で既定を確認したうえで、重心を e20（分岐元）に置いた |
| （0006）調査計画書のリスク欄は「観点 C が『別 worktree で動かせない』と出て、以降の観点が空振りする」を想定していた | 答えは肯定で、空振りは起きなかった。代わりに「動かせるが、そのまま載せると機構が静かに無効化される」という条件付きの肯定になった | 0007 以降は計画どおり続ける。ただし観点 D の合流コストは「サブエージェント worktree が `worktree-<名前>` という別ブランチを作る」ことを前提に見積もる必要がある（設計への反映 22） |
| （0006）`decisions.jsonl` から「サブエージェント実行時の `cwd` の実値」を拾えると見込んでいた（調査計画書の「対象と方法」の観点 C 行） | **`cwd` は記録されていない**（キーは 10 個）。拾えるのは `session_id` と、記録がどのファイルに落ちたかだけだった | 拾えるもので代えた。`session_id` の一致からサブエージェントがセッションを共有することを示し（e19）、`cwd` そのものは実測 C2 に落とした。記録側の不足は設計への反映 16 に上げた |
| （0006）0004 の実測手順 P2 の識別子 W1（`main` を基点にした作業ツリー = チケット 0 枚）は、あくまで実測を切り分けるための人工物だと見込んでいた | **既定設定のサブエージェント worktree そのもの**だった（分岐元が既定ブランチだから）。P2 の「W1 だけ無音」という予測は、そのまま「隔離サブエージェントでは機構が無音になる」という予測でもある | e20 で両者を結びつけた。0009 で P2 と C1 の結果を並べて読む |
| （0006）Claude Code 側に worktree 隔離の強制があるとは想定していなかった | 隔離中は 4 つの検査が掛かり、うち File edits の検査が **0004 の e5（作業ツリーをまたぐ絶対パス書き込み）を外から塞ぐ**。一方で command shape の検査は無効化できず、本プロジェクトのヒアドキュメント運用に正面から当たる | e22 に表として整理し、追い風と逆風を分けて書いた |

| （0007）調査計画書は合流コストを「`wip/10_tickets/` のファイル移動による衝突」として見積もることを求めていた（観点 D の問いと「成果物の形」） | **`wip/10_tickets/` の衝突は 0 件だった。** チケットごとに別ファイルで、1 コミット 1 rename（`feature-10` の 104 コミットすべて）なので、別のチケットを動かす限り重ならない。実際に効いたのは**レポート 1 対への追記**（同一行 13 行）と**採番の重複**だった | 観点は書き換えず、e30 で 4 対象すべてを判定したうえで、重心を e29 の (6)(7) と e30 の (1) に置いた |
| （0007）却下文の「1 issue = 1 ブランチ = 1 MR の原則と衝突し」は、今も成り立つ側だろうと見込んでいた（起動プロンプトも「この理由が今も成り立つかを判定できる形にする」ことを主眼に置いていた） | **成り立たない。** 原則の正文が禁じているのは MR を増やすことで、ローカルの中間ブランチではない。しかも**同じ前提条件の次の行（`:164`）が「並行して作業する場合は git worktree または別の clone を使う」と worktree を明示的に許していた** | e32 の D-2 として判定し、根拠を 3 つ（原則の正文 / `:164` の許可 / squash merge で中間履歴が残らないこと）並べた。読み方の承認は ◆ に上げた |
| （0007）合流コストの主体はファイルの衝突だろうと見込んでいた | **主体は「合流という操作を機構が想定していないこと」だった。** `cherry-pick` / `rebase` / `am` は WF401 で拒否され、`git merge <ローカルブランチ>` は `unknown` で WF204。**AI に通る道は「作業中 0 枚のときの `git merge`」と「ファイルをコピーして `commit.sh`」の 2 つだけ**で、前者は DDR `i0004-07` が「拒否できる」と書いた統制の抜けに乗る形になる | コストを 3 分類（ファイル / 操作 / 合流後の前提）に分け直し、e25 の 2 つ目の表で大きさを並べた |
| （0007）`git merge` は機構が一律に拒否すると見込んでいた（0006 の e22 の「git リダイレクト検査」と同じ扱いだと思っていた） | **`block-direct-git` は `merge` と `stash` を明示的に対象外にしている**（`block-direct-git.sh:35-36`、DDR `i0004-07`）。拒否しているのは `workflow-guard` 側で、しかも**作業中チケットが 0 枚なら素通りする** | e28 の M1 として「条件付きで通る」と書き、通ることが設計判断ではないこと（DDR の文面）を併記した |
| （0007）チケットの状態遷移コミットは「純粋な rename」だと見込んでいた | **完了コミット 53 件中 8 件（15%）が rename として検出されない。** `ticket-check.sh:62` の未コミット検査がチケットファイル自身を除外するため、**作業ログの追記が完了コミットに相乗りする**（実例は 63 行削除 / 95 行追加で、`-M20%` でも rename にならない） | e29 の (4) に実例つきで書き、合流時の衝突の型が変わることを設計への反映 28 に上げた |
| （0007）衝突の件数は `git merge` を試して数えるつもりでいた | **3-way マージを実行する手段が 1 つも無い。** `merge` は `unknown`、`merge-tree` は `_SC_GIT_READ_SUBCMDS` に無く、`diff3` は `_SC_READ_ONLY_CMDS` に無い。読み取りだけで数えるには「過去の追記の hunk 位置を共通の基点に写す」しかなかった | 静的な方法に切り替えて (6)(7) を出し、実件数の確定は実測手順 D3 に落とした。◇ に「実行していない」ことを明記した |
| （0007）`isolation: worktree` の worktree は、ブランチ構成の第 5 の案として別に立てるつもりでいた | `worktree-<名前>` は `git worktree add <path>`（引数省略）が作るブランチ（`$(basename <path>)`）と**同じ性質**で、案 2 の具体形だった | e27 の案 2 の欄に併記し、「隔離を採る = 案 2 の合流手順を決める」と書いた |

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
| R12 | （0006）SubagentStart フックの `cwd` が、`isolation: worktree` のとき worktree 作成の前の値か後の値か。公式は `WorktreeCreate` と `SubagentStart` の発火順を書いていない。**観点 C の「どちらの `cwd` を読むか」のうち確定できたのは PreToolUse `Agent` 経路だけ**で、SubagentStart 経路は不明のまま残る | 0009（実測手順 C2） |
| R13 | （0006）`isolation: worktree` が本環境の Claude Code 2.1.259 で実際に解釈されるか。公式は `isolation` の導入版を明記していない（同ページ内の他の記述は v2.1.203 / 210 / 246 などを挙げている） | 0009（実測手順 C1） |
| R14 | （0006）`worktree.baseRef: "head"` のとき、サブエージェント worktree の分岐元がメイン会話の `HEAD`（= feature ブランチの先端）になるか。公式 S8 が明示しているのは「worktree の中では `"head"` はその worktree の `HEAD`」だけで、メイン会話が本流にいるときのサブエージェント worktree については書いていない | 0009（実測手順 C4） |
| R15 | （0006）Claude Code の隔離検査（git リダイレクト・command shape）がフックのプロセスにも及ぶか。公式は対象を「a Bash, PowerShell, or Monitor command」と限っているが、フックが対象外だと明示した文は無い。及ぶなら `git -C "$HOOK_WORKTREE"` を持つフック 4 本が隔離下で止まる | 0009（実測手順 C3 の副産物）／0010 |
| R16 | （0006）隔離下で提供コマンド 5 本が実際に走るか（`bash .claude/skills/…/ticket.sh`）。走らないなら A1（`isolation: worktree`）は成立せず、代替は A2 / A3 に倒れる | 0009（実測手順 C3 の (1)） |
| R17 | （0006）`.worktreeinclude` で `logs/` を worktree へ複製したときに、進行状態（`merge-state.json` / `mr.json` / `review-state.json`）が二重になって何が起きるか。0005 の e13 は「残るほうが壊れる」と結論しているので、複製は 0005 が挙げた 3 件をそのまま worktree にも持ち込む | 0010（調査計画書の保留 P2） |
| R18 | （0006）e20 を受け入れ条件 A1 の「動かない箇所」に載せるか、A4（並列採否）の材料に留めるか。0004 の R6・0005 の R10 と同じ種類の判断 | 0009／0010（人間の判断） |
| R19 | （0006）並列の単位が「1 issue 内のチケット」ではなく「人間のセッション」になった場合（A2 / A3）、issue #50 の受け入れ条件 A4 に対する答えは「1 issue 内の並列は採らない」になる。その場合でも A1（worktree 上の健全性）は必要なのでフェーズ列は変わらない見込みだが、AI アセット設計の対象範囲は狭まる | 0010 |
| R20 | （0007）**並列の利得（所要時間の短縮幅）を測る材料が無い。** チケットの `started_at` / `completed_at` は記録されているが、完了した issue の `wip/` は `finalize.sh` の片付けで消えており、`git show` で復元しないと読めない。しかも直列で実施した時間しか無く、並列にしたときの短縮幅は推定になる。**「統合のコストが利得を上回る」（DDR `i0001-23`）はコスト側しか数値で言えていない**（e32 の D-3）。0010 で保留 P1 を決めるとき、この非対称を明示したうえで判断するか、`git show` で過去の `started_at` / `completed_at` を掘って利得側の目安を作るかを選ぶ必要がある | 0009 / 0010 |
| R21 | （0007）合流時の**衝突の実件数**（conflict marker の数）。読み取りだけでは「同一行の書き換え 13 行は確実」「同一の挿入点 6 か所は衝突する見込み」までしか言えない。3-way マージを実行する手段が機構に無い（`merge` / `merge-tree` / `diff3` がすべて分類外） | 0009（実測手順 D3）／人間 |
| R22 | （0007）**サブエージェント worktree の `worktree-<名前>` ブランチが終了後にいつまで残るか。** ref ごと消えるなら未合流の成果が失われ、合流手順は「終了前に本流へ書き戻す」形（J4）に限定される。公式は worktree ディレクトリの sweep には触れるが ref には触れていない | 0009（実測手順 D4）／0010 |
| R23 | （0007）**合流の実行者を誰にするか**（e33 の J1〜J6）。J2（`scope.sh` の分類を広げる）を選ぶと DDR `i0004-07` の決定を部分的に覆すことになり、J3（`merge.sh` を足す）は同 DDR が却下した案に戻ることになる。どちらも「当時の判断を、worktree という新しい前提のもとで見直す」形の決定なので、**DDR を上書きする新しい DDR が要る** | 0010（AI アセット設計計画）／AI アセット設計 |
| R24 | （0007）**採番の重複が「衝突せずに通る」経路をどう塞ぐか**（e30 の (1)）。番号を作業ツリーに閉じない採り方にするのか、合流の手順で検査するのか。前者はチケットの命名規則（`<4 桁>-<種類>.md`）と `find_ticket` / `boundary.sh` の番号の扱いに波及し、後者は合流を機構が担うこと（J2 / J3）を前提にする | 0010 |
