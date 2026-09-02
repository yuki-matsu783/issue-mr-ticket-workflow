---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0027"]
executor: main
human_review: {required: true, reason: "基準どおり（振る舞いが変わる。承認④により opus の敵対的自己レビューで代替）"}
adversarial_review: {required: true, reason: "基準どおり（フック本体 6 本の追加）"}
allow:
  write: [".claude/hooks/**", "wip/10_tickets/**", "wip/30_reports/**", "wip/tmp/**"]
  ops: ["read", "remote-read", "hook-test", "build-test"]
started_at: "2026-09-02T20:12:06+09:00"
completed_at: ""
base_sha: "200df48"
---

# 0029 案内側フック 6 本とテスト

## 目的

登録段階 ① に載る 6 本を書く。案内側はラッパー無しで、失敗しても操作を通す

## DoD

- [x] session-start.sh があり、boundary.sh status --offline（3/3・未実装）が無ければ何も出さずに終了 0 する。依存する 8 件のテスト観点（SE-T01〜04・07〜09・WE-T10 と SE-T05 / SE-T06 の前半）は書かず、#10 へ送る旨を作業ログに書いた（根拠: `.claude/hooks/00-SessionStart/session-start.sh`。`boundary.sh` 不在・`jq` 不在・status 失敗のいずれでも無出力で終了 0 する。テストは `test_session_start.sh`（SE-T05 後半 / SE-T06 後半 = 14 件 FAIL 0）。3/3 へ送った 9 件は作業ログ「判断と根拠」に列挙）
- [x] workflow-diff-check.sh があり、scope.sh の同じ許可範囲 A で範囲外を判定する。テストが通る（根拠: `.claude/hooks/22-PostToolUse/workflow-diff-check.sh`。判定は `scope.sh` の `scope_resolve` だけを使い独自の範囲を持たない。`test_workflow_diff_check.sh` の DC-T01〜T07 = 43 件 FAIL 0）
- [x] post-push-compact-prompt.sh があり、push-detect.sh を状態非依存で使う。テストが通る（根拠: `.claude/hooks/22-PostToolUse/post-push-compact-prompt.sh`。起点 sha を自分の `push-state.json` から渡す（`push_detect` は状態を読まない）。`test_post_push_compact_prompt.sh` の PP-T01〜T08 = 37 件 FAIL 0）
- [x] post-push-usage-report.sh があり、--accumulate と既定の両方で hc_lock usage-<branch> を取ってから加算し、取れなければ 2 秒で諦めて実行ログに 1 行残して終了 0 する。時刻の変換は自前の暦計算（strptime を使わない）。テストが通る（根拠: `.claude/hooks/22-PostToolUse/post-push-usage-report.sh`。`--accumulate` と既定の両方が `hc_lock usage-<branch>` を取ってから加算し、取れなければ実行ログに 1 行残して終了 0 する。時刻は `transcript.sh` の自前の暦計算（`strptime` を使わない）。`test_post_push_usage_report.sh` の UR-T01〜T07 = 36 件 FAIL 0）
- [x] subagent-start-check.sh があり、PreToolUse Agent（WF801 を systemMessage + additionalContext の 2 経路・WF803 の background 警告）と SubagentStart（要点の注入）の両方の入口を持つ。テストが通る（根拠: `.claude/hooks/12-SubagentStart/subagent-start-check.sh`。PreToolUse `Agent` と SubagentStart を `hook_event_name` で分ける。`test_subagent_start_check.sh` の SA-T01〜T09 = 56 件 FAIL 0）
- [x] subagent-stop-check.sh があり、tool_response.status（completed / async_launched）で分岐し agentId（camelCase）を読む。SubagentStop と PostToolUse Agent の両方の入口を持つ。テストが通る（根拠: `.claude/hooks/13-SubagentStop/subagent-stop-check.sh`。`tool_response.status` で `completed` / `async_launched` を分け、`tool_response.agentId`（camelCase）で SubagentStop の記録を引く。`test_subagent_stop_check.sh` の SP-T01〜T08 = 51 件 FAIL 0）
- [x] 6 本とも実装の型（HOOK_DENY_ID の代入 → lib の source → hook_init）に従い、bash -n を通り（`shellcheck` はこの環境に未導入で未実施）、bash <script> < 入力 JSON の単体実行が終了 0 で通る（根拠: 6 本とも `HOOK_DENY_ID` の代入 → `__ss_load logger nop` → lib の source → `hook_init` の順。`bash -n` は 6 本とも通る。各テストが `bash <script> < 入力 JSON` の形で本体を起動しており、終了 0 を `assert_exit` で固定している）
- [x] 6 本に「4c プローブ」を仕込んだ。環境変数 WORKFLOW_PROBE_4C=1 のときだけ有効で、(a) tool_response.status / agentId / agent_type / model / permission_mode / source / run_in_background の値と、その他のキーの有無と型だけを logs/hooks/probe-4c.jsonl に落とす、(b) subagent-start-check が Agent の呼び出しで無条件に systemMessage を 1 つ出す。既定（環境変数なし）では一切の副作用が無いことをテストで固定した。出力は hc_append_jsonl 経由にした（redact と 4 KB 切り詰めを得るため。並列のフックが 4 KB を超える行を書くと JSONL が割れる）。session-start ではプローブを早期 return の前に置いた（boundary.sh 不在で「何も出さずに終了 0」する経路の後だと source の行が一切残らないため）（根拠: `.claude/hooks/lib/probe-4c.sh` を 6 本すべてが source し、入力の読み込み直後・早期 return より前で `probe_4c` を呼ぶ。(b) は `subagent-start-check` の `probe_4c_enabled` 分岐（通知が 1 件も無いときに systemMessage を 1 つ出す）。既定で副作用が無いことは SE-T06 / PP-T01 / SA-T02 / SP-T01 の 4 本が `probe-4c.jsonl` の不在で固定している）
- [x] 4c プローブの逸脱 2 件を作業ログ「仕様からの逸脱」に書いた: (1) rules/logger.md の「値ではなく有無・長さ」からの逸脱（値を落とすのは上記 7 フィールドに限る）、(2) §5 の logs/ の表に無いパス（logs/hooks/probe-4c.jsonl）を一時的に増やすこと（§5 の表は正なのでこちらが重い）（根拠: 作業ログ「仕様からの逸脱」の 1・2 に記載）
- [x] 新規に作った .sh（本体 6 本 + テスト）の `__ss_load` 行が assets/script.template.sh とバイト一致し、SS-T05 が通る（SS-T05 は .claude/hooks/** 全体を走査するため）（根拠: `test_templates.sh`（SS-T05 を含む）が 43 件 FAIL 0。SS-T05 は `.claude/hooks/**` 全体を走査する）
- [x] 6 本のテストが `run-tests.sh --filter '<glob>' --ids` で通る（boundary.sh 依存の 10 件を除く。除いた ID を作業ログに列挙した）（根拠: 6 本の filter 実行はすべて FAIL 0（上記の件数）。全件テストは 既定ロケールと LC_ALL=C.UTF-8 の両方で **21 本 / 112 件・FAIL 0**。`boundary.sh` 依存で書かなかった 9 件（SE-T01〜T04・T05 前半・T06 前半・T07・T08・T09）と WE-T10 は作業ログ「判断と根拠」に列挙）

## 作業内容

- 計画書 wip/20_plans/0016-ai-asset-implementation-plan.md のステップ 3 に従う
- 案内側は fail-closed ラッパーを付けない（§3）。失敗は通す
- 重い 2 本（session-start / post-push-usage-report）と軽い 4 本を含む。0006 f5 の分割を案内側 / 拒否側の区切りの内側で満たす
- .claude/docs/** には書かない。決定は作業ログ「判断と根拠」に書く
- WORKFLOW_PROBE_4C は環境変数なので AI には設定できない（§4）。プローブを有効にした実測は 0031 で人間が新しいセッションを起動して行う\n- 4c プローブが必要な理由: decisions.jsonl は 10 キー固定（§5）で permission_mode / model / tool_response / agent_type を入れる場所が無く、systemMessage を出す WF801 / WF803 は subagent_type が task-executor（.claude/agents/ は空で実装が無い）で executor が main 以外のときにしか発火しないため、そのままでは T9 が測れない
- ⓪ の登録により block-chmod は本番で生きている。chmod を使う作業が出たら WORKFLOW_BLOCK_CHMOD_ENFORCE=0 の新セッションで回避する

## 作業ログ

### 現在地

- 完了。6 本の実装と 6 本のテスト（新規 237 件）、全件テスト 2 ロケール（21 本 / 112 件・FAIL 0）、結果報告まで済み

### うまくいったこと

- **共有ライブラリが揃っていたので本体が薄く済んだ**。6 本とも「読む → 組み立てる → 記録する」だけで、判定規則を自前で持つ箇所は 1 つも無い。`workflow-diff-check` と `subagent-stop-check` は同じ `scope.sh` を通すので、許可範囲の判定が食い違わない
- **案内側の型が揃った**。`hook_fail` は案内側では `skip` を記録して終了 0 なので、fail-closed ラッパー無しでも「判定できないときは黙って通す」が自然に出る
- **既存テストが自分のバグを拾った**。`post-push-compact-prompt` の `push-state.json` が 1 度も書けていなかったこと（`jq --slurpfile` にプロセス置換を渡していた）は PP-T01 の `state_of` が空になって分かった。本体を書いた時点では気づいていなかった

### うまくいかなかったこと

- **テストが本物の github.com へ接続して認証プロンプトを出した**（ユーザーに見えた）。`post-push-compact-prompt` の PP-T04 でリンク形式を見るために origin の URL を `https://github.com/example/repo.git` に差し替え、**そのまま `git push` していた**。push 先はローカルの bare リポジトリに固定し、fake URL は「リンクの組み立てを見るための見せかけ」に限る形へ直したうえで、`GIT_TERMINAL_PROMPT=0` と空の `credential.helper` を下ごしらえに入れた
- **`git clean -qfdx` を下ごしらえのコミットより前に呼んで、テスト用リポジトリの `.claude` ごと消した**（`test_workflow_diff_check`）。素の状態を先にコミットする順序に直した
- **python のヒアドキュメントで制御文字を書き込んだ（2 回）**。`'\r'` と `"\u0000"` がエスケープされず、生の CR と NUL がシェルスクリプトに入った。「ファイルに書いてから実行する」は守っていたが、ヒアドキュメント経由だったので同じ罠だった。**シェル経由で python を書くときはエスケープ 1 段ぶん多く見る**

### 仕様からの逸脱

1. **4c プローブ (1)**: `rules/logger.md` の「値ではなく有無・長さを書く」からの逸脱。`tool_response.status` / `agentId` / `agent_type` / `model` / `permission_mode` / `source` / `run_in_background` の **7 フィールドに限り値を落とす**。T1〜T4 / T9 の結論を出すには値そのものが要る。0031 の実測が終わったら `probe-4c.sh` ごと消す
2. **4c プローブ (2)**: フック共通仕様 §5 の `logs/` の表に無いパス（`logs/hooks/probe-4c.jsonl`）を一時的に増やす。§5 の表は正なのでこちらのほうが重い。同じく 0031 の後に消す
3. **`workflow-diff-check` の `git status` に `-uall` を足した**。仕様（制御方式 4）は `git status --porcelain=v2 -z` と書いているが、既定では未追跡が**ディレクトリ単位に畳まれる**（`wip/` の 1 行になる）。畳まれたパスでは中身の許可範囲を判定できず、実測で `wip/`（未記載）が WF601 に化けた。**0032 で仕様側に書き戻す**
4. **`subagent-stop-check` の縮退判定の引き方**。仕様（制御方式 2）は「同じ `tool_response.agentId` についての `subagent-start-check` の記録」と書くが、**`subagent-start-check` が走る PreToolUse `Agent` の時点では agentId がまだ発行されていない**ので、記録に agentId を載せられない。実装は「このセッションの `subagent-start-check` の記録が 1 件でもあるか」で引く。縮退は「登録行が外れている」というセッション横断の条件なので、単位としてはこちらのほうが実態に合う。**0032 で仕様側に書き戻す**
5. **`subagent-start-check` の 2 経路出力**（`systemMessage` + `additionalContext`）に `hook-common` の公開 API が無く、`__hc_redact_to_reply` / `__hc_json_str`（private）を直に使った。0032 で公開 API 化を提案する
6. **SP-T08 の `executor` の例**（仕様は `sub-opus`）は `model-aliases.txt` に無い表記なので、テストは `work-defaults.md` と同じ族名（`opus`）で書いた。`sub-opus` のままだと正規化できず「model が特定できない」に落ちて、観点（不一致の検知）が成立しない
7. **WF911 / WF913 の識別子を本文の先頭に自分で置いた**。仕様の「記録」節が `inject` を求めるので `hook_inject` を使うが、`hook_inject` は `hook_notify` と違って識別子を本文に付けない。付けないと additionalContext に `WF911` の文字列が 1 つも現れず、AI が識別子で引けない（テストが拾った）

### 判断と根拠

- **`session-start` のテストは SE-T05 後半・SE-T06 後半だけ**（14 件）。`boundary.sh`（3/3・issue #10）が無い環境では「本物と一致するか」という観点が成立せず、偽実装で代えると観点そのものが失われる（DDR i0009-09）。**3/3 へ送った 10 件**: SE-T01 / SE-T02 / SE-T03 / SE-T04 / SE-T05 前半 / SE-T06 前半 / SE-T07 / SE-T08 / SE-T09 / WE-T10
- **`workflow-diff-check` は、今回の操作で承認された範囲をその場の差分判定にも反映する**（`SC_APPROVED` に足してから範囲判定に入る）。足さないと「未記載パスへの Write が承認されて実行された直後に、そのファイルが WF601 として列挙される」ことになり、承認の記憶の意味が無い
- **`workflow-diff-check` は `approvals.json` にロックを取らない**。ホットパス（§1 の 5 本）から `hc_lock` を呼ぶと `find` が毎回 fork する。`hc_json_write` の一時ファイル + `mv` による原子的な置き換えだけで守り、失われるのは「同時に別のフックが書いた承認 1 件」に留まる
- **`post-push-usage-report` の実作業時間は呼び手側で計算する**。`transcript.sh` は `timestamps` を返すだけという契約なので、間隔の足し合わせ（ユーザー入力の直前を除く・10 分超を除く）は本体の jq に置いた
- **`--accumulate` は停止中に記録も残さない**。Stop のたびに `decisions.jsonl` へ `disabled` が 1 行増えるのは記録として無意味なので、既定モードだけ `hook_disabled` を通す
- **`subagent-stop-check` は SubagentStop では出力しない**（記録のみ）。§12 T1 のとおりメインエージェントに届かないため、出しても捨てられる
- **`subagent-start-check` の対象チケットは `10_doing/` の先頭 1 枚**。2 枚以上は `workflow-guard`（0030）が拒否する範囲なので、こちらは黙って先頭を使う
- **`post-push-compact-prompt` の `logs/mr.json` のキーを `.mr` に直した**。正のキーは `00-workflow-issue-mr-driven` 仕様の `{"host","issue","mr","url"}` で、`.number` / `.iid` は別実装からの受け皿として残した

### 拒否・確認・迂回の記録

- **git の認証プロンプトが 1 回出た**（ユーザーから指摘）。原因は上記「うまくいかなかったこと」の 1 件目で、テストが fake URL のまま `git push` していたこと。**機構の拒否ではない**。認証情報は設定せず、テストがネットワークに出ない形へ直して解消した
- `block-chmod` は ⓪ で登録済みだが、今回 `chmod` を使う作業は無く、拒否も迂回も発生していない

### 使った AI アセットと効き目

- `20-common-step-shell-script` の `test-lib.sh`: `make_tmp_repo` / `make_restricted_path` / `hook_payload` がそのまま使えた。ただし `hook_payload` は `tool_input` の文字列フィールドしか組めないので、`tool_response` / `agent_transcript_path` / `run_in_background`（真偽値）が要るテストは各テストで `jq -nc` を書いた。**共通化の候補**
- `.claude/hooks/lib/*`: `hook-common` / `cmdpos` / `push-detect` / `transcript` / `scope` の 5 本で、本体に判定規則を書かずに済んだ
- `20-common-step-report-view` の `check-html.sh`: 結果報告の HTML は `OK: 検査 7 項目すべて通過（id 21 件 / リンク 14 件を確認。テンプレート: report）`

### スコープ外で見つけたこと

- **`post-push-compact-prompt` の `push-state.json` が 1 度も書けていなかった**。`jq -nc --slurpfile cur <(cat ...)` のプロセス置換（`/dev/fd/63`）を Windows の jq が開けず、`__cp_new` が空になって黙って終わっていた。同じチケットで書いたコードなのでその場で直した（ファイルを直に読む形）。**`--slurpfile` + プロセス置換は他にも無いか 0032 で見る**
- `hook_inject` と `hook_notify` で識別子の付き方が違う（`notify` は付ける / `inject` は付けない）。フック共通仕様 §3 に書かれていない差
- `test-lib.sh` の `hook_payload` に `--session` 以外の名前付き引数が無い

### AI アセットに反映すべき内容

**0032（設計反映）へ送る（今回の分）**

- 仕様 `workflow-diff-check.md` 制御方式 4 に `-uall` を書く（未追跡はファイル単位で判定する）
- 仕様 `subagent-stop-check.md` 制御方式 2 の縮退判定を「セッション単位で `subagent-start-check` の記録があるか」に直す（agentId では引けない理由を添える）
- 仕様 `subagent-start-check.md` に、`systemMessage` + `additionalContext` の 2 経路を出す公開 API を `hook-common` に置くことを書く
- フック共通仕様 §3 に `hook_notify` と `hook_inject` の識別子の扱いの差を書く
- 仕様 `subagent-stop-check.md` SP-T08 の `sub-opus` を `opus`（`model-aliases.txt` にある族名）へ直す
- `logs/mr.json` の MR 番号のキーが `.mr` であることを、フック共通仕様 §5 か各フック仕様に明記する

**累積（0028 までに挙がっていて未反映）**

- フック共通仕様 §7 に `CP_DATA[i]` / 正規化の記述 / 語の切れ目に改行を含めること / 内部プレースホルダの割り当て表（`\x01` `\x02` `\x03`）を書く
- `push_detect` の終了コード検査を除く（DDR i0009-07。`tool_response` に終了コードのフィールドは存在しない）
- §1 の表の review-state / merge-state を jq 2 回目へ移す
- §2 の worktree 判定、§8 の `SC_TARGETS` / `SC_CLASS` / `scope_load` 系の戻り値 / `scope_match` の引数順 / `SC_BUILD_TEST[]` の名前
- 区切りバイト（0x1E / 0x1D / 0x1F）の割り当てを 1 か所にまとめる
- DDR i0009-08 の `SS-T00〜T04`
- チケットの `allow.write` に作業ログの置き場（`wip/10_tickets/**`）を必ず含める規約

### 備考

- `shellcheck` はこの環境に未導入（6 巡連続）。静的検査は未実施
- `check-html.sh` は md と HTML の内容一致を検査しない（17 回連続の申し送り）
