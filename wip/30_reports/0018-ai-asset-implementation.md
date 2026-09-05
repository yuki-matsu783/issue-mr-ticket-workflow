---
type: report
title: 0018〜0027 AI アセット実装・テスト結果 — 入口の設定と hook-common.sh の作業ツリーの三分（S1・S2 分）
description: issue #50 の AI アセット実装フェーズ（S1〜S10 / チケット 0018〜0027）が積み上げる実装結果レポート。S1 では scope-limits.json の allow に .gitignore を足し .claude/worktrees/ を無視した。S2 では hook-common.sh に作業ツリーの三分・作業ツリーの集合・パスの 4 段の畳み込み・共有ルートを入れ、decisions.jsonl に cwd と agent_id を足し、呼び手 3 本を WF209 / WF309 / WF605 に分岐させた。全フックのテスト 17 本 128 ID が PASS。SG-T11 の退行の検出と、fail-closed の deny がツールを止めなかった観察を記録した
tags: [report, ai-asset-implementation, issue-50]
keywords: [scope-limits.json, .gitignore, .claude/worktrees/, common.confirm, WF203, WF601, ロックアウト対策, HK-T01, HK-T02, 判定順, hook-common.sh, HOOK_SHARED_ROOT, hook_worktrees, hook_rel_path, 作業ツリーの三分, 畳み込み, WF209, WF309, WF605, HK-T06, HK-T21, HK-T22, SG-T11, fail-closed]
---

# 0018〜0027 AI アセット実装・テスト結果 — 入口の設定と hook-common.sh の作業ツリーの三分（S1・S2 分）

- 対象 issue: [#50](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/50)
- MR: [#51](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/pull/51)（draft）
- ブランチ: `feature-50-worktree-parallel-tickets`
- チケット: 0018〜0027（実装計画書 `wip/20_plans/0016-ai-asset-implementation-plan.md` の S1〜S10。**このレポートは各チケットが節を積み上げる器**で、現時点の内容は 0018（S1）と 0019（S2）分）
- 作成日: 2026-09-05（0018）／更新: 2026-09-05（0019）

## サマリ

S1（0018）は実装フェーズの**入口の設定**を 2 つ変えた。①`.claude/hooks/config/scope-limits.json` の `types["ai-asset-implementation"].allow` に `.gitignore` を足し（`.gitattributes` と同じ「`common.protected` を明示で判定順 (2) を通す」形）、②`.gitignore` に `.claude/worktrees/` を足した。①→② の順を守り、②が `WF201` にならず **judge stage 5 の allow** で `logs/hooks/decisions.jsonl` に記録されたことをもって、変えた判定を実際に踏んだことを確かめた。機械テストは `HK-T01` / `HK-T02` とも PASS、`jq -e .` も成功、変更直後の `Write` と提供コマンド `ticket.sh next` も通り、機構は自分を止めていない。

一方で **`common.confirm` の壁は計画書の保留 P5 のとおりに顕在化した**。`.claude/hooks/config/**` は判定順 (4) の `WF203`（ask）に落ち、サブエージェント実行者は確認に答えられないため書き込めない。①の編集は呼び出し元のメインエージェントが代行した。さらに、チケットの `allow.write` に `.claude/hooks/config/**` を宣言していても `workflow-diff-check` は当該ファイルを**許可範囲外（WF601）として報告し続ける** — 宣言と差分検査の見え方がずれる。どちらも仕様どおりの振る舞いなので仕様は直さず、逸脱として記録した。

S2（0019）は**中核 a**として `hook-common.sh` に作業ツリーの三分（`HOOK_ROOT` / `HOOK_WORKTREE` / `HOOK_SHARED_ROOT`）・同一リポジトリの作業ツリーの集合（`hook_worktrees`。`git` を呼ばない）・作業ツリーをまたぐパスの 4 段の畳み込み（`hook_rel_path`）と「判定できない」の戻り値を入れ、`logs/` の置き場を §5 の根の列に合わせ、`decisions.jsonl` に `cwd` と `agent_id` を足した。値が往復する呼び手 3 本の分岐（`workflow-guard` = `WF209` / `workflow-state-guard` = `WF309` / `workflow-diff-check` = `WF605`）も同じチケットで閉じた。`HK-T06` / `HK-T21` / `HK-T22` を含む**全フックのテスト 17 本・128 ID が PASS**（`--timeout 300`）。

S2 で得た大きな学びは 2 つある。①全通しで **`SG-T11` の退行**（`rm -rf .` が `WF302` → `WF309` に化ける）を検出できた。「点だけの相対パス」を判定できない側に倒したのが原因で、置き場ごと消す形を拾えなくなる退行だった（e10）。②中核を壊した瞬間に **fail-closed の deny が `decisions.jsonl` に記録されたのに、対応する `Edit` は止まらなかった**（e11）。「中核を壊しても機構が自分を止める」という前提が成り立っておらず、原因は特定できていない。

- ◎良 8 件 / △注意 2 件（e4・e10）/ ✕問題 1 件（e11）（節は e1〜e11 の 11 件。HTML ビューの章 ID は `f1`〜`f11` で 1 対 1）
- 機械テスト: S1 は `HK-T01` / `HK-T02` PASS。S2 は `HK-T06` / `HK-T21` / `HK-T22` PASS に加え、**全フックのテスト 17 本 128 ID が PASS / FAIL 0 / 重複 ID なし**
- eval: **S1・S2 とも対象は 0 件**（設定ファイルとシェルスクリプトのみで、機械検証できない指示文のアセットを作っていない）。このフェーズでは eval を**実行しない**
- 仕様からの逸脱: 7 件（D1〜D7。D6・D7 が S2 分）

### ◆特に見てほしい（0018 分）

- **`common.confirm` のパスをサブエージェント実行者が書けない運用をこのまま続けてよいか**（D3・D4）。S1 は呼び出し元のメインエージェントが `scope-limits.json` の 1 行だけを代行して抜けたが、同じ問題は S10（0027 / `.claude/settings.json`）でも起きる。計画書は 0027 の実行者を最初からメインエージェントに置いているので実害は無い見込みだが、「サブエージェントに委ねたチケットの一部を呼び出し元が代行する」形自体の是非は人間に判断してほしい

### ◇判断が欲しい（0018 分）

- **`workflow-diff-check` の `WF601` が、宣言済みの `common.confirm` パスを許可範囲外として報告する件（D4）**。差分検査が「宣言（`allow.write`）」ではなく「`scope_classify` の分類が `allow` か」で判定しているために起きる。S2 以降も `.claude/hooks/config/**` に触れるたびに同じ通知が出続けるので、AI が「巻き戻すべき差分」と誤読して成果を消す事故が起こり得る。**このフェーズでは直さず**（`scope.sh` / `workflow-diff-check` の判定を変える話で S3・S5 の範囲を越える）、フィードバック計画（0028）へ渡す案で進めてよいか
- **`.gitignore` を `allow` に足したままにするか**。S1 の目的（`.claude/worktrees/` を無視して `push.sh` 項目 1 が落ちないようにする）は 1 度きりの編集で達成される。以後の実装チケットが `.gitignore` を書く必要は無いので、恒久的に `allow` へ残すか S9 で外すかは選べる。**残す側に倒した**（`.gitattributes` と同じ扱いにしておくほうが、以後 AI アセットフェーズが無視設定を足すたびに設定変更から始めずに済む）

### ◆特に見てほしい（0019 分）

- **fail-closed の deny がツールを止めなかった件（e11 / D7 とは別）**。`hook-common.sh` に未定義関数の呼び出しがある状態で、`workflow-guard` / `workflow-state-guard` の両方が `WF209` / `WF309` を `decisions.jsonl` に記録したのに、`Edit` は 2 回とも成功した。**中核の変更でロックアウトしない**という点では都合がよいが、裏を返せば「中核が壊れたときに機構が止めてくれる」という実装計画書のロックアウト対策の前提が成り立っていない。原因を特定できていないので、S3 以降の中核チケットの進め方（1 つ変えるごとにテスト、を守り続けるか）も含めて判断してほしい
- **`hook_rel_path` の 4 段化で判定対象が広がったこと自体の副作用**。これまで「自ツリーの外」として無視されていたパスが `shared` / `other` として判定に入る。S2 では退行が 1 件（`SG-T11`）出て直したが、`workflow-guard` 側で同じ性質の見落としが無いかは `WG-T19`〜`WG-T21` / `SG-T12` / `SG-T13`（S4）を待たないと確定しない

### ◇判断が欲しい（0019 分）

- **呼び手 3 本の「判定できない」分岐に、S2 では専用の機械テストを足していない**。計画書は `SG-T13`（`WF309`）を S4、`WF605` を S5 に割り付けており、S2 の「依存するテスト」は既存の 3 本が**通り続けること**だけを求めている。この配分のままでよいか（S2 で先に足すべきだったか）を確認したい。現状は既存 IDs（`WG-T10` の `WF209`・`SG-T06`/`SG-T07` の `WF309`・`DC-T01`〜`DC-T07`）が通ることで退行のみを見ている
- **`workflow-state-guard` の実在検査の根を直したこと（e9 後半）が S2 の範囲を越えていないか**。仕様の `SG-T12` が要求する振る舞い（他ツリーの `10_doing/` の既存チケットの更新は通す）を満たすための修正だが、テストは S4 で入る。範囲外なら S4 へ戻す
- **`__hc_roots_n`（正規化済みの根のキャッシュ）を入れたこと**。仕様が要求したものではなく、§1 のホットパスの費用を下げるための実装判断である。`HOOK_WORKTREE` を `__hc_resolve_worktree` の外で代入するとキャッシュが古くなるという制約が増えた（コメントに明記）。残すか外すか

### ・細かいレビューは不要（ほぼ確実）

- `.gitignore` の追記 2 行（コメント 1 行 + `.claude/worktrees/`）の文言と置き場所（末尾）
- 実装計画書 S1 の記述 `WF205` は `WF201` の誤記（D5）。同じ計画書の別の 2 か所（許可範囲の節・DoD）は `WF201` と書いており、実測も `WF201` の経路
- `hook_worktrees` が stale な登録を集合に残すこと（仕様がそう定めている。緩まない理由もコメントに書いた）
- `hook_rel_path` の互換の取り方（`REPLY` を stdout にも出し続ける）。既存の呼び手 3 本はいずれも `>/dev/null` して `REPLY` を読む形で、変更していない
- `test_workflow_guard.sh` が 120 秒に収まらないこと（S2 の変更で始まった話ではなく、9/4 の全通しでも 124 秒。全通しは `--timeout 300` で行う）

## 確かめられなかったこと

| 対象 | 確かめられなかった理由 | 引き取り先 |
|---|---|---|
| `.gitignore` に `.claude/worktrees/` を足した効果（`push.sh` 項目 1 が落ちないこと） | `push.sh` は S1 の `allow.ops` に無く（`remote-write:push` 不許可）、そもそも実際に `.claude/worktrees/` が作られる状況（サブエージェント隔離）が S10 の実測まで発生しない | S10（0027）の実測 / 切れ目の `push` |
| `scope-limits.json` の編集がサブエージェント実行者でも通る条件 | 判定順 (4) の `WF203`（ask）はヘッドレスで deny になるため、実行者からは 1 度も成功させられなかった（代行で回避） | フィードバック計画（0028） |
| `HK-T02` が `.gitignore` の追加そのものを検査しているか | `HK-T02` は「3 つのキー集合の照合と `commands.build-test` の振る舞い」を見るテストで、`types[*].allow` の中身の網羅は見ない。追加の妥当性はテストではなく仕様書 §8 との突き合わせで確かめた（D1） | S9（0026）の全体検査 |
| 呼び手 3 本の「判定できない」分岐が**実際の worktree 環境で**期待どおり出ること（0019） | 機械テストは偽のルート（`.git` ファイルと `.git/worktrees/<名前>/gitdir` の相互参照）で作った構成に対する検査で、`git worktree add` は使えない（`WF204`）。実物の worktree での挙動は S10（0027）の実測まで確かめられない | `SG-T13` / `DC-T08` / `DC-T09`（S4・S5）と S10 の実測 |
| e11（fail-closed の deny がツールを止めない）の原因（0019） | 再現させるには中核を意図的に壊す必要があり、そのたびにロックアウトの危険を負う。1 度目の観測記録（`decisions.jsonl` の 4 行）だけを根拠として残し、追試はしていない | フィードバック計画（0028） |
| `shellcheck` による静的検査（0019） | この環境に `shellcheck` が入っていない（`command not found`）。`bash -n` は変更した 4 本すべてで通した | 環境整備 / S9（0026） |

## 実施条件（測った対象・環境）

- 基準点: `9c2e4d7`（チケット 0018 の `base_sha`）。着手コミット `6dcaabc`
- ブランチ: `feature-50-worktree-parallel-tickets`
- 実行コマンド: `bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --filter '*config_integrity*'` / 同 `--ids` / `jq -e . .claude/hooks/config/scope-limits.json`
- `jq` 1.6

0019（S2）分:

- 基準点: `9059a0f`（チケット 0019 の `base_sha`）。着手コミット `ea6d047`
- 実行コマンド: `bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --filter '*test_hook_common*'` / 同 `--filter '*hooks*' --timeout 300 --ids` / 各テストの直接実行（`bash .claude/hooks/.../tests/test_*.sh`）/ `bash -n <変更した 4 本>`
- `shellcheck` はこの環境に無い（`command not found`）

## 実施した内容と結果

### e1. `scope-limits.json` の `ai-asset-implementation` の `allow` に `.gitignore` を足した ◎良

`.claude/hooks/config/scope-limits.json` の `types["ai-asset-implementation"].allow` の末尾（`".gitattributes"` の後ろ）に `".gitignore"` を 1 要素だけ足した。差分は 1 行の置換（`git diff 9c2e4d7 -- .claude/hooks/config/scope-limits.json` が `2 +-` = 1 行削除 1 行追加）。

形は `.gitattributes` と同じで、**`common.protected`（`[".claude/**", ".gitignore", "apl/*/.gitignore", ".gitattributes"]`）に居るパスを型の `allow` に明示することで判定順 (2) を抜ける**（フック共通仕様 §8「上限設定」）。`.gitignore` は `common.confirm` には入っていないので、明示だけで stage 5 の allow に落ちる。

構文の確認は編集直後に `jq -e . .claude/hooks/config/scope-limits.json`（終了コード 0）。`scope-limits.json` が壊れると `WF210` で全書き込みが止まるため、計画書のロックアウト対策どおり編集は 1 回にまとめた。

**この編集は実行者（サブエージェント）ではなく呼び出し元のメインエージェントが代行した**。理由は e4 と D3 を参照。

### e2. `.gitignore` に `.claude/worktrees/` を足した ◎良

`.gitignore` の末尾に次の 2 行を足した（設計計画書 結論方針 P10 後半 / 設計結果 残課題 R55、実装計画書 変更対象 #2）。

```
# Claude Code のサブエージェント隔離が作る作業ツリーの置き場。ローカル限りで追跡しない（設計計画書 結論方針 P10）
.claude/worktrees/
```

`worktree.sh` の既定の置き場はリポジトリの外なので、この行が効くのは **Claude Code のサブエージェント隔離（`isolation: "worktree"`）や `--worktree` 起動のような外部の仕組みが `.claude/worktrees/` を作る場合だけ**である。実装計画書の保留 P4 のとおり「足しても失うものが無い」ので足す側に倒してある。

### e3. 変えた判定を実際に踏み、機構が自分を止めないことを確かめた ◎良

計画書のロックアウト対策 S1 が要求する 2 点をどちらも踏んだ。

1. **`HK-T02` が `scope-limits.json` を実際に読んで `scope_classify` を走らせる**: `run-tests.sh --filter '*config_integrity*'` が `PASS / exit 0 / passed=95 failures=0`。`--ids` での内訳は `PASS ID: HK-T01 HK-T02 HK-T09` / `FAIL ID:`（空）/ 重複 ID なし
2. **`scope-limits.json` を直した後の `.gitignore` への `Edit` が `WF201` にならず allow（判定 stage 5）で記録された**: `logs/hooks/decisions.jsonl` の該当行（時刻 `2026-09-05T19:15:34+09:00`）

```
{"ts":"2026-09-05T19:15:34+09:00", ... ,"hook":"workflow-guard","event":"PreToolUse","decision":"allow","id":"","tool":"Edit","target":".gitignore","ticket":"0018-ai-asset-implementation.md","note":"判定 5 / 種類 ai-asset-implementation"}
```

`note` の `判定 5` が判定順 (5)（型の `allow` に一致）を指す。`.gitignore` は `common.protected` に居るので、S1 の①が無ければ判定順 (2) で `WF201` になる経路である。**変えた判定をそのまま踏んで allow に抜けた**ことがこの 1 行で確かめられる。

加えて、中核の設定を変えた直後に自分の道具が生きていることを 2 経路で確認した。

| 確認 | 実行 | 結果 |
|---|---|---|
| ツールでの書き込み | `Write` で `wip/tmp/0018-selfcheck.txt` を作成 | 成功（拒否なし） |
| 提供コマンド | `bash .claude/skills/20-common-step-ticket/scripts/ticket.sh next` | `{"current":"0018","next":null,"type":"ai-asset-implementation","skill":"10-task-ai-asset-implementation-exec"}` |

### e4. `common.confirm` の壁と `WF601` の見え方のずれが、計画書の想定どおり（一部は想定外に）出た △注意

`.claude/hooks/config/**` は `common.confirm` なので、判定順 (4) が `WF203`（ask）を返し、**宣言の有無に関わらず (5) に落ちない**。サブエージェント実行者は確認に答えられないため deny になり、e1 の編集は成立しなかった。計画書の保留 P5 が予告していた事象で、対処も保留 P5 が書いたとおり（迂回せず呼び出し元のメインエージェントが 1 ファイルの編集だけを代行）にした（D3）。

想定外だったのは**その後**である。チケットの `allow.write` に `.claude/hooks/config/**` が入っているにもかかわらず、`workflow-diff-check`（PostToolUse）は以後すべてのツール呼び出しで次を報告し続けた（D4）。

```
WF601: 作業中チケット 0018-ai-asset-implementation.md（種類: ai-asset-implementation）の許可範囲外に差分がある。基準点は 9c2e4d7。
- .claude/hooks/config/scope-limits.json（変更 / WF203）
```

差分検査が「チケットが宣言したか」ではなく「`scope_classify` の分類が `allow` か」で見ているために起きる。識別子が `WF203` と併記されているので**宣言違反ではない**と読めるが、文面は「巻き戻せ」と指示している。実装フェーズの残り（S2〜S10）は `.claude/hooks/**` をほぼ毎チケットで触るため、この通知は出続ける。**指示に従って巻き戻すと計画の成果が消える**ので、判断の分かれ目としてここに残す。

### e5. 作業ツリーの三分を入れ、共有ルートを `HOOK_ROOT` に固定した（0019 / S2 ①）◎良

`hook-common.sh` に `HOOK_SHARED_ROOT` と `HOOK_WORKTREE_STATE` を足し、フック共通仕様 §2 の 3 つの根（置き場 `HOOK_ROOT` / 判定対象の作業ツリー `HOOK_WORKTREE` / 共有ルート `HOOK_SHARED_ROOT`）を別々の変数で持つようにした。

`HOOK_SHARED_ROOT` は**上書きの口を作らない**。`${HOOK_SHARED_ROOT:-...}` の形にせず、宣言時と `__hc_resolve_worktree` の冒頭の 2 か所で無条件に `HOOK_ROOT` を代入し直す。環境変数で先に置かれていても勝たない。仕様の理由（進行状態の置き場を外から動かせると `workflow-state-guard` の保護対象そのものを外せる）をコメントに残した。`HK-T21` は入力を流す前に `HOOK_SHARED_ROOT=$TMP_REPO/evil-shared` を置き、読み込み後に `HOOK_ROOT` に戻っていることを assert する（負のコントロール）。

### e6. 同一リポジトリの作業ツリーの集合 `hook_worktrees` を `git` なしで作った（0019 / S2 ②）◎良

`<HOOK_ROOT>/.git/worktrees/*/gitdir` を glob で列挙し、各ファイルを組み込みの `$(<file)` で読み、`/.git` を落として集合 `__HC_WT_SET` に入れる。`git` は 1 度も呼ばない（§1 のホットパスの fork 上限）。集合は入力 1 件のあいだキャッシュし、`__hc_resolve_worktree` が入力ごとに捨てる。

- **stale な登録も残す**（指し先が実在しなくても集合に入れる）。この集合は「保護してよい範囲」を広げるためだけに使い、`HOOK_WORKTREE` の決定には使わないので、余分に含めても判定は緩まない
- `.git/worktrees` が**在るのに列挙できない**（ディレクトリでない・読めない・辿れない）ときだけ `unreadable` にして戻り 1。**存在しない（worktree が 1 つも無い）のは正常**で、集合は `HOOK_ROOT` の 1 件になる。`HK-T22` はこの 2 つを別々の assert に分けている

### e7. `hook_rel_path` を 4 段の畳み込みにし、「判定できない」を戻り値で返すようにした（0019 / S2 ③）◎良

畳み込みは仕様 §2 の順で、結果は「どのツリーの、ルート相対のどのパスか」の対で返す。呼び手は `REPLY`（ルート相対パス）・`REPLY_ROOT`（そのツリーのルート）・`REPLY_KIND`・戻り値の 4 つを読む。

| 段 | 条件 | `REPLY_KIND` | 戻り |
|---|---|---|---|
| 1 | `HOOK_WORKTREE` の配下 | `worktree` | 0 |
| 2 | 共有ルートの配下 | `shared` | 0 |
| 3 | 作業ツリーの集合のいずれかの配下 | `other` | 0 |
| 4 | どれの配下でもない（同一リポジトリの外と確定） | `outside` | 1 |
| — | 作業ツリーを確定できない / 正規化に失敗 / 集合を読めない | `unknown` | **2** |

比較の前に `__hc_winpath` で `.` / `..` を畳み、`\` と `/` の差と大文字小文字を吸収する。相対パスは自ツリー基準で絶対に直してから畳む。互換のため `REPLY` を stdout にも出す（既存の呼び手は `>/dev/null` して `REPLY` を読む形のまま動く）。

### e8. `logs/` の置き場を §5 の根の列に合わせ、`decisions.jsonl` に `cwd` と `agent_id` を足した（0019 / S2 ④）◎良

| 記録 | 根 | 実装 |
|---|---|---|
| 判定記録 `logs/hooks/decisions.jsonl` | ツリー | `hook_record` が `$HOOK_WORKTREE/logs/hooks/` へ |
| 実行ログ `logs/sh/` | ツリー | `__hc_relog` が作業ツリー確定後に `LOGGER_DIR` / `LOGGER_FILE` だけを貼り替える（`LOGGER_ROOT` は動かさない — 置き場を探すのに使われるため） |
| 進行状態（`review-state` / `merge-state`） | 共有 | `hook_read_state` が `$HOOK_SHARED_ROOT/logs/` から読む |
| ロック `logs/locks/` | 共有 | `hc_lock` / `hc_unlock` / `__hc_unlock_all`（ロックはブランチ単位の資源なので、ツリーごとに分けると排他が成立しない） |
| セッション状態 `logs/sessions/<id>/` | 共有 | `hook_session_dir`（宣言・承認は issue と MR に属する。ツリーごとに分けると worktree の中で宣言が無い扱いになる） |

`decisions.jsonl` の 1 行に `agent_id`（サブエージェント内のツール呼び出しにだけ付く。メインでは空文字）と `cwd`（判定時の作業ツリー）を足した。**このチケットの実作業でも実際に出ている**（下の e11 の記録は `"agent_id":"a20098422793dfc22","cwd":"c:/Users/.../issue-mr-ticket-workflow"` を含む）。

### e9. 呼び手 3 本を「判定できない」の規約どおりに分岐させた（0019 / S2 ⑤）◎良

`hook_rel_path` は書く側と読む側が往復する値なので、呼び手の分岐を同じチケットで閉じた。

| 呼び手 | 側 | 判定できないとき | 実装 |
|---|---|---|---|
| `workflow-guard` | 拒否 | **deny `WF209`** | `__wg_rel` が戻り 2 を受けて `hook_deny WF209`。4 段目（同一リポジトリの外）は従来どおり絶対パスのまま返るので、既存の「作業ツリーの外」の検査が拾う（文面を「同一リポジトリのどの作業ツリーの外」に直した） |
| `workflow-state-guard` | 拒否 | **deny `WF309`** | `__sg_rel` が戻り 2 を受けて `hook_deny WF309`。外と**確定**した場合はここに来ず、従来どおり許可（保護対象はリポジトリの中にしか無い） |
| `workflow-diff-check` | 案内 | **`WF605` を additionalContext** | 制御方式 0 として `HOOK_WORKTREE_STATE != ok` で `hook_notify PostToolUse WF605` して抜ける。承認の記憶の走査で個別のパスが畳めなかった場合も `__dc_unknown` を立てて `WF605` を 1 段落足す（黙って飛ばさない） |

あわせて `workflow-state-guard` の**実在検査の根**を直した。`10_doing/` への新規作成だけを `WF302` にする判定は `[[ ! -e "$HOOK_WORKTREE/$p" ]]` で見ていたが、他の作業ツリーへ畳まれたパス（`REPLY_KIND=other`）では自ツリーに同名が無いだけで**既存チケットの更新まで拒否**になる。畳んだ根（`REPLY_ROOT`）から見るように変えた。

### e10. 退行 1 件（`SG-T11`）を全フックのテストで検出して直した／ホットパスの費用を測った △注意

`--filter '*hooks*'` の全通しで `SG-T11` が 1 件落ちた: **`rm -rf .` が `WF302` ではなく `WF309`** になっていた。原因は `hook_rel_path` が「正規化の結果が空」を一律に「判定できない」に倒していたこと。`.` / `./` / `./.` は `__hc_winpath` の結果が空文字になるが、これは**自ツリーのルートを指す正当な入力**である。入力そのものが空のときだけ 2 を返し、点だけの相対パスは `.` として相対解決へ回すように直し、`HK-T22` に 3 つの assert（`.` / `./` / `./.` → `0|worktree|.`）を足して固定した。**置き場ごと消す形を拾えなくなる退行**だったので、負のコントロールの価値がそのまま出た形になる。

ホットパスの費用も測った。`hook_rel_path` は書き込み対象の数だけ呼ばれるので、根の正規化を毎回やり直すのは無駄である。`__hc_roots_n` を入れて正規化済みの根（`__HC_ROOT_N` / `__HC_WT_N`）を入力ごとに 1 回だけ作るようにした。一時計測（測定後に削除）で 1 回あたり **1.5〜2.2 ms**（2000 回で 3.0〜4.4 秒。Windows の Git Bash）で、1 回のフック起動あたり数回の呼び出しなら §1 の 1 秒の目安には影響しない。

なお `test_workflow_guard.sh` は **`run-tests.sh` の既定の 120 秒に収まらない**（今回 149〜207 秒）。これは本チケットの変更で始まったことではなく、9/4 の全通し（`--timeout 300`）でも 124 秒かかっていた。同じ日の他のテスト（変更していない `test_block_chmod` 等）も 1.6〜1.8 倍に伸びていたので、機械の負荷（並行セッション）の影響が大きい。**全フックの確認は `--timeout 300` で行った**（9/4 の全通しと同じ条件）。

### e11. 中核を壊した瞬間、fail-closed の deny が記録されたのに**ツールは止まらなかった** ✕問題

`__hc_roots_n` を「呼ぶ側」だけ先に入れ、定義を入れる前に 2 回 `Edit` した瞬間（`hook-common.sh` に未定義関数の呼び出しがある状態）、`decisions.jsonl` に次の 2 組が残った。

```
20:50:48 workflow-state-guard deny WF309 機構の不調 — フックの内部エラー（hook-common.sh:867）...
20:50:48 workflow-guard       deny WF209 機構の不調 — フックの内部エラー（hook-common.sh:867）...
20:51:01 （同じ 2 行）
```

`hook_fail` → `hook_deny` の経路（`__hc_on_err` の ERR トラップ）が正しく発火し、拒否側 2 本が deny を**記録**している。ところが**対応する `Edit` は 2 回とも成功し、ツールは止まらなかった**（ファイルには両方の編集が入っており、直後の `bash -n` も通った）。つまり fail-closed の deny が実際の遮断につながっていない。

- 事実として言えるのはここまでで、**原因は特定できていない**（`__wg_rel` の呼び出しはコマンド置換の中ではないので、「サブシェルで `exit 0` した」という説明は当たらない。拒否側 2 本が同時に deny を出したときの扱い、または登録ラッパーの出力の扱いを疑っている）
- 結果としてロックアウトは起きず、復旧手順（`git show <base_sha>:<パス>` → Write）は使わずに済んだ。ただし**「中核を壊しても機構が自分を止めてくれる」という前提が成り立っていない**ことになるので、実装フェーズの残り（S3〜S10）は今回と同じく**1 つ変えるごとにテストを回す**運用で進める必要がある
- 仕様 §3 は打ち切り（timeout）を「フェイルクローズドの原則の唯一の穴」と書いているが、今回の事象は打ち切りではない。フィードバック計画へ渡す（R8）

## 検証の結果

| 検証 | 結果 |
|---|---|
| `jq -e . .claude/hooks/config/scope-limits.json` | 終了コード 0（構文は壊れていない） |
| `run-tests.sh --filter '*config_integrity*'` | `PASS / exit 0 / passed=95 failures=0`（1 本 / 3 件） |
| 同 `--ids` | `PASS ID: HK-T01 HK-T02 HK-T09` / `FAIL ID:` 空 / 重複 ID なし |
| `.gitignore` の `Edit` が allow / stage 5 | `logs/hooks/decisions.jsonl` に 1 行（`"decision":"allow"` かつ `"note":"判定 5 / 種類 ai-asset-implementation"`）。`WF201` の行は同じ対象に無い |
| 変更が S1 の許可範囲に収まっているか | `git diff 9c2e4d7 --stat` = `scope-limits.json` 1 行 / `.gitignore` 3 行 / チケット 1 枚。いずれも `allow.write`（`wip/**`, `.claude/hooks/config/**`, `.gitignore`）の内側 |
| 中核変更後に自分が動くか | `Write`（`wip/tmp/`）と `ticket.sh next` の 2 経路が成功 |
| S1 が担当する参照更新 | 実装計画書「参照更新一覧」7 行はすべて S9（0026）担当。**S1 の担当は 0 行**（消し込む対象が無い） |
| プレースホルダ | 二重波かっこのテンプレート記法は md・HTML とも 0 件（`check-html.sh` の検査 1 が数えるのはこの記法だけ）。`TODO` / `TBD` は**検査項目の名前として書いた 2 行**（この表と「検査結果」の表）以外に 0 件 |
| frontmatter | このレポートの md に `type` / `title` / `description` / `tags` / `keywords` の 5 キー。S1 は frontmatter を持つアセット（スキル・エージェント・チケット）を作成・変更していないので、他に検査対象なし |

0019（S2）分:

| 検証 | 結果 |
|---|---|
| `bash -n`（変更した 4 本） | `hook-common.sh` / `workflow-guard.sh` / `workflow-state-guard.sh` / `workflow-diff-check.sh` すべて終了コード 0 |
| `run-tests.sh --filter '*test_hook_common*'` | `PASS / exit 0 / passed=238 failures=0`（`HK-T01`〜`HK-T22`） |
| `run-tests.sh --filter '*hooks*' --timeout 300 --ids` | `OK: 17 本 / 128 件`。全 17 本 PASS、`FAIL ID:` 空、重複 ID なし。`HK-T06` / `HK-T21` / `HK-T22` / `SG-T11` を含む |
| 退行の検出と修正 | 既定の 120 秒で回した 1 回目に `SG-T11` が FAIL（`rm -rf .` → `WF309`）。`hook_rel_path` を直し、`HK-T22` に assert を 3 つ足して再実行し PASS |
| 中核変更後に自分が動くか | `Write`（`wip/tmp/0019-lockout-check.txt`）と `Read` が成功。`decisions.jsonl` に `workflow-guard allow / 判定 5 / 種類 ai-asset-implementation` が 1 行 |
| `decisions.jsonl` の新しい列が実運用でも入るか | 上の 1 行が `"agent_id":"a20098422793dfc22"`（サブエージェント）と `"cwd":"c:/Users/.../issue-mr-ticket-workflow"` を持つ |
| `WF605` の誤爆 | `decisions.jsonl` に `"id":"WF605"` は **0 件**（`grep` で確認） |
| 変更が S2 の許可範囲に収まっているか | `git diff 9059a0f --stat` = `.claude/hooks/**` 5 ファイル / `wip/10_tickets/**` 1 枚。いずれも `allow.write`（`wip/**`, `.claude/hooks/**`）の内側。範囲外の差分・未追跡ファイルなし |
| S2 が担当する参照更新 | 実装計画書「参照更新一覧」7 行はすべて S9（0026）担当。**S2 の担当は 0 行** |

## 作成・更新したアセットの一覧（仕様書の節との対応）

| # | アセット | 種別 | 変更 | 仕様書の節 | チケット |
|---|---|---|---|---|---|
| 1 | `.claude/hooks/config/scope-limits.json` | フックの設定 | 更新（1 行） | `10_spec/フック共通仕様.md` §8「上限設定」（`ai-asset-implementation` の行） | 0018 |
| 2 | `.gitignore` | リポジトリ設定 | 更新（2 行追加） | 設計計画書 結論方針 P10 後半 / 設計結果 残課題 R55（仕様書に節は無い） | 0018 |
| 3 | `wip/30_reports/0018-ai-asset-implementation.md` / `.html` | 成果物（レポート） | 新規 | `10_spec/skills/10-task-ai-asset-implementation-exec.md`「OUT ひな形」 | 0018 |
| 4 | `.claude/hooks/lib/hook-common.sh` | フックの共通ライブラリ | 更新 | `10_spec/フック共通仕様.md` §2「作業ツリーの三分」「同一リポジトリの作業ツリーの集合」「作業ツリーをまたぐパスの畳み込み」「判定できないときの倒し方」／§5「記録と状態」の根の列 | 0019 |
| 5 | `.claude/hooks/lib/tests/test_hook_common.sh` | フックのテスト | 更新（`HK-T06` 追記・`HK-T21`・`HK-T22` 新設） | 同 §11 テスト（`HK-T06` / `HK-T21` / `HK-T22`） | 0019 |
| 6 | `.claude/hooks/20-PreToolUse/workflow-guard.sh` | フック | 更新（`__wg_rel` の `WF209` 分岐） | `10_spec/hooks/20-PreToolUse/workflow-guard.md` 制御方式 5（畳み込みの結果ごとの扱い） | 0019 |
| 7 | `.claude/hooks/20-PreToolUse/workflow-state-guard.sh` | フック | 更新（`__sg_rel` の `WF309` 分岐・実在検査の根） | `10_spec/hooks/20-PreToolUse/workflow-state-guard.md`「対象パスの畳み込み」・制御方式 2 | 0019 |
| 8 | `.claude/hooks/22-PostToolUse/workflow-diff-check.sh` | フック | 更新（制御方式 0 の `WF605`・承認の記憶の `WF605`） | `10_spec/hooks/22-PostToolUse/workflow-diff-check.md` 制御方式 0・`WF605` | 0019 |

`.claude/skills/**` / `.claude/rules/**` / `.claude/agents/**` / `.claude/evals/**` / `.claude/settings.json` は S1・S2 では**1 件も触っていない**。`.claude/hooks/config/**` は S1 のみ（S2 は触っていない）。

## テスト結果

### 機械テスト

| テスト ID | 対象 | 実行コマンド | 結果 |
|---|---|---|---|
| HK-T01 | `settings.json` の登録表（PreToolUse `Agent` の行が無いことの負のコントロール。S1 では `settings.json` を変えないことの確認として踏む） | `bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --filter '*config_integrity*'` | **PASS** |
| HK-T02 | `scope-limits.json` の 3 つのキー集合の照合と `commands.build-test` の振る舞い | 同上 | **PASS** |
| HK-T09 | 同じテストファイル（`test_config_integrity.sh`）が持つ 3 件目。S1 の DoD には無いが同時に走る | 同上 | **PASS**（参考） |

- 集計: `1 本 / 3 件`、`passed=95 failures=0`、`FAIL` 0 件、重複 ID なし
- テスト先行（失敗確認 → 実装 → 成功）は**適用していない**。S1 は既存のテスト（`test_config_integrity.sh`）が読む設定値を変えるだけで、新しいテストを足していないため（計画書「依存するテスト」も S1 に新設テストを割り付けていない）

0019（S2）分:

| テスト ID | 対象 | 実行コマンド | 結果 |
|---|---|---|---|
| HK-T21 | 作業ツリーの三分（`cwd`=worktree で `HOOK_WORKTREE`=worktree・`HOOK_ROOT`/`HOOK_SHARED_ROOT`=本流）と `logs/` の根。環境変数での `HOOK_SHARED_ROOT` 上書きが効かないこと（負のコントロール）、作業ツリーが 1 つなら 3 つとも同じ値になること（負のコントロール） | `bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --filter '*test_hook_common*'` | **PASS**（新設） |
| HK-T22 | `hook_rel_path` の 4 段の畳み込み。`.` / `..` / `\` 区切り / 大文字小文字を畳んでも同じ、外の絶対パスは畳めない（負のコントロール）、集合を読めないときは「判定できない」、集合が空なだけなら「判定できない」にならない（負のコントロール）、点だけの相対パスは自ツリーのルート | 同上 | **PASS**（新設） |
| HK-T06 | `decisions.jsonl` の 1 行が §5 のスキーマ（12 キー）を満たし、`cwd` に判定時の作業ツリー、サブエージェント内では `agent_id` が入る。メインでは空文字（負のコントロール） | 同上 | **PASS**（`agent_id` / `cwd` の検査を追記） |
| SG-T11 | 置き場ごとの削除（`rm -rf .` を含む）。**1 回目は FAIL**（`WF302` を期待して `WF309`）。`hook_rel_path` を直して PASS | `run-tests.sh --filter '*hooks*' --timeout 300` | **PASS**（修正後） |
| 全フック 17 本 / 128 ID | `hook-common.sh` を読み込むフックの全テスト | `run-tests.sh --filter '*hooks*' --timeout 300 --ids` | **全 PASS**（`FAIL ID:` 空 / 重複 ID なし / `OK: 17 本 / 128 件`） |

- テスト先行: `HK-T21` / `HK-T22` は**実装より先に書いて失敗を確認**してから実装した（0019 の前半。作業ログ参照）。`SG-T11` は**既存テストが退行を先に落とした**形で、失敗を見てから直した
- 呼び手 3 本の「判定できない」分岐に対する**新設テストは無い**。計画書が `SG-T13`（`WF309`）を S4、`WF605` を S5 に割り付けており、S2 の「依存するテスト」は既存 3 本が通り続けることだけを求めているため（◇判断が欲しい に挙げた）

### eval

| eval ID | 状態 |
|---|---|
| （該当なし） | S1 は設定ファイルのみを変更し、機械検証できない指示文のアセット（スキル・ルール・エージェント）を作成・変更していないので、定義すべき eval は 0 件 |

**このフェーズで eval は実行しない**（`10-task-ai-asset-implementation-exec` の禁止事項。実行は人間の判断）。S5 以降で作るスキル・ルール・エージェントの eval も、定義まで作って実行しない。

## 検査結果

| 検査 | 対象 | 件数 | 判定 |
|---|---|---|---|
| プレースホルダ（二重波かっこのテンプレート記法 / `TODO` / `TBD`） | `wip/30_reports/0018-ai-asset-implementation.md` と `.html` | 0 件（`TODO` / `TBD` は検査項目名として書いた 2 行を除く） | OK |
| frontmatter の必須項目 | 上記 md（`type` / `title` / `description` / `tags` / `keywords`） | 5 / 5 | OK。S1 は frontmatter を持つアセットを作成・変更していない |
| 参照更新一覧の消し込み | 実装計画書の 7 行 | S1 の担当 0 行 | 対象なし（全 7 行が S9 / 0026 担当） |
| HTML ビュー | `wip/30_reports/0018-ai-asset-implementation.html` | `check-html.sh` 7 項目 | OK（作業ログに出力を記録） |
| プレースホルダ（0019） | 変更した 4 本のシェルスクリプトとこのレポート md / HTML | 0 件（テンプレート由来の二重波かっこ・`TODO` / `TBD` とも。`TODO` / `TBD` はこの表と「検証の結果」の項目名を除く） | OK |
| frontmatter（0019） | S2 が触ったアセットに frontmatter を持つものは無い（シェルスクリプト 4 本）。チケット 0019 の frontmatter は変更していない | 対象 0 件 | OK |
| 参照更新一覧の消し込み（0019） | 実装計画書の 7 行 | S2 の担当 0 行 | 対象なし（全 7 行が S9 / 0026 担当） |
| 静的検査（0019） | 変更した 4 本 | `bash -n` 4 / 4 OK、`shellcheck` は環境に無く未実施 | 一部未実施（「確かめられなかったこと」に記載） |

## 仕様からの逸脱

**設計文書（`.claude/docs/**`）は 1 文字も直していない**（実装フェーズの `deny`）。食い違いはすべてここに記録し、フィードバック計画（0028）→ 設計反映フェーズへ渡す。

| # | 逸脱 | 仕様・計画の記述 | 実装の実態 | 扱い |
|---|---|---|---|---|
| D1 | フック共通仕様 §8 の**初期値の JSON**（`"ai-asset-implementation"` の行）に `.gitignore` が無い | `10_spec/フック共通仕様.md` L306: `"allow": [".claude/skills/**", ..., ".claude/evals/**", ".gitattributes"]` | 実物の `scope-limits.json` は `..., "CLAUDE.md", ".gitattributes", ".gitignore"` | 仕様は直さず記録。設計反映で JSON と表を実物に合わせる |
| D2 | 同 §8 の**初期値の JSON と同節の表が、S1 の変更より前から食い違っている** | L306 の JSON には `CLAUDE.md` が**無い**が、L330 の表には `CLAUDE.md` がある | 実物には `CLAUDE.md` がある（表が正しい） | S1 の変更とは無関係な既存の不整合。D1 と同じ箇所を直すときに一緒に直す |
| D3 | `common.confirm` のパスは、チケットで宣言しても**サブエージェント実行者には書けない** | 実装計画書 保留 P5 が予告（「サブエージェントは確認に答えられないので deny になり得る」） | そのとおり deny。呼び出し元のメインエージェントが `scope-limits.json` の編集を代行した | 迂回せず代行という保留 P5 の運用に従った。運用の是非は切れ目のレビューで人間に確認する |
| D4 | `workflow-diff-check` の `WF601` が、**チケットが宣言済みのパスを「許可範囲外」として報告する** | チケット 0018 の `allow.write` に `.claude/hooks/config/**` がある | `common.confirm` のパスは `scope_classify` が `confirm`（`WF203`）に分類するため `allow` にならず、差分検査が許可範囲外として列挙し続ける | **巻き戻さない**（巻き戻すと S1 の成果が消える）。差分検査が宣言ではなく分類で見ている点の是非をフィードバック計画へ |
| D5 | 実装計画書 S1 の識別子の誤記 | 計画書 L236: 「①が済むまで②は **WF205** で止まる」 | 正しくは `WF201`（`Edit` / `Write` ツールの宣言範囲外）。同じ計画書の L151・L153 と 0018 の DoD は `WF201` と書いている | 計画書の誤記。設計文書ではないが、S9 の全体検査で直すか設計反映へ渡す |
| D6 | `workflow-diff-check` の `WF605` を、仕様の**制御方式 0**（停止中の判定より前）ではなく**制御方式 1 の後**に置いた（0019） | `10_spec/hooks/22-PostToolUse/workflow-diff-check.md` は「0. 作業ツリーの確定 … 決められない → WF605 を伝えて抜ける」を 1 より前に置く | 実装は `hook_enforce_enabled \|\| hook_disabled` の**後**に置いた | 共通仕様 §3「停止中のフックは判定・注入を行わず `disabled` を 1 行残す」と両立させるため。`workflow-state-guard` 仕様は同じ状況に「0 は 1 の後に評価する」と明記しており、そちらに揃えた。仕様は直さず、diff-check 仕様にも同じ注記を足す案を設計反映へ |
| D7 | `hook_read_state`（`review` / `merge` / `approvals` / `entry`）が共通仕様 §1 の**1 回目の jq** ではなく**2 回目**にある（0019 で維持） | §1 の表は `review-state` / `merge-state` を 1 回目に置く | 共有ルートの解決は `cwd`（= stdin）を読む `__hc_resolve_worktree` の後なので、1 回目には渡せない。既存の逸脱コメント（「作業ツリー」基準）を S2 で「共有ルート」基準に読み替えて維持した | S2 で作った逸脱ではなく、三分の導入で理由が変わった逸脱。設計反映で §1 の表を実装に合わせる |

## 設計への反映

| # | 反映すること | 引き取り先 |
|---|---|---|
| 1 | フック共通仕様 §8 の初期値 JSON と表に `.gitignore`（と JSON 側の `CLAUDE.md`）を反映する（D1・D2） | `10_spec/フック共通仕様.md` / 設計反映フェーズ |
| 2 | `common.confirm` のパスをサブエージェント実行者が扱えない件の恒久的な扱い（型の `allow` で `confirm` を上書きできる形にするか、実行者をメインエージェントに固定するか、代行を正式な運用として書くか）（D3） | フィードバック計画（0028）→ 設計反映 |
| 3 | `workflow-diff-check` が宣言済みの `confirm` パスを許可範囲外として報告する件（D4） | フィードバック計画（0028）→ 設計反映（`workflow-diff-check` 仕様 / `scope.sh`） |
| 4 | 実装計画書 S1 の `WF205` → `WF201` の訂正（D5） | S9（0026）の全体検査 |
| 5 | `workflow-diff-check` 仕様の制御方式 0 に「1（停止中）の後に評価する」注記を足す（D6。`workflow-state-guard` 仕様には既にある） | 設計反映フェーズ |
| 6 | フック共通仕様 §1 の副入力の表（1 回目 / 2 回目）を実装に合わせる（D7） | 設計反映フェーズ |
| 7 | 中核が壊れたときの fail-closed が実際には遮断にならない件（e11）。仕様 §3 は打ち切りだけを「唯一の穴」と書いている | フィードバック計画（0028）→ 設計反映 |

## 想定と異なった点

| 計画時の見込み | 実際 | どう扱ったか |
|---|---|---|
| S1 の実行者（サブエージェント）が `scope-limits.json` を編集できるかは五分五分（保留 P5） | できなかった（判定順 (4) の `WF203` が ask を返し、ヘッドレスでは deny） | 迂回せず、呼び出し元のメインエージェントが**その 1 ファイルの編集だけ**を代行した。実行者は結果報告に上げる運用（保留 P5 の記述どおり）を守った |
| 宣言に書いたパスは差分検査で許可範囲内として扱われる | `common.confirm` のパスは宣言していても `WF601` で許可範囲外として報告され続ける | 巻き戻さず、D4 として記録した。作業ログの「拒否・確認・迂回の記録」にも同じ判断を残した |
| `.gitignore` を先に編集しようとすると `WF205` で止まる（計画書 L236） | 止まるのは `WF201`（`Edit` ツールの宣言範囲外）。`WF205` は**コマンドによる書き込み**の識別子 | D5 として記録。実測では①→②の順を守ったので、②は最初から allow で通った |
| 中核を変えた直後は何かが止まりうる | `Write`・`ticket.sh next`・`run-tests.sh` のいずれも止まらなかった | ロックアウト対策の復旧手順（`git show <base_sha>:<パス>` → `Write`）は使わずに済んだ |
| （想定外）`mkdir -p wip/tmp` が通る | `WF205` で拒否された。コマンドで書いてよいのは `wip/tmp/**` と `logs/**` で、**ディレクトリ `wip/tmp` そのもの**はパターンに含まれない | ディレクトリは既に存在していたので実害なし。R3 として残す |
| （0019）`hook_rel_path` の 4 段化は「これまで無視していたパスを判定に入れる」変更なので、**通っていた書き込みが落ちる**のが主なリスク（計画書のリスク 1） | 落ちたのは書き込みではなく `rm -rf .`（`WF302` → `WF309`）だった。「範囲が広がる」方向ではなく「判定できないに倒しすぎる」方向の退行 | 既存の `SG-T11` が拾った。`hook_rel_path` を直し、`HK-T22` に負のコントロールを足して固定した（e10） |
| （0019）中核を壊せば機構が自分を止める（＝ロックアウト対策が要る） | `decisions.jsonl` には deny が記録されたが、**ツールは止まらなかった**（e11）。復旧手順（`git show` → Write）は使わずに済んだ | 止まらなかったこと自体を ✕問題として記録し、R8 でフィードバック計画へ渡す。運用は「1 つ変えるごとにテスト」を続ける |
| （0019）`test_workflow_guard.sh` は既定の 120 秒で回る | 149〜207 秒かかり `TIMEOUT`。9/4 の全通しでも 124 秒で、変更していないテストも同日比 1.6〜1.8 倍に伸びていた（機械の負荷） | 全通しは 9/4 と同じ `--timeout 300` で行った。S2 の変更による退行ではないと判断（e10） |
| （0019）`shellcheck` を掛けられる | この環境に入っていない | `bash -n` だけで確認し、「確かめられなかったこと」に残した |

## 残課題

| # | 残課題 | 引き取り先 |
|---|---|---|
| R1 | `.gitignore` の `.claude/worktrees/` が実際に効くこと（`push.sh` 項目 1 が落ちないこと）の確認 | S10（0027）の実測 / 切れ目の `push` |
| R2 | `.gitignore` を `ai-asset-implementation` の `allow` に**恒久的に残すか**の判断（S1 の目的は 1 度きりの編集で達成済み） | 切れ目のレビュー / S9（0026） |
| R3 | コマンドによる書き込みの許可パターンが `wip/tmp/**` で、ディレクトリ `wip/tmp` 自身の作成（`mkdir`）を通さない | フィードバック計画（0028） |
| R4 | このレポートは 0019〜0027 が節を積み上げる器である。各チケットは md 側 `e5, e6, …` / HTML 側 `f5, f6, …` と連番を続け、サマリの件数・逸脱・残課題を**その都度更新**する（累積の数は「サマリ」1 か所にだけ置く） | 0019〜0027 |
| R5 | 呼び手 3 本の「判定できない」分岐に専用の機械テストが無い（`SG-T13` は S4、`WF605` は S5 の割り付け）。S2 は既存テストの非退行だけで確かめている | S4（0021）/ S5（0022） |
| R6 | `workflow-state-guard` の実在検査を畳んだ根から見るように直した（e9 後半）が、その振る舞いを固定するテストは `SG-T12`（S4）である | S4（0021） |
| R7 | `__hc_roots_n`（正規化済みの根のキャッシュ）は仕様に無い実装判断。`HOOK_WORKTREE` を `__hc_resolve_worktree` の外で代入するとキャッシュが古くなる制約が増えた | 切れ目のレビュー / 設計反映 |
| R8 | 中核が壊れたとき、fail-closed の deny が `decisions.jsonl` に残るのに**ツールが止まらない**（e11）。原因未特定 | フィードバック計画（0028） |
| R9 | `test_workflow_guard.sh` が `run-tests.sh` の既定 120 秒に収まらない（9/4 時点で 124 秒）。全通しに `--timeout 300` が要る | S9（0026）/ フィードバック計画（0028） |
| R10 | `shellcheck` がこの環境に無く、シェルスクリプトの静的検査が `bash -n` だけになっている | 環境整備 / S9（0026） |
