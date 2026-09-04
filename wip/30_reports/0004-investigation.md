---
type: report
title: 0004 調査結果 — worktree 上でのフックの作業ツリー解決と、WIP・宣言範囲・差分判定の健全性
description: issue #50 の調査フェーズの結果。観点 A について、フックの HOOK_ROOT / HOOK_WORKTREE の全参照 81 件を判定つきで一覧にし、6 本のフックが worktree 側と本流側のどちらで判定するかを行番号つきで確定し、既存テスト HK-T18 が検証済みの範囲と実測でしか確かめられない残余を分け、人間が実行するための実測手順（コマンド列 + 予測）を残した。
tags: [report, investigation, issue-50]
keywords: [worktree, HOOK_WORKTREE, HOOK_ROOT, 作業ツリー解決, 静かな無効化, workflow-guard, workflow-diff-check, hc_lock, HK-T18, 実測手順]
---

# 0004 調査結果 — worktree 上でのフックの作業ツリー解決と、WIP・宣言範囲・差分判定の健全性

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

### ◆特に見てほしい（判断に困っている）

- e5 の位置づけ。「作業ツリーをまたぐ絶対パス指定で進行状態ファイル保護がすり抜ける」ことは、フック共通仕様 §13「意図的な緩和」が約束している「機構が守るのは進行状態・コミット / push・`chmod`（常時フック）まで」に反する。**issue #50 の受け入れ条件 A1 の「動かない箇所」として扱うか、全体計画書の保留 P2（機構の不具合として別 issue）へ回すか**を決めきれていない。並列実施を採らなくても worktree を使えば踏むので前者に寄せたが、判断は 0009 と 0010 に委ねる
- e2 の `session-start.sh:74`（`boundary.sh` のパスを `HOOK_WORKTREE` から取る）。仕様 §2 の「スクリプトの置き場は常に `HOOK_ROOT`」に反するが、`boundary.sh` は自分の `BASH_SOURCE` からルートを決めるので、本流の実体を呼ぶと本流の `wip/` を読んでしまい、かえって間違った現在地が出る。**「原則が例外を必要としている」のか「原則の書き方が粗い」のか**を設計フェーズで決めてほしい

### ◇判断が欲しい（決めた方針の承認 / 決められない点の判断）

- 取り違えの判定基準を「その参照が指しているものが、①スクリプト・設定の実体（= `HOOK_ROOT` が正）か、②`wip/` `logs/` `git` の状態（= `HOOK_WORKTREE` が正）か」の 2 択に固定し、定義行・コメント・テストの設定は判定の対象外とした（e2 の表の `C` と `T`）。この線引きで 81 行を 5 群に割った
- 実測手順は **「Claude を worktree に入れる」実測と「`cwd` を worktree にしたフックの単体実行」の 2 段に分け、後者を主にした**（e8）。前者は `git worktree add` も `cd` も機構が WF204 で拒否するため AI からは組み立てられず、人間の手数も多い。後者は同じ判定経路を stdin から直接叩けて、識別子（W1 = チケット 0 枚の作業ツリー）を置けば「worktree 側で判定したか」を一意に切り分けられる
- 実測の識別子として **`main` を基点にした作業ツリー W1（`wip/10_tickets/10_doing/` が `.gitkeep` だけ = チケット 0 枚）** を使う設計にした。本流と同じ内容の作業ツリーでは「worktree 側を見た」と「本流を見た」が同じ出力になり区別できないため

### ・細かいレビューは不要（ほぼ確実）

- 参照の総数 81 行・90 箇所（`grep -rn ... | wc -l` と `grep -rno ... | wc -l`）は機械的に数えた値である
- `logs/` が `.gitignore` されていること（`.gitignore` の `logs/` 行、`git ls-files logs/` が 0 件）と、`wip/` が追跡されていること（`git ls-files wip/` が 19 件）
- `hc_lock` / `hc_unlock` / `__hc_unlock_all` のロックの置き場が `"$HOOK_WORKTREE/logs/locks/<name>.lock"` であること（`hook-common.sh:604` / `624` / `634`）

## 確かめられなかったこと

| 対象 | 確かめられなかった理由 | 引き取り先 |
|---|---|---|
| Claude が worktree に入ったとき、`cwd` が本当に各イベント（SessionStart / UserPromptSubmit / PreToolUse / PostToolUse / SubagentStart / SubagentStop）で worktree を指すか | 公式ドキュメントの原文を読むには `web` が要るが、0004 の `allow.ops` は `read` / `remote-read` のみ。本レポートは DDR `i0009-55` が引用した原文（`hooks.md:598-601`）を二次資料として使った。原文が言及しているのは `cwd` フィールド一般で、イベントごとの明示は引用の範囲に無い | 0006（観点 C。`allow.ops` に `web` あり）と 0009（実測） |
| `EnterWorktree` / `ExitWorktree` というツールが実在するか、Claude が worktree に入る手段は何か | 同上（外部仕様）。リポジトリ内の根拠はフック共通仕様 §13 の記述だけで、これは自プロジェクトの文書であり一次資料ではない | 0006 / 0009 |
| Skill ツールが読み込む `SKILL.md` は本流と worktree のどちらの実体か | 外部仕様。これが決まらないと `session-start.sh:140`（`__se_has_skill`）の正誤が確定しない | 0006 / 0010（AI アセット設計） |
| `git worktree add` が実際に書く `.git` ファイルと `.git/worktrees/<名前>/gitdir` の中身（絶対 / 相対、Windows でのパス表記） | `git worktree` は `scope.sh` の git 分類に無く、どの `allow.ops` を宣言しても WF204 で拒否される（全体計画書の差分 2）。実行は人間に回す | 0009（実測手順 P0） |
| 6 本のフックを `cwd` = worktree で走らせたときの実際の出力 | 同上。作業ツリーを作れないため | 0009（実測手順 P1〜P7） |
| `logs/` が無い worktree で提供コマンド 5 本（`ticket.sh` ほか）が何を読み、どう振る舞うか | 観点 B（0005）の担当範囲。本レポートはフック側の `logs/` 依存だけを見た | 0005 |

## 実施条件（測った対象・環境）

- 対象コミット: `feature-50-worktree-parallel-tickets` の `65d908e`（チケット 0004 の基準点は `9721416`）
- 実行したのは読み取りのコマンドだけ（`grep -rn` / `sed -n` / `git ls-files` / `git ls-tree` / `git rev-parse` / `git log -S`）。ファイルの作成は `wip/30_reports/` と `wip/tmp/` のみ
- 参照の数え方: `grep -rn "HOOK_ROOT\|HOOK_WORKTREE" .claude/hooks/ | wc -l` = 81（行数）、`grep -rno ... | wc -l` = 90（箇所数。内訳 `HOOK_ROOT` 28 / `HOOK_WORKTREE` 62）、テストを除いた本体 = 71 行

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

## 想定と異なった点

| 計画時の見込み | 実際 | どう扱ったか |
|---|---|---|
| 調査計画書は「`HOOK_ROOT` を使うべき箇所と `HOOK_WORKTREE` を使うべき箇所が取り違えられていないか」を主な問いに置いていた | 明確な取り違えは 0 件で、疑い・潜在が 4 件。より効くのは「1 つの作業ツリーしか基準にできない」ことの帰結（e5）だった | 観点は書き換えず、e2 で取り違えを 4 件として報告したうえで、重心を e5 に置いた |
| フック共通仕様 §13 と DDR `i0009-64` の「`workflow-diff-check` は worktree の差分を見ない」は現状の記述として使えると見込んでいた | 実装は初版から `git -C "$HOOK_WORKTREE"` で、記述と逆 | e6 の D1 として記録し、実測 P5 で確定させることにした |
| 実測は「Claude を worktree に入れる」形でしか取れないと見込んでいた | フックは stdin の `cwd` だけで作業ツリーを決めるので、`cwd` を与えて直接叩けば大半の観点が確かめられる（P1〜P7）。Claude 本体の挙動に依存するのは「`cwd` が追随するか」だけ | 実測手順を 2 段に分け、人間の手数を P8 に閉じ込めた |
| `git worktree list` は読み取りなので通ると見込んでいた | `git worktree` は `_SC_GIT_READ_SUBCMDS` に無く WF204。同じコマンド行に混ぜた他の `git` 読み取りも巻き添えで拒否された | 迂回せず、`ls-tree` / `rev-parse` に分けて取り直した。観点 E（0008）の材料として記録 |

## 残課題

| # | 残課題 | 引き取り先 |
|---|---|---|
| R1 | Claude が worktree に入ったとき、各イベントの `cwd` が実際に worktree を指すか。本レポートは DDR `i0009-55` が引用した公式原文を二次資料として使っただけで、原文の確認も実測もしていない | 0006（`web` あり）／0009（実測 P8） |
| R2 | 仕様 §13 と DDR `i0009-64`「残る穴」の根拠になった **0031 の実測**が、なぜ「worktree の差分は事後検査に現れない」と結論したのか。当時の作業ログ・レポートは本ブランチの `wip/` に無い（別 issue の作業領域は片付け済み） | 0009（実測 P5 で現在の挙動を確定）／必要なら過去 MR の履歴を読む |
| R3 | `git worktree repair` 前の作業ツリー（相互参照が片方向）が本流に倒れることの実害。DDR `i0009-64` が却下した副作用が実装では起きている（e6 D2）。安全側ではあるが、worktree を移動する運用があるなら気づけない静かな縮退になる | 0010（AI アセット設計） |
| R4 | Skill ツールが読み込む `SKILL.md` が本流と worktree のどちらの実体か。これが決まるまで `session-start.sh:140`（X1）の正誤は確定しない | 0006／0010 |
| R5 | 本流と worktree で `scope-limits.json` の内容が食い違う場合（worktree が古い / 新しいブランチ）、フックは常に本流の設定で判定する（`hook-common.sh:347`）。設定を変えるブランチを worktree で開発すると、そのブランチの設定はテストされない | 0010 |
| R6 | e5 を受け入れ条件 A1 の「動かない箇所」として扱うか、全体計画書の保留 P2（機構の不具合として別 issue）へ回すか | 0009／0010（人間の判断） |
