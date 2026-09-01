---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0014", "0024"]
executor: main
human_review: {required: true, reason: "中核（提供コマンド・lib）を含む実装。切れ目で 1 回（承認④により opus 自己レビューで代替）"}
adversarial_review: {required: false, reason: "実装の切れ目で 1 回"}
allow:
  write: [".claude/hooks/lib/**", "wip/**"]
  ops: ["read", "build-test", "hook-test"]
started_at: "2026-09-01T13:55:42+09:00"
completed_at: "2026-09-01T14:27:43+09:00"
base_sha: "d36cfea"
---

# 0015 AI アセット実装 S2-2: hooks/lib 5 本（hook-common / cmdpos / scope / push-detect / transcript）

## 目的

フック共通ライブラリ 5 本をフック共通仕様どおりに作り、2/3 のフック本体がそのまま乗れる状態にする。フック本体は作らない・登録しない。

## DoD

- [x] `hook-common.sh` が §3（deny / ask / notify ヘルパの内側で `redact`）・§4（緊急停止と `disabled` 記録）・§5（`decisions.jsonl` スキーマ・セッション状態の原子的更新）・§10（ヘッドレスで ask → deny）・`hook_jq`（CR 除去）を実装し、HK-T03（lib 部分）・T04・T06・T07・T08・T10 が通る（根拠: `.claude/hooks/lib/hook-common.sh`（`hook_deny` / `hook_ask` / `hook_notify` / `hook_inject` / `hook_record` の内側で `__hc_redact_to_reply`、`hook_enforce_enabled` + `hook_disabled`、`hook_session_write` は tmp → `mv -f`、`hook_ask` はヘッドレスで `hook_deny`、`hook_jq` は CR 除去）。`test_hook_common.sh` 79 assert 全 PASS（HK-T03 / T04 / T06 / T07 / T08 / T10））
- [x] `cmdpos.sh` が §7 の 1〜8（前処理・分割・ラッパー剥がし・正規化・opaque・PowerShell・縮退・提供コマンド識別）を実装し、HK-T05・HK-T12 が通る（根拠: `.claude/hooks/lib/cmdpos.sh`（`_cp_normalize_to_reply` = 7-1、分割 = 7-2、`_CP_PREFIX_WORDS` = 7-3、`_cp_basename_to_reply` = 7-4、`CP_OPAQUE` = 7-5、`_cp_ps_preprocess_to_reply` + `CP_GITLIKE` = 7-6、`CP_DEGRADED` = 7-7、`CP_PROVIDED` = 7-8）。`test_cmdpos.sh` 135 assert 全 PASS（HK-T05 / T12。BG-T01〜T09b の例を lib 単位で網羅））
- [x] `scope.sh` が §8 の判定順・glob 規則（`*` は `/` を跨がない）・`ops` 分類（`build-test` の `tests/` `test/` 配下 sh を含む）・`d.write` / `d.ops` の絞り込みを実装し、`frontmatter.sh` を読み込み行（deny ポリシー）で source して HK-T11 が通る（根拠: `.claude/hooks/lib/scope.sh`（`scope_resolve` (1)〜(7)、`_sc_glob_to_re`、`scope_classify`、`scope_op_declared`、`scope_load_ticket` は `fm_get` / `fm_list`、冒頭に `__ss_load frontmatter deny`）。`test_scope.sh` 105 assert 全 PASS（glob 20 件・判定順・宣言は広げられない・ops・分類 37 件・設定不正 6 件））
- [x] `push-detect.sh` が `post-push-compact-prompt` 仕様の push 検知（fork ゼロの前置フィルタ・`tool_response` による成功判定・`@{upstream}` の縮退）を実装し、HK-T13（0024 で §11 に追加）が通る（根拠: `.claude/hooks/lib/push-detect.sh` の `push_detect`。`test_push_detect.sh` 26 assert 全 PASS（bare リモートへの実 push で `pushed` / `not-advanced` / `head-not-on-upstream` / `head-not-on-origin-branch` / `degraded-exit-code` / `exit-1` / `not-a-push` / `no-push-word`、PATH を空にしても fork なし））
- [x] `transcript.sh` が `post-push-usage-report` 仕様の集計をカーソル付きの 1 関数で実装し、HK-T14（0024 で §11 に追加）が通る（根拠: `.claude/hooks/lib/transcript.sh` の `transcript_aggregate`（1 回の jq。ファイルパス渡し）。`test_transcript.sh` 21 assert 全 PASS（全件 / カーソル差分 / 同カーソルで同値 / 超過カーソル / 追記分 / 不在・空・CRLF / オフセット付き時刻 / jq 不在））
- [x] H1（redact を通す前にログへ書く経路が無い）・H2（無視リストは `logs/**`）が満たされている（根拠: H1: `hook-common.sh` の `log_*` 呼び出しは `hook_record` の 1 か所で、引数はすべて redact 済み（`grep -n 'log_info' hook-common.sh` で確認）。出力ヘルパの本文も内側で redact。HK-T06 が `token=` / `ghp_` を含む理由で記録と出力の両方にマスクを検査。H2: `scope_resolve` (1) で `logs/**` を skip、`state_files` は除外しない（HK-T11））
- [x] 全 lib が `bash -n` を通り `run-tests.sh --filter '.claude/hooks/**'` が全通過（根拠: `bash -n` 10 ファイル通過。`run-tests.sh --ids` 全体で `OK: 14 本 / 55 件`（hooks 配下 6 本を含む）。PASS ID に HK-T03 / T04 / T05 / T06 / T07 / T08 / T10 / T11 / T12 / T13 / T14、FAIL なし、重複なし）
- [x] プレースホルダ（`{{ }}`・`TODO`・`TBD`。テンプレート `assets/*.template.*` は対象外）と frontmatter の検査が 0 件（根拠: 新規 10 ファイルに `grep -nE '\{\{|TODO|TBD'` → 0 件。frontmatter は対象なし（sh のみ））
- [x] 参照更新一覧の検索語で新規アセットに旧名が持ち込まれていない（0 件）（根拠: 旧名 5 語 + 参考固有の `.claude/hooks/.state` / `shell-script-style` → 0 件。CR 0 ファイル）
- [x] `git diff --stat <base_sha>` が許可範囲内（根拠: `git diff --name-only d36cfea` は `.claude/hooks/lib/**`（10 ファイル）と `wip/` のみ）
- [x] 実装結果レポート `wip/30_reports/0013-ai-asset-implementation.md` に担当ステップの節（作成・更新したアセットと仕様の節・テスト結果・検査結果・逸脱）を追記した（根拠: 「### 0015 S2-2」を 作成・更新したアセット / テスト結果 / 検査結果 に追加、逸脱 D-22〜D-27、想定と異なった点 3 件を追加）

## 作業内容

- 順: hook-common → cmdpos → scope → push-detect → transcript。1 本ごとにテストを通してから次へ
- 流用元は調査レポート Q1（付録 A §1〜§3）。移植時に参考固有の記述と参考のログ行を持ち込まない
- フック本体が要るテスト（HK-T01・T09・T03 の登録部分）は書かず、作業ログに 2/3 送りと明記

## 作業ログ

### 現在地

- 済: hook-common → cmdpos → scope → push-detect → transcript の順に実装し、1 本ごとにテスト
- 済: `run-tests.sh --ids` 全通過（14 本 / 55 件）、検査 0 件、H1 / H2 確認
- 済: レポート追記、DoD 記入
- 完了: `commit.sh` → `ticket.sh complete 0015`

### うまくいったこと

- 参考実装の正規化部（クォート・ヒアドキュメント・コメント・`$( )`）は無改造で流用でき、`cmdpos.sh` のテスト 135 件が初回からほぼ通った（走査部の書き直しに集中できた）
- テストをドライバ sh + 別プロセスで書いたことで、fail-closed（未捕捉エラー → deny JSON 1 行・終了 0）と fork ゼロ（PATH を空にしても動く）を観察できた
- hook-common の JSON 組み立て・redact・時刻を純 bash にしたので、拒否側フックのホットパスで起動する外部プロセスは入力 JSON の jq 1 回だけになる見込み

### うまくいかなかったこと

- `redact` の `Bearer` パターンが置換後の `***` に再一致して無限ループになり、テスト全体が 120 秒でタイムアウトした（バックグラウンドに回ったタスクを止めて修正）。置換ループは「結果が再び当たらない」ことをパターンごとに確かめる必要がある
- Windows の jq 1.6 で `fromdateiso8601` が動かず、最初の実装ではタイムスタンプが全部落ちた（参考実装が自前の暦計算を持っていたのはこのため）
- `local i="$1" exe="${CP_EXE[$i]}"` のように同じ `local` 文で前の変数を参照すると `set -u` で落ちる（`local` の全引数が代入前に展開される）

### 仕様からの逸脱

- D-22: cmdpos の出力の形（bash 配列 `CP_*`）を決めた。§7 は項目のみ
- D-23: `tool_response` の終了コードのフィールド名（`exit_code` / `exitCode` / `returnCode` / `code`、無ければ 0、`interrupted` は失敗）を決めた。実機の形は未確認
- D-24: transcript のカーソルは「処理済み行数」
- D-25: redact の 40 文字超パターンは `/` を含む語を除く（パスを壊さないため）
- D-26: scope.sh の判定順・宣言・ops 分類・設定検査のテストを HK-T11 に付けた（§11 に ID が無い）
- D-27: scope.sh の frontmatter 読み込みは deny ポリシー（チケットどおり）。案内側フックが source したときの挙動は 2/3 で確認
- 詳細はレポート「仕様からの逸脱」D-22〜D-27

### 判断と根拠

- lib の関数名は仕様に無いので `hook_*` / `cmdpos_*` / `scope_*` / `push_detect` / `transcript_aggregate` で統一した（仕様にある `redact` / `tool_class` / `hook_jq` / `hook_enforce_enabled` はそのまま）。2/3 のフック本体はこの名前を使う
- `HOOK_ROOT` はライブラリの置き場から導く（`lib` → `hooks` → `.claude` → ルート）。テストは `HOOK_ROOT` を一時リポジトリに向けて記録先を切り替える
- `find` は `-exec` / `-execdir` / `-ok` / `-okdir` があるときだけ opaque にした（参考実装は無条件。`find . -name` を WF209 にしないため。§7-5 の列挙「`find ... -exec`」どおり）
- 提供コマンドの識別は「`bash` / `sh` の直後のトークン」に限った（`bash -n <path>` は構文検査で実行ではないので提供コマンドにしない。`scope_classify` は `bash -n` を read にする）
- `hook-test` の分類は提供コマンドの判定より先に行う（`.claude/hooks/**/tests/*.sh` は提供コマンドの形にも一致するため）
- push 検知の前置フィルタは「文字列に `push` を含む」だけにした（`push.sh` も `git push` も含む。`git` を条件にすると提供コマンドを落とす）
- `git 'commit'` のようにクォートで割った語は判定できない（参考実装と同じ既知の制約。サブコマンドは `_` になる）。block-direct-git は `_` を「特定できない」として扱える

### 拒否・確認・迂回の記録

- なし（フック・提供コマンドの拒否なし）

### 使った AI アセットと効き目

- `20-common-step-shell-script`（`test.template.sh` の骨格、`test-lib.sh` の `run_cmd` / `make_tmp_repo` / `make_restricted_path` / `hook_payload` / `tl_jq`、`run-tests.sh --ids`）: 5 本のテストを同じ型で書けた。`make_restricted_path` で jq 不在・PATH 空の観点がそのまま書けた
- `frontmatter.sh`（`fm_get` / `fm_list`）: scope.sh がチケットの宣言を自前で解析せずに済んだ
- 調査レポート付録 A（流用 / 改変 / 新規の判定と H1〜H6）: 何を流用し何を書き直すかの迷いが無かった
- `20-common-step-ticket` / `20-common-step-commit-push`: 状態遷移とコミット

### スコープ外で見つけたこと

- フック共通仕様 H6 に「jq 1.6（Windows）では `fromdateiso8601` / `strptime` が使えない」を足すべき
- §11 に判定順・ops 分類のテスト ID が無い（D-26）。`tool_response` の形（D-23）は 2/3 の実機確認項目
- `hook_payload`（test-lib）は `session_id` が固定 `testsession` で、HK-T07 のような分離のテストには手書きの JSON が要る。`--session` 引数を足すと楽

### AI アセットに反映すべき内容

- フック共通仕様: §7 に cmdpos の出力の形（D-22）、§3 に redact のパターン注記（D-25）、§11 に HK-T15 の検討（D-26）、H6 に jq の strptime（上記）→ 0022
- `post-push-compact-prompt` 仕様: `tool_response` の形の確認と明記（D-23）→ 0022 / 2/3
- `post-push-usage-report` 仕様: `last_offset` の単位（D-24）→ 0022
- `test-lib.sh` の `hook_payload` に session_id の指定を足す → 0022

### 備考

- 5 本とも `source` 専用。フック本体（2/3）は `. "$(dirname "${BASH_SOURCE[0]}")/../lib/hook-common.sh"` の形で読み、`hook_init <名前> deny|guide <WFx09>` → `hook_fail_closed`（拒否側）→ `hook_read_input` の順に使う想定

### うまくいったこと

### うまくいかなかったこと

### 仕様からの逸脱

### 判断と根拠

### 拒否・確認・迂回の記録

### 使った AI アセットと効き目

### スコープ外で見つけたこと

### AI アセットに反映すべき内容

### 備考
