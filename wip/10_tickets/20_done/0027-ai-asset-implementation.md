---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0026"]
executor: main
human_review: {required: false, reason: "全体計画書の方針（差分 3）"}
adversarial_review: {required: true, reason: "全体計画書の方針（差分 3: フェーズごとに 1 回）"}
allow:
  write: ["wip/**", ".claude/settings.json"]
  ops: ["read", "remote-read", "build-test", "hook-test"]
started_at: "2026-09-06T05:28:48+09:00"
completed_at: "2026-09-06T06:02:25+09:00"
base_sha: "450a201"
---

# 0027 S10 並列実施の発効の可否の判定（実効性の確認）

## 目的

DDR i0050-08 の解禁の条件 1・2 を実測で突き合わせ、並列実施を発効させるか保留を据え置くかを判定する。判定が肯定のときだけ .claude/settings.json に worktree.baseRef を残す。.claude/docs/ は触らず、結果は実装結果レポートに書く。

## DoD

- [x] 解禁の条件 2（割り付けた作業ツリーの中の書き込みに workflow-guard の判定が効くことを機械テストで固定した）が WG-T19・WG-T20・DC-T08・DC-T09・SA-T10・SP-T09 の PASS で満たされていることが根拠付きで示されている（根拠: レポート e51 の表。`run-tests.sh --filter '*workflow_guard*' --timeout 300 --ids` = `OK: 1 本 / 21 件`・FAIL 空 / `'*diff_check*'` = `OK: 1 本 / 9 件`・FAIL 空 / `'*subagent*'` = `OK: 2 本 / 20 件`・FAIL 空）
- [x] 解禁の条件 1 の実測を行い、3 点（分岐元が呼び出し元の HEAD か / ブランチ名の規約 / 成果を載せたまま作業ツリーが消えないか）それぞれの観測結果がレポートに書かれている（実測は捨ててよい成果 = wip/tmp/ への 1 ファイルで行い、本 issue の実チケットを使わない）（根拠: レポート e52 の 3 行の表。`isolation: worktree` のサブエージェントを 3 回起動。1 回目は `wip/tmp/probe-artifact-0027.txt`、3 回目は `wip/30_reports/probe-0027-tracked.md`。本 issue の実チケットは使っていない）
- [x] 実測の結果と判定の**提案**（発効してよい / 保留を据え置く）がその根拠付きでレポートに書かれている。**このチケットでは発効しない**（根拠: レポート e53。提案は「保留の据え置きをやめ、発効の方向で次フェーズが手当てする」。`i0050-08` の決め手が実測で崩れたことを根拠に置き、本チケットでは発効しない理由も同節に書いた）
- [x] 判定が肯定でも否定でも .claude/settings.json の worktree.baseRef が**取り除かれた状態**で終わっている（実測のための一時的な追加であり、残さない。git diff .claude/settings.json に worktree の行が無い）（根拠: `git diff --name-only -- .claude/settings.json` が空。`jq -e .` は終了コード 0）
- [x] 発効に要る残りの作業が次フェーズへ渡る形でレポートに書かれている（根拠: レポート e54 の 6 行の表と残課題 R47。各行に対象ファイルと「なぜ本チケットでできないか」を書いた）
- [x] 機械テスト HK-T01 が通る（run-tests.sh --filter '*config_integrity*'。settings.json の hooks 登録が変わっていない）（根拠: `run-tests.sh --filter '*config_integrity*' --timeout 300 --ids` = `OK: 1 本 / 3 件`・`FAIL ID:` 空）
- [x] settings.json に触った直後に通常のツール呼び出しを 1 回行い、フックが起動することを確かめた（ロックアウト対策。機構が無音になっていない）（根拠: 追加の直後の `jq -e .` に対して `workflow-diff-check` が `WF601`（`.claude/settings.json` / `WF203`）を返した。取り除いた後も `run-tests.sh` と `git diff` が通り、隔離した作業ツリーの中では `workflow-guard` が `WF205` を返した）
- [x] .claude/docs/ を 1 ファイルも変更していない（DDR i0050-08 の書き換えは設計反映フェーズ。実装フェーズは deny）（根拠: `git diff 450a201 --name-only -- .claude/docs/` が空）
- [x] 判定の結果として設計文書に反映すべきことが、実装結果レポートの「仕様からの逸脱」または残課題として次フェーズへ渡る形で記録されている（根拠: 残課題 R46（`i0050-08` の決め手が崩れた）・R47（発効に要る 6 件）・R48（S10 で閉じた / 閉じなかった残課題））

## 作業内容

- 計画書 wip/20_plans/0016-ai-asset-implementation-plan.md の S10 と「ロックアウト対策」の S10 行に従う
- 発効（worktree.baseRef を残すこと）はこのチケットの成果に含めない。解禁の条件 1 の第 2 択は「3 点が確かめられ、かつ worktree.sh の管理対象の定義と merge の前提検査 6 をそれに合わせて改めた」なので、条件 1 を肯定側で満たすには .claude/skills/** と .claude/docs/** の変更が要る。本チケットの宣言と実装フェーズの deny の外なので、肯定側でも発効に進まず提案に留める
- 復旧は git checkout を使わない（checkout は分類が unknown で WF204）。git show <base_sha>:.claude/settings.json で内容を取り、Write ツールで書き戻す。.claude/settings.json は common.confirm なので書き込みのたびに WF203（ask）が入る前提で、編集を 1 回にまとめる
- 実行者をメインエージェントに外す理由: 条件 1 の確認にサブエージェントの起動が要り、サブエージェントは入れ子にできない（task-executor の禁止事項）。work-defaults.md の ai-asset-implementation 行に実行者の調整条件は無いので、基準に無い調整として記録する

## 作業ログ

### 現在地

- 完了。条件 2 の確認・条件 1 の実測 3 点・判定の提案・発効に要る残りの作業までレポートに書き、`settings.json` は戻し切った

### うまくいったこと

- `worktree.baseRef: "head"` を置いた状態で隔離したサブエージェントを起動すると、分岐元が呼び出し元の HEAD になり、**作業ツリー側に作業中チケットが見えた**。設計が心配していた「チケット 0 枚で統制が素通りする」状態にはならなかった
- **隔離した作業ツリーの中で `workflow-guard` が実際に働いた**（`WF205`）。0021 が疑似の作業ツリーで固定した振る舞いを、実物で裏づける観測が取れた
- 3 点目を 2 通りの書き込み先で試したことで、`i0050-08` の決め手が「clean だから消える」ではなく「**git から見て変更が無いから消える**」だと切り分けられた

### うまくいかなかったこと

- 1 回目の実測はチケットの指示どおり `wip/tmp/` に書いたが、そこは gitignore 対象で git から見れば変更が無く、作業ツリーごと消えた。**実測の設計が弱く、1 回では 3 点目に答えられなかった**（追跡対象に書く 3 回目でようやく答えが出た）
- 実測で作った作業ツリーを AI では片付けられなかった。`worktree.sh remove` は管理対象外として `WT005` で拒否し、`git worktree remove` は `WF204`。人間の手を借りた

### 仕様からの逸脱

- 無し。`.claude/docs/` は 1 ファイルも変更していない（`git diff 450a201 --name-only -- .claude/docs/` が空）。判定の結果として設計文書に反映すべきことは残課題 R46・R47 に回した

### 判断と根拠

- **実測を 3 回に分けた**。1 回目（`wip/tmp/`）で 3 点目が「消えた」と出たが、書き込み先が gitignore 対象だったため「機構が必ず clean になる」という設計の前提を検証できていなかった。追跡対象に書く 3 回目を足して切り分けた
- **発効しない**。解禁の条件 1 の第 2 択の後半（`worktree.sh` の管理対象の定義と `merge` の前提検査 6 の改訂）は `.claude/skills/**` と `.claude/docs/**` の変更を要し、本チケットの `allow.write`（`.claude/settings.json`）と実装フェーズの `deny` の外。肯定側に進むと仕様違反になる
- **判定の提案は「発効の方向」**。`i0050-08` が保留を選んだ決め手が実測で崩れ、残る障害はブランチ名の規約 1 点だけになったため

### 拒否・確認・迂回の記録

- `WF601`（`.claude/settings.json` / `WF203`）: 設定を足した直後から取り除くまで、すべてのツール呼び出しに付随した。宣言に `.claude/settings.json` があるが `common.confirm` のパスは `allow` ではなく `confirm` に分類されるため出る。**文面は `git checkout` での破棄を促すが従わなかった**（0018 の D4 と同じ判断）
- `WF205`（隔離した作業ツリーの中）: サブエージェントが `echo > wip/30_reports/…` を実行して拒否された。迂回せず Write ツールに切り替えさせた。**この拒否そのものが観測の成果**
- `WT005`（`worktree.sh remove`）: 実測で作った作業ツリーが管理対象外として拒否された。迂回せず、片付けを人間に依頼した

### 使った AI アセットと効き目

| アセット | 観点 | 類型 | 候補 |
|---|---|---|---|
| `10-task-ai-asset-implementation-exec` | 問題なし | - | - |
| `20-common-step-worktree`（`worktree.sh`） | 足りなかった | (a) | 隔離が作る作業ツリーを片付ける口が無い（R47 の 6 番目） |
| `workflow-diff-check`（`WF601`） | あったが誤っていた | (b) | 宣言に書いても `common.confirm` のパスを「許可範囲外」と報告し、`git checkout` での破棄を促す。従うと成果が消える |
| チケット 0027 の DoD | あったが罠が書かれていなかった | (c) | 実測の書き込み先を `wip/tmp/` と指定していたが、そこは gitignore 対象で 3 点目の判定材料にならない |

### スコープ外で見つけたこと

- **`workflow-diff-check` の `WF601` の文面が危険**。「復旧: 追跡済みの変更は `git checkout <基準点> -- <path>`」と書くが、(1) `git checkout` は分類が `unknown` で `WF204` に落ちるので実行できず、(2) 宣言に書いてある `common.confirm` のパスに対しても出るため、素直に従うと**正当な成果を捨てることになる**。0018 が D4 として記録し、S10 でも同じ状態が続いた

### AI アセットに反映すべき内容

- `WF601` の文面から `git checkout` の案内を外し、`common.confirm` のパスは「宣言に書いてあれば違反ではない」と読める形にする
- 実測を伴うチケットの DoD では、書き込み先が gitignore 対象かどうかを明示する（今回はそれで 1 回無駄になった）

### 備考

- 実測で作った作業ツリー `.claude/worktrees/agent-a0194b10452b44141` とブランチ `worktree-agent-a0194b10452b44141` は、AI からは片付けられないため人間に依頼した
