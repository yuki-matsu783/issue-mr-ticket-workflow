---
type: report
title: 調査 A 付録 — 参考実装フック系スクリプトと新仕様の突き合わせ（生データ）
description: チケット 0003 の Q1（フック共通ライブラリ側）の調査結果の生データ。43 機能単位の流用 / 改変 / 新規判定、仕様との食い違い、新規機能一覧、Windows Git Bash の懸念。要約は 0003-investigation.md
tags: [report, investigation, issue-6, appendix]
keywords: [参考実装, hook-common, cmdpos, scope, push-detect, transcript, CommandPosition.sh, workflow-lib.sh, UsageTracking.sh, 流用, 改変, 新規, Windows, CRLF, jq]
---

# 調査A: 参考実装シェルスクリプトと新仕様の突き合わせ（流用 / 改変 / 新規）

- 調査日: 2026-09-01
- 仕様（正）: `.claude/docs/10_spec/フック共通仕様.md` §1〜§13、`.claude/docs/10_spec/hooks/20-PreToolUse/{block-direct-git,block-chmod,workflow-guard}.md`、`.claude/docs/10_spec/hooks/22-PostToolUse/{post-push-usage-report,post-push-compact-prompt}.md`、`.claude/docs/10_spec/hooks/10-UserPromptSubmit/workflow-entry.md`
- 参考実装（読み取りのみ・未変更）: `参考ディレクトリ/agent-workflow/.claude/hooks/`、`参考ディレクトリ/MR-driven-workflow/.claude/hooks/`
- 実行環境の実測: bash 5.2.12 (msys)、jq 1.6（`/c/Program Files/jq/jq` = **Windows ネイティブ版。標準出力が CRLF**）、`realpath` / `mktemp` / `date` あり

判定語の定義: **流用** = ほぼ手を入れずに移植できる / **改変** = 構造や部品は使えるが仕様差の吸収が要る / **新規** = 参考実装に対応物が無い。

---

## 1. 機能単位ごとの判定

| # | 仕様の機能単位 | 参考実装の対応箇所（ファイル:行） | 判定 | 理由（仕様との差分） |
|---|---|---|---|---|
| 1 | フック入力 JSON の読み取り（jq） | `agent-workflow/.claude/hooks/workflow-guard.sh:26-33`、`workflow-entry.sh:154-162`、`workflow-lib.sh:36-38`（`wf_jq` = `jq \| tr -d '\r'`）、`MR-driven-workflow/.claude/hooks/block-direct-git-commit.sh:96-112` | 改変 | 「RS 区切りで 1 回の jq にまとめる」「CRLF を除去する」は流用価値が高い。ただし §2 が要求するフィールドが多い（`tool_response` / `agent_id` / `agent_type` / `model` / `source` / `transcript_path` / `cwd` / `hook_event_name`）ので `hook-common.sh` の汎用リーダへ一般化が要る。決定的な差は**失敗時の向き**: 参考は読めなければ `exit 0`（通す。`block-direct-git-commit.sh:101-102, 112`）だが、新仕様の拒否側は入力不正で `deny WFx09`（§3）。fail-open → fail-closed に反転させる |
| 2 | deny の出力形式 | `workflow-guard.sh:35-41`（`exit 2` + stderr）、`agent-workflow/.claude/hooks/block-chmod.sh:17-18`（deny JSON + `exit 2`）、`block-direct-git-commit.sh:138-141`（stderr + `exit 2`） | 改変 | §3 は「stdout に `hookSpecificOutput.permissionDecision=deny` + `permissionDecisionReason` を出して**終了 0**」。参考は 3 本とも `exit 2` + stderr が主で、`block-chmod.sh:17` は JSON を出すが `permissionDecisionReason` が無く `exit 2` と併用しており作法が混在している。文面規約（先頭に識別子・日本語・「何が起きたか/対処」・コマンド引用は 80 文字・`redact` 通し）も無い |
| 3 | ask の出力形式 | `workflow-guard.sh:44-53` | 流用 | `jq -n --arg r '{hookSpecificOutput:{... permissionDecision:"ask", permissionDecisionReason:$r}}'` は仕様どおり。追加するのは §10 のヘッドレス時の `deny`（WF213）置換だけ |
| 4 | additionalContext の出力（3 イベント） | `workflow-entry.sh:197-198`（UserPromptSubmit）、`workflow-diff-check.sh:119-120`（PostToolUse）、`MR.../session-start.sh:66-70`（SessionStart） | 流用（SessionStart のみ改変） | UserPromptSubmit / PostToolUse はそのまま。SessionStart は §3 が「stdout のテキストをそのまま」としているので、`session-start.sh:66-70` の JSON 包みは外す（どちらでも通るかは実装時に要検証 — **推測**） |
| 5 | 緊急停止変数 | `workflow-entry.sh:52-53`（`WORKFLOW_ENFORCE` / `WORKFLOW_ENTRY_ENFORCE`）、`workflow-lib.sh:181`（`WORKFLOW_ENFORCE` のみ） | 改変 | 2 段構え（全体 + フック単位）の考え方は §4 と同じ。差分は 3 点: (a) MR-driven 側 6 本は緊急停止を一切持たない、(b) 停止時に `decisions.jsonl` へ `{"decision":"disabled"}` を残す要求が無く単に `exit 0`、(c) `WORKFLOW_<NAME>_ENFORCE` をフック名から機械的に導く共通関数が無く entry にハードコード。`hook-common.sh` に `enforce_enabled <name>` として一般化する |
| 6 | 実行ログ（`logs/sh/<name>.log`） | `workflow-lib.sh:40-43`（`wf_log`）、`workflow-entry.sh:61-63` | 改変 | 「失敗しても本体を止めない（`\|\| true`）」「1 行 = タイムスタンプ + メッセージ」は流用。出力先が `.claude/hooks/workflow.log` 固定で、§5 の `logs/sh/hook-<name>.log`・共通 logger（`20-common-step-shell-script/scripts/logger.sh`、`LOGGER_NAME=hook-<name>`）を使う要求と合わない。`date` を毎回 fork する点も要検討（4 章 D） |
| 7 | 判定の記録（`logs/hooks/decisions.jsonl`） | 直接の対応物なし。JSONL 追記の唯一の例が `MR.../lib/UsageTracking.sh:403-430`（`_usage_append_push_index`） | 新規 | §5 のスキーマ（`ts/session_id/hook/event/decision/id/tool/target/ticket/note`）も `allow\|ask\|deny\|notify\|inject\|disabled\|skip` の 7 値も参考に無い。`jq -c -n` で 1 行組み立てて `>>` する形（`UsageTracking.sh:421-429`）だけ流用できる |
| 8 | コマンド分割（`;` `&&` `\|\|` `\|` のセグメント化、サブシェル、クォート、ヒアドキュメント、コメント） | `MR.../lib/CommandPosition.sh:106-357`（正規化本体）、`358-390`（`$((...))` の読み飛ばし）、`392-470`（ヒアドキュメント区切り語の解決）、`471-566`（トークン走査） | 流用 | §7-1・§7-2 が要求する前処理（シングル / ダブルクォート、`#` コメントの語頭判定 `CommandPosition.sh:115-129`、ヒアドキュメント `<<` `<<-` `<<'TAG'`、ダブルクォート内の `$( )` / `` ` `` はコードとして残す、行継続の結合 `:130-153`）がすべて実装済み。「外部プロセスを一切呼ばない純粋関数」という制約も §7 と一致。**このリポジトリで最も流用価値が高い資産** |
| 9 | cmdpos の出力形式（segment ごとの `exe` / `args[]` / `redirects[]` / `write_targets[]` / `opaque`） | `CommandPosition.sh:584-626`（`command_invokes_git_subcommand <cmd> <sub>`）、`816-842`（`command_invokes_script <cmd> <basename>`） | 改変（API の作り直し） | 参考の公開 API は**真偽値の述語 2 本**で、セグメントの列を返さない。走査本体（`471-566`）は「探す語を引数で受けて見つけたら return」構造。§7 は「呼び出し側はこの出力だけを見て判定し、コマンド文字列を再パースしない（規則の複製禁止）」を明記しているので、正規化部（`106-470`）は無改造で流用し、走査部を「セグメント境界ごとに `exe` / `args[]` / `redirects[]` / `write_targets[]` / `opaque` を積んで返す」形へ書き直す必要がある |
| 10 | 実行位置の git 判定（サブコマンド、グローバルオプション飛ばし、パス付き / `.exe`、透過ラッパー） | `CommandPosition.sh:498-534`（basename + `.exe` 除去 `:500-502`、git グローバルオプションの 2 トークン飛ばし `:517-533`、`_CP_PREFIX_WORDS` の sticky `:537-539`）、定数 `:52`（透過ラッパー語彙）、`:69`（`-c` `--git-dir` 等） | 流用 | §7-3・§7-4 とほぼ 1:1。`_CP_PREFIX_WORDS`（`if then elif else do while until ! time sudo doas env command builtin exec nohup nice ionice setsid stdbuf timeout`）は仕様の列挙を包含する。`-C` は小文字化により `-c` と同じ扱いになり値を 1 つ飛ばす（`:65-68` のコメント）ので `git -C . commit` も取れる（BG-T01 相当） |
| 10b | コミットを生成する他のサブコマンド（`revert` / `cherry-pick` / `am` / `rebase` / `commit-tree`）の拒否 | 対応物なし（`block-direct-git.md:40` が要求） | 新規 | 参考は 1 呼び出し 1 サブコマンドの述語。セグメント列 API に変えたうえで、呼び出し側（block-direct-git）が第 1 サブコマンドを集合と照合するループを書く |
| 11 | opaque な実行系 | `CommandPosition.sh:55-63`（`_CP_OPAQUE_WORDS` / `_CP_OPAQUE_WITH_OPT` / `_CP_CODE_OPTS`）、`541-556`、`618-625`（部分一致フォールバック） | 改変 | 語彙は §7-5 の列挙（`eval` `bash -c` `sh -c` `zsh -c` `xargs` `find ... -exec` `powershell -Command` `pwsh` `node -e` `python -c` `perl -e` `ruby -e`）を包含している。ただし参考は「opaque を見つけたら lib の内部で部分一致へ落として真偽を返す」設計で、§7-5 は「そのセグメントを `opaque` として返し、**呼び出し側**が対象語の有無で拒否側に倒す」。責務の置き場所が違うので出力側の改変が要る |
| 12 | リダイレクトと書き込み先の抽出 | `CommandPosition.sh:507-513` / `671-676`（コマンド前のリダイレクトを**読み飛ばすだけ**）、`workflow-guard.sh:201-207`（`>` を含むかの文字列判定で一律 deny） | 新規 | §7 の `redirects[]`（`>` `>>` `2>` `&>` `<>` の宛先パス）も `write_targets[]`（`cp` `mv` `tee` `touch` `mkdir` `rm` `truncate` `sed -i` `install` `ln`）も参考に存在しない。`workflow-guard.sh:201` の `[[ "${sanitized}" == *">"* ]]` は宛先を取らないため、workflow-guard.md 制御方式 6 の「対象が `wip/tmp/**` または `logs/**` なら許可」が実装できない |
| 13 | PowerShell コマンドの扱い | `CommandPosition.sh:60`（`pwsh` / `powershell` を opaque 語彙に含めるだけ）、`806-813`（PowerShell のバックスラッシュ区切りパスは検知できないと**既知の制約として明記**）、`block-direct-git-commit.sh:106-108` / `block-unchecked-push.sh:110-113`（`tool_name` で受けるが bash と同じ正規化を通す） | 新規 | §7-6 が求める PowerShell 専用前処理（`;` と改行で分割、呼び出し演算子 `&` / `.` を剥がす、ヒアストリング `@'`〜`'@` / `@"`〜`"@` の除去、バッククォート行継続の結合、サブコマンド不特定なら拒否側）は 1 つも無い。**むしろ危険側の挙動がある**: `.\git.exe commit` は正規化 `:130-153` の `\g` エスケープ解決で `.git.exe` になり、basename が `.git` となって `git` と一致せず**検知漏れする**（BG-T08 が落ちる）。ヒアストリング `@'…'@` も未対応で、開始の `'` から sq 状態へ入るため BG-T09b の判定が不安定 |
| 14 | glob マッチ（allow / deny / protected / confirm） | `workflow-lib.sh:69-80`（`wf_match`。`**` を `*` に読み替えて `case` でマッチ）、`workflow-lib.sh:56-66`（`wf_to_rel`。`\`→`/`、ドライブレター大小無視） | 改変 | 純 bash・fork 無しの `case` マッチは流用したい。ただし `**` → `*` の読み替えは bash の `case` glob が `*` で `/` を跨ぐため過剰一致になる（`.claude/*` が `.claude/hooks/config/x` に一致する）。§8 は「パターンは glob（`**` 対応）」としか書いておらず `*` と `**` の区別を明示していない（→ 2 章 B）。`wf_to_rel` の Windows パス正規化は流用価値が高い |
| 15 | 判定順 (1)〜(7) | `workflow-lib.sh:117-130`（`wf_resolve`。8 段）、`workflow-types.json:2`（判定順のコメント） | 改変 | 「表引きを 1 関数に閉じ込め、結果を `WF_DECISION` / `WF_SOURCE` で返す」構造はそのまま `scope.sh` に使える。段の中身は別物: 参考は `type.deny → type.ask → type.allow → global.deny → global.ask → ticket.allowed_paths → global.allow → session`。§8 との決定的差は (a) `logs/**` を対象外にする段が無い、(b) 参考は `type.allow` が `global.deny` より**先**に効く（type が保護パスを無条件に上書き）が §8 (2) は「`common.protected` に一致し、かつ `types[t].allow` に**明示されていない**とき deny」という条件付き、(c) チケットの宣言の意味が逆（→ 2 章 A） |
| 16 | approvals.json（承認の記憶） | `workflow-lib.sh:85-113`（記憶単位 `file:` / `dir:`、`<session_id>.approved` に行テキストで追記）、`workflow-diff-check.sh:46-54`（PostToolUse で `unlisted` だけ記憶） | 改変 | 「PreToolUse は読むだけ / PostToolUse が書く」「未記載だけ記憶し毎回確認（ask_paths）は記憶しない」「単位は親ディレクトリ、`file_level` のみファイル単位」という設計が §5・workflow-guard.md 制御方式・§8 (6)(7) とそのまま一致する。変更は保存形式（行テキスト → `[{"scope","ticket","at"}]` の JSON）と置き場（`.claude/hooks/.state/` → `logs/sessions/<session_id>/approvals.json`）だけ |
| 17 | セッション状態の分離（`session_id`） | `workflow-entry.sh:160-162`（`tr -cd 'A-Za-z0-9_-'` でサニタイズしてファイル名に）、`workflow-lib.sh:94-97` | 流用 | HK-T07（`session_id` ごとの分離）とパストラバーサル対策の両方に効く。置き場を `logs/sessions/<session_id>/` へ移すだけ |
| 18 | 宣言状態（`entry.json`） | `workflow-entry.sh:123-139`（読み）、`141-147`（tmp → `mv -f` の原子的置換）、`149-151`（`declared_seq == prompt_seq` で宣言済み） | 改変 | 「プロンプト連番で宣言を失効させる」中核ロジックはそのまま使える。形式が `key=value` → JSON（`{"prompt_seq","declared_skill","declared_at","continuation"}`）に変わり、`continuation` の値（`tickets` / `review` / `merge_prep` / `null`）を持つ必要がある。破損時に初期化して未宣言扱いにする `:137-138` は WF102 と同義で流用可 |
| 19 | 振り分けの継続条件 | `workflow-entry.sh:82-90`（todo / doing に `*.md`）、`94-107`（20_done の最終チケット）、`111-120`（`review-state.json` が `requested`） | 改変 | 新仕様（workflow-entry.md 制御方式 2）は継続条件を 3 系統に拡張: (a) todo / doing / **20_done** のいずれかにチケット、(b) `logs/review-state.json` が `requested`、(c) `logs/merge-state.json` が `started`/`cleaned`/`pushed` のとき **`finalize.sh` / `boundary.sh status` の実行だけ**を許す。参考の (b) は「done の最終チケットと一致」まで見ているが新仕様は state だけ。置き場も `wip/10_tickets/review-state.json` → `logs/review-state.json` |
| 20 | スラッシュ起動を宣言として扱う | `workflow-entry.sh:174-183` | 流用 | workflow-entry.md 呼出条件（UserPromptSubmit の行）・WE-T04 が同じ振る舞いを要求している。スキル名を `00-workflow-*` の新名称に替えるだけ |
| 21 | Skill 宣言の記録 | `workflow-entry.sh:203-211`（`record` モード）、`agent-workflow/.claude/settings.json`（PostToolUse matcher `Skill`） | 改変 | 新仕様 §1 の表は **PreToolUse(Skill)** で記録する（順 1）。読み取るフィールド（`tool_input.skill`）は同じだが、登録イベントと「まだ実行前に宣言とみなす」意味が変わる |
| 22 | WIP 1 枚制限 | `workflow-lib.sh:184-197`（`nullglob` で `*.md` を数える。元の設定を保存して戻す `:185-189`）、`workflow-guard.sh:61-67` | 改変 | 数え方は流用。新仕様 WF207 は「提供コマンド（`ticket.sh` 等）以外の書き込み・実行を deny」という例外を持つが、参考は無条件 block |
| 23 | チケット frontmatter の読み取り | `workflow-lib.sh:46-48`（`wf_extract_type`）、`51-53`（`wf_fm_get`。`sed -n '2,/^---/{s/^key:[[:space:]]*//p}'`）、`229-238`（`allowed_paths` の `["a","b"]` を sed + `IFS=,` で分解） | 改変 | `ticket_type` / `executor` / `predecessors` のような**フラットな 1 行キー**には使える。しかし §9 の `allow: {write: [...], ops: [...]}` と `human_review: {required:..., reason:...}` は**ネストしたマッピング**で、この 1 行 sed では読めない。ネスト対応の frontmatter パーサ（または限定的な YAML→JSON 変換）が新規に要る |
| 24 | チケット自身の改変拒否（WF208） | `workflow-guard.sh:273-319`（`check_ticket_edit`。Edit の `old_string`/`new_string` を bash 置換で当てて編集後の内容をシミュレートし、frontmatter を再パースして比較。CRLF 正規化 `:290`、`replace_all` 対応 `:299-305`） | 改変 | シミュレーション方式が workflow-guard.md 制御方式 5 の「Edit の `old_string` / `new_string` または Write の内容と現在値の差で判定」とそのまま合致する。監視対象を `type` 1 つから `ticket_type` / `allow` / `executor` / `human_review` / `predecessors` の 5 項目へ広げるだけ |
| 25 | 差分検査（PostToolUse） | `workflow-diff-check.sh:57-87`（`git status --porcelain --untracked-files=all` + `core.quotepath=false`、リネーム `R old -> new` の宛先採用 `:62`、引用符除去 `:63-65`、無視リスト `:67-72`、`wf_resolve` で `deny`/`unlisted` を違反に） | 改変 | 骨格はそのまま使える。新仕様（workflow-diff-check.md 入出力）は基準点が**チケット frontmatter の `base_sha`**（参考は `git log -1 --grep='chore(ticket): start'` `:81`）で、`--porcelain=v2 -z` を 1 回 + `git diff --name-status <base_sha>` を併用する |
| 26 | 先行チケット未完了の警告 | `workflow-diff-check.sh:100-115` | 流用 | キー名が `depends_on` → `predecessors`、識別子が WF005 → WF602 に変わるだけ |
| 27 | push 検知（Bash の `git push` 側） | `MR.../post-push-usage-report.sh:360-378`（`raw_hints_at_git_push`。生 JSON から JSON エスケープ 2 文字列を除去してから大小無視の部分一致。**fork ゼロの前置フィルタ**）、`:428-438`（`command_invokes_git_subcommand ... push`）、`block-unchecked-push.sh:71-86`（縮退時の「`git` トークン AND `push` トークン」） | 改変 | 前置フィルタ（`:360-378`）は post-push-compact-prompt.md 呼出条件の「前置判定で push でなければ即抜ける」にそのまま使える優れた部品で、`\\` を先に処理する順序（`:363-371`）まで含めて流用したい。`block-unchecked-push.sh:71-86` は仕様 §7-7 の縮退判定（`git` と `push` が共に含まれれば拒否）とほぼ同義。ただし新仕様は提供コマンド `push.sh` の実行も検知対象（push-detect 1）なので、`command_invokes_script` 側（`:816-842`）と併用する形へ改変が要る |
| 28 | push 検知（PostToolUse の `tool_response` による成功判定） | 対応物なし（参考は 3 本とも**コマンド文字列だけ**で「push した」と判断する） | 新規 | post-push-compact-prompt.md「push 検知 2」の 3 条件 AND（`tool_response` の終了コード 0 / `git rev-parse HEAD` == `git rev-parse @{upstream}` / `push-state.json[b].sha != HEAD`）は完全に新規。参考は失敗した push でもレポートを作ってしまう |
| 29 | transcript からの発話抽出（`UserUtteranceSelect.jq`） | `MR.../lib/UserUtteranceSelect.jq:1-170`（母集団条件 `:53-70`、ブランチ絞り `:102-110`、uuid 重複除去 `:112-115`、相槌辞書・スラッシュ・タグ除外 `:118-136`、head/tail 採取 `:137-147`、UTF-8 バイト予算 `:148-162`） | 新規（仕様に対応要件が無い） | 新仕様の `session-start.md` に「直近のユーザー発言の再注入」に相当する記述が無い（`発言` / `transcript` / `utterance` のいずれも grep でヒットしない）。使うなら**仕様追加が先**。ただし `lib/transcript.sh` を書くうえで transcript 形式の一次情報として価値が高い（特に `:59-61` の「`isSidechain` は bool なので `// null` を使うと false が null に化ける」という実地の落とし穴） |
| 30 | transcript からの使用量集計（`lib/transcript.sh`） | `MR.../lib/UsageTracking.sh:202-259`（`_usage_aggregate_new_lines`。カーソル `offset` 以降の新規行だけを **1 回の jq** で集計。トークン 4 種 `:222-226`、`tool_use` 数 `:228-230`、assistant ターン数 `:219`）、`:431-456`（カーソル読み書き）、`:108-169`（`_usage_aggregate_transcript`。`activeSeconds` と自前 ISO8601→epoch `:115-131`）、`:275-354`（`_usage_merge_state`） | 改変 | post-push-usage-report.md `--accumulate` 2〜4 が求める 4 指標と `last_offset` による二重計上防止（UR-T02）がほぼ同型で、**流用価値が 2 番目に高い**。改変点: (a) 「解析は `lib/transcript.sh` の 1 関数」（禁止事項）に合わせて 2 本立て（activeSeconds 専用の全件再パース + 差分集計）を 1 本に寄せる、(b) 実作業時間の定義が違う（参考は「閾値未満の gap を加算し、閾値以上なら tail buffer」`:151-166`。新仕様は「ユーザー入力待ち（user メッセージ直前の間隔）と 10 分超を除く」）、(c) `jq -R -n ... "$path"` でファイルパスを渡す設計（`:177-189` のコメント。引数に中身を載せると Windows のコマンドライン長上限 32KB で `jq` が起動失敗する実例）は**必ず踏襲する** |
| 31 | usage レポート本文の整形 | `MR.../post-push-usage-report.sh:39-42`（`fmt_num`。sed のラベルループで 3 桁区切り）、`:44-55`（`fmt_duration`。「H 時間 M 分」）、`:71-344`（`build_usage_report_body`） | 改変 | `fmt_num` / `fmt_duration` は UR-T01（桁区切り・「H 時間 M 分」）にそのまま使える。本文の項目は仕様（既定 3 のテンプレート: 集計期間・`since_sha`・ブランチ・`count`・4 指標・サブエージェント・注記・署名 1 行）と全く違うので中身は書き直し。Gemini / OpenTelemetry 分岐（`:102-159` ほか）は不要 |
| 32 | usage の投稿とリセット | `MR.../post-push-usage-report.sh:543-546`（CLI 不在ならスキップ）、`:548-574`（`add_mr_comment` で投稿）、`:576-589`（成功時 `_usage_reset_since_last_push`） | 新規（というより**流用禁止**） | 新仕様はフックが**投稿しない**（禁止事項「投稿の実行（提供コマンドの責務）」）・**リセットもしない**（既定 5。`posted` と `since_sha` は `boundary.sh` が書く）。この 47 行は捨てる。代わりに `logs/usage/report-<branch>-<count>.md` への書き出しと WF911 の additionalContext が要る |
| 33 | サブエージェント分の蓄積 | `MR.../lib/UsageTracking.sh:457-492`（`agentId` 単位スナップショット）、`:493-545`（サブエージェントログを探して集計）、`post-push-usage-report.sh:405-409`（`agent_id` があれば何もしないガード） | 改変 | データ構造（`subagents[agent_id]`）は §5 の `logs/usage/<branch>.json` と同型で流用できる。新仕様は SubagentStop で `--accumulate` を明示的に呼ぶ（呼出条件）ため「フックが自分でサブエージェントログを探す」`:493-545` は不要になり単純化する。逆に `:405-409` のガードは新設計と**矛盾する**ので落とす |
| 34 | `redact`（機密情報のマスク） | 対応物なし。むしろ `workflow-guard.sh:39` / `:56` はコマンドを 120 文字で切って**生のまま**ログへ書く | 新規 | §3 の 6 パターン（`ghp_`/`gho_`/`github_pat_`/`glpat-`、`Bearer <語>`、`token=`/`password=`/`secret=`/`api[_-]?key=`、`AKIA` + 20 文字、40 文字以上の hex/base64 様）と HK-T10（日本語・通常パスを壊さない）はすべて新規実装 |
| 35 | fail-closed ラッパ / `trap ERR` | 対応物なし。**逆向きの実装**が多数: `block-direct-git-commit.sh:101-102, 112`、`block-unchecked-push.sh:100-101, 117, 150, 158-163`、`post-push-usage-report.sh:596`（`( main ) \|\| true; exit 0`） | 新規 | §1 の登録ラッパー（`bash ... \|\| printf '{... deny WFx09 ...}'`）も §3 の `trap ERR` も参考に無い。参考の「bash のバージョン・`source` の成否・関数の存在を確かめてから使う」（`block-direct-git-commit.sh:128-130`）という縮退の作法自体は流用できるが、**縮退先が「部分一致で判定を続ける」であり、新仕様の「判定できなければ deny」とは方向が違う** |
| 36 | 縮退（`degraded`） | `CommandPosition.sh:568-582`（1 行 8192 文字超で正規化を諦める）、`:584-626`（部分一致へ落とす）、`block-unchecked-push.sh:71-86` | 改変 | §7-7 は「bash 4.3 未満、または 1 コマンドが **4096 文字**超で `degraded` を返し、**呼び出し側**が部分一致で判定して『縮退した判定』をメッセージに含める」。参考は閾値 8192・**行**単位、かつ縮退を lib の内部で吸収して呼び出し側に伝えない。閾値と「`degraded` を返す」形への変更が要る |
| 37 | 提供コマンドの識別（§7-8） | `CommandPosition.sh:816-842`（`command_invokes_script`）、`628-814`（走査。インタプリタ経由の直後トークン判定 `:684-740`、透過ラッパーの 1 回だけ判定 `:742-788`）、`workflow-guard.sh:141`（`TEST_RE`） | 改変 | 「`bash <path>` の直後トークンの basename を見る」構造は §7-8 の要求に近い。差分は (a) 参考は **basename 一致のみでパスを見ない**ので `/tmp/commit.sh` も提供コマンドになる、(b) 既知の制約（`:806-813`）でクォート付きパス（`bash "$DIR/commit.sh"`）は検知できず opaque 扱いになる。§7-8 は提供コマンドを「判定の対象外にする」＝**許可側**に倒す用途なので、(a) の緩さと (b) の検知漏れはいずれも危険側に働く（→ 2 章 E） |
| 38 | 禁止コマンド一覧（`blocked-commands.txt`） | `agent-workflow/.claude/hooks/block-chmod.sh:10-13`（コード内の正規表現配列） | 新規 | block-chmod.md の禁止事項が「一覧をコードに埋めること」を明示的に禁じており、参考は真逆。制御方式 2 の高速前置判定も無い。判定も `grep -Eq` の部分一致なので `echo "chmod"` を誤検知する（BC-T02 が落ちる） |
| 39 | コマンドの分類（`READ_ONLY_CMDS` / `build-test` / `hook-test` / `remote-read` / `remote-write:<種別>` / `merge-base`） | `workflow-guard.sh:134`（`READONLY_RE`）、`:136`（`TICKETOP_RE`）、`:138`（`BUILD_RE`）、`:141`（`TEST_RE`）、`:194-268`（`check_bash`。deny-by-default の allowlist） | 改変 | 「既定拒否 + allowlist、セグメントごとに判定」という骨格（workflow-guard.md 制御方式 6）は同じ。差分は (a) `remote-read` / `remote-write:<種別>` / `merge-base` の分類が無い（`gh` / `glab` を一切扱わない）、(b) 分類が正規表現ハードコードで、§8 が求める `scope-limits.json` の `commands.build-test` / チケットの `allow.ops` との突き合わせが無い、(c) セグメント分割が `sed -E 's/\|\|&&\|;\|\|/\n/g'`（`:257`）という素朴な置換で `cmdpos.sh` を使っていない |
| 40 | プランモード | `workflow-guard.sh:332-337`（チケット作業中は一律 block） | 改変 | 新仕様は `types[t].plan_mode` が true なら許可し、false のときだけ WF212。分岐 1 か所の追加で済む |
| 41 | ヘッドレス判定（§10） | 対応物なし | 新規 | `WORKFLOW_HEADLESS` / `CI` による `ask` → `deny` 置換（HK-T08、WF213）は全部新規 |
| 42 | `settings.json` への登録 | `agent-workflow/.claude/settings.json`（6 登録）、`MR-driven-workflow/.claude/settings.json`（4 グループ） | 改変 | §1 の表は 14 登録・8 イベント（SessionStart / UserPromptSubmit / PreToolUse / PostToolUse / SubagentStart / SubagentStop / Stop）。参考には `PowerShell` matcher が無いもの（agent-workflow 側）、`Stop` / `SubagentStop` / `SubagentStart` 登録が無いもの、fail-closed ラッパが無いものがある。HK-T01（表と `settings.json` の行単位照合）に相当するテストも無い |
| 43 | 上限設定ファイル | `agent-workflow/.claude/hooks/workflow-types.json:1-116`（`global.{allow,deny,ask}_paths` / `session_memory.file_level` / `types.<type>.{allow,deny,ask}_paths, bash_groups`） | 改変 | 「type ごとのパス集合を外部 JSON に置き、フックはコードに埋めない」という設計は §8 と同じ。キー名と構造が全部違う（`common.{allow,protected,confirm,file_granular,state_files}` / `types.<t>.{allow,deny,confirm,ops,plan_mode}` / `commands.build-test`）。`bash_groups`（build / test の 2 値）→ `ops`（6 分類・必須）への拡張が最大の差。`wf_load_config`（`workflow-lib.sh:145-161`）の「jq 1 回で全部読み、RS/US 区切りの 1 行に畳んで配列へ分解する」という**プロセス起動を 1 回に抑えるパターン**は流用価値が高い |

---

## 2. 流用時に仕様と食い違う点（見立て付き）

### A. チケットの宣言の意味が逆（参考: 上限を広げる / 仕様: 上限を絞る）

- 参考: `workflow-lib.sh:117-130` の判定順 6 段目で `ticket.allowed_paths` が **追加の allow** として働く（`workflow-lib.sh:17-18` のコメント「チケット frontmatter の allowed_paths → allow（deny / ask には勝てない）」）。つまりチケットに書けば `global.allow_paths` に無いパスも書けるようになる。
- 仕様: §8 (5) の `A` = `common.allow ∪ (d.write ∩ types[t].allow)`、かつ「宣言は上限の内側で**絞る**役で、`d.write` の上限外の要素は無視する」。workflow-guard.md 禁止事項にも「宣言による上限の拡大」が明記されている。
- **見立て: 実装で吸収（仕様が正）。** `wf_resolve` を移植するときにこの 1 段の意味を反転させる。ここを見落とすと要件そのものを裏切るので、`scope.sh` のテストで最優先に固定する。

### B. glob の `*` / `**` の意味が仕様で未定義

- 参考の `wf_match`（`workflow-lib.sh:69-80`）は `**` を `*` に読み替えて bash の `case` に渡す。bash の `case` glob では `*` が `/` を跨ぐため、`.claude/*` が `.claude/hooks/config/scope-limits.json` にも一致する。
- 仕様 §8 は「パターンは glob（`**` 対応）、リポジトリルート相対」としか書いておらず、`*` が `/` を跨ぐかを定めていない。ところが初期値の表には `src/**` と `package.json` のような**ファイル単位**の指定が混在し、`common.confirm` の `.claude/hooks/config/**` と `types[t].allow` の `.claude/settings.json` の優先関係が glob の解釈に依存する。
- **見立て: 仕様を直す。** §8 に 1 文（「`*` は `/` を跨がない。`/` を跨ぐ一致は `**` で書く」）を足し、`scope.sh` はその意味で実装する。参考の 1 行読み替えはそのままでは使えない。

### C. push 成功判定の `@{upstream}` が初回 push で解決できない

- 仕様 post-push-compact-prompt.md「push 検知 2」は `git rev-parse HEAD` と `git rev-parse @{upstream}` の一致を条件にする。しかし feature ブランチの**初回 push**（`git push -u origin <b>` に相当。この機構では `push.sh` 経由）では、push 実行前に upstream が無く、PostToolUse の時点で解決できるかは `push.sh` の実装依存になる。解決できなければ 3 条件 AND が偽になり、初回 push でレポートも `/compact` 案内も出ない。
- 参考は `tool_response` を一切見ないのでこの問題を踏んでいない（＝参考から学べない）。
- **見立て: 仕様を補う。** 「`@{upstream}` が解決できないときは `origin/<branch>` を見る。それも無ければ `tool_response` の終了コード 0 と `push-state.json` に記録が無いこと（初回）で真とする」を §push 検知 2 に追記する。

### D. `redact` を通す前にログへ書く経路が参考には常にある

- `workflow-guard.sh:39` / `:56` は `cmd=${COMMAND:0:120}` を生のままログへ書く。§3 は「記録・拒否理由・通知に含めるコマンド文字列・パス・本文は、出力前に `redact` を通す」。
- **見立て: 実装で吸収。** ログ出力ヘルパ（`hook-common.sh` の `log_decision` / `deny` / `ask` / `notify`）の**内側**で `redact` を呼び、素の `wf_log "...cmd=$COMMAND"` という書き方を残さない。参考のログ行をそのまま移植すると HK-T06 / HK-T10 が落ちる。

### E. 提供コマンドの識別漏れが「許可側」に倒れる

- §7-8 は提供コマンドを「判定の対象外」とする＝**通す**方向に働く。参考の `command_invokes_script`（`:816-842`）は (a) basename 一致だけでパス（`.claude/skills/*/scripts/` 配下か）を見ず、(b) クォート付きパスを検知できない（`:806-813` の既知の制約）。
- (a) は「`/tmp/commit.sh` を作れば判定を回避できる」という穴になり、(b) は「本物の提供コマンドが opaque 扱いされて deny される」という誤検知になる。方向が逆の 2 つの問題が同居している。
- **見立て: 仕様を補ったうえで実装で吸収。** §7-8 に「第 1 引数のパスが `.claude/skills/*/scripts/*.sh` または `.claude/hooks/**/*.sh` に**リポジトリルート相対で**一致すること。パスが確定できない（クォート・変数展開）セグメントは提供コマンドとして扱わず通常判定にかける」を明記する。

### F. deny の伝え方（`exit 2` + stderr と permissionDecision JSON）

- 参考 4 本（`workflow-guard.sh` / `workflow-entry.sh` / `block-chmod.sh` / `block-direct-git-commit.sh`）はいずれも `exit 2` + stderr でブロックしており、実運用の実績がある。§3 は permissionDecision JSON + 終了 0 を正とする。
- **見立て: 仕様どおり（JSON）で実装するが、TBD として実装時に検証する。** §12 の TBD 表に「PreToolUse の deny が JSON 経路で確実に効くか（効かなければ `exit 2` 併用へ縮退）」を 1 行足す価値がある。なお §1 の fail-closed ラッパは JSON を `printf` する前提なので、JSON 経路が効くことが前提になっている。

### G. `.claude/hooks/.state/` を差分検査から除外している

- `workflow-diff-check.sh:67-69` はフック自身のログと `.state/` を差分から常に無視する。新仕様では相当物が `logs/` にあり、§5 が「`logs/` への書き込みは `workflow-guard` の許可範囲の判定対象外」と定めているので同じ扱いになる。移植時に無視リストのパスを `logs/**` へ差し替えるだけで整合する。
- **見立て: 実装で吸収（仕様変更不要）。**

---

## 3. 参考実装に無く、新規に書く必要がある機能

1. **`redact`**（§3 の 6 パターン、HK-T10）— 参考にマスク処理が 1 か所も無い。
2. **`decisions.jsonl` の記録**（§5 のスキーマ、7 種の `decision` 値、HK-T06）。
3. **fail-closed**（§1 の登録ラッパー、§3 の `trap ERR`、WFx09 系識別子、HK-T09）— 参考はすべて fail-open。
4. **ヘッドレス判定**（§10、WF213、HK-T08）。
5. **緊急停止時の `disabled` 記録**（§4、HK-T03）— 参考は無言で `exit 0`。
6. **`cmdpos.sh` のセグメント列 API**（§7 の `exe` / `args[]` / `redirects[]` / `write_targets[]` / `opaque`）— 正規化部は流用できるが、出力構造そのものは新規。
7. **`redirects[]` と `write_targets[]` の抽出**（§7、WF205 の `wip/tmp/**` / `logs/**` 例外の前提）。
8. **PowerShell 専用の前処理**（§7-6 の 5 項目）— 参考は bash と同じ正規化を通しており、`.\git.exe` を取りこぼす。
9. **push の成功判定**（post-push-compact-prompt.md「push 検知 2」の 3 条件 AND、`tool_response` の読み取り）。
10. **`scope-limits.json` の `ops` 体系**（`read` / `build-test` / `hook-test` / `remote-read` / `remote-write:<7 種>` / `merge-base` / `web`）とチケットの `allow.ops` との突き合わせ — 参考は `bash_groups` の 2 値のみ。
11. **`gh` / `glab` のサブコマンド分類**（`remote-read` と `remote-write:<種別>` の判別、WF206）。
12. **ネストした frontmatter の読み取り**（`allow.write` / `allow.ops` / `human_review.required`）— 参考の 1 行 sed では読めない。
13. **`blocked-commands.txt` の外部化と高速前置判定**（block-chmod.md 制御方式 2・BC-T04/T05）。
14. **`logs/sessions/` の 7 日より古いディレクトリの非侵襲的削除**（§5）。
15. **`common.confirm` の「どの type の allow より優先」規則**（§8）— 参考の判定順にこの優先関係が無い。
16. **`logs/**` を判定対象外にする段**（§8 (1)）と `state_files` の概念。
17. **`--accumulate` モード（Stop / SubagentStop）** — 参考は push 時にしか集計せず、Stop 契機の蓄積が無い。
18. **HK-T01〜T10 に相当するテスト基盤** — 参考の `agent-workflow/.claude/hooks/tests/` は 6 本のみで、`settings.json` の登録照合・`redact`・fail-closed・ヘッドレスの観点が無い。
19. **`subagent-start-check` / `subagent-stop-check` / `workflow-state-guard`** — 参考に対応するフックが存在しない（本調査の対象外だが、新規であることを記録しておく）。

---

## 4. Windows Git Bash で問題になりそうな箇所

### A. jq が Windows ネイティブ版で CRLF を出す（**実測で再現**）

```
$ command -v jq          → /c/Program Files/jq/jq
$ echo '{"a":"x"}' | jq -r .a | od -c
0000000   x  \r  \n
```

- 影響: `$(jq -r ...)` はコマンド置換で末尾の `\n` は落ちるが **`\r` は残る**。パス比較・`case` マッチ・数値比較がすべて静かに壊れる。
- 参考実装の対策: `workflow-lib.sh:34-38`（`wf_jq() { jq "$@" | tr -d '\r'; }`）、`workflow-entry.sh:56-59` が同じラッパを持つ。MR-driven 側は個別に `| tr -d '\r'` を挟む（`post-push-usage-report.sh:90, 129, 148`、`session-start.sh:372-377`）。
- **対応: `hook-common.sh` に `hook_jq`（= `jq | tr -d '\r'`）を置き、素の `jq` を使わない規約にする。** ただし `wf_jq` はパイプなので終了コードが jq のものにならない点に注意が要る（`workflow-lib.sh:35` は `pipefail` 前提と書いているが、`pipefail` を設定していないフックから source されると壊れる）。
- 加えて `read` で受ける側の CRLF 対策も必要（`workflow-lib.sh:52`、`workflow-entry.sh:135`、`workflow-guard.sh:290` が `tr -d '\r'` を挟んでいる）。**チケット・設定ファイル自体が CRLF で保存されている可能性**（Windows のエディタ）があるため、frontmatter の読み取りでは必須。

### B. `mapfile` / `${var,,}` / `${arr[-1]}` — bash 4.3 以上が必要

- `CommandPosition.sh:33` が明示（`mapfile` `:111`、`${var,,}` `:472`、`${arr[-1]}` / `unset 'arr[-1]'` `:210-213, 231-234, 313-316`）。
- 本環境の bash は 5.2.12 なので問題ないが、`block-direct-git-commit.sh:77-80` / `block-unchecked-push.sh:49-50` は「実行環境の bash バージョンを制御できない」として**前置フィルタだけは bash 3.2 互換で書く**（`case "$probe" in *[Pp][Uu][Ss][Hh]*)`）という配慮をしている。§7-7 の縮退（bash 4.3 未満で `degraded`）を実装するなら、この配慮は必須。`${var,,}` を縮退判定より前に書くと**縮退へ到達する前に展開エラーで落ちる**（`block-direct-git-commit.sh:78-80` の指摘）。

### C. コマンドライン長の 32KB 上限（jq への引数渡し）

- `UsageTracking.sh:177-189` が実データでの失敗を記録している: transcript の新規行 32 件（約 120KB）を `--argjson entries` で渡すと Windows のプロセス生成時のコマンドライン長上限（実測 ≈32KB）を超えて `jq` 自体が終了コード 126（`Argument list too long`）で落ちる。
- **対応: `lib/transcript.sh` は必ず `jq -R -n ... "$transcript_path"` でファイルパスを渡し、内容をシェル変数や引数に載せない。** `--argjson` で渡すのは小さい状態 JSON まで。

### D. 外部プロセス起動が 1 回あたり約 95ms（git bash）

- `CommandPosition.sh:13-15`、`post-push-usage-report.sh:383-389`（strace 実測で空振り 1 回が `execve 6 / clone 14`）が記録。フックは**毎ツール呼び出し**で走るため、前置フィルタ（fork ゼロ）で足切りする設計が必須。
- 影響する箇所:
  - `workflow-lib.sh:42` の `wf_log` は毎回 `date` を fork する。§5 が全フックにログを要求するので、ログ 1 行ごとに 95ms 積む。`printf '%(%Y-%m-%dT%H:%M:%S)T'`（bash 4.2+ の組み込み）へ置き換えるべき。
  - `workflow-guard.sh:198`（`sed`）、`:212`（`sed`）、`:215/:219/:244/:248`（`printf | grep -Eq` をセグメントごと）はセグメント数に比例して fork する。`cmdpos.sh` の純 bash 実装へ寄せて解消する。
  - `session-start.sh:75-80` の `wc -c`（セッション開始 1 回なので許容と明記）。
- **対応: 拒否側 5 本には `raw_hints_at_*` 相当の fork ゼロ前置フィルタ（`block-direct-git-commit.sh:65-85` の形）を必ず置く。** block-chmod.md 制御方式 2 の「高速前置判定」はこれに当たる。

### E. `mktemp` / `realpath`

- `realpath` は本環境に存在する（`/usr/bin/realpath`）が、参考実装は 1 か所も使わず、**パス正規化を純 bash で行っている**（`workflow-lib.sh:56-66` の `wf_to_rel`。`\` → `/` 置換とドライブレターの大小無視）。fork コストと、`realpath` が Windows パス（`C:\...`）を返す形式の差を避ける意図と読める（**推測**）。同じ方針を踏襲するのが安全。
- `mktemp` は `session-start.sh:306, 319`、`post-push-usage-report.sh:569`、`UsageTracking.sh:1020, 1041` で使用。`session-start.sh:306` は `mktemp "${dir}/.xxx.XXXXXX"` と**書き込み先と同じディレクトリ**に作っている（`mv` を同一ファイルシステム内に収めるため）。`$TMPDIR` 直下に作ると Windows では別ドライブになりうるので、状態ファイルの原子的更新は `workflow-entry.sh:143-146` の形（`${STATE_FILE}.tmp.$$` → `mv -f`）を使うのが確実。
- なお `.tmp.$$` は同一 PID の衝突を防げない（同一セッションで並行するフックは PID が違うので実害は小さい — **推測**）。

### F. 改行コードとリポジトリ設定

- チケット（`wip/10_tickets/**/*.md`）と `scope-limits.json` が CRLF で保存されると:
  - frontmatter の `sed -n '2,/^---/{s/^key:...//p}'` が値の末尾に `\r` を残す（`workflow-lib.sh:52` は `tr -d '\r'` で対処済み）。
  - `workflow-guard.sh:288-290` の Edit シミュレーションは、`old_string`（AI が渡す LF）とファイル内容（CRLF）が一致せず**判定漏れ**になる。参考は `current=$(tr -d '\r' <"$path")` で正規化して回避している。同じ対処が WF208 の実装に必須。
  - `blocked-commands.txt` を CRLF で保存すると 1 行が `chmod\r` になり照合が外れる。読み取り時に `tr -d '\r'` を通す。
- `git status --porcelain` は `core.autocrlf` の設定によって差分の見え方が変わるが、参考は `core.quotepath=false`（`workflow-diff-check.sh:78`）だけを明示している。日本語ファイル名がエスケープされて `wf_resolve` のマッチが外れるのを防ぐためで、**これは新実装でも必須**（新仕様は `--porcelain=v2 -z` を使うので `-z` により引用の問題は解消するが、`core.quotepath=false` の併用が安全）。

### G. `shopt` の副作用

- `workflow-lib.sh:185-189` は `nullglob` を設定する前に元の状態を保存して戻している。`workflow-guard.sh:19` / `work-boundary.sh:19` / `merge-prep.sh:29` は `shopt -u patsub_replacement 2>/dev/null || true`（bash 5.2 で `${var/pat/rep}` の置換文字列中の `&` が特別扱いされる問題への対処）。**本環境は bash 5.2.12 なのでこの対処は必要**。チケット名やパスに `&` が含まれるとき（稀だが）に効く。

---

## 補足: 流用価値の高い順（実装計画の参考）

1. `CommandPosition.sh:106-470`（正規化・ヒアドキュメント・算術式）— ほぼ無改造で `cmdpos.sh` の前半になる。
2. `UsageTracking.sh:202-259` + `:431-456`（カーソル付き差分集計）— `lib/transcript.sh` の骨格。
3. `raw_hints_at_git_push` / `raw_hints_at_git_commit`（`post-push-usage-report.sh:360-378` ほか）— fork ゼロ前置フィルタの型。
4. `workflow-lib.sh:145-161`（`wf_load_config`）— jq 1 回で設定を読む型。`scope-limits.json` の読み取りにそのまま応用できる。
5. `workflow-guard.sh:273-319`（Edit シミュレーション）— WF208 の実装。
6. `workflow-entry.sh:123-151` + `:174-236`（宣言状態と 3 モード）— workflow-entry の骨格。
7. `workflow-lib.sh:85-113` + `workflow-diff-check.sh:46-54`（承認の記憶の読み書き分離）— `approvals.json`。
