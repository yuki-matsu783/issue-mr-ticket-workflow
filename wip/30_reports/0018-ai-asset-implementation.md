---
type: report
title: 0018〜0027 AI アセット実装・テスト結果 — 実装フェーズの許可範囲の設定と .claude/worktrees/ の無視（S1 分）
description: issue #50 の AI アセット実装フェーズ（S1〜S10 / チケット 0018〜0027）が積み上げる実装結果レポート。S1 では scope-limits.json の ai-asset-implementation の allow に .gitignore を足し、.gitignore に .claude/worktrees/ を足し、HK-T01 / HK-T02 と「自分が止まらないこと」で確かめた。common.confirm のパスがサブエージェントでは書けないこと、宣言していても WF601 が許可範囲外として報告することを逸脱に記録した
tags: [report, ai-asset-implementation, issue-50]
keywords: [scope-limits.json, .gitignore, .claude/worktrees/, common.confirm, WF203, WF601, ロックアウト対策, HK-T01, HK-T02, 判定順]
---

# 0018〜0027 AI アセット実装・テスト結果 — 実装フェーズの許可範囲の設定と .claude/worktrees/ の無視（S1 分）

- 対象 issue: [#50](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/50)
- MR: [#51](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/pull/51)（draft）
- ブランチ: `feature-50-worktree-parallel-tickets`
- チケット: 0018〜0027（実装計画書 `wip/20_plans/0016-ai-asset-implementation-plan.md` の S1〜S10。**このレポートは各チケットが節を積み上げる器**で、現時点の内容は 0018（S1）分だけ）
- 作成日: 2026-09-05

## サマリ

S1（0018）は実装フェーズの**入口の設定**を 2 つ変えた。①`.claude/hooks/config/scope-limits.json` の `types["ai-asset-implementation"].allow` に `.gitignore` を足し（`.gitattributes` と同じ「`common.protected` を明示で判定順 (2) を通す」形）、②`.gitignore` に `.claude/worktrees/` を足した。①→② の順を守り、②が `WF201` にならず **judge stage 5 の allow** で `logs/hooks/decisions.jsonl` に記録されたことをもって、変えた判定を実際に踏んだことを確かめた。機械テストは `HK-T01` / `HK-T02` とも PASS、`jq -e .` も成功、変更直後の `Write` と提供コマンド `ticket.sh next` も通り、機構は自分を止めていない。

一方で **`common.confirm` の壁は計画書の保留 P5 のとおりに顕在化した**。`.claude/hooks/config/**` は判定順 (4) の `WF203`（ask）に落ち、サブエージェント実行者は確認に答えられないため書き込めない。①の編集は呼び出し元のメインエージェントが代行した。さらに、チケットの `allow.write` に `.claude/hooks/config/**` を宣言していても `workflow-diff-check` は当該ファイルを**許可範囲外（WF601）として報告し続ける** — 宣言と差分検査の見え方がずれる。どちらも仕様どおりの振る舞いなので仕様は直さず、逸脱として記録した。

- ◎良 3 件 / △注意 1 件（e4）/ ✕問題 0 件（節は e1〜e4 の 4 件。HTML ビューの章 ID は `f1`〜`f4` で 1 対 1）
- 機械テスト: `HK-T01` PASS / `HK-T02` PASS（同じテストファイルが持つ `HK-T09` も PASS。`passed=95 failures=0`）
- eval: **S1 の対象は 0 件**（設定ファイルのみで、機械検証できない指示文のアセットを作っていない）。このフェーズでは eval を**実行しない**
- 仕様からの逸脱: 5 件（D1〜D5。うち仕様書の記述と実装の食い違いが 2 件、機構の振る舞いと計画書・宣言の見え方のずれが 3 件）

### ◆特に見てほしい（0018 分）

- **`common.confirm` のパスをサブエージェント実行者が書けない運用をこのまま続けてよいか**（D3・D4）。S1 は呼び出し元のメインエージェントが `scope-limits.json` の 1 行だけを代行して抜けたが、同じ問題は S10（0027 / `.claude/settings.json`）でも起きる。計画書は 0027 の実行者を最初からメインエージェントに置いているので実害は無い見込みだが、「サブエージェントに委ねたチケットの一部を呼び出し元が代行する」形自体の是非は人間に判断してほしい

### ◇判断が欲しい（0018 分）

- **`workflow-diff-check` の `WF601` が、宣言済みの `common.confirm` パスを許可範囲外として報告する件（D4）**。差分検査が「宣言（`allow.write`）」ではなく「`scope_classify` の分類が `allow` か」で判定しているために起きる。S2 以降も `.claude/hooks/config/**` に触れるたびに同じ通知が出続けるので、AI が「巻き戻すべき差分」と誤読して成果を消す事故が起こり得る。**このフェーズでは直さず**（`scope.sh` / `workflow-diff-check` の判定を変える話で S3・S5 の範囲を越える）、フィードバック計画（0028）へ渡す案で進めてよいか
- **`.gitignore` を `allow` に足したままにするか**。S1 の目的（`.claude/worktrees/` を無視して `push.sh` 項目 1 が落ちないようにする）は 1 度きりの編集で達成される。以後の実装チケットが `.gitignore` を書く必要は無いので、恒久的に `allow` へ残すか S9 で外すかは選べる。**残す側に倒した**（`.gitattributes` と同じ扱いにしておくほうが、以後 AI アセットフェーズが無視設定を足すたびに設定変更から始めずに済む）

### ・細かいレビューは不要（ほぼ確実）

- `.gitignore` の追記 2 行（コメント 1 行 + `.claude/worktrees/`）の文言と置き場所（末尾）
- 実装計画書 S1 の記述 `WF205` は `WF201` の誤記（D5）。同じ計画書の別の 2 か所（許可範囲の節・DoD）は `WF201` と書いており、実測も `WF201` の経路

## 確かめられなかったこと

| 対象 | 確かめられなかった理由 | 引き取り先 |
|---|---|---|
| `.gitignore` に `.claude/worktrees/` を足した効果（`push.sh` 項目 1 が落ちないこと） | `push.sh` は S1 の `allow.ops` に無く（`remote-write:push` 不許可）、そもそも実際に `.claude/worktrees/` が作られる状況（サブエージェント隔離）が S10 の実測まで発生しない | S10（0027）の実測 / 切れ目の `push` |
| `scope-limits.json` の編集がサブエージェント実行者でも通る条件 | 判定順 (4) の `WF203`（ask）はヘッドレスで deny になるため、実行者からは 1 度も成功させられなかった（代行で回避） | フィードバック計画（0028） |
| `HK-T02` が `.gitignore` の追加そのものを検査しているか | `HK-T02` は「3 つのキー集合の照合と `commands.build-test` の振る舞い」を見るテストで、`types[*].allow` の中身の網羅は見ない。追加の妥当性はテストではなく仕様書 §8 との突き合わせで確かめた（D1） | S9（0026）の全体検査 |

## 実施条件（測った対象・環境）

- 基準点: `9c2e4d7`（チケット 0018 の `base_sha`）。着手コミット `6dcaabc`
- ブランチ: `feature-50-worktree-parallel-tickets`
- 実行コマンド: `bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --filter '*config_integrity*'` / 同 `--ids` / `jq -e . .claude/hooks/config/scope-limits.json`
- `jq` 1.6

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

## 作成・更新したアセットの一覧（仕様書の節との対応）

| # | アセット | 種別 | 変更 | 仕様書の節 | チケット |
|---|---|---|---|---|---|
| 1 | `.claude/hooks/config/scope-limits.json` | フックの設定 | 更新（1 行） | `10_spec/フック共通仕様.md` §8「上限設定」（`ai-asset-implementation` の行） | 0018 |
| 2 | `.gitignore` | リポジトリ設定 | 更新（2 行追加） | 設計計画書 結論方針 P10 後半 / 設計結果 残課題 R55（仕様書に節は無い） | 0018 |
| 3 | `wip/30_reports/0018-ai-asset-implementation.md` / `.html` | 成果物（レポート） | 新規 | `10_spec/skills/10-task-ai-asset-implementation-exec.md`「OUT ひな形」 | 0018 |

`.claude/skills/**` / `.claude/hooks/*.sh` / `.claude/rules/**` / `.claude/agents/**` / `.claude/evals/**` / `.claude/settings.json` は S1 では**1 件も触っていない**。

## テスト結果

### 機械テスト

| テスト ID | 対象 | 実行コマンド | 結果 |
|---|---|---|---|
| HK-T01 | `settings.json` の登録表（PreToolUse `Agent` の行が無いことの負のコントロール。S1 では `settings.json` を変えないことの確認として踏む） | `bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --filter '*config_integrity*'` | **PASS** |
| HK-T02 | `scope-limits.json` の 3 つのキー集合の照合と `commands.build-test` の振る舞い | 同上 | **PASS** |
| HK-T09 | 同じテストファイル（`test_config_integrity.sh`）が持つ 3 件目。S1 の DoD には無いが同時に走る | 同上 | **PASS**（参考） |

- 集計: `1 本 / 3 件`、`passed=95 failures=0`、`FAIL` 0 件、重複 ID なし
- テスト先行（失敗確認 → 実装 → 成功）は**適用していない**。S1 は既存のテスト（`test_config_integrity.sh`）が読む設定値を変えるだけで、新しいテストを足していないため（計画書「依存するテスト」も S1 に新設テストを割り付けていない）

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

## 仕様からの逸脱

**設計文書（`.claude/docs/**`）は 1 文字も直していない**（実装フェーズの `deny`）。食い違いはすべてここに記録し、フィードバック計画（0028）→ 設計反映フェーズへ渡す。

| # | 逸脱 | 仕様・計画の記述 | 実装の実態 | 扱い |
|---|---|---|---|---|
| D1 | フック共通仕様 §8 の**初期値の JSON**（`"ai-asset-implementation"` の行）に `.gitignore` が無い | `10_spec/フック共通仕様.md` L306: `"allow": [".claude/skills/**", ..., ".claude/evals/**", ".gitattributes"]` | 実物の `scope-limits.json` は `..., "CLAUDE.md", ".gitattributes", ".gitignore"` | 仕様は直さず記録。設計反映で JSON と表を実物に合わせる |
| D2 | 同 §8 の**初期値の JSON と同節の表が、S1 の変更より前から食い違っている** | L306 の JSON には `CLAUDE.md` が**無い**が、L330 の表には `CLAUDE.md` がある | 実物には `CLAUDE.md` がある（表が正しい） | S1 の変更とは無関係な既存の不整合。D1 と同じ箇所を直すときに一緒に直す |
| D3 | `common.confirm` のパスは、チケットで宣言しても**サブエージェント実行者には書けない** | 実装計画書 保留 P5 が予告（「サブエージェントは確認に答えられないので deny になり得る」） | そのとおり deny。呼び出し元のメインエージェントが `scope-limits.json` の編集を代行した | 迂回せず代行という保留 P5 の運用に従った。運用の是非は切れ目のレビューで人間に確認する |
| D4 | `workflow-diff-check` の `WF601` が、**チケットが宣言済みのパスを「許可範囲外」として報告する** | チケット 0018 の `allow.write` に `.claude/hooks/config/**` がある | `common.confirm` のパスは `scope_classify` が `confirm`（`WF203`）に分類するため `allow` にならず、差分検査が許可範囲外として列挙し続ける | **巻き戻さない**（巻き戻すと S1 の成果が消える）。差分検査が宣言ではなく分類で見ている点の是非をフィードバック計画へ |
| D5 | 実装計画書 S1 の識別子の誤記 | 計画書 L236: 「①が済むまで②は **WF205** で止まる」 | 正しくは `WF201`（`Edit` / `Write` ツールの宣言範囲外）。同じ計画書の L151・L153 と 0018 の DoD は `WF201` と書いている | 計画書の誤記。設計文書ではないが、S9 の全体検査で直すか設計反映へ渡す |

## 設計への反映

| # | 反映すること | 引き取り先 |
|---|---|---|
| 1 | フック共通仕様 §8 の初期値 JSON と表に `.gitignore`（と JSON 側の `CLAUDE.md`）を反映する（D1・D2） | `10_spec/フック共通仕様.md` / 設計反映フェーズ |
| 2 | `common.confirm` のパスをサブエージェント実行者が扱えない件の恒久的な扱い（型の `allow` で `confirm` を上書きできる形にするか、実行者をメインエージェントに固定するか、代行を正式な運用として書くか）（D3） | フィードバック計画（0028）→ 設計反映 |
| 3 | `workflow-diff-check` が宣言済みの `confirm` パスを許可範囲外として報告する件（D4） | フィードバック計画（0028）→ 設計反映（`workflow-diff-check` 仕様 / `scope.sh`） |
| 4 | 実装計画書 S1 の `WF205` → `WF201` の訂正（D5） | S9（0026）の全体検査 |

## 想定と異なった点

| 計画時の見込み | 実際 | どう扱ったか |
|---|---|---|
| S1 の実行者（サブエージェント）が `scope-limits.json` を編集できるかは五分五分（保留 P5） | できなかった（判定順 (4) の `WF203` が ask を返し、ヘッドレスでは deny） | 迂回せず、呼び出し元のメインエージェントが**その 1 ファイルの編集だけ**を代行した。実行者は結果報告に上げる運用（保留 P5 の記述どおり）を守った |
| 宣言に書いたパスは差分検査で許可範囲内として扱われる | `common.confirm` のパスは宣言していても `WF601` で許可範囲外として報告され続ける | 巻き戻さず、D4 として記録した。作業ログの「拒否・確認・迂回の記録」にも同じ判断を残した |
| `.gitignore` を先に編集しようとすると `WF205` で止まる（計画書 L236） | 止まるのは `WF201`（`Edit` ツールの宣言範囲外）。`WF205` は**コマンドによる書き込み**の識別子 | D5 として記録。実測では①→②の順を守ったので、②は最初から allow で通った |
| 中核を変えた直後は何かが止まりうる | `Write`・`ticket.sh next`・`run-tests.sh` のいずれも止まらなかった | ロックアウト対策の復旧手順（`git show <base_sha>:<パス>` → `Write`）は使わずに済んだ |
| （想定外）`mkdir -p wip/tmp` が通る | `WF205` で拒否された。コマンドで書いてよいのは `wip/tmp/**` と `logs/**` で、**ディレクトリ `wip/tmp` そのもの**はパターンに含まれない | ディレクトリは既に存在していたので実害なし。R3 として残す |

## 残課題

| # | 残課題 | 引き取り先 |
|---|---|---|
| R1 | `.gitignore` の `.claude/worktrees/` が実際に効くこと（`push.sh` 項目 1 が落ちないこと）の確認 | S10（0027）の実測 / 切れ目の `push` |
| R2 | `.gitignore` を `ai-asset-implementation` の `allow` に**恒久的に残すか**の判断（S1 の目的は 1 度きりの編集で達成済み） | 切れ目のレビュー / S9（0026） |
| R3 | コマンドによる書き込みの許可パターンが `wip/tmp/**` で、ディレクトリ `wip/tmp` 自身の作成（`mkdir`）を通さない | フィードバック計画（0028） |
| R4 | このレポートは 0019〜0027 が節を積み上げる器である。各チケットは md 側 `e5, e6, …` / HTML 側 `f5, f6, …` と連番を続け、サマリの件数・逸脱・残課題を**その都度更新**する（累積の数は「サマリ」1 か所にだけ置く） | 0019〜0027 |
