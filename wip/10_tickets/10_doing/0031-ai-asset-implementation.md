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

- [ ] HK-T01 の期待値として 17 行分の command 文字列の逐語一覧が .claude/hooks/tests/fixtures/settings-hooks.expected.tsv（イベント・matcher・位置・command の 4 列）にあり、引数を取る 2 行（--accumulate）と実体のディレクトリと登録先が一致しない 4 行が正しく入っている。うち拒否側 5 行は fail-closed ラッパー（`|| printf … WFx09 …`）まで含めた逐語で、x が workflow-entry = WF109 / workflow-guard = WF209 / workflow-state-guard = WF309 / block-direct-git = WF409 / block-chmod = WF509 と一致する（根拠: ）
- [ ] 各段で AI が渡したのは「その段までの PreToolUse 配列の全文」で、人間は配列ごと貼り替えた。位置は §1 の表の順（1=workflow-entry(Skill) / 2=workflow-entry / 3=workflow-state-guard / 4=block-chmod / 5=block-direct-git / 6=workflow-guard / 7=subagent-start-check）に一致する（HK-T01 は配列上の位置まで照合するため）（根拠: ）
- [ ] 段階 ①（案内側 12 行: SessionStart 1 / UserPromptSubmit 1 / PreToolUse Skill 1 / PreToolUse Agent 1 / PostToolUse 4 / SubagentStart 1 / SubagentStop 2 / Stop 1）を人間が登録し、AI がコミットした。新しいセッションで軽い操作（Read → Skill 宣言 → Edit → commit.sh）を通し想定外の deny が無いことを確かめた（根拠: ）
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

- 未着手

### うまくいったこと

### うまくいかなかったこと

### 仕様からの逸脱

### 判断と根拠

### 拒否・確認・迂回の記録

### 使った AI アセットと効き目

### スコープ外で見つけたこと

### AI アセットに反映すべき内容

### 備考
