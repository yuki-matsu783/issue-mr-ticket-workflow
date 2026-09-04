---
type: ticket
ticket_type: investigation
predecessors: []
executor: opus
human_review: {required: false, reason: "全体計画書の差分 3（人間レビューを敵対的レビューに置き換える）"}
adversarial_review: {required: true, reason: "全体計画書の差分 3。フェーズごとに 1 回、claude-fable-5-1 で実施する"}
allow:
  write: ["wip/**"]
  ops: ["read", "remote-read", "web"]
started_at: "2026-09-04T23:48:04+09:00"
completed_at: ""
base_sha: "436ecb0"
---

# 0006 調査: サブエージェントを呼び出し元と別の worktree で動かせるか

## 目的

調査計画書の観点 C に答える。Agent ツールに作業ディレクトリ／worktree を指定する手段があるか、subagent-start-check がサブエージェント側の cwd を見るのかを、公式ドキュメントと実装から確定する。動かせないなら 1 プロセス内での並列は成立せず、受け入れ条件 A4 の採否がその時点で決まる。

## DoD

- [x] 観点 C『サブエージェントを呼び出し元と別の worktree で動かせるか』への答え（可否）が wip/30_reports/0004-investigation.md に書かれている（根拠: e17「可否: 動かせる」。口はエージェント定義の frontmatter `isolation: worktree`。サマリの 0006 段落にも結論を置いた。条件は e20〜e22）
- [x] 公式ドキュメントの URL・引用文・取得日が添えられている。取得できなかった場合は『不明』と明記し、その理由と実測手順が書かれている（根拠: e18 の出典表。4 URL・18 引用・取得日 2026-09-04。301 リダイレクトの経緯も記載。書かれていない事項（SubagentStart と WorktreeCreate の発火順）は e19 で「不明」と明記し、実測手順 C2 に落とした）
- [x] subagent-start-check.sh が読む cwd が呼び出し元のものかサブエージェント側のものかの結論と、根拠（ファイル・行、または logs/hooks/decisions.jsonl の実レコード件数付き）が添えられている（根拠: e19 の 2 経路の表。PreToolUse `Agent` は「呼び出し元」で確定（`subagent-start-check.sh:36-49, 153` / `hook-common.sh:369` / 公式 S14・S17）、SubagentStart は「不明」。実レコードは SubagentStart 22 件・本セッション 4 件・着手後 37 件（うち deny 2 件）・キー 10 個の件数付き）
- [x] 動かせない場合の代替（人間が別セッション・別 clone を開く等）が成立する条件が書かれている（根拠: e23 の代替 6 案の表。A2 = `claude --worktree` の別セッション、A3 = 別 clone を含め、成立条件を案ごとに列挙。「動かせない場合」に相当するのは A1 の成立条件 5 つのいずれかが満たせない場合であることも明記）
- [x] 答えが出なかった問いは理由付きで残課題に残っている（根拠: 残課題 R12〜R19 の 8 件と「確かめられなかったこと」の 0006 分 6 行。いずれも理由と引き取り先つき）

## 作業内容

- Claude Code の Agent ツール・worktree に関する公式ドキュメントを WebFetch で読み、作業ディレクトリ指定の可否を引用付きで確定する
- .claude/hooks/12-SubagentStart/subagent-start-check.sh と hook-common.sh の HOOK_WORKTREE 解決を読み、サブエージェント起動時にどの cwd が渡るかを追う
- .claude/agents/task-executor.md と 00-workflow-issue-mr-driven/SKILL.md の起動手順・assets/subagent-prompt.template.md を読み、worktree を渡す口があるかを確かめる
- logs/hooks/decisions.jsonl の過去レコードからサブエージェント実行時の cwd の実値を拾い、呼び出し元と一致していたかを件数付きで書く
- 実測手順（人間が worktree を作った状態でサブエージェントを起動し、decisions.jsonl の cwd を見る手順と予測）を書く

## 作業ログ

### 現在地

- 完了。観点 C の節（e17〜e24）を `wip/30_reports/0004-investigation.md` に追記し、同名 HTML（f17〜f24）を同期して `check-html.sh` を通した。次は 0007（観点 D）だが、本チケットの担当範囲外なので着手しない

### うまくいったこと

- 公式ドキュメント 4 本（`sub-agents` / `worktrees` / `hooks` / `agents`）から 18 件の逐語引用を取り、観点 C の可否を**肯定**で確定できた。決め手は `sub-agents` の「Subagent working directory」節と frontmatter 表の `isolation` 行
- DDR `i0009-55` が二次資料として引用していた `hooks.md:598-601` の原文が、現在の `hooks` ページに**同じ文言で実在する**ことを確認できた。0004 の e1・e3 の前提が一次資料で裏付けられた
- `decisions.jsonl` から、サブエージェントが呼び出し元と `session_id` を共有することを **4 件の同一 ID** で示せた。環境変数 `CLAUDE_CODE_SESSION_ID` / `CLAUDE_CODE_CHILD_SESSION=1` と突き合わせて裏を取れた
- 0004 の実測手順 P2 の識別子 W1（`main` 基点 = チケット 0 枚）が、**既定設定のサブエージェント worktree そのもの**だと分かり、既存の実測設計をそのまま流用できた（e20）
- md と HTML の突き合わせで、`###` 見出し 24 / `<h3 id=` 24、記号内訳 ◎10・△11・✕3 が両側で一致。表の行数も 8 か所すべて一致した

### うまくいかなかったこと

- `isolation: worktree` を実際に試せなかった。`.claude/agents/` への書き込みが本チケットの `allow.write`（`wip/**`）の外であるため。実測手順 C1〜C5 に落として人間に回した
- `decisions.jsonl` から「サブエージェント実行時の `cwd` の実値」を拾う計画だったが、**`cwd` は記録されていない**（キーは 10 個）。`session_id` と「どのファイルに落ちたか」で代えた
- SubagentStart フックの `cwd` が worktree 作成の前か後かは、公式に発火順の記述が無く**不明のまま**。推測で埋めず R12 と実測 C2 に残した

### 仕様からの逸脱

- 無し（読み取りと Web 取得のみ。書き込みは `wip/30_reports/` と `wip/tmp/`）

### 判断と根拠

- **「可否」を 2 段に分けて答えた**（機能として存在するか / 現行の機構を載せて成立するか）。前者だけなら「動かせる」、後者だけなら「動かせない」になり、どちらか一方だけでは後続の判断材料にならないため。結論は前者を主にし、後者を e20〜e22 の条件として並べた
- **PreToolUse `Agent` 経路は「呼び出し元」と断定し、SubagentStart 経路は「不明」に留めた**。前者は Agent ツールの呼び出しがメイン側のツール呼び出しであることと公式 S14（`agent_id` は「Present only when the hook fires inside a subagent call」）から断定できる。後者は `WorktreeCreate` と `SubagentStart` の発火順が公式に無いため
- **フックは Claude Code の隔離検査の対象外と読んだ**が、これは公式が検査対象を「a Bash, PowerShell, or Monitor command」と限っていることからの**推論**であって明文ではない。R15 に残した
- **`decisions.jsonl` の 22 件を「証明にならない」と明記した**。worktree を 1 度も作っていないので負のコントロールが無く、「本流に落ちた」だけでは worktree 側を見るかどうかを区別できないため
- **サマリの件数行の扱い**。0005 の行が「ここが唯一の合計」と書いていたので、0005 の行は書き換えず、0006 の行に「0005 の行を積み上げた最新の合計で、以後はこの行を指す」と読み替えの注記を添えた（過去の節を書き換えない原則）

### 拒否・確認・迂回の記録

- `cd` を含むコマンドが **WF204 で 2 回**拒否（`2026-09-04T23:48:12` / `23:48:24`）。迂回せず、以後の読み取りをすべて絶対パスに切り替えた
- `for f in …; do …; done` を含むコマンドが **WF204 で 1 回**拒否（`_ はどの分類にも当たらない`）。`grep` を並べる形に書き換えた
- `bash wip/tmp/splice.sh` が **WF204 で 1 回**拒否（`bash はどの分類にも当たらない`）。`scope.sh` の提供コマンド判定は `bash .claude/skills/*/scripts/*.sh` か `.claude/hooks/**/*.sh` のルート相対表記だけを通す（`cmdpos.sh:314-318`）。迂回せず、`awk -f` の出力を `wip/tmp/report.new` に書いて内容を確かめ、反映は Edit ツールで行う形に変えた
- `cp wip/tmp/report.new wip/30_reports/0004-investigation.md` が **WF205 で 1 回**拒否（コマンドで書いてよいのは `wip/tmp/**` と `logs/**` だけ）。指示どおり Edit ツールでの反映に切り替えた
- `bash /c/…/check-html.sh` が **WF204 で 1 回**拒否。絶対パスは提供コマンドと判定されないため、ルート相対表記（`bash .claude/skills/20-common-step-report-view/scripts/check-html.sh`）に直して通した

### 使った AI アセットと効き目

- `10-task-investigation-exec`: 実施タスクの共通手順（1 タスク 1 レポート・過去の節を書き換えない・表に載せきれない対象を本文で足さない）が、積み上げ 3 枚目で効いた。とくに「書き終える前に計画書の『成果物の形』を読み返す」に従い、観点 C に求められた 4 項目（可否 / 出典 / `cwd` の実値 / 代替）をすべて節として持てたか確認できた
- `20-common-step-report-view`: `check-html.sh` は 7 項目通過（id 39 件 / リンク 32 件）。ただし手順 5 のとおり md と HTML の対応は検査されないので、見出し数・記号内訳・表の行数を 8 組手作業で突き合わせた（すべて一致）
- `20-common-step-ticket` / `20-common-step-commit-push`: 提供コマンド経由の着手・コミット・完了。`ticket.sh start` は基準点 `436ecb0` を自動で記録した

### スコープ外で見つけたこと

- **`decisions.jsonl` に `agent_id` が記録されていない**。`hook_read_input` は読んでいる（`hook-common.sh:360`）のに記録行が落としており、メインとサブエージェントの判定を記録から区別できない。並列の可否と独立に効く欠落なので、設計への反映 16 に上げた
- **`.claude/worktrees/` が `.gitignore` に無い**。公式が Tip で入れることを勧めており、入れないと `push.sh` 項目 1 が落ちる。worktree を使うかどうかに関わらず、Claude Code の `--worktree` を人間が 1 度でも使うと踏む
- **`scope.sh` の分類の穴が git サブコマンドだけではない**。`bash <任意のスクリプト>` も `for` も `unknown` に落ちる。観点 E（0008）の対象は git 分類だけではないので、0008 の表に足す提案を設計への反映 20 に書いた

### AI アセットに反映すべき内容

- `10-task-investigation-exec` か `20-common-step-shell-script` に、**長文を扱うときの一時ファイルの作り方**を書く。現行の運用（ヒアドキュメントで `wip/tmp/*.sh` を書いて `bash` で実行）は、①機構の `scope.sh` が `bash <任意のスクリプト>` を `unknown` に落とす ②Claude Code の worktree 隔離が引用符なしヒアドキュメントを拒否する、の 2 つに当たる。Write ツールで一時ファイルを作り、反映は Edit ツールで行う形が両方を避けられる
- `20-common-step-report-view` の手順 5 に、**md と HTML の突き合わせで数える対象の既定リスト**（見出し数 / 記号内訳 / 各表の行数 / 累積件数）を置くと、毎回の数え方を決め直さずに済む。本チケットでは 8 組を自分で選んで数えた
- レポートの「サマリの件数行」について、**積み上げのたびに前の行を『その時点の合計』と読み替える書き方**を共通ステップに明文化する。現状は「ここが唯一の合計」と書く決まりだけがあり、追記のたびに複数の行が同じ主張をしてしまう

### 備考

- 本チケットの成果は 1 本のレポート（`wip/30_reports/0004-investigation.md` と同名 HTML）への追記であり、新しいファイルは作っていない
- 観点 C の結論が肯定に転んだため、調査計画書のリスク欄が想定した「0006 の結論が否定的 → 0007 以降を読み替える」は発動しない。0007（観点 D）は計画どおり進められるが、「サブエージェント worktree が `worktree-<名前>` という別ブランチを作る」ことを合流コストの前提に足す必要がある
