---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0030"]
executor: main
human_review: {required: true, reason: "基準どおり（登録は人間の操作。ロックアウトの復旧経路も人間）"}
adversarial_review: {required: true, reason: "基準どおり（中核の登録。実測の解釈が後続の書き戻しを左右する）"}
allow:
  write: [".claude/hooks/**", ".claude/settings.json", ".claude/skills/20-common-step-shell-script/**"]
  ops: ["read", "remote-read", "hook-test", "build-test"]
started_at: "2026-09-03T00:57:36+09:00"
completed_at: ""
base_sha: "c3440fc"
---

# 0031 段階登録 ①② の 16 行とフェーズ 4c の実測・HK-T01・全件テスト

## 目的

残る 16 行を 2 段で登録し、登録済みの本物のフックの記録でフェーズ 4c の実測を行い、HK-T01 と run-tests.sh --ids の全件を通す

## DoD

- [ ] HK-T01 の期待値として **16**（T9 が外れたので当初の 17 から 1 行減。下の T9 の項）行分の command 文字列の逐語一覧が .claude/hooks/tests/fixtures/settings-hooks.expected.tsv（イベント・matcher・位置・command の 4 列）にあり、引数を取る 2 行（--accumulate）と実体のディレクトリと登録先が一致しない 3 行（§1 の数え方。機械的に数えると 5 行で、差の内訳はテストのコメントにある）が正しく入っている。うち拒否側 5 行は fail-closed ラッパー（`|| printf … WFx09 …`）まで含めた逐語で、x が workflow-entry = WF109 / workflow-guard = WF209 / workflow-state-guard = WF309 / block-direct-git = WF409 / block-chmod = WF509 と一致する（根拠: ）
- [ ] 各段で AI が渡したのは「その段までの PreToolUse 配列の全文」で、人間は配列ごと貼り替えた。位置は §1 の表の順（1=workflow-entry(Skill) / 2=workflow-entry / 3=workflow-state-guard / 4=block-chmod / 5=block-direct-git / 6=workflow-guard。**7=subagent-start-check は T9 の縮退で削除**）に一致する（HK-T01 は配列上の位置まで照合するため）（根拠: ）
- [ ] 段階 ①（案内側 **11** 行: SessionStart 1 / UserPromptSubmit 1 / PreToolUse Skill 1 / PostToolUse 4 / SubagentStart 1 / SubagentStop 2 / Stop 1。**PreToolUse Agent 1 は T9 の縮退で削除**）を人間が登録し、AI がコミットした。新しいセッションで軽い操作（Read → Skill 宣言 → Edit → commit.sh）を通し想定外の deny が無いことを確かめた。12 行版（Agent 行あり・プローブの env あり）で 1 度通した後、実測を受けて 11 行版に貼り直した（根拠: ）
- [ ] 段階 ②（拒否側 4 行を fail-closed ラッパー付きで追加し、⓪ の block-chmod にもラッパーを付ける）を人間が登録し、AI がコミットした。1 行ずつ足して各行の後に軽い操作を通した。HK-T09 が通る。HK-T09 は機械テスト（一時コピーに対してラッパー文字列を再現して実行する）であって実登録の破壊試験ではない — 実登録の workflow-guard を壊すと matcher が Edit|Write|MultiEdit|NotebookEdit|Bash|PowerShell|EnterPlanMode|Agent|Workflow なので書き込みも実行も全部 deny になり、壊したファイルを AI が書き戻せない（根拠: ）
- [ ] T9（systemMessage が PreToolUse でユーザーに実際に表示されるか）を ① の後に実測し、結果を作業ログに書いた。外れた場合は HK-T01 のフィクスチャを 16 行に直し、§1 の書き戻しをフェーズ 6 へ送った（根拠: ）
- [ ] ① の登録後、人間が WORKFLOW_PROBE_4C=1 を設定した新しいセッションを起動した（環境変数はセッション開始時に読まれ AI は設定できない。§4。Bash ツールで前置しても外側のフックプロセスには届かない）（根拠: ）
- [ ] T9 の観測者を人間とし、3 つの証跡を揃えた: (1) プローブ (b) を有効にしてサブエージェントを 1 つ起動し人間が見た / 見なかったの一次報告、(2) T3 のために走らせる claude -p を --output-format stream-json --verbose にして Agent 呼び出しを 1 回させ SDKInformationalMessage の有無を機械的に採る、(3) 負のコントロールとして同じ呼び出しでプローブ (a) が logs/hooks/probe-4c.jsonl に 1 行落ちていること（落ちていなければ「表示されない」ではなく「フックが起動していない」）。systemMessage は §3 のとおり AI には届かない（根拠: ）
- [ ] 4c プローブを有効にし、T2（親子の session_id）・T3（claude -p の判別と defer の実在）・T4（SubagentStart と agent_id / agent_type の実在。model は来ない前提）・T5（PowerShell ツールの stdin 共通フィールドが Bash と同じ形か。あわせて #6 の作業ログと DDR を読み既に解決済みかを判定）・T7（tool_response の終了コードのフィールド名）・T9（systemMessage が実際に表示されるか）を実測し、結果を作業ログの表に書いた（根拠: ）
- [ ] T1 と T8 を含めていない。§12 が両方とも取り消し線つきで「解決（TBD ではない）」としており、T8 は機械テスト HK-T16 が固定するため。実ファイルの mv による T8 の実測はしない（mv すると scope_load_ticket が戻り値 2 を返して拒否側が WF209 に倒れ、戻すための mv も止まって自分自身をロックアウトするため）。T6 は 0028 で確認済み（根拠: ）
- [ ] 実測が終わった後に 4c プローブを取り除き、`grep -rn 'WORKFLOW_PROBE_4C\|probe-4c' .claude` が 0 件であることと、取り除いた後に全件テストが通ることを確かめた（根拠: ）
- [ ] tool_response.status が既定で async_launched になるか・agent_type の実物を ① の後に実測した。worktree は ② より前に git worktree add で**リポジトリの外**（親ディレクトリの兄弟）に作っておき、② の後に EnterWorktree ツールでそこへ移って workflow-guard が worktree 側のチケットを判定するかを見た（② の後は worktree / claude が WF204、mv が WF205 で止まるため順序を分けた。リポジトリ配下に作ると未追跡ファイルとして push.sh の項目 1 で CP005 になり、逃げ道の .gitignore は common.protected かつ許可範囲外なので WF201 で足せない。worktree で新しいセッションを起動してはならない — CLAUDE_PROJECT_DIR が worktree になり HOOK_ROOT == cwd で §2 の経路を一切踏まない）（根拠: ）
- [ ] ホットパス 5 本の実行時間を `time bash <script> < wip/tmp/input.json` で各本 10 回測った（logs/sh/ は秒精度（logger.sh:54 の printf '%()T'）なので 1 秒以内の目安を測れない。logs/sh/ は起動の有無の確認だけに使った）。あわせて post-push-usage-report を測り hc_lock の陳腐化 60 秒の妥当性を評価した（根拠: ）
- [ ] HK-T01（17 行のフィクスチャと settings.json の行単位の照合）が通る（根拠: ）
- [ ] run-tests.sh の全件（--ids を付けて ID を確認）を実行し、結果（通過数・失敗した ID と理由・boundary.sh 依存で実施できない 10 件）を結果報告に記録した。全件はバックグラウンド実行でファイルに出した（根拠: ）
- [ ] 実測で判明した仕様との食い違いを作業ログ「仕様からの逸脱」に列挙し、DDR にすべきものを「AI アセットに反映すべき内容」に書いた（実装フェーズは .claude/docs/** に書けないため）（根拠: ）

## 作業内容

- 計画書 wip/20_plans/0016-ai-asset-implementation-plan.md のステップ 5 に従う
- 登録は人間の操作。AI は貼り付ける JSON と手順を提示し、登録後のコミットだけを行う
- ロックアウトの復旧は 3 通りに分ける。(1) 1 本の判定が誤って deny → WORKFLOW_<NAME>_ENFORCE=0 の新セッション、(2) 複数が同時に deny / 原因が絞れない → WORKFLOW_ENFORCE=0 の新セッション、(3) フック本体が起動できない（ラッパーの WFx09）→ 環境変数は効かないのでバックアップから復元し、直してから登録し直して HK-T01 と全件を通してからコミットする（復元したままだと push.sh の項目 1 で CP005、部分登録のままコミットすると HK-T01 が落ちる）
- 登録前に 4 本とも単体実行と bash -n を通し（`shellcheck` はこの環境に未導入で未実施）、② は 1 行ずつ足して各行の後に軽い操作を通す
- 登録は対話セッションでのみ可能（settings.json は common.confirm でヘッドレスでは WF203 が deny）。T3 の実測は逆に claude -p を 1 回走らせる

## 作業ログ

### 現在地

- **人間の登録待ち**。AI 側の下ごしらえは済んでいる:
  - HK-T01 の期待値 `.claude/hooks/tests/fixtures/settings-hooks.expected.tsv`（17 行の逐語）と、HK-T01 / HK-T09 のテスト（`.claude/hooks/tests/test_config_integrity.sh`）
  - 段階ごとに貼り替える settings.json 全文 6 本（`wip/tmp/settings-stage1.json` / `settings-stage2-1..5.json`）
  - **手順とロックアウトの復旧手順は `wip/tmp/0031-handoff.md`**（セッションをまたぐのでここから読む）
- **段階 ① 登録済み**（人間が `cp wip/tmp/settings-stage1.json .claude/settings.json` を実施）。軽い操作を通して確認した:
  - **再起動なしで反映された**（実測）。`cp` の直後の Bash 呼び出しで `workflow-diff-check` と `workflow-entry` が発火した
  - `session_id` は実 UUID（`ee9cc8e9-…`）。`logs/sessions/<uuid>/entry.json` が作られ、UserPromptSubmit で `prompt_seq=1`、PreToolUse `Skill` で `declared_skill=00-workflow-issue-mr-driven` が記録された
  - Read（matcher 外・無反応）→ Skill 宣言（記録）→ Edit → `commit.sh` の順で通し、**想定外の deny は 0 件**
  - **`WF601` が `settings.json` の変更を毎回列挙する**: このチケットは `.claude/settings.json` を `allow.write` に宣言しているのに、`common.confirm`（判定 4）が許可範囲（判定 5）より先に効いて `WF203` 扱いになるため。登録作業のチケットでは避けられないノイズ（0032 へ）
- **ホットパスの実行時間を実測した**（`wip/tmp/timing.sh`。`bash <script> < wip/tmp/input.json` を各 10 回。他の重い処理を止めた状態）:

| フック | 10 回 | 1 回 |
|---|---|---|
| block-chmod | 3234 ms | **323 ms** |
| block-direct-git | 3472 ms | **347 ms** |
| workflow-entry | 4137 ms | **413 ms** |
| workflow-state-guard | 4840 ms | **484 ms** |
| workflow-guard | 6423 ms | **642 ms** |
| post-push-usage-report | 4311 ms | 431 ms |
| post-push-usage-report --accumulate | 4262 ms | 426 ms |

  - 目安（1 秒以内）は 5 本とも満たす。5 本は**並列に走る**ので 1 ツール呼び出しの待ちは合計（2.2 秒）ではなく最大値（0.64 秒）＋起動のオーバーヘッドに近い
  - **0030 の結果報告に書いた「フック 1 回 = 約 1.9 秒」は誤り**。全件テストを 2 本同時に走らせている最中に測っていた（競合下の値）。同じ理由で「`test_workflow_guard` は 5 分 07 秒」も誤りで、静かな状態では **1 分 47 秒**（既定の 120 秒に収まる）。0030 の報告と PR 本文を訂正した
  - `hc_lock` の陳腐化 60 秒は、`--accumulate` が 0.43 秒で終わることに対して十分に長い（ロックを取ったまま落ちたプロセスの検知までの猶予として妥当）
- **フェーズ 4c を実測した**（セッション `843ef779…`。`WORKFLOW_PROBE_4C=1` を `settings.json` の `env` で入れた =
  handoff の方法 A。記録は `logs/hooks/probe-4c.jsonl`、ヘッドレスの生ログは `wip/tmp/p4c-headless.jsonl`）:

| ID | 見たもの | 実測の結果 | 仕様（§12）との対比 |
|---|---|---|---|
| T2 | 親子の `session_id` | **同じ**。親 `843ef779…` の下でサブエージェントの `Bash` も同じ `session_id` で届く。子の呼び出しには `agent_id` / `agent_type` が**追加で付く**ので親子は判別できる | 一致（`logs/sessions/` の対応表は不要） |
| T3 | `claude -p` の判別 | **判別する入力フィールドは無い**。`SessionStart` の `source` は対話と同じ `startup`。副産物として `permission_mode` がヘッドレスでは `plan`、対話では `auto` だったが、対話でも plan モードなら `plan` になるので決め手にならない。`defer` は不採用のまま（実在確認の対象外） | 一致（`WORKFLOW_HEADLESS` / `CI` での明示を維持） |
| T4 | `SubagentStart` の `agent_id` / `agent_type` / `model` | `agent_id` / `agent_type` は**実在**（`general-purpose`）。キーは 6 つだけで **`model` は来ない**。加えて **`PreToolUse:Agent` の `tool_input` にも `model` が無かった**（呼び出し側が指定しなかったため。来たのは `subagent_type` / `prompt` / `description`）。`PostToolUse:Agent` には `tool_response.resolvedModel` が来る | 一致。ただし §1 の 7 行目の実行者比較は「呼び出し側が `model` を明示したときだけ成立する」ことが実物で確認された（下の「仕様からの逸脱」1） |
| T5 | `PowerShell` の共通フィールド | **Bash と同形**（`session_id` / `cwd` / `permission_mode` / `prompt_id` / `transcript_path`）。差は `tool_input.description` の有無だけで、これは呼び出し側が渡したかどうかの差 | 一致（`hook-common.sh` での吸収は不要） |
| T7 | `tool_response` の終了コードのフィールド名 | **存在しない**（`tool_response` は `stdout` / `stderr` のみ。`duration_ms` は入力の直下に来る）。さらに **exit≠0 のツール呼び出しでは PostToolUse フックが 1 本も起動しない**ことを負のコントロール 2 回（`exit 3` / `exit 7`）で確認した — probe に行が増えず WF601 の追記も出ない | 一致。「PostToolUse に届いた = 成功」（`post-push-*` の判定）を実物で裏付けた |
| T9 | `systemMessage` が実際に表示されるか | **外れた。人間に通知は来ない**（観測者: 人間の一次報告。面: VSCode 拡張。プローブが `PreToolUse:Agent` で無条件に 1 件出している状態で見て、通知が来なかった）。機械側では到達している — `claude -p … --output-format stream-json --verbose` の出力に `{"type":"system","subtype":"informational","content":"PreToolUse:Agent says: [プローブ] …","level":"notice"}` が 1 件あり、**破棄はされず SDK メッセージには載るが対話 UI が人間に見せない**。負のコントロール（probe-4c.jsonl に該当行が落ちている）も満たす | **不一致 → §12 の縮退を発動**（登録表 17 行 → **16 行**）。ユーザーの判断「systemMessage が人間に届くという要件は特に無い」 |
| 追加 | `tool_response.status` の既定 | **対話セッションで `run_in_background` を省略 → `async_launched`**（WF814 が実際に発火した）。ヘッドレス側は呼び出しが `run_in_background: false` を明示していて **`completed`** だった。両方の分岐を実物で観測した | 一致（§2 の「明示的に `false` でなければ background」） |
| 追加 | `permission_mode` の実値 | 対話 `auto` / ヘッドレス `plan` / `SessionStart` では**キー自体が来ない**ことがある | §2 の列挙（`default` / `plan` / `acceptEdits` / `auto` / `dontAsk` / `bypassPermissions`）に収まる |

  - `PostToolUse:Agent` の `tool_response` は情報が厚い（`agentId` / `agentType` / `resolvedModel` / `status` /
    `totalTokens` / `totalDurationMs` / `usage.*`）。`post-push-usage-report` の材料として使える
  - プローブの `additionalContext`（`PreToolUse:Agent`）はメインエージェントに**届いた**。届かないのは `systemMessage` の方で、
    この非対称は §3 の記述どおり
- **プローブを撤去し 16 行への縮退を済ませた**（`a41167e` / `656fca3` / `19eb5b9`）。`grep -rn 'WORKFLOW_PROBE_4C\|probe-4c' .claude` は 0 件。
  撤去で触った 6 本のテストは 251 件すべて通過（16 / 57 / 56 / 36 / 38 / 48、失敗 0）。
  HK-T01 は 26 件通過・1 件失敗で、失敗は「拒否側 5 行が未登録」の 1 件だけ（段階 ② が終われば通る）
- **段階 ②-1 を登録した**（人間が `cp wip/tmp/settings-stage2-1.json .claude/settings.json`）。
  足したのは `workflow-entry` の拒否側 1 行（matcher = 全ツール + `mcp__.*`、fail-closed ラッパー `|| printf … WF109 …`）。
  軽い操作（Bash → Read → Edit → `commit.sh`）を通し、**想定外の deny は 0 件**。作業中チケットがあるので継続の緩和（§13）が効いている
- **段階 ②-2 を登録した**（`workflow-state-guard` の拒否側 1 行、ラッパー `WF309`）。軽い操作を通し**想定外の deny は 0 件**
- **段階 ②-3 を登録した**（`block-direct-git` の拒否側 1 行、ラッパー `WF409`）。読み取り系の git（`git status` / `git log`）は通り、
  `commit.sh` 経由のコミットも通る。**想定外の deny は 0 件**
- **段階 ②-4 を登録した**（`workflow-guard` の拒否側 1 行、ラッパー `WF209`）。直後に **`cd` の前置が `WF204` で止まった**
  （拒否・確認・迂回の記録を参照）。`cd` を外せば Bash / Read / Edit / `commit.sh` はすべて通る。
  この段からメモリ（`~/.claude/projects/…/memory/`）の書き込みは `WF209` で止まる（合意済みの案 (a)）
- **段階 ②-5 を登録した = 登録は完了**（`block-chmod` に fail-closed ラッパー `WF509` を付けた最終形 16 行）。
  **HK-T01 / HK-T09 が全通過（27 件・失敗 0）**。16 行の登録が期待値の逐語と行単位で一致した
- **次にやること**: 全件テスト（`run-tests.sh --ids`）の結果を結果報告に記録 → 残る DoD の埋め合わせ
- 現時点の HK-T01 は**期待どおり 1 件だけ失敗する**（段階 ② が終われば通る）

### うまくいったこと

### うまくいかなかったこと

### 仕様からの逸脱

1. **`PreToolUse:Agent` の `tool_input` に `model` は「呼び出し側が明示したときだけ」入る**。§2 は「実行者の比較は
   `Agent` ツールの `tool_input.model` を読める PreToolUse で行う」と書くが、実測ではモデルを指定しない起動で
   `tool_input` が `subagent_type` / `prompt` / `description` の 3 つだけになり、**比較する値が無い**（＝既定モデルで走る）。
   一方 **`PostToolUse:Agent` には `tool_response.resolvedModel` が来る**ので、実際に使われたモデルの比較は
   起動後なら機械的に行える。7 行目を外す縮退（下記 2）と合わせて、実行者の検査は `subagent-stop-check` 側に寄せられる
2. **T9 が外れたため §12 の縮退を発動する**: `systemMessage` は対話 UI で人間に届かない。§1 の 7 行目
   （`PreToolUse` `Agent` の `subagent-start-check`）を残す唯一の支えが `systemMessage` だった（DDR i0009-54）ので、
   **この行を登録から外し、登録表は 16 行に戻る**。`additionalContext` はメインエージェントに届いたが、
   §12 のとおりこれは 7 行目を残す根拠にならない（不一致を起こしている当事者に伝えても意味がない）
3. **exit≠0 のツール呼び出しでは PostToolUse フックが 1 本も起動しない**。§2 の「PostToolUse に届いた = 成功」と
   整合するが、含意として **`workflow-diff-check`（WF601）は失敗したツール呼び出しの後の差分を見ない**。
   失敗しても書き込みが起きているケース（部分的に書けた `Write`、途中で落ちたスクリプト）は次の成功した呼び出しまで
   検知が遅れる。仕様に明記が無いので追記が要る

### 判断と根拠

- **T9 が外れたので登録表を 16 行に縮退させた**（DoD の「外れた場合」の分岐に従う。ユーザーの判断
  「`systemMessage` が人間に届くという要件は特に無い」）。手を入れたのは 3 つ:
  - `wip/tmp/fixture.py` の `ROWS` から `PreToolUse` / matcher `Agent` の行を削除 →
    `.claude/hooks/tests/fixtures/settings-hooks.expected.tsv` を 16 行で再生成
  - `wip/tmp/stages.py` の `PRE` と `G` から `agent` を削除 → 段階ファイル 6 本を再生成
    （`stage1` = 12 フック（案内 11 + ⓪ の block-chmod）、`stage2-5` = 16 フック・ラッパー 5 本）
  - DoD の 17 行 / 12 行 / 位置 7 の記述を 16 行 / 11 行に整合させた（DoD 自体が定めた分岐なので、
    条件を緩めたのではなく分岐先を書き写したもの）
  - **フック本体 `subagent-start-check.sh` は消さない**。`SubagentStart` の登録（WF802 の要点注入）は残るし、
    `PreToolUse` の経路も設定を戻せば生き返る。登録から外すだけにする
  - 失われるのは起動**前**の WF801（実行者の不一致）と WF803（background 起動）。WF803 は
    `subagent-stop-check` の **WF814 が起動直後に同じことを伝える**（この実測で実際に発火した）。
    WF801 は `subagent-stop-check` の縮退判定が担う（`logs/sessions/<id>/subagent-start-check.json` の
    印が常に無くなるので、縮退の側が必ず動く。DDR i0009-52 の設計どおり）
- **4c プローブを撤去した**: `lib/probe-4c.sh` を削除、6 フックの `source` と `probe_4c` 呼び出し、
  `subagent-start-check.sh` の `probe_4c_enabled` ブロック 2 か所、テスト 6 本の `cp` とプローブ用の assertion。
  撤去の際に **SE-T06 の前半（`source=compact` でも同じ内容）の検査がプローブの assertion に寄生していた**ことが
  分かったので、本来の検査（無出力・終了 0・記録が残る）を `case_compact` として書き直した
- **作業ツリーの外の書き込みは WF209 のまま拒否する**（ユーザーの決定。0030 の r2 を維持）。
  Claude Code のメモリ（`~/.claude/projects/<project>/memory/`）はリポジトリの外にあるので、段階 ②-4 の登録後は
  **メモリの書き込みが止まる**。このプロジェクトではメモリを使わず、どうしても要るときだけ
  `WORKFLOW_GUARD_ENFORCE=0` の新しいセッションで書く。設定に「外でも書いてよい場所」を足す案は採らない
  （設定の構造が増えるわりに、リポジトリ外への書き込みは本来まれなため）
- **worktree は段階 ② より前に作った**: `git worktree add ../issue-mr-ticket-workflow-probe4c -b probe-4c-worktree`。
  リポジトリの兄弟に置いたので `push.sh` の項目 1（未追跡ファイル）に引っかからない。② の後は `git worktree` 自体が
  WF204 で止まるため、この順序でしか用意できない

### 拒否・確認・迂回の記録

- **WF204（`cd` はどの分類にも当たらない・既定拒否）**: 段階 ②-4 で `workflow-guard` を登録した直後、
  それまで惰性で前置していた `cd "<リポジトリルート>" && …` が止まった。cwd は元からリポジトリルートなので
  **`cd` を書かない形に直して続行**した（迂回ではなく、宣言の範囲内の書き方に合わせたもの）。
  拒否側フックが実際に効いていることの生きた確認にもなった。
  なお `cd` を読み取り系の分類に足すかどうかは設定の判断なので **0032 へ**（既定拒否のままでも実害は無いが、
  複数リポジトリを跨がない限り `cd` は無害な操作で、毎回止まるとノイズになる）
- **WF204（`bash wip/tmp/<一時スクリプト>.sh` も既定拒否）**: 全件テストを回すのに一時スクリプト経由で
  `bash wip/tmp/p31-full.sh` としたら止まった。**提供コマンドを直接呼ぶ形**
  （`bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --ids`）に直して続行した。
  分類は「`bash` に渡すパス」で決まり、`.claude/hooks/tests/**`（hook-test）と提供コマンド（build-test）は当たるが、
  `wip/tmp/**` の任意スクリプトはどの分類にも当たらない。**設計としては正しい**（作業ツリー内に置いた任意のコードを
  無条件に実行できてしまうと許可範囲の意味が薄れる）が、長いコマンドを一時スクリプトに逃がす書き方が使えなくなる
  影響は大きいので **0032 へ**（案: `allow.ops` に `tmp-script` のような分類を設けて、宣言したチケットでだけ
  `wip/tmp/**` の実行を許す）

### 使った AI アセットと効き目

### スコープ外で見つけたこと

- **作業ツリーの外を WF209 で拒否する判断（0030 の r2）は、メモリ機構と衝突する**。Claude Code のメモリは
  `~/.claude/projects/<project>/memory/` にあり、リポジトリの外にある。段階 ②-4（workflow-guard）を登録すると
  **メモリの書き込みが全部 WF209 で止まる**（このチケットの途中で 1 件書いた。登録後は書けなくなる）。
  取りうる案は 3 つ: (a) このまま拒否し、メモリは使わない / (b) 上限設定に「作業ツリー外でも書いてよい場所」を足す /
  (c) 作業ツリー外はファイル単位の確認（WF202）に戻す。**設定・仕様の判断なので 0032 へ送る**
- **PR 本文の訂正はこのチケットの `allow.ops` に無い**（`remote-write:mr-edit` を宣言していない）ため、
  ワークの切れ目（手順 5-3）で行う。0030 の性能の記述を訂正する必要がある

### AI アセットに反映すべき内容

実装フェーズは `.claude/docs/**` に書けないので、フェーズ 6（design-feedback）へ送る。

1. **`フック共通仕様.md` §1 の登録表を 16 行にする**（`PreToolUse` `Agent` の `subagent-start-check` を削除）。
   §12 の T9 の行を「実測で外れた（人間に通知は来ない。SDK メッセージには載る）」に書き換え、縮退の発動を確定させる。
   関連: DDR i0009-54（7 行目の根拠が `systemMessage` に移った経緯）、i0009-26
2. **`subagent-start-check` 仕様から `PreToolUse` `Agent` の経路（WF801 / WF803 の起動前通知）を落とす**。
   実行者の不一致の検知は `subagent-stop-check`（`PostToolUse` `Agent`）に一本化する。あわせて
   **`tool_response.resolvedModel` で実際に使われたモデルを比較できる**ことを §2 と当該仕様に書く（実測で実在を確認）
3. **§2 に「`PreToolUse:Agent` の `tool_input.model` は呼び出し側が明示したときだけ来る」を追記**する
   （未指定＝既定モデル。値が無いことを「一致」と読まない）
4. **§2 に「exit≠0 のツール呼び出しでは PostToolUse フックが起動しない」を追記**し、
   `workflow-diff-check` 仕様に「失敗した呼び出しの後の差分は次の成功した呼び出しまで検知が遅れる」を
   意図的な緩和（§13）として書く
5. **§12 の T2 / T3 / T4 / T5 / T7 を「実測で確認済み」に更新**する（結果はこのチケットの現在地の表）。
   T2 の縮退（`logs/sessions/` の親子対応表）は不要と確定。副産物として
   「サブエージェント内のツール呼び出しには `agent_id` / `agent_type` が付く」を §2 に明記できる

### 備考
