---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0021"]
executor: main
human_review: {required: true, reason: "振る舞いが変わる（承認④により opus 自己レビューで代替。切れ目の note に追記）"}
adversarial_review: {required: false, reason: "切れ目の敵対的レビューの指摘対応。上限（切れ目 1 回）に達している"}
allow:
  write: [".claude/rules/**", ".claude/hooks/lib/**", ".claude/hooks/config/**", ".claude/hooks/tests/**", ".claude/skills/20-common-step-*/**", ".claude/evals/**", "wip/**"]
  ops: ["read", "build-test", "hook-test", "remote-read"]
started_at: "2026-09-01T15:21:02+09:00"
completed_at: "2026-09-01T16:07:59+09:00"
base_sha: "2475fce"
---

# 0025 AI アセット実装・追加（敵対的自己レビュー F-1〜F-25 の対応）

## 目的

0013〜0021 の切れ目で行った opus 自己レビュー（PR #7 の boundary:note ai-asset-implementation:0021、全文 wip/tmp/review-impl-findings.md）の confidence >= 0.5 の指摘 19 件のうち実装で解消できるもの（F-1〜F-6・F-8〜F-14・F-17〜F-19）と、軽微だが安価な F-20・F-21(a)・F-22・F-23(b)・F-24・F-25(b) を直す。仕様の判断が要る F-7・F-15・F-16・F-23(a)・F-25(a)(c) は 0022 の候補に載せ、ここでは触らない

## DoD

- [x] F-1 / F-24 / F-18(a): commit.sh が git add 後に実際にステージされた全パス（git diff --cached --name-only）へ除外パターンを当てて除外分を reset し、ディレクトリ引数は CP001 で拒否する。CP-T03 にディレクトリ・symlink・.gitignore 混在のケースがあり、SKILL.md の文言（対象はファイル単位）を合わせた（根拠: commit.sh 手順 4 でステージ後に `git diff --cached --name-only` の実パスへ `matches_exclude` を当て直し一致は `git reset` + CP003。引数の `-d` 判定で CP001 終了 2（末尾 / と symlink も -d）。CP-T03 に `src` / `src/` / `linkdir` のケース（コミット数不変・`src/.env` 未追跡を確認）と `src/a.ts src/.env` の正常系。SKILL.md 手順 3 に「対象はファイル単位で渡す」）
- [x] F-2 / F-18(b): push.sh はスキップ記録を HEAD のコミット済み版（git show HEAD:wip/push-check-skip.md）からだけ読み、未コミットの記録では項目を飛ばせない。テスト（CP-T06 または CP-T07）に未コミット記録のケースがある（根拠: `read_skip_file` が `git show HEAD:wip/push-check-skip.md` の内容だけを読む。CP-T06 に「作業ツリーだけの `- 項目 1:` + dirty.txt」で exit 1・`項目 1: 未コミットの変更が`・`skip 項目 1` 不在。SKILL.md 手順 2 に「読まれるのはコミット済みの版だけ」）
- [x] F-3: script.template.sh と提供コマンド全部（commit.sh / push.sh / ticket.sh / check-html.sh / run-tests.sh）の読み込み行の nop 分岐で LOGGER_ROOT を必ず設定し、logger.sh 不在で commit.sh -m ... が CP<番号>: または OK: で終わる。SS-T に logger 不在のケースがある（根拠: 読み込み行の `nop)` 直後に `LOGGER_ROOT="${r:-$PWD}"; export LOGGER_ROOT;` を追加し、同じ行を持つ 22 ファイル（雛形 2・提供コマンド 5・lib 1・テスト 13・SKILL.md / logger.md）を同一文字列に置換（SS-T02 の一致検査 PASS）。CP-T01 に logger.sh を退避して `env -u CLAUDE_PROJECT_DIR -u LOGGER_ROOT` で commit.sh を実行するケース: `OK: 1 ファイルをコミットした` / `CP002:` で終わり stderr 空）
- [x] F-4: check-html.sh の属性値抽出（src / href / id / @import 相当）が二重引用符と単一引用符の両方に対応し、RV-T02 に単一引用符の負のケースがある（根拠: `Q="[\"']"` / `NQ` で `extract_ids` / `extract_required` / src / link href / href="#" / data-template の抽出を両引用符対応に。RV-T02 に `src='https://evil…'` ×2 + `id='sq1'` + `href='#sq1'` で `RV002: …（2 件）` かつ RV004 なし）
- [x] F-5 / F-6 / F-21(a) / F-25(b): ticket.sh complete が根拠欄の無い - [x] 行を未充足に数える（TICKET-T03 に追加）、cancel --reason と set_field の値の & と \ をエスケープする（TICKET-T09 に記号入りのケース）、未コミット判定を grep -Fvx の完全一致にする、commit.sh の -m 値なしは CP001 終了 2（根拠: complete に `grep -nv '（根拠:'` の検査（メッセージ「根拠欄そのものが無い」）、TICKET-T03 に `- [x] g` を足して未充足 7 件。`sed_escape` で `\`→`\\` `"`→`\"`（YAML）と `&` `|` のエスケープ・改行を空白に、TICKET-T05 の理由を `不要 & 重複 | "引用" \ 記号` にして frontmatter が `cancel_reason: "不要 & 重複 | \"引用\" \\ 記号"` になることを grep -F で確認。未コミット判定は `awk 'substr($0, 4) != p'`。commit.sh の `-m` 値なしは CP001 終了 2（CP-T04 に追加））
- [x] F-10 / F-19(a)(c): scope.sh でルート直下ファイルの承認単位をファイル単位にして承認済み "." が全体 allow にならない（HK-T11 に追加）、cmdpos の CP_GITLIKE を対象セグメントの exe / args だけで判定し gitlike=0 の負のケースを HK-T05 に置く、hook_record の id / decision も JSON エスケープを通す（根拠: scope_resolve (6) で `"."` を読み飛ばし (7) のルート直下は `SC_ASK_SCOPE="$p"`。HK-T11 に承認 `[".", "README.md", "logs"]` で README.md / logs/mr.json が allow 6、LICENSE / other/x.txt が ask 7 のケース。cmdpos の gitlike は `CP_LOWER =~ (^|[^a-z0-9_.-])git(\.exe)?([^a-z0-9_-]|$)`、HK-T05 に `'git' commit` / `"git.exe" push` = 1、`'digit'` `'legit'` `'github'` `'gitlab'` = 0。hook_record で `decision` / `id` を `__hc_json_str` に通す）
- [x] F-12 / F-13: redact のパターン 3 のキー名を [A-Za-z_]*(secret|token|key|password)[A-Za-z_]*= に広げ AWS 形式（/ を含む 40 文字）をマスクし、規則 5 は英小文字とハイフンだけの語（ブランチ名・チケット名）を対象外にする。HK-T10 に AWS 形式の正のケースと長いブランチ名の負のコントロールがある（根拠: パターン 3 を `(token|password|passwd|secret|(api|access|private|auth|client|secret[_-]?access)[_-]?key)=` に、規則 5 をカーソル走査にして `( *-*-* かつ大文字なし ) または [A-Z0-9+=-] を含まない` 語を残す。HK-T10 に AWS_SECRET_ACCESS_KEY（`/` 入り 40 字）= ***、PRIVATE_KEY / client-key / access_key、hex 40（大小混在）= ***、`feature-6-workflow-foundation-and-more-stuff` / `0025-ai-asset-…` / `some_very_long_…_chars` = そのまま。既存 17 ケースも PASS）
- [x] F-9 / F-11 / F-14 / F-17 / F-19(b): テストの実質化 — cmdpos の語彙定数（ラッパー / opaque / 書込先）と scope の読み取り一覧・git 読み取りサブコマンド・gh 分類・tool_class の分類表を配列で全要素ループ検査する、HK-T05 の負のケースに正の期待値（count / exe）を併記する、HK-T13 / HK-T14 の fork ゼロ・jq 1 回を呼び出し記録 PATH で回数として検査する、HK-T08 に CI=false の負のケースを置く。いずれもレビューの変異（M7〜M19・M29）を再現して FAIL することを確かめた（根拠: `case_hk_t05_vocab`（`_CP_PREFIX_WORDS` 全 20 語・`_CP_OPAQUE_WITH_OPT` 全 13 語 × 2・`_CP_OPAQUE_WORDS` 6 語・書込先 10 コマンド・負ケースの `count=1` `seg0: exe=grep|echo|cat|ls`・gitlike 6 件）、test_scope に `_SC_READ_ONLY_CMDS` 全語・`_SC_GIT_READ_SUBCMDS` 全語・git/gh/glab/find/bash/npm の 45 行、test_hook_common に `tool_class` 14 行と `CI=false` / `CI=0`、`make_counting_path` で HK-T13（`git status` / `grep "git push"` で 0 回、`git push` で git > 0 の正のコントロール）と HK-T14（jq ちょうど 1 回）。実装 7 ファイルを `git stash` で戻して流すと cmdpos 4 / scope 6 / hook_common 5 / commit 14 / push 2 / ticket 3 / check_html 2 = 36 件 FAIL（レビューの変異 M7〜M19・M29 相当が見える）、戻すと 0）
- [x] F-8: ルール 4 本（work-defaults / logger / design-docs / ai-asset-design-docs）の eval 定義が .claude/evals/ に eval.template.md の形であり、ID の接頭辞が台帳・既存 eval と重複しない（未実行の明記）（根拠: `.claude/evals/{work-defaults,logger,design-docs,ai-asset-design-docs}.md` を eval.template.md の 5 節で作成。ID は WD-E / LR-E / DD-E / AD-E 各 01〜03（台帳・既存 eval AC/FM/IS/RQ/SP・テスト ID CP/LG/SS/FR/TR/TICKET/RV/HK と重複なし）。実行状況は未実行）
- [x] F-20 / F-23(b) / F-22: push.sh の jq 検査を logs/merge-state.json が存在するときに限定した。work-defaults.md の前文に「載っていない種類はスキルの既定に倒し、基準に無いことを明示して合意する」を追加した。レポート 0013 の文言（テンプレート 11 本・旧名は仕様書に 1 件）を訂正し、HTML に逸脱 D-1〜D-28 の一覧表を載せ check-html.sh OK（根拠: push.sh の `command -v jq` を `if [ -f "$MERGE_STATE" ]` の内側へ。work-defaults.md 前文末尾に「この表に載っていないタスクの種類は、スキルの既定（…）に倒し、基準に無いことを明示してユーザーと合意する。」。レポート 0013 の要約を「テンプレート 11 本」に、HTML の再検索の文言に仕様書の 1 件を明記し、HTML に `<section id="deviations">`（D-1〜D-34 の表、md から生成）と f10 を追加、`check-html.sh` OK（id 25 件））
- [x] run-tests.sh --ids が全通過し、ID の追加分（あれば）が仕様のテスト観点と対応している。レポート 0013 に 0025 の節（変更したアセット・追加したテスト・逸脱）を追記した（根拠: 最終 `OK: 14 本 / 55 件`、FAIL なし、重複なし。ID の追加はなし（観点は既存 ID に付ける D-26 の運用）。レポート 0013 に「### 0025 追加」（アセット表）・「### 0025（最終）」（テスト結果）・「### 0025」（検査結果）・D-29〜D-34・想定と異なった点 3 件・残課題 2 件を追記）

## 作業内容

- review-impl-findings.md の F-1〜F-25 を順に読み、修正 → 該当テストに負のケース追加 → 個別テスト → 全体テストの順で進める
- 各修正の前にレビューの再現手順（一時リポジトリ）で FAIL を確かめ、修正後に PASS を確かめる
- 0022 送りの F-7 / F-15 / F-16 / F-23(a) / F-25(a)(c) は作業ログ「仕様からの逸脱」に写すだけで実装に触れない

## 作業ログ

### 現在地

- 済: F-1〜F-6・F-8〜F-14・F-17〜F-20・F-21(a)・F-22・F-23(b)・F-24・F-25(b) の修正とテスト追加 → 全テスト PASS → 旧実装で FAIL を確認 → eval 4 本 → レポート 0013 の追記と HTML → このチケットの記入
- 完了: `commit.sh` → `ticket.sh complete 0025` → `push.sh` → PR #7 の note に追記 → 0022 へ

### うまくいったこと

- レビューの「再現手順」をそのまま負のケースにでき、修正前に FAIL・修正後に PASS を機械的に確かめられた（実装 7 ファイルだけ `git stash` で戻す）
- 語彙表を全要素ループで踏むテストにしたら、レビューが挙げていない欠陥（`gh api -X POST` の値がパスに化ける）が最初の実行で見つかった。表形式の実装は表形式のテストで検査する価値が実証された
- `make_counting_path` で「fork ゼロ」「jq 1 回」を回数として検査でき、`2>/dev/null` で隠した fork にも効く

### うまくいかなかったこと

- `test_check_html.sh` が TIMEOUT（120 s）に触れた。`check-html.sh` が 1 回 12 s（bash の多バイト文字列のパターン照合と 1 行ごとの fork）で、0021 までは偶然収まっていた。fork を減らして 8 s にしたが根本対策は残課題
- RV-T02 の追加ケースを既存の assert 列の途中に差し込み、直後の assert が別の実行結果を見ていた（`R_OUT` の上書き）。末尾に移して解消
- `sed` の置換文字列の `\"` は `"` になる。旧コードの `cancel_reason` も `"` を含む理由で YAML を壊していた（テストが試していなかった）

### 仕様からの逸脱

- D-29〜D-34（レポート「仕様からの逸脱」）: CP001 のディレクトリ拒否、skip 記録は HEAD の版、nop の LOGGER_ROOT、frontmatter 値の YAML エスケープと根拠欄なしの検査、承認単位 "." の禁止、redact の除外条件
- 0022 送り（実装で触れていない）: F-7 / F-15 / F-16 / F-23(a) / F-25(a)(c)。理由は作業内容の 3 項目目どおり

### 判断と根拠

- F-7 は実装・テストを据え置いた: `read` / `remote-read` を宣言必須にすると、読むだけの計画タスクが宣言漏れで拒否される。仕様を「常に可」に直す提案が妥当（0022）
- F-13 の除外条件は「ハイフン 2 個以上かつ大文字なし」と「小文字と `_` のみ」: base64 / hex は通常ハイフンを含まず、含む url-safe base64 は大文字を含む。ブランチ名・チケット名・識別子はこの 2 形。リスク（小文字ハイフン区切りの秘密）は受け入れて注記（D-34）
- F-12 で `key=` 単独は加えない（`monkey=` 等の誤爆）。`*_key` の接頭語を列挙した
- F-1 はディレクトリを拒否したうえで、ステージ後の実パス検査も残した（指定と実パスが異なる経路の保険。両方とも失敗側に倒す）
- F-2 は「HEAD の版だけ読む」にした: 未コミットの版を読んで項目 1 で止める案は、項目 1 自身を飛ばす行で無効化されるため
- `check-html.sh` の高速化はレビューの指摘ではないが、TIMEOUT でテストが不安定になるため最小限（fork 削減・C ロケール）だけ行った
- 敵対的レビューはこのチケットでは実施しない（切れ目 1 回の上限。frontmatter どおり）

### 拒否・確認・迂回の記録

- なし（提供コマンド・フックの拒否なし）

### 使った AI アセットと効き目

- `20-common-step-shell-script`（`test-lib.sh` の `make_restricted_path` を土台に `make_counting_path` を追加、`run-tests.sh --ids`）: 計数 PATH の追加が 20 行で済んだ
- `20-common-step-report-view`（`check-html.sh`）: HTML の追記後の検査
- `20-common-step-ticket` / `20-common-step-commit-push`: 状態遷移とコミット
- レビュー結果 `wip/tmp/review-impl-findings.md`: 再現手順が具体的で、負のケースをそのまま書けた

### スコープ外で見つけたこと

- `gh api -X POST …` の値がパスに化ける（修正済み。語彙ループで発見）
- `check-html.sh` の `strip_comments` が純 bash のループで遅い（残課題）
- `HOOK_DENY_ID` の既定 `WF009` が台帳の `WFx09`（x = 1〜5）に無い番号（レビューの限界欄。2/3 で決める）

### AI アセットに反映すべき内容

- 仕様へ（0022）: D-29〜D-34、F-7 / F-15 / F-16 / F-23(a) / F-25(a)(c)。テスト観点として「語彙表の全要素」「負のケースの正の期待値」「fork / 呼び出し回数の計数」を shell-script 仕様のテスト節（または `bash-script` ルール）に書く候補
- `20-common-step-shell-script` SKILL.md / test-lib: `make_counting_path` の使いどころ（性能・実装の約束の検査）を 1 行

### 備考

- レビュー全文は一時ファイルのまま（`wip/tmp/` は gitignore）。要点は PR #7 の note・レポート 0013・このチケットに写した
