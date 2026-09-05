---
type: plan
title: 0003 調査計画 — worktree 上での機構の挙動と、1 issue 内チケット並列実施の費用対効果
description: issue #50 の調査フェーズの計画。worktree でのフック・提供コマンド・状態ファイルの挙動、サブエージェントの別 worktree 起動可否、並列成果の合流コスト、scope.sh の git 分類の穴の 4 系統を 6 観点に分け、調査チケット 6 枚と次の計画チケット 1 枚に割り付ける。
tags: [plan, investigation-plan, issue-50]
keywords: [worktree, HOOK_WORKTREE, 並列実施, 宣言範囲の強制, 差分の基準点, 合流, scope.sh, git分類, サブエージェント, 実測]
---

# 0003 調査計画 — worktree 上での機構の挙動と、1 issue 内チケット並列実施の費用対効果

- 対象 issue: [#50](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/50)
- MR: [#51](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/pull/51)（draft）
- ブランチ: `feature-50-worktree-parallel-tickets`
- チケット: 0003
- 作成日: 2026-09-04

## この計画で何をするか

DDR `i0001-23` は「並列時だけ別ブランチ・別作業ツリーに分ける」案を「1 issue = 1 ブランチ = 1 MR の原則と衝突し、統合のコストが利得を上回る」として却下した。本フェーズは、この却下理由が git worktree という具体的な手段のもとで今も成り立つかを、**測れる問いに分解して答える**。

効く受け入れ条件は A1（worktree 上で機構が健全に動くことの実測）と A4（並列実施の採否と理由を DDR に残す）で、A5・A6 には「並列を採用する場合に何が要るか」の材料として効く。全体計画書の保留 P1（並列の採否）はここでは決めず、判断材料だけを揃えて AI アセット設計計画（0010）へ渡す。全体計画書の保留 P3 は本計画で決着させる（下の「保留した点 / 対象なし」）。

## 対象と範囲

| 区分 | 内容 |
|---|---|
| 根拠とする入力 | `wip/00_overall_plan/overall-plan.md`（フェーズ列・方針・差分 1〜3・保留 P1 / P3）、issue #50 本文（受け入れ条件 A1〜A6・確かめる必要があること・スコープ外）、DDR `i0001-23`（並列実施の廃止）、DDR `i0009-55`（worktree では cwd 側の作業ツリーを採る） |
| 扱う対象 | `.claude/hooks/`（`lib/hook-common.sh`・`lib/scope.sh`・各イベントのフック）、提供コマンド 5 本（`ticket.sh` / `commit.sh` / `push.sh` / `boundary.sh` / `finalize.sh`）、`logs/` 配下の進行状態とロック、`wip/10_tickets/` と `wip/30_reports/` のファイル運用、`.claude/docs/` の関連要件・仕様・DDR、Agent ツールの worktree に関する外部仕様 |
| 扱わない対象 | 直し方の決定（AI アセット設計 0010 以降）／実際のコード変更（AI アセット実装）／別 issue 同士の並行（issue #50 スコープ外）／1 issue = 1 ブランチ = 1 MR の原則の変更（同スコープ外）／マージ操作 |

### 実測の扱い（この計画の前提）

全体計画書の差分 2 のとおり、`scope.sh` の git 分類に `checkout` / `switch` / `worktree` が無く、**どの `allow.ops` を宣言しても AI からは実行できない**（`WF204: … はどの分類にも当たらない（既定拒否）`）。本チケットの実施中にも `cd` が同じ理由で 2 回拒否された。したがって worktree を実際に作る実測は、次の形で行う。

1. 調査チケット 0004〜0007 は、**読み取りだけで答えられるところまで答え**、残った不確かさを「実測手順」として調査結果レポートに書く。手順は **そのまま貼れるコマンド列と、観点ごとの期待値（予測）** を対にして書く
2. 実測手順の実行は**人間が行う**。実行の依頼は、0008 完了時点の切れ目で呼び出し元（メインエージェント）がまとめてユーザーに渡す
3. 実行結果は `wip/tmp/worktree-probe/` 配下に置く（`.gitignore` 対象。同一作業ツリーなので後続チケットが読める）
4. 調査チケット 0009 が、その結果を 0004〜0007 の予測と突き合わせて確定させる。結果が得られなかった項目は理由と再実行手順つきで残課題に残す

**この計画では、先に `scope.sh` の穴を直してから実測する道は採らない**（理由は「保留した点 / 対象なし」の P3 決着）。

## 調査観点

読み取りで答えられる問いと、実測でしか答えが出ない問いを混ぜず、後者は「予測 + 実測手順」の形に落として観点の中に残す。

| 観点 | 問い | どの判断点・受け入れ条件に効くか |
|---|---|---|
| A | Claude が worktree に入ったとき、フックは worktree 側の `wip/` と `logs/` を見て判定するか。`workflow-guard`（WIP リミット・宣言範囲）・`workflow-diff-check`（差分の基準点）・`workflow-entry`（継続条件）・`workflow-state-guard`（置き場保護）・`session-start` が、DDR `i0009-55` の言う「静かな無効化」に落ちない実装になっているか。`HOOK_ROOT` を使うべき箇所と `HOOK_WORKTREE` を使うべき箇所が取り違えられていないか | A1 / A5 / 保留 P1 |
| B | 提供コマンド 5 本と `logs/` 配下の状態ファイルは worktree ごとに分かれるか。`logs/` は `.gitignore` されており worktree には存在しないが、その状態で `boundary.sh` / `push.sh` / `finalize.sh` / `ticket.sh` は何を読み、無いときにどう振る舞うか。`__ss_load` の `LOGGER_ROOT` 解決が、本流の絶対パスで呼ばれたときに worktree とずれないか | A1 / A5 / 保留 P1 |
| C | サブエージェントを呼び出し元と別の worktree で動かせるか。Agent ツールに作業ディレクトリ／worktree を指定する手段があるか。`subagent-start-check` は起動されるサブエージェント側の `cwd` を見るのか呼び出し元の `cwd` を見るのか。動かせないなら「1 プロセス内での並列」は成立せず、A4 の採否がその時点で決まる | A4 / A5 / 保留 P1 |
| D | 1 issue = 1 ブランチ = 1 MR を保ったまま複数 worktree を使えるか。git は同じブランチを 2 つの作業ツリーで checkout させないが、その回避策（detached HEAD / サブブランチ + 合流 / `--force`）それぞれで何が起きるか。並列作業の成果を feature ブランチへ合流させるとき、`wip/10_tickets/` のファイル移動・連番の採番・`wip/30_reports/` の同一ファイルへの追記・`ticket.sh` と `commit.sh` の状態遷移コミットは、どんな衝突を何件生むか | A4 / A6 / 保留 P1 |
| E | `scope.sh` の git 分類にどれだけ穴があるか（`checkout` / `switch` / `worktree` / `cd` が `unknown` → 既定拒否）。穴を塞ぐ案は何通りあり、それぞれ `block-direct-git.sh`・`scope-limits.json`・既存のテストにどう影響するか | A1 / 保留 P3 の後始末 |
| F | 人間が実行した実測の結果は、A〜D の予測と一致するか。食い違った項目はどれで、並列採否（保留 P1）と A1 の「動かない箇所」の一覧はどう確定するか | A1 / A4 / 保留 P1 |

答えが次の計画（AI アセット設計計画 0010）に効かない問い — たとえば worktree 一般の運用ノウハウ、他プロジェクトでの並列開発事例 — は観点に含めない。

## 対象と方法

書き込みは `wip/**` のみ。`.claude/**` は読むだけで、一時的な変更（`settings.json` へのフックの一時登録など）は計画しない。

| 観点 | 読む場所 | 確かめ方 | 外部調査 |
|---|---|---|---|
| A | `.claude/hooks/lib/hook-common.sh`（`__hc_resolve_worktree` / `__hc_is_worktree_of` / `HOOK_ROOT` の定義）、`.claude/hooks/20-PreToolUse/*.sh`、`.claude/hooks/22-PostToolUse/*.sh`、`.claude/hooks/10-UserPromptSubmit/workflow-entry.sh`、`.claude/hooks/00-SessionStart/session-start.sh`、`.claude/hooks/13-SubagentStop/subagent-stop-check.sh`、`.claude/hooks/lib/tests/test_hook_common.sh`、`.claude/docs/10_spec/` のフック共通仕様 §2、DDR `i0009-55` | `grep -rn "HOOK_ROOT\|HOOK_WORKTREE" .claude/hooks/` で全参照を機械的に抜き、1 件ずつ「スクリプトの置き場（HOOK_ROOT が正）」「作業ツリーの状態（HOOK_WORKTREE が正）」のどちらを指すべきかを判定して表にする。既存テストが検証済みの範囲を `test_hook_common.sh` から特定し、残余を実測手順にする | 不要 |
| B | `.claude/skills/*/scripts/*.sh` の `__ss_load` 行、`ticket.sh` / `commit.sh` / `push.sh` / `boundary.sh` / `finalize.sh` の `LOGGER_ROOT` 利用箇所、`.claude/skills/20-common-step-shell-script/scripts/logger.sh`、`.gitignore`（`logs/`）、`logs/` 配下の実ファイル一覧、各コマンドの仕様書 | `grep -n 'LOGGER_ROOT\|logs/' <各スクリプト>` で状態ファイルへの依存を全件抜き、「コマンド × 依存する状態ファイル × 無いときの振る舞い（既定値 / 警告 / 停止）」の表を作る。`__ss_load` の探索順（`BASH_SOURCE` 上向き → `CLAUDE_PROJECT_DIR` → `git rev-parse`）に、相対パス起動と本流の絶対パス起動を当てはめて解決先を書き分ける。残余を実測手順にする | 不要 |
| C | Claude Code / Agent ツールの公式ドキュメント（worktree・サブエージェントの作業ディレクトリ）、`.claude/hooks/12-SubagentStart/subagent-start-check.sh`、`.claude/agents/task-executor.md`、`.claude/skills/00-workflow-issue-mr-driven/SKILL.md` の起動手順と `assets/subagent-prompt.template.md`、`logs/hooks/decisions.jsonl` に残る `cwd` の実値 | 公式ドキュメントを WebFetch で読み、Agent ツールが作業ディレクトリ／worktree を指定できるかを**引用（URL と該当行）付き**で確定する。取得できないときは「不明」と明記して実測手順に落とす。`decisions.jsonl` の過去のレコードからサブエージェント実行時の `cwd` の実値を拾い、呼び出し元と一致していたかを見る | **要**（`allow.ops` に `web` を含める） |
| D | `git worktree` の同一ブランチ制約に関する公式ドキュメント、`.claude/skills/20-common-step-ticket/scripts/ticket.sh`（採番・ファイル移動・状態遷移コミット）、`commit.sh` / `push.sh` の push 前チェック 4 項目、`.claude/skills/00-workflow-issue-mr-driven/SKILL.md` の切れ目、`boundary.sh`、`wip/10_tickets/` と `wip/30_reports/` の運用（過去 issue の git ログ） | 選択肢（detached HEAD / サブブランチ + 合流 / `--force`）ごとに表を作り、成立可否・合流手順・衝突の種類を書く。衝突の件数は `git log --diff-filter=R --name-status -- wip/10_tickets/` などで**過去 issue の実データ**から見積もる（1 チケットあたりの rename 件数・同一ファイルへの追記回数）。DDR `i0001-23` の却下理由の各文に対して「今も成り立つ / 成り立たない」を根拠付きで判定する | 要（git 公式の worktree 制約のみ。`allow.ops` に `web` を含める） |
| E | `.claude/hooks/lib/scope.sh`（`scope_classify` / `_SC_GIT_READ_SUBCMDS` / `_SC_READ_ONLY_CMDS`）、`.claude/hooks/20-PreToolUse/block-direct-git.sh`、`.claude/hooks/20-PreToolUse/workflow-guard.sh`（WF204 / WF205）、`.claude/hooks/config/scope-limits.json`、`.claude/hooks/lib/tests/test_scope.sh`、`.claude/docs/10_spec/` の該当仕様 | `git help -a` などで得た git サブコマンド一覧を `_SC_GIT_READ_SUBCMDS` と突き合わせ、`unknown` に落ちるものを全件列挙する。`cd` のように `_SC_READ_ONLY_CMDS` に無い基本コマンドも同様に洗う。塞ぎ方は **最低 2 案**（既存分類への追加 / 新分類の導入）を挙げ、案ごとに `block-direct-git.sh` との関係・影響するテスト ID・拒否が緩む範囲を書く | 不要 |
| F | `wip/tmp/worktree-probe/` 配下の実測結果、`wip/30_reports/0004-investigation.md` の A〜D の予測 | 予測と実測を 1 対 1 で並べ、「一致 / 不一致（実測が正） / 未取得」の 3 値で判定する。不一致は原因の候補まで書く。未取得は理由と再実行手順を残課題へ | 不要 |

## 方法とステップ

読み取りで答えが出る観点を先に片付け、実測は 1 回にまとめる。実測の実行が人間側に依存するため、**実測を待つ箇所を 1 か所（S6 の直前）に集める**のが順序の理由である。

| # | ステップ | チケット | 先行 |
|---|---|---|---|
| S1 | 観点 A: フック側の作業ツリー解決を全参照で確かめ、残余を実測手順にする | 0004 | — |
| S2 | 観点 B: 提供コマンドと `logs/` 状態ファイルの worktree 分離を確かめ、残余を実測手順にする | 0005 | 0004 |
| S3 | 観点 C: サブエージェントを別 worktree で動かせるかを外部仕様と実装から確定する | 0006 | — |
| S4 | 観点 D: ブランチ構成の選択肢と合流コストを、過去 issue の実データで見積もる | 0007 | 0004, 0005 |
| S5 | 観点 E: `scope.sh` の git 分類の穴を全件洗い、塞ぎ方の案を 2 つ以上出す | 0008 | — |
| — | （切れ目）呼び出し元が 0004〜0007 の実測手順をまとめてユーザーに渡し、実行結果を `wip/tmp/worktree-probe/` に受け取る | — | 0008 |
| S6 | 観点 F: 実測結果を予測と突き合わせ、A1 の「動かない箇所」一覧と保留 P1 の判断材料を確定する | 0009 | 0004〜0008 |
| S7 | 次フェーズ（AI アセット設計）の計画 | 0010 | 0004〜0009 |

### 許可範囲（やってよいこと）

| ステップ | write | ops |
|---|---|---|
| S1 / S2 / S6（0004・0005・0009） | `wip/**` | `read`, `remote-read` |
| S3 / S4（0006・0007） | `wip/**` | `read`, `remote-read`, `web`（外部技術調査） |
| S5（0008） | `wip/**` | `read`, `remote-read` |
| S7（0010） | `wip/**` | `read`, `remote-read` |

## 検証

全ステップが終わった時点で、次がすべて成り立つことをもって「調査フェーズができた」とする。

| 検証 | 方法 | 期待値 |
|---|---|---|
| 観点が判断点と受け入れ条件を網羅している | 本計画書「調査観点」表の「効く先」列を読む | A1・A4・A5・A6・保留 P1・保留 P3 がすべて 1 回以上現れる |
| 調査チケットが観点と 1 対 1 で存在する | `ls wip/10_tickets/00_todo/` | `0004`〜`0010` の 7 枚 |
| 次の計画チケットが 1 枚だけ | `grep -l "ticket_type: ai-asset-design-plan" wip/10_tickets/00_todo/*.md \| wc -l` | `1` |
| 調査結果レポートが md と HTML の対で存在する | `ls wip/30_reports/0004-investigation.*` | `.md` と `.html` の 2 件 |
| A1 の「動かない箇所」が一覧になっている | `wip/30_reports/0004-investigation.md` の観点 F の節 | 箇所ごとにファイル・行・症状・実測の出力が添えられている |
| 却下理由の再評価が済んでいる | 同レポートの観点 D の節 | DDR `i0001-23` の却下文 3 つそれぞれに「今も成り立つ / 成り立たない」と根拠がある |

## チケット

DoD は調査チケットの型（「観点への答えがレポートに書かれている」「根拠が添えられている」「答えが出なかった問いは理由付きで残課題に残っている」）に、観点固有の粒度を足して書く。実行者・レビュー要否は全体計画書の方針（差分 1・差分 3）に従う。

| 番号 | 種類 | 内容 | 先行 | 実行者 | 人間レビュー | 敵対的レビュー |
|---|---|---|---|---|---|---|
| 0004 | investigation | 観点 A: worktree 上でのフックの作業ツリー解決と、WIP・宣言範囲・差分判定の健全性 | — | opus | 不要 | 要 |
| 0005 | investigation | 観点 B: 提供コマンドと `logs/` 状態ファイルの worktree 分離 | 0004 | opus | 不要 | 要 |
| 0006 | investigation | 観点 C: サブエージェントを別 worktree で動かせるか | — | opus | 不要 | 要 |
| 0007 | investigation | 観点 D: 1 issue = 1 ブランチとの両立と、並列成果の合流コスト | 0004, 0005 | opus | 不要 | 要 |
| 0008 | investigation | 観点 E: `scope.sh` の git 分類の穴と塞ぎ方の選択肢 | — | opus | 不要 | 要 |
| 0009 | investigation | 観点 F: 実測結果と予測の突き合わせ、並列採否の判断材料の確定 | 0004, 0005, 0006, 0007, 0008 | opus | 不要 | 要 |
| 0010 | ai-asset-design-plan | 次フェーズ（AI アセット設計）の計画 | 0004〜0009 | opus | 不要 | 不要 |

- 敵対的レビューは全体計画書の差分 3 のとおり**フェーズごとに 1 回**であり、チケットごとに 1 回ではない。切れ目で `00-workflow-issue-mr-driven` が上限を管理する
- `allow.write` は全チケット `wip/**`。`allow.ops` は 0004・0005・0007・0008・0009 が `read` / `remote-read`、0006 が `read` / `remote-read` / `web`（Agent ツールの外部仕様を読むため）、0007 も `web` を含める（git の worktree 制約の公式記述を読むため）
- 全体計画書は investigation に `build-test`（既存テストの実行のみ）も許しているが、**本計画では宣言しない**。観点 A・B・E は既存テストを「読む」ことで検証済み範囲を特定でき、実行が要る確認は worktree を作る実測とひとまとまりで人間側に回るためである。実行が必要と分かったら未着手チケットの見直しで足す

## 成果物の形

成果物は `wip/30_reports/0004-investigation.md`（と同名の HTML）1 本で、観点ごとに節を足して積み上げる。「分かった」で終わらせないため、観点ごとに**必要な記載の粒度**を先に決めておく。

| 観点 | 調査結果レポートに必要な記載 |
|---|---|
| A | `HOOK_ROOT` / `HOOK_WORKTREE` の全参照一覧（ファイル:行・どちらを指すべきか・現状の判定）と件数。`test_hook_common.sh` が検証済みの範囲。実測手順（コマンド列 + 観点ごとの予測）と、実測でしか確かめられない項目の一覧 |
| B | 「提供コマンド × 依存する状態ファイル × 無いときの振る舞い」の表（5 コマンド分）。`__ss_load` の解決先が起動パス（相対 / 本流の絶対）でどう変わるかの対応表。`logs/` が無い worktree で最初に壊れるコマンドの特定。実測手順と予測 |
| C | 可否の結論と、公式ドキュメントの URL・引用・取得日。`decisions.jsonl` から拾ったサブエージェント実行時の `cwd` の実値（件数付き）。動かせない場合の代替（人間が別セッションを開く等）が成立する条件。実測手順と予測 |
| D | ブランチ構成の選択肢 3 案の比較表（成立可否・合流手順・衝突の種類）。過去 issue の実データから出した衝突件数の見積もり（1 チケットあたりの rename 件数・同一レポートへの追記回数、算出に使ったコマンドと出力）。DDR `i0001-23` の却下文 3 つそれぞれへの「今も成り立つ / 成り立たない」の判定と根拠 |
| E | `unknown` に落ちる git サブコマンドと基本コマンドの全件一覧（`cd` を含む）。塞ぎ方 2 案以上について、変更する箇所・`block-direct-git.sh` との関係・影響する既存テスト ID・拒否が緩む範囲 |
| F | 「予測 / 実測 / 判定（一致・不一致・未取得）」の 3 列表。A1 の「動かない箇所」の一覧（ファイル・行・症状・実測の出力）。保留 P1 を決めるために揃った材料と、まだ足りない材料 |

## リスクと復旧

| リスク | 兆候 | 復旧 |
|---|---|---|
| 実測結果が返らないまま 0009 に入る | `wip/tmp/worktree-probe/` が空 | 0009 は突き合わせを行わず、未取得項目を再実行手順つきで残課題に残して完了する。0010（AI アセット設計計画）は「実測なしでは保留 P1 を決められない」と明記して呼び出し元に判断を戻す |
| 実測で worktree を作った結果、本流の `logs/` や `wip/` が壊れる | `git status` に想定外の差分 | 実測手順に「worktree は `../` 配下の新規ディレクトリに作り、終わったら `git worktree remove` で片付ける」「本流の `wip/` `logs/` には触れない」を必ず含める。壊れたら着手時の `base_sha`（0003 は `8c68128`）を基準に戻す |
| 観点 C が「別 worktree で動かせない」と出て、以降の観点が空振りする | 0006 の結論が否定的 | 0007 以降は「並列を採らない場合でも A1・A2・A3 のために worktree 上の健全性は要る」ことを理由に続行する。観点 D は合流コストの見積もりを「開始時 worktree 分離（狙い B）でも同じ問題が出るか」に読み替える |

## スコープ外

- 穴の塞ぎ方・worktree 運用の既定・並列方式そのものの**決定**（AI アセット設計 0010 以降が引き取る）
- 全体計画書の保留 P2（本全体計画の実施中に見つかった機構の不具合 4 件）の調査（全体まとめで別 issue として起票する）
- 別 issue 同士の並行、1 issue = 1 ブランチ = 1 MR の原則の変更、マージ操作の自動化（いずれも issue #50 のスコープ外）

## 保留した点 / 対象なし

| # | 保留した点 | 決める時期・場所 |
|---|---|---|
| P1 | 1 issue 内の並列実施を採用するか見送るか。全体計画書の保留 P1 をそのまま引き継ぐ。現行の正史では DDR `i0001-23`「チケットの並列実施を廃止する。チケットは常に 1 枚ずつ、タスクの実行者の中で直列に実施する」が生きており、本フェーズはこれを覆す材料を集めるだけで覆さない | AI アセット設計計画（0010）。材料は 0009 の観点 F |
| P2 | `logs/` が `.gitignore`（`logs/` 行）されているため worktree 側に複製されない。worktree で進行状態をどう用意するか（本流からコピーする / worktree ごとに新規に作る / 本流の `logs/` を共有する）。現行の DDR `i0009-55` は「`logs/` と `wip/` は作業ツリー側に置く（worktree ごとに進行状態が分かれる）」と決めているが、**存在しないときの初期化については何も決めていない** | AI アセット設計。材料は 0005 の観点 B |
| P3 | `scope.sh` の git 分類の穴の塞ぎ方（どの案を採るか）。現行の `scope.sh` は `scope_classify` の git 分岐で `_SC_GIT_READ_SUBCMDS` に無いサブコマンドを `unknown` に落とし、`workflow-guard` が WF204 で既定拒否する | AI アセット設計。案は 0008 の観点 E が出す |

### 全体計画書の保留 P3 の決着

全体計画書の保留 P3「調査で必要な実測を、ユーザー実行で回すか、先に git 分類の穴を直してから回すか」は、本計画で**ユーザー実行で回す**と決めた。理由は 3 つ。

1. 穴を先に直すのはフェーズ列（調査 → AI アセット設計 → AI アセット実装）の逆行で、`scope.sh` は中核（フック共通ライブラリ）にあたるため、設計と実装計画のレビューを飛ばして触ることになる
2. 塞ぎ方そのものが設計判断であり（観点 E で 2 案以上を出す）、調査の途中で 1 案を実装で固定すると、設計フェーズの選択肢が調査の都合で狭まる
3. 実測は worktree の作成・削除を含む数コマンドで、1 回にまとめれば人間の手間は小さい。恒常的な迂回路を先に作るほどの頻度ではない

この決着により、全体計画書の保留 P3 は解消済みとして扱う（全体計画書自体は書き換えない）。
