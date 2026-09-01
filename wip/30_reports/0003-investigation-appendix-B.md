---
type: report
title: 調査 B 付録 — 参考実装と提供コマンド・logger・redact 仕様の突き合わせ（生データ）
description: チケット 0003 の Q1（提供コマンド側）と Q4（logger と redact）の調査結果の生データ。31 機能単位の流用 / 改変 / 新規判定、logger の読み込み方式の比較、仕様との食い違い 8 件、新規機能 16 件、Windows Git Bash の懸念 12 件。要約は 0003-investigation.md
tags: [report, investigation, issue-6, appendix]
keywords: [参考実装, ticket.sh, commit.sh, push.sh, check-html.sh, logger.sh, redact, extract-frontmatter.sh, create-commit.sh, push-checklist.sh, 流用, 改変, 新規, Windows, CRLF, jq]
---

# 調査 B: 参考実装 × 新仕様（提供コマンド / 共通 logger・redact）の突き合わせ

- 調査日: 2026-09-01
- 対象仕様: `.claude/docs/10_spec/skills/20-common-step-{ticket,commit-push,shell-script,report-view}.md`、`.claude/docs/00_requirement/rules/logger.md`、`.claude/docs/10_spec/フック共通仕様.md` §3〜§6・§9
- 対象参考実装: `参考ディレクトリ/MR-driven-workflow/.claude/**`、`参考ディレクトリ/agent-workflow/.claude/**`（読み取りのみ。変更・git 操作なし）
- パスはすべてリポジトリルート（`C:/Users/taniyama/Desktop/git/issue-mr-ticket-workflow`）からの相対
- 判定の凡例: **流用**=ほぼそのまま移植できる / **改変**=構造や部品は使えるが仕様に合わせて作り直す / **新規**=参考に相当物が無い

---

## 1. 機能単位 × 対応箇所 × 判定

### 1-1. チケット（`ticket.sh` / TK0xx）

| # | 機能単位 | 参考実装の対応箇所（ファイル:行） | 判定 | 理由 |
|---|---------|--------------------------------|------|------|
| 1 | frontmatter ブロックの切り出し | `参考ディレクトリ/MR-driven-workflow/.claude/scripts/src/extract-frontmatter.sh:101-124`（`extract_frontmatter_block`） | 流用 | 1 行目 `---` 判定・CR 除去・2 本目 `---` までの本文返却。仕様の frontmatter 形式（フック共通仕様 §9）にそのまま当たる |
| 2 | frontmatter の YAML 解析（スカラー・フロー配列・ブロック配列） | 同 `:147-187`（`parse_frontmatter_block`）、`:32-43`（`JQ_FM_DEF`）、`:189-228`（`run_fm_jq`）、`:241-260`（yq 優先→自前フォールバック） | **改変** | フラットなキーしか読めない。`^([A-Za-z0-9_]+):` を行頭固定で当てる（`:154`）ため、仕様 §9 の `allow:` 配下の入れ子（`write:` / `ops:`）は**どの分岐にも当たらず黙って捨てられる**。さらに `allow:` は値が空なので `:158-161` の分岐でブロック配列扱いになり、`allow` が空配列として登録される（誤った成功）。`human_review: {required: true, reason: "..."}` はインラインマップ非対応で、`{required: true, reason: "..."}` という**文字列スカラー**になる（`:175-180`）。`predecessors: ["0006"]` のフロー配列だけは `:163-174` でそのまま読める |
| 3 | frontmatter の単一キー取得（軽量） | `参考ディレクトリ/agent-workflow/.claude/hooks/workflow-lib.sh:46-53`（`wf_extract_type` / `wf_fm_get`。sed の範囲指定 `2,/^---/`） | 改変 | jq を起動せず 1 キーを取る型としては優秀（フックの毎回起動に向く）。ただし行頭アンカーのため入れ子は取れず、`predecessors` のような配列は生文字列で返る（分解は `workflow-lib.sh:229-238` が別途 sed で行っている） |
| 4 | インライン配列の分解 | `workflow-lib.sh:229-238`（`allowed_paths` を `sed -E 's/^\[//; s/\]$//'` + `IFS=','`）、`extract-frontmatter.sh:163-174`（bash だけで分解し fork しない） | 流用 | `extract-frontmatter.sh:168-174` の方が fork ゼロで速く、クォート除去も込み。`predecessors` / `allow.ops` / `allow.write` の分解にそのまま使える |
| 5 | 連番の採番（全ディレクトリの最大 +1） | `参考ディレクトリ/agent-workflow/.claude/hooks/work-boundary.sh:43-47`（`wb_ticket_num`）・`:68-78`（todo/done の走査）、`push-checklist.sh:121-166`（`checklist_number_to_reply` / `max_checklist_to_reply`。`10#` で 8 進誤読を回避＝`:159`） | **改変** | 走査と 10 進強制は流用可。ただし参考は **todo / done の 2 ディレクトリしか見ない**（`work-boundary.sh:69-77`）。仕様は取り消し済みを含む 4 ディレクトリ全走査（TICKET-T05）。`nullglob` の退避・復帰（`work-boundary.sh:64-78`）はそのまま使える型 |
| 6 | チケットの移動 | 該当スクリプト無し。AI の手順として `参考ディレクトリ/agent-workflow/.claude/skills/work-ticket-driven/SKILL.md:97-100`（`git mv` + `git commit` を AI が直接実行） | **新規** | 仕様は「移動はスクリプト経由のみ・手動移動はフックが拒否」。参考は真逆（AI が手で動かす前提）で、移植元が無い |
| 7 | 状態変更のコミット | `work-boundary.sh:130`（`wb_git`）・`:143-146`（`wb_commit_state`: `git add -- <path>` → `git commit -q -m <msg> -- <path>`）、`参考ディレクトリ/agent-workflow/.claude/hooks/merge-prep.sh:167-169` | 流用 | パス限定の add/commit という型がそのまま使える。件名は仕様の規約（`chore: チケット <連番> を作成`）に差し替え |
| 8 | 完了検査（全件列挙して 1 件目で止めない） | `参考ディレクトリ/MR-driven-workflow/.claude/scripts/src/push-checklist.sh:247-329`（`verify_stream`。`ok=0` を立てて走査を続け、最後に `[ "$ok" -eq 1 ]`）、`:238-246`（「通してよいと積極的に確認できたときだけ 0」という否定形の方針） | 改変（構造のみ流用） | TK003 の「未充足をすべて列挙」の骨格として最適。ただし検査内容（DoD の `- [ ]` 残存・根拠欄の空・作業ログ見出し）は参考に相当物が無く中身は新規 |
| 9 | 未コミット差分の検査 | `work-boundary.sh:176`（`[ -n "$(wb_git status --porcelain)" ]`）、`merge-prep.sh:155`（`mp_dirty`） | 流用 | complete の「チケットファイル以外の未コミット変更が無い」と push 前チェック項目 1 の両方に使える（対象の除外だけ足す） |
| 10 | `next` の依存解決 | `参考ディレクトリ/agent-workflow/.claude/hooks/workflow-diff-check.sh:100-115`（`depends_on` を `20_done/<name>` の存在で判定し未充足を列挙）、`work-boundary.sh:74-77`（todo の最小連番） | **改変** | 依存判定そのものは流用可。ただし参考は「先頭 1 枚を取ってから依存違反を*警告*する」形で、仕様は「依存が満たされたものの中から最小連番を選び、満たされないものは飛ばす」＋全滅時 `blocked` を返す（TICKET-T08）。走査の順序を作り直す必要がある。加えて `depends_on` はファイル名、仕様の `predecessors` は**番号**（`"0006"`）なので、突合は `20_done/<番号>-*.md` の glob へ変える |
| 11 | 取り消し（`30_cancelled`） | 相当なし（`work-boundary.sh:69-77` は 3 ディレクトリのみ） | **新規** | 状態そのものが参考に存在しない |
| 12 | `overall-plan` だけコミットしない分岐 | 相当なし | **新規** | TICKET-T09。参考は全チケットを一律にコミットする（`work-ticket-driven/SKILL.md:85-90`） |
| 13 | 種類 → スキル名の解決 | `参考ディレクトリ/agent-workflow/.claude/hooks/workflow-types.json`（jq 1 回で読む: `workflow-lib.sh:145-161`） | 改変 | 「設定を jq 1 回で読み、RS/US 区切りの 1 行にして bash 側で分解する」型（`workflow-lib.sh:132-140`・`:209-226`）は流用価値が高い。ただし仕様の実体は TSV（`.claude/hooks/config/task-types.tsv`）で jq 不要。TSV なら `split_tsv_line`（`push-checklist.sh:83-103`。**`IFS=$'\t' read -a` を使うと連続タブが畳まれる**という注意付き）が正解 |
| 14 | チケットのテンプレート | `参考ディレクトリ/agent-workflow/.claude/skills/work-ticket-driven/assets/ticket.template.md:1-35` | **改変** | frontmatter は 3 キー（`type` / `status` / `depends_on`）だけで、仕様の 8 項目（`ticket_type` / `predecessors` / `executor` / `human_review` / `allow` / `started_at` / `completed_at` / `base_sha`）に足りない。作業ログの見出しも 2 個（`:29-35`）で、仕様の固定 10 項目に足りない。プレースホルダ記法も HTML コメント（`<!-- ... -->`）で、仕様の `{{名前}}` と異なる。骨格（目的 / DoD / 作業内容 / 作業ログ の節構成）だけ流用 |

### 1-2. コミット・push（`commit.sh` / `push.sh` / CP0xx）

| # | 機能単位 | 参考実装の対応箇所 | 判定 | 理由 |
|---|---------|------------------|------|------|
| 15 | パス指定 add（一括ステージ不可） | `参考ディレクトリ/MR-driven-workflow/.claude/scripts/src/create-commit.sh:94`（`git add -- "${files[@]}"`）・`:59-63`（対象 0 件を拒否）・`:16-19`（`--amend` / `--no-verify` / `-A` を**構造的に持たない**設計）・`:117-121`（空配列で `git add` を呼ばない） | **流用** | 仕様 commit.sh 手順 2・4 とほぼ一致。設計思想（オプションを持たせないことで不可能にする）も仕様の禁止事項と同じ |
| 16 | 削除済みパスの分類と冪等スキップ | 同 `:65-89`（`classify_files`: `git ls-files` / `git ls-tree` で add/skip/unknown に分ける）・`:94-122` | 流用（任意） | 仕様に記載は無いが「削除だけステージ済みのパスを再度渡された」ケースを吸収する。移植コストが低く実運用で効く |
| 17 | コミットメッセージの規約検査（CP002） | 検査の実装なし。`create-commit.sh:53-57` は `--message` の非空しか見ない。規約は `参考ディレクトリ/MR-driven-workflow/.claude/skills/commit/SKILL.md:61-77`（prefix 表）・`:180-245`（件名の内容規約）に**AI 向けの文章として**存在 | **新規** | 仕様の正規表現による機械検査・1 行検査・AI フッター検出はすべて新規。prefix 一覧は `commit/SKILL.md:63-76` から流用できるが、参考は `style` / `revert` を持ち `ai-asset` の定義も異なる（`.claude/scripts/` を対象外にしている）ので、仕様の一覧へ読み替えが必要 |
| 18 | 除外パターン | `参考ディレクトリ/MR-driven-workflow/.claude/skills/commit/SKILL.md:84-108`（クレデンシャル系 6 群・開発副産物 9 群。`*.stackdump`・`settings.local.json` を含む） | **改変** | 一覧の中身は丸ごと流用できる。ただし参考は Markdown の箇条書き（AI が読む）で、仕様は `assets/exclude-patterns.txt`（1 行 1 glob、スクリプトが読む）。形式の移し替えが必要。マッチャは `参考ディレクトリ/agent-workflow/.claude/hooks/workflow-lib.sh:69-80`（`wf_match`。`case` による glob、`**`→`*` 読み替え、fork ゼロ）または `参考ディレクトリ/MR-driven-workflow/.claude/scripts/src/cleanup-task.sh:148-158`（`is_keep_path`。完全一致＋basename 一致）が流用可 |
| 19 | 除外一覧の常時報告 | `commit/SKILL.md:113-118`（AI がチャットへ出す） | 改変 | 「スクリプトの出力として必ず出す」形への移し替え。参考は AI 任せ |
| 20 | push 前チェック | `push-checklist.sh` 全体。特に `:37-58`（項目 5 件を定数配列で持ち外部定義ファイルにしない判断）・`:247-329`（`verify_stream`）・`:355-377`（`cmd_verify`。HEAD 断面を読む）・`:383-395`（`cmd_stale`）・`:399-411`（`head_has_task_artifacts`） | **改変** | 機構が別物。参考は「AI が TSV に自己申告で done/skip を書き、HEAD にコミット済みの断面を検証する」。仕様は「スクリプトが 4 項目を自分で判定する」。流用できるのは (a) 全件列挙の骨格、(b) 「作業ツリーだけ埋めて push するのを防ぐ」という設計意図（`:23-25`）— 仕様では項目 1（未コミット 0）が同じ役目を果たす、(c) `head_has_task_artifacts:399-411` の考え方が項目 4（作業領域が空）に対応 |
| 21 | 意図的スキップの記録 | `push-checklist.sh:468-529`（`set_state` の `skip` + 理由必須。`:474-478` で理由が空なら拒否） | 改変 | 「理由を必須にする」「記録が Git 差分に見える」という要求は同じ。仕様は TSV ではなく `wip/push-check-skip.md`（Markdown）で、項目 4 はスキップ不可という追加規則がある |
| 22 | md / html の対の検査（項目 3） | 相当なし。規約だけ `参考ディレクトリ/MR-driven-workflow/.claude/skills/issue-mr-flow/references/deliverables.md:158-159`（「同じベース名で拡張子だけ `.html`」）と `push-checklist.sh:52`（チェックリスト項目の文言） | **新規** | 実際に対を突き合わせるコードは無い |
| 23 | `--set-upstream` / push 結果の出力 | `work-boundary.sh:229`・`merge-prep.sh:163-165` はいずれも `git push -q` のみ（上流未設定の扱い無し） | **新規** | CP006 の「リモート拒否をそのまま返す」「force しない」も明示実装が要る |
| 24 | 空コミット（`--allow-empty`） | `参考ディレクトリ/MR-driven-workflow/.claude/scripts/src/vcs/Provider.sh:1153`（`add_empty_commit_for_draft_mr`） | 流用（参照） | draft MR 作成時に空コミットを積む用途は仕様と同じ（`20-common-step-feature-mr`） |

### 1-3. HTML 検査（`check-html.sh` / RV0xx）

| # | 検査 | 参考実装の対応箇所 | 判定 | 理由 |
|---|------|------------------|------|------|
| 25 | 検査 1 プレースホルダ残存（RV001） | `deliverables.md:88`・`:143-149`（成果物は 0 件、テンプレート本体は 0 件でないのが合格という**逆転**の明記）、`参考ディレクトリ/MR-driven-workflow/.claude/scripts/test/test_report_templates.sh:110-115` | 改変 | 記法が `<!-- ここに書く` → 仕様は `{{名前}}`。合格条件の逆転（テンプレート側）は仕様の RV には無いが、テストで守る価値がある |
| 26 | 検査 2 外部リソース（RV002） | `deliverables.md:91-92`（検査 4・5: `(src\|href)=` に続く `//` と `url()` / `@import` の `//`）、`test_report_templates.sh:100-108` | 改変 | 参考は 2 検査に分かれ、仕様は 1 検査（RV002）に統合。仕様は `<a href>` を除外する追加規則を持つが、参考の正規表現は `href=` を無差別に拾うので**そのままでは仕様に合わない**（ページ内アンカーと `data:` の除外も要る） |
| 27 | 検査 3 id の重複（RV003） | `deliverables.md:89`（`ids` を `uniq -d`）、抽出は `:88`（`grep -oE` で**タグ内に限定**。DDR `i0186-02`） | 流用 | 抽出をタグ内に限定する工夫がそのまま使える |
| 28 | 検査 4 ページ内リンクの破断（RV004） | `deliverables.md:87-89`（`comm -23` で href 集合 − id 集合） | 流用 | `comm` は MSYS 側なのでプロセス置換で問題ない（jq に渡さない限り） |
| 29 | 検査 5 `<style>` がちょうど 1 つ（RV005） | `deliverables.md:107-109`（**コメントを先に除いてから**数える。`perl -0pe` でコメント除去）、`test_report_templates.sh:61-90`（実装と負のコントロール） | 流用 | 「行頭固定にするとインデントされた重複を取りこぼし、外すとコメント中の地の文が誤検出になる」という経緯付き（`deliverables.md:133-135`）。この解が最短 |
| 30 | 検査 6 必須節（`data-required`）（RV006） | 相当なし | **新規** | 「必須節一覧をテンプレート自身から導出する」という仕様要求（二重管理の禁止）も参考に無い |
| 31 | 検査 7 負のコントロール（RV007） | `deliverables.md:130-135`（一般則 2）・`:141`（空振りガード＝拾えた件数を必ず出す）、`test_report_templates.sh:49-55`・`:84-98` | **流用** | 「出力なし＝合格の検査は負のコントロールを取る」「拾えた件数を出す」という設計がそのまま RV007 と `OK:` の件数出力に対応する |

---

## 2. logger / redact

### 2-1. 参考実装のログ関数と仕様の差分

参考リポジトリ 2 本を `log_info` / `log_debug` / `log_warn` / `log_error` / `LOG_LEVEL` / `logger.sh` / `debug_log` で全文検索した結果、**ヒット 0 件**。共通 logger に相当する仕組みは存在しない。個別実装は次の 3 つだけ。

| 参考の実装 | 場所 | 出力先 | レベル | 行フォーマット | redact | 失敗時 |
|-----------|------|--------|--------|--------------|--------|--------|
| `wf_log` | `参考ディレクトリ/agent-workflow/.claude/hooks/workflow-lib.sh:40-43` | `.claude/hooks/workflow.log`（**単一ファイル固定**） | 無し | `date '+%Y-%m-%dT%H:%M:%S'` + メッセージ（TZ なし・レベルなし・出どころなし・pid なし） | 無し | `2>/dev/null >>... || true` で黙殺（**思想は仕様と一致**） |
| `log` | `参考ディレクトリ/MR-driven-workflow/.claude/scripts/src/cleanup-task.sh:194-196` | 標準エラー | 無し | 素のメッセージ | 無し | — |
| `wb_die` / `mp_die` | `work-boundary.sh:32-40` / `merge-prep.sh:45-53` | 標準エラー + `wf_log` | 無し | `[WFxxx] 概要` / `未充足: ...` / `対処: ...` の 3 行 | 無し | `exit 2`（フック契約） |

仕様との差分:

| 項目 | 仕様（`20-common-step-shell-script.md` Script 処理 / `rules/logger.md`） | 参考実装 | 差分の扱い |
|------|--------------------------------------------------|---------|-----------|
| 出力先 | `logs/sh/<出どころ>.log`（リポジトリ直下・`.gitignore` 済み） | `.claude/hooks/workflow.log` 1 本 | **そのまま流用不可**。新仕様では `.claude/**` は `common.protected`（フック共通仕様 §8）で、機構自身のログ置き場としては使えない。`logs/**` は guard の判定対象外（§8 判定順 (1)）なので置き場は仕様どおりにする |
| 出どころの分離 | スクリプトごとにファイルを分ける。`LOGGER_NAME` で上書き（フックは `hook-<name>`。§5） | 単一ファイル | 新規 |
| レベル | DEBUG(10)/INFO(20)/WARN(30)/ERROR(40)、`LOG_LEVEL` を読み無効値は INFO に正規化 | 無し | 新規 |
| 行フォーマット | `<ISO8601 秒・TZ 付き> [<LEVEL>] [<出どころ>] [pid:<PID>] <メッセージ>` | 時刻（TZ なし）+ メッセージ | 新規（時刻の取り方は §5-1 の注意参照） |
| 改行の畳み | 改行を `\n` リテラルへ置換して 1 行にする | 無し | `push-checklist.sh:105-116`（`normalize_log_to_reply`。タブ・改行・CR を半角スペースへ潰す**外部プロセス不使用**の純関数）が土台。置換先を `\n` リテラルに変えるだけ |
| 失敗時 | すべて握りつぶし常に 0 を返す（`set -e` の利用側を巻き込まない） | `wf_log:42` が同じ | **流用**（`|| true` の型） |
| 標準出力への出力 | 禁止（ファイルのみ） | `cleanup-task.sh:194-196` は stderr へ出す（用途が違う進捗ログ） | 仕様どおり分離する。参考の「人間向け進捗は stderr、機械可読な結果は stdout」という分離（`cleanup-task.sh:36`）自体は提供コマンドの結果出力に流用できる |
| redact | フック共通仕様 §3: `ghp_` / `gho_` / `github_pat_` / `glpat-`、`Bearer <語>`、`token=` / `password=` / `secret=` / `api[_-]?key=`、`AKIA` + 20 文字、40 文字以上の 16 進・base64 様 → `***` | **実装なし**。規約だけ `参考ディレクトリ/MR-driven-workflow/.claude/rules/shell-script-style.md:1248-1268` にある | **新規**。ただし方針の食い違いあり（§3-1） |

### 2-2. skills 配下の logger を hooks 配下から読む相対パス解決

参考実装が使っている解決方法（すべて実例あり）:

| 方式 | 実例 | fork | cwd 非依存 | 備考 |
|------|------|------|-----------|------|
| (a) `$(dirname "${BASH_SOURCE[0]}")/lib.sh` | `workflow-diff-check.sh:19`、`work-boundary.sh:22` | 1 回（`dirname`） | ○ | 同一ディレクトリ限定 |
| (b) `script_dir="${BASH_SOURCE[0]%/*}"` + 自身と等しければ `.` | `push-checklist.sh:178-183`、`extract-frontmatter.sh:362-364`、`test_cleanup_task.sh:14-15` | **0 回** | ○ | パラメータ展開だけ。相対で登るなら `${script_dir}/../..` を足す |
| (c) `repo_root="$(cd "$script_dir/../../.." && pwd)"` | `test_cleanup_task.sh:16` | 1 回（サブシェル） | ○ | 段数がハードコード。置き場の階層が変わると壊れる |
| (d) `git rev-parse --show-toplevel` → `cd` | `cleanup-task.sh:219-223`、`extract-frontmatter.sh:294-297`（`cd` してから `pwd` で MSYS 形式へ正規化） | 1 回（git 起動） | ○（リポジトリ内なら） | **仕様の雛形サンプルがこの形**（`20-common-step-shell-script.md` の IN/OUT サンプル） |
| (e) `CLAUDE_PROJECT_DIR` | `workflow-lib.sh:166-167`（`${CLAUDE_PROJECT_DIR:-.}` + `\` を `/` へ正規化） | 0 回 | ○ | Claude Code が渡す環境変数。フックでのみ確実 |

推奨（この順で試すフォールバック鎖）:

1. **(b) を起点に、`.claude` を持つ親ディレクトリを探す上向きループ**（fork ゼロ・cwd 非依存・置き場の段数に依存しない）。`.claude/skills/<name>/scripts/`、`.claude/hooks/<NN-Event>/`、`.claude/hooks/<NN-Event>/tests/`、`.claude/skills/<name>/scripts/tests/` の 4 通りの深さがあるため、段数固定の (c) は避ける
2. 見つからなければ `CLAUDE_PROJECT_DIR`（(e)）
3. それも無ければ `git rev-parse --show-toplevel`（(d)）。**空文字を返しうるので `source "/.claude/..."` にならないようガードする**
4. すべて失敗したら logger を無効化（no-op 関数を定義）して本体を止めない（`rules/logger.md`「ログ機構の失敗が本体を止めない」に合わせる）

仕様の雛形サンプルが (d) 単独である点は、`source "$(git rev-parse --show-toplevel)/..."` が (i) 実行のたびに git を 1 回起動する、(ii) git 不在・リポジトリ外で `source "/.claude/..."` になり `set -e` 下で即死する、の 2 点で弱い。**雛形の 1 行を上の鎖へ差し替えるのが望ましい**（→ §3-2）。

---

## 3. 流用するときに仕様と食い違う点

### 3-1. redact のパターン指定が参考ルールと正面から衝突する

- 参考ルール `rules/shell-script-style.md:1252-1262`:「**接頭辞は設定で変更できるため、接頭辞決め打ちの正規表現に頼らない**」「**当たらないマスクは無いのと同じで、しかも『マスクした』という誤った安心を与える分たちが悪い**」「そもそも値を出さない形にできないかを先に考える」
- 新仕様 フック共通仕様 §3 は `ghp_` / `glpat-` / `AKIA` の**接頭辞決め打ち**を列挙している
- **見立て: 仕様は直さず実装で吸収**。§3 は同時に「環境変数の値・トークン・個人情報を含めない」という一次規則を持ち、redact は最後の砦という位置づけ。HK-T10（`redact` が §3 のパターンをすべて `***` に置換し、通常のパス・日本語を壊さない）が「当たることを確かめる」を担保する
- ただし**仕様側に 1 文足す価値はある**:「redact は最後の砦であり、一次防御は『そもそも値を出さない』こと」。参考の経緯（`glab auth status --show-token` の実例）が根拠になる

### 3-2. logger の読み込み 1 行が仕様に固定されている

- `rules/logger.md`「使い方」と `20-common-step-shell-script.md` のサンプルが `source "$(git rev-parse --show-toplevel)/.claude/skills/20-common-step-shell-script/scripts/logger.sh"` を**文字列として固定**している（要件の「ルールが定める内容」に入っている）
- **見立て: 仕様（`rules/logger.md`「使い方」）を直す**。フック（`.claude/hooks/**`）は毎ツール呼び出しで起動するため git の fork が積み上がる（`extract-frontmatter.sh:15-17` が「git bash では外部プロセス起動が約 95ms/回」と実測付きで警告）。要件は「1 行で読み込む」「コピー禁止」を守れればよく、行の中身を固定する必要はない

### 3-3. frontmatter の入れ子・インラインマップを自前パーサで読めない

- 仕様 §9 は `allow:` の入れ子（`write:` / `ops:`）と `human_review: {required: ..., reason: ...}`（インラインマップ）を使う
- 参考パーサ（`extract-frontmatter.sh:147-187`）はどちらも非対応で、**エラーにならず黙って落ちる**（§1-1 の #2）
- `yq` フォールバック（`:249-256`）は当てにできない。**この環境に `yq` は無い**（実測）。参考自身も「yq を新規の必須外部依存にはしない」（`:10-12`）
- 見立ては 2 案:
  - **A. 実装で吸収**（パーサに 2 機能を足す）: 入れ子は「直前のトップレベルキー + インデント」で `parent.child` のフラットキーに畳む。インラインマップは `{k: v, k: v}` を分解する分岐を足す。追加は 20〜30 行程度で済む見込み（**推測**。実測なし）。仕様は無傷
  - **B. 仕様を直す**（frontmatter をフラットに保つ）: `human_review_required` / `human_review_reason`、`allow_write` / `allow_ops` の 4 キーにする。パーサが単純なまま済み、`wf_fm_get` 相当（`workflow-lib.sh:51-53`）の sed 1 行で 1 キー取得もできる（フックの高速化に効く）。ただし §9 の例・§8 の記述・WF208（`allow` への書き込み拒否）の記述を書き換える必要がある
  - 判断はユーザー。**A を推す**（仕様の階層構造は人間の可読性に効いており、パーサの拡張は局所的なため）

### 3-4. 【仕様内の食い違い】状態変更コミットを `commit.sh` 経由にするか `git` 直実行にするか

- `20-common-step-commit-push.md`「呼出条件」:「`20-common-step-ticket` の `ticket.sh`・片付けの提供コマンドが、**状態変更のコミットに内部から `commit.sh` を使う**」
- `20-common-step-ticket.md`「Script 処理」:「状態変更のコミットは**各サブコマンドが内部で `git` を直接実行して行う**」
- **仕様どうしが矛盾している**。見立て: **`commit.sh` 経由に寄せて ticket 仕様を直す**（メッセージ検査・除外突合・除外一覧の出力が 1 箇所に集まり、ticket.sh 側は「メッセージと対象パスを渡すだけ」になる）。参考にも同じ構図の実例がある — `cleanup-task.sh:16-18` が「コミットはしない。commit スキルへ渡すのは呼び出し側の責務」と明記して自前コミットを避けている

### 3-5. 差分基準点の持ち方

- 参考は `git log -1 --grep='chore(ticket): start'` でコミットメッセージから基準点を探す（`workflow-diff-check.sh:81`）
- 仕様は frontmatter の `base_sha` に記録する（§9・ticket start 手順 4）
- **仕様が正**。参考方式は「`overall-plan` の create / start はコミットしない」仕様（ticket 仕様 Script 処理・TICKET-T09）と両立しない。参考の grep 方式は流用しない

### 3-6. チケットのファイル名から種類を推測しない

- 参考は `NNN-<type>-<slug>.md`（`work-ticket-driven/SKILL.md:77`）で、境界判定は**frontmatter の type** を読む（`work-boundary.sh:49-52`）
- 仕様は `<4 桁>-<種類>.md` で slug なし。ファイル名からも種類が取れてしまうが、機械可読の正は frontmatter の `ticket_type`（§9）。**両方を読んで食い違ったときの扱いが仕様に無い** → 実装では frontmatter を正とし、ファイル名は表示用に留める（仕様に 1 文足す価値あり）

### 3-7. `check-html.sh` の外部リソース検査が参考の正規表現のままでは仕様に合わない

- 参考の検査 4（`deliverables.md:91`）は `href=` を無差別に拾う
- 仕様 RV002 は「`<a href>` のハイパーリンク（issue・MR への参照）は対象外」、RV-T05 は「ページ内アンカー・`data:` URI・`<a href>` の外部リンクは外部リソースと数えない」
- **実装で吸収**（`<a` タグの `href` と `#` / `data:` を除外する）。参考の一般則 1（「ヒットするが問題ない、を残さない」`deliverables.md:126-129`）に照らすと、除外規則は正規表現側で明示するのが筋

### 3-8. 検査項目数の表記

- `20-common-step-report-view.md` の IN/OUT サンプルは `OK: 検査 7 項目すべて通過`、Script 処理の表も RV001〜RV007 の **7 行**。今回の調査依頼にあった「検査 1〜6」は表記のずれで、**仕様は 7 項目**が正

---

## 4. 新規に書く必要がある機能（参考に移植元が無いもの）

| # | 機能 | 備考 |
|---|------|------|
| 1 | `logger.sh` 本体（4 関数・レベル正規化・行フォーマット・出どころ導出・pid・改行畳み・fail-open） | 流用できるのは `wf_log:40-43` の fail-open 1 行と `normalize_log_to_reply`（`push-checklist.sh:105-116`）だけ |
| 2 | `redact`（フック共通仕様 §3 のパターン群） | 参考に実装なし |
| 3 | `assets/script.template.sh` / `assets/test.template.sh` | 参考に雛形ファイルが無い。テスト側は `test_cleanup_task.sh:21-44`（`assert_eq` / `status_of` / `passed=N failures=N` の出力規約）と `test_report_templates.sh:18-33` が土台になる |
| 4 | `ticket.sh` の 5 サブコマンド全体（create / start / complete / cancel / next） | 参考はすべて AI の手順（`work-ticket-driven/SKILL.md` 手順 2・3）。移動・採番・時刻記録・検査のいずれもスクリプト化されていない |
| 5 | チケットテンプレート（記載事項 8 項目・作業ログ固定見出し 10 項目・`{{名前}}` 記法） | 参考テンプレは frontmatter 3 キー・作業ログ 2 見出し |
| 6 | 完了検査の中身（DoD の `- [ ]` 残存 / 根拠欄が空でない / 作業ログ「現在地」の未完了 / 「AI アセットに反映すべき内容」が空でない） | 参考に相当物なし |
| 7 | 取り消し（`30_cancelled` への遷移と理由記録） | 状態そのものが参考に無い |
| 8 | `overall-plan` のときコミットしない分岐（TICKET-T09） | 参考は一律コミット |
| 9 | `next` の JSON 出力（`current` / `next` / `type` / `skill` / `blocked`）と `task-types.tsv` の解決 | 参考の type 定義は JSON（`workflow-types.json`）で、スキル名を解決するコマンド自体が無い |
| 10 | `commit.sh` のメッセージ規約検査（CP002）・一括指定の拒否（CP001）・除外突合と除外一覧の出力（CP003）・差分なし検出（CP004） | `create-commit.sh` は検査を持たない薄いラッパー |
| 11 | `assets/exclude-patterns.txt`（1 行 1 glob） | 中身は `commit/SKILL.md:84-108` から移せるが、ファイル形式としては新規 |
| 12 | `push.sh` の 4 項目チェック・`wip/push-check-skip.md` の読み取り・項目 4 のスキップ不可・`--set-upstream`・push 範囲（コミット数）の出力 | 参考は自己申告 TSV 方式で機構が別 |
| 13 | md / html の対の突き合わせ（push 前チェック項目 3） | 実装なし |
| 14 | `check-html.sh` 本体（スクリプト化そのもの） | 参考は AI が手で打つ grep コマンド列（`deliverables.md:96-110`） |
| 15 | RV006（`data-required` の必須節検査。必須節一覧をテンプレート自身から導出する） | 参考に無い |
| 16 | 出力の型の統一（最終行が `OK:` または `<接頭辞><番号>:`）と終了コード 0/1/2 の統一 | 参考は不統一。`push-checklist.sh:20` は 3 を、`work-boundary.sh:39` は 2 を返す（後者はフック契約）。`push-checklist.sh:11-13` は「exit 2 はフック契約なのでスクリプト単体では使わない」と明記しており、**新仕様の「2＝引数や環境の誤り」と衝突しないよう、フックとスクリプトの終了コード規約を切り分けて書く必要がある** |

---

## 5. Windows Git Bash で問題になりそうな箇所

計測環境（すべて実測）: `GNU bash 5.2.12(1)-release (x86_64-pc-msys)`、`jq` は Windows ネイティブ（`/c/Program Files/jq/jq`）、`yq` **不在**、`shellcheck` **不在**、`perl` / `comm` / `md5sum` / `stat` / `xargs` / `paste` は在。

### 5-1. ISO 8601 のタイムゾーン表記（logger の行フォーマットに直撃）

仕様の行フォーマットは `2026-09-01T14:03:12+09:00`（コロン付き）。実測結果:

- `date +%Y-%m-%dT%H:%M:%S%:z` → `2026-09-01T10:54:21+09:00`（GNU date。OK）
- bash 組み込み `printf '%(...%z)T'` → `+0900`（コロン無し）
- bash 組み込み `printf '%(...%:z)T'` → **空文字**（`%:z` を解釈しない）

logger は 1 行ごとに時刻を取る。フックは毎ツール呼び出しで走るため、**date の fork（約 95ms/回。`extract-frontmatter.sh:15-17` の実測）を 1 行ごとに払うのは避けるべき**。推奨は `printf -v` で `+0900` を得てから bash の文字列操作でコロンを挿入する形（fork ゼロ）。

### 5-2. Windows ネイティブ jq の CR 付与

- コマンド置換・パイプ・ファイルリダイレクトのいずれでも行末に `\r` が付く（`rules/shell-script-style.md:785-830`。実機確認済みと明記）
- 対処の型は `workflow-lib.sh:36-38`（`wf_jq() { jq "$@" | tr -d '\r'; }`）。全 jq 呼び出しをこの 1 関数に通す方式が最も安全
- ただし**「複数行になりうる値」だけが壊れる**（`shell-script-style.md:812-830`）。単一行の値に `tr` を足して回ると fork が無駄に増える。`task-types.tsv` を TSV で持つ仕様は jq を通さない分この問題を避けられる（利点）

### 5-3. `git rev-parse --show-toplevel` が Windows 形式で返る

- 実測: `C:/Users/taniyama/Desktop/git/issue-mr-ticket-workflow`（MSYS 形式 `/c/...` ではない）
- MSYS 形式と混在させると接頭辞除去・文字列比較が黙って失敗する
- 参考の対処: `extract-frontmatter.sh:291-297`（`cd` してから `pwd` で MSYS 形式へ正規化）、`workflow-lib.sh:56-66`（`wf_to_rel`。`\` を `/` に直しドライブレターの大小を無視して比較）
- logger の `logs/sh/` 解決、`commit.sh` のパス突き合わせ、許可範囲判定の相対パス化のすべてで基準形式を 1 つに決める必要がある

### 5-4. `.gitattributes` が無い（`*.sh` の改行コードが保証されていない）

- `rules/shell-script-style.md:22-30`:「LF 改行はリポジトリルートの `.gitattributes` が保証する。CRLF で取り出されるとシバン行の解釈に失敗し `bash: $'\r': command not found` になる」
- **本リポジトリのルートに `.gitattributes` は存在しない**（実測）。一方でフック共通仕様 §8 の `common.protected` には `.gitattributes` が載っており、存在する前提で仕様が書かれている
- 実装フェーズで `*.sh text eol=lf` を持つ `.gitattributes` の作成が必要（sh を 1 本でも置く前に）

### 5-5. `shellcheck` / `yq` が不在

- `20-common-step-shell-script.md` 処理フロー 5 は「shellcheck が導入されていれば」と条件付き。**この環境では常に「省略の事実を記録」の分岐に入る**
- `yq` 不在により、frontmatter の解析は**必ず自前パーサ側**へ落ちる（`extract-frontmatter.sh:249-256`）。§3-3 の判断が実質的に必須になる

### 5-6. `MSYS_NO_PATHCONV` と jq / プロセス置換の相互干渉

- `shell-script-style.md:743-760`: `MSYS_NO_PATHCONV=1` を効かせたシェルでは Windows ネイティブ jq が MSYS 形式パスを開けなくなる
- `:762-776`: **Windows ネイティブ jq にプロセス置換 `<(...)` のパスを渡せない**（`/proc/<pid>/fd/<n>` は見えない）。一時ファイル経由にする
- `check-html.sh` の `comm -23 <(...) <(...)`（`deliverables.md:98`）は comm が MSYS 側なので問題ない。**jq に `<(...)` を渡さない**ことだけ守る

### 5-7. コマンドライン長の上限

- `extract-frontmatter.sh:45-48`・`:204-222`: jq へ位置引数で渡す量が閾値（24576 バイト）を超えると `Argument list too long` になるため一時ファイルへフォールバックする
- `commit.sh` が多数のパスを受ける場合・`push.sh` が違反一覧を jq に渡す場合に同じ問題が出うる（**推測**。実測はしていない）

### 5-8. 日本語ファイル名とパスのクォート

- `git status --porcelain` は既定で非 ASCII をエスケープする。`workflow-diff-check.sh:78` は `-c core.quotepath=false` を付けて回避
- `find -print0` + `LC_ALL=C sort -z`（`cleanup-task.sh:179-187`）でクォートを避ける型
- `commit.sh` / `push.sh` の未コミット一覧の表示・突き合わせで同じ配慮が要る

### 5-9. `jq` へのハイフン始まり引数

- `extract-frontmatter.sh:205-209`: フィルタの直後に `--` を置かないと `-A` のような値をオプションと誤認して `jq: Unknown option -A` で落ちる（issue #69 の実例）
- `next` の JSON 組み立て・`decisions.jsonl` の書き込みで可変長リストを `--args` で渡すときに同じ罠がある

### 5-10. `set -e` とサブシェル / コマンド置換の落とし穴

- `shell-script-style.md:34-70`（bash 5.2.21 実測）: 条件文脈では `set -e` が停止し、それが `( func )` の内側にも伝播する。`$(...)` は `inherit_errexit` 既定オフのため `-e` を一切継承しない
- 対処は「フォークされる側の内側で `set -e` を掛け直す」2 形
- `ticket.sh complete` のように「複数の検査を関数化して失敗を集める」実装で直撃する。**検査関数は終了コードではなくフラグ変数（`push-checklist.sh:247-329` の `ok=0`）で結果を集める**のが安全

### 5-11. TSV の分割

- `push-checklist.sh:83-103`:「**`IFS=$'\t' read -r -a` を使ってはいけない**。タブは bash の IFS 空白文字であり、連続タブが 1 つに畳まれ行末のタブが捨てられる」
- `task-types.tsv` を読む `next` で直撃する。`split_tsv_line`（同 `:88-103`）をそのまま移植するのが正解

### 5-12. `rm -rf` / `find -delete` の Windows 挙動

- `cleanup-task.sh:273-292` の削除処理は、対象ファイルが他プロセス（エディタ・ウイルス対策）に握られていると失敗しうる（**推測**。参考にも実測の記録は無い）
- 片付けの提供コマンドで同じ処理を持つ場合、失敗を握りつぶさず報告する設計にする

---

## 付録: 判定のサマリ

- **流用（ほぼそのまま）**: パス指定 add（`create-commit.sh`）、id 抽出・重複・破断リンク・`<style>` 数え・負のコントロール（`deliverables.md` + `test_report_templates.sh`）、未コミット検査、パス限定コミット、fail-open ログの型、frontmatter ブロック切り出し、インライン配列の分解、TSV 分割
- **改変**: frontmatter パーサ（入れ子・インラインマップ）、連番採番（4 ディレクトリ化・10 進強制）、`next` の依存解決（飛ばす方式へ）、除外パターン（Markdown → txt）、push 前チェック（自己申告 → 自動判定）、外部リソース検査（`<a href>` 除外）、チケットテンプレート
- **新規**: `logger.sh`、`redact`、雛形 2 種、`ticket.sh` の全サブコマンド、完了検査の中身、取り消し、`check-html.sh` のスクリプト化と RV006、`commit.sh` の全検査、`push.sh` の 4 項目と `--set-upstream`
