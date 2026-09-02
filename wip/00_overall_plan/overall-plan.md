---
type: overall-plan
title: issue #9 全体計画 — 自己改善ワークフロー機構の実装 2/3（フック本体と登録）
description: フック本体 11 本の実装・settings.json への登録（人間の操作）・フック共通仕様 §12 の TBD（T1〜T4・T6〜T8）の実測検証を行う issue の全体計画。フェーズ列、受け入れ条件との対応、work-defaults との差分としての実行者・レビュー要否・やってよいこと、登録によるロックアウトと全体まとめの実行経路の段取りを定める
tags: [overall-plan, issue-9, ai-asset]
keywords: [全体計画, フェーズ列, AI アセット, フック本体, settings.json 登録, TBD 検証, ロックアウト, 段階登録, work-defaults, HK-T01, WF304]
---

# issue #9 全体計画 — 自己改善ワークフロー機構の実装 2/3（フック本体と登録）

## 対象

- 対象 issue: #9 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/9
- MR: #12 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/pull/12（draft）
- ブランチ: `feature-9-hook-bodies-settings`（`origin/main` 058855e から分岐。058855e は #6 の PR #7 が squash で入った版）
- マージ方式: リポジトリは squash / merge commit / rebase のすべてが許可（`gh repo view --json squashMergeAllowed,mergeCommitAllowed,rebaseMergeAllowed` → すべて true）。main の履歴は #2・#5・#7 とも squash で 1 コミットに畳まれているので、本 MR も squash 前提とする（既定の設定変更は行わない）

## 種別

**AI アセット**。変更対象は `.claude/hooks/<イベント>/*.sh` と各テスト、`.claude/settings.json`（登録は人間）、および検証結果の書き戻し先 `.claude/docs/`（`10_spec/フック共通仕様.md`・各フック仕様・`20_ddr/`）。`docs/`・アプリのソースコードは含まない。

## フェーズ列

AI アセットのテンプレート（`10_spec/skills/00-workflow-issue-mr-driven.md`「フェーズ列のテンプレート」）をそのまま採用する。省略なし。

| 順 | フェーズ | チケット種類 | この issue での中身 |
|---|---|---|---|
| 1 | 全体計画 | `overall-plan` | 本計画（このチケット。指摘反映の追加チケットを含む） |
| 2 | 調査 | `investigation-plan` → `investigation` | **読み取りだけで答えられる問い**に限る: 11 本の仕様の判定順・識別子・終了方式・テスト ID の洗い出しと矛盾の検出、#6 で作った `hooks/lib` 5 本の公開関数と結線点の確認、参考実装（`agent-workflow`）のフックの実績（`exit 2` + stderr）と本仕様（`permissionDecision` + 終了 0）の差、公式 hooks リファレンス（`web`）による入力・出力フィールドの確認。**実測が要る問い（§12 の T1〜T4・T6〜T8）は「実装フェーズの検証項目」の一覧として整理するだけで、この段では実施しない**（理由は下記） |
| 3 | AI アセット設計 | `ai-asset-design-plan` → `ai-asset-design` | 実測を待たずに決められるものを仕様に書く: `HOOK_DENY_ID` の既定と §6 台帳の整合 / 「作業中チケット 2 枚以上」の扱い（G8。WF207 の側で決め、提供コマンド側の非対称は方針だけ）/ `web` の強制の可否（D3）/ `investigation` 以外の実施タスクの `ops` 上限（D5。方針まで。`scope-limits.json` の実体変更はフェーズ 4）/ `shellcheck` の CI 実行の方針（D6）/ 調査で見つかった仕様の矛盾の解消。経緯は DDR `i0009-NN` に残す |
| 4 | AI アセット実装・テスト | `ai-asset-implementation-plan` → `ai-asset-implementation` | 主作業。(a) フック本体 11 本と各テスト（案内側 6 本 → 拒否側 5 本）→ (b) `settings.json` への段階登録（人間の操作。①記録・案内側 → ②-1 拒否側 1 本で **T6** を確認 → ②-2 残る拒否側 4 本）→ (c) **登録済みの本物のフックの記録（`logs/hooks/decisions.jsonl`・`logs/sh/`）で T1〜T4・T7・T8・`agent_type` を実測** → (d) HK-T01（登録照合）と `run-tests.sh --ids` の全件通過。`.claude/hooks/config/blocked-commands.txt`（`block-chmod` が読む禁止コマンド一覧。初期値 `chmod`）の新規作成もこのフェーズ。実測の結果は作業ログに残す（このフェーズは `.claude/docs/**` に書けない） |
| 5 | フィードバック計画 | `feedback-plan` | 実測の結果と実装で判明した仕様との食い違いを棚卸しし、後続フェーズ（仕様への書き戻しと DDR）の要否を決める。受け入れ条件 3・5 は「仕様に反映されていること」を求めるので、書き戻しの `ai-asset-design` が要る見込みが高い（決定はこのフェーズで行う） |
| 6 | 後続（フィードバック計画が選んだものだけ） | `ai-asset-design` 系 / `ai-asset-implementation` 系 | 未定 |
| 7 | 全体まとめ | `overall-summary` | 統括レポート、MR 本文の最終整形（成果物リンク一覧を本文の表に置く）、片付け、draft 解除。**登録済みのフックとの関係は下記「登録後に全体まとめが通らない経路」で扱う** |

テンプレートとの差分: なし。

**実測を調査フェーズに置かない理由**: `10-task-investigation-plan` 仕様は「`.claude/**` への一時的な変更（`settings.json` へのフックの一時登録など）は計画しない。……確かめたいことは既存の記録で代えるか、AI アセット実装フェーズの検証に回す」と明示している。プローブフックの本体を `wip/tmp/` に置いても、登録そのものを計画すればこの禁止に当たる。実装フェーズなら `.claude/hooks/**` が許可範囲で、登録も段取りに含まれるため、**本物のフックが残す記録で同じことが確かめられる**（捨てるプローブを作る必要がない）。

**書き戻しの置き場（決定ではなく制約）**: 受け入れ条件 3・5・6 は `.claude/docs/**` への書き戻しを求めるが、実装フェーズは `.claude/docs/**` に書けない（`scope-limits.json` の `ai-asset-implementation.deny`）。したがって「実測の結果を仕様に反映する必要があると判断された場合、その置き場はフェーズ 6 以外に無い」という制約がある。**要否の判断自体はフィードバック計画（フェーズ 5）が行う**（`10-task-overall-plan` 仕様の禁止事項により、全体計画はフィードバック計画より後のフェーズの要否を決めない）。フェーズ 3 の時点で書けるのは、実測に依存しない決定だけ。

## 受け入れ条件との対応

| # | issue #9 の受け入れ条件 | 満たすフェーズ | 検証の形 |
|---|---|---|---|
| 1 | フック本体 11 本が各仕様の判定順・識別子・終了方式どおりに動き、テスト（HK-T01 / HK-T09 / HK-T03 の登録部分を含む）が失敗ケースを含めて通る | 2（仕様の洗い出し）→ 4 | 各フック仕様のテスト ID 表（SS-H\* / WE-T\* / WG-T\* / SG-T\* / …）＋ 共通の HK-T01・T03・T04・T09 を `run-tests.sh` で実行。終了方式は T6 の実測（フェーズ 4b の ②-1）で裏を取る |
| 2 | `settings.json` への登録手順（人間の操作）が全体計画と結果報告に書かれ、登録後に `run-tests.sh --ids` の全件と HK-T01 が通る | 1（本計画の「settings.json の登録とロックアウト対策」）→ 4b・4d | 登録前後のテスト結果を実装結果報告に記録 |
| 3 | §12 の TBD T1〜T4 の検証結果が共通仕様に反映され、経緯が DDR に残っている | 4c（実測）→ 5 → 6（書き戻し） | 実装結果報告の実測ログ、共通仕様 §12 の該当行の消滅、DDR `i0009-NN` |
| 4 | `HOOK_DENY_ID` の既定と「作業中チケット 2 枚以上」の扱いが仕様（§6・該当フック）に決まり、テストで固定されている | 3 → 4 | 仕様の差分 ＋ テスト（WG-T\*（WF207）・登録ラッパーの WFx09） |
| 5 | `tool_response` / `agent_type` / `web` の強制 / `defer` の扱いが実物の確認に基づいて仕様に書かれている（扱わないものは理由つきで「扱わない」） | 2（公式リファレンス）→ 4c（実測）→ 5 → 6 | 実測表 ＋ 共通仕様 §2・§8 の差分 |
| 6 | 実装で判明した仕様との食い違いは仕様書へ書き戻し、経緯を DDR に残している | 4（作業ログ「仕様からの逸脱」）→ 5 → 6 | フィードバック計画の棚卸し表、DDR |

## 方針

基準は `.claude/rules/work-defaults.md`（#6 で作成済み。この issue が初めてこの表を基準として使う）。差分は「何を・どちらへ・なぜ」で書く。

| type | 基準（work-defaults） | この issue | 差分（何を → どちらへ・なぜ） |
|---|---|---|---|
| overall-plan | メイン / 要 / 不要 | メイン / 代替 / 不要 | 人間レビュー: 要 → **opus の敵対的自己レビューで代替**（承認④）。敵対的レビュー: 不要 → **要**（代替の実施主体になるため） |
| investigation-plan | opus サブ / 不要 / 不要 | メイン / 不要 / 不要 | 実行者: サブ → **メイン**（※1） |
| investigation | sonnet サブ / 要 / 不要 | メイン / 代替 / 要 | 実行者: サブ → **メイン**（※1）。人間レビュー: 要 → 代替（承認④）。敵対的レビュー: 不要 → **要**（同上。結論が実装計画を左右するので省かない） |
| ai-asset-design-plan | opus サブ / 不要 / 不要 | メイン / 不要 / 不要 | 実行者: サブ → **メイン**（※1） |
| ai-asset-design | opus サブ / 要 / 要 | メイン / 代替 / 要 | 実行者: サブ → **メイン**（※1）。人間レビュー: 要 → 代替（承認④）。敵対的レビューは基準どおり要 |
| ai-asset-implementation-plan | opus サブ / 要 / 不要 | メイン / 代替 / 要 | 実行者: サブ → **メイン**（※1）。人間レビュー: 要 → 代替（承認④）。敵対的レビュー: 不要 → **要**（中核とロックアウト対策を含むため） |
| ai-asset-implementation | opus サブ / 要 / 要 | メイン / 代替 / 要（切れ目ごと 1 回） | 実行者: サブ → **メイン**（※1）。人間レビュー: 要 → 代替（承認④）。敵対的レビューは基準どおり要。中核そのものなので軽減しない |
| feedback-plan | メイン / 要 / 不要 | メイン / 代替 / 要 | 人間レビュー: 要 → 代替（承認④）。敵対的レビュー: 不要 → **要**（後続フェーズの要否を人間の代わりに検証するため） |
| overall-summary | メイン / 要（最終確認）/ 不要 | メイン / **人間**（最終確認）/ 不要 | 基準どおり。draft 解除の前の最終確認だけは人間が行う（承認③の再取得。マージも人間） |

（※1）**実行者を全種類メインエージェントに倒す**。理由: サブエージェントの起動テンプレートと `task-executor` エージェントは 3/3（#10）の範囲で未実装であり、チケットの状態遷移・コミットの作法をサブエージェントに教える手段が無い。加えて、この issue で作る `subagent-start-check` はサブエージェントの実行者（`model`）とチケットの `executor` を突き合わせるフックであり、その検査対象の運用を検査の実装と同時に始めると、失敗の原因が「運用の誤り」か「フックの欠陥」か切り分けられない。サブエージェントは**敵対的レビュー**にだけ使う。既定のサブエージェント運用は #10 で提供コマンド・エージェントが揃ってから始める。

**承認④の代替の中身**: 切れ目ごとに差分を opus サブエージェントに渡して敵対的レビューを行い、confidence >= 0.5 の指摘は同じ type の追加チケットに落としてから次のタスクへ進む。レビュー依頼コメントの MR への投稿は証跡として続ける。全体まとめの draft 解除の直前だけは人間の最終確認（承認③）を取る。マージは人間が行う（`gh pr merge` は実行しない）。

**`boundary.sh` 不在による既知の逸脱**: 切れ目の判定・レビュー依頼・完了の記録は `boundary.sh`（3/3）が担う設計だが未実装のため、依頼は `gh pr comment` の直接投稿で代替する（`00-workflow-issue-mr-driven` 仕様の禁止事項に当たる既知の逸脱。`logs/review-state.json` は生成されない）。3/3 で解消する。

やってよいこと（`allow`）:

| type | write（宣言） | ops |
|---|---|---|
| 計画系（`*-plan`） | `wip/**` | `read`, `remote-read` |
| `feedback-plan` | `wip/**` | `read`, `remote-read`, `remote-write:issue-create`（別 issue の起票） |
| `investigation` | `wip/**` | `read`, `remote-read`, `web`（公式 hooks リファレンスの確認） |
| `ai-asset-design` | `.claude/docs/**`, `wip/**` | `read`, `remote-read` |
| `ai-asset-implementation` | `.claude/hooks/**`（`config/scope-limits.json` の変更・`config/blocked-commands.txt` の新規作成を含む）, `.claude/skills/20-common-step-shell-script/**`（テストヘルパの拡張が要る場合のみ）, `wip/**` | `read`, `hook-test`, `remote-read` |
| `overall-summary` | `wip/**` | `read`, `remote-read`, `merge-base`, `remote-write:mr-edit`, `remote-write:mr-comment`, `remote-write:issue-create`, `remote-write:attach`, `remote-write:push`, `remote-write:draft-ready` |

- `wip/**` は `scope-limits.json` の `common.allow`（`wip/00_overall_plan/**`・`wip/10_tickets/**`・`wip/20_plans/**`・`wip/30_reports/**`・`wip/tmp/**` ほか）により宣言によらず書ける。上表の `wip/**` は意図の記録で、判定上の実効は `common.allow` の側にある（`wip/` 直下の任意ファイルは WF202 の確認になる）
- `build-test` はどの type でも宣言しない。フックのテストは `.claude/hooks/**/tests/*.sh` = `hook-test`、提供コマンドのテスト（`run-tests.sh` 経由を含む）は `provided` で常に通り、`commands.build-test` は空配列のため `build-test` に該当するコマンドが無い
- `.claude/settings.json` は**どの type でも AI が書かない**（宣言にも入れない）。登録は人間が行う。コミットの扱いは下記
- `.claude/hooks/config/**` の変更（D5・G8 の結論が `scope-limits.json` の上限に及ぶ場合、`blocked-commands.txt` の新規作成）はフェーズ 4 で行う（`common.confirm` に当たるため WF203 の確認が毎回入り、`scope-limits.json` を変えるなら HK-T02 の 3 者一致も回す）
- `CLAUDE.md` / 旧ワークフロースキル / 用語集の参照更新は 3/3（#10）。この issue では触らない
- コミット・push・チケットの状態遷移は提供コマンド（`commit.sh` / `push.sh` / `ticket.sh`）経由のみ

## settings.json の登録とロックアウト対策

登録すると機構の強制が初めて実体を持つ。誤りがあると自分自身の操作（Edit / Bash / コミット）が止まるため、次の段取りで進める（詳細は実装計画で確定する）。

1. **バックアップ（登録前の必須手順）**: 人間が `.claude/settings.json` を登録前の版としてコピーしておく（`settings.json` は git 追跡下だが、登録の途中で復元できる形を手元に持つ）。AI は貼り付ける JSON（§1 の登録表どおり。拒否側 5 登録は fail-closed ラッパー付き）と手順を用意して提示する
2. **段階登録**（§1 の登録表 16 行をすべて割り当てる）:
   - **① 記録・案内側（11 行）**: SessionStart 1 / **UserPromptSubmit 1（workflow-entry・宣言の記録）** / **PreToolUse `Skill` 1（workflow-entry・宣言の記録）** / PostToolUse 4 / SubagentStart 1 / SubagentStop 2 / **Stop 1**。この段では `entry.json`・`decisions.jsonl` が書かれ始めるが拒否は起きない。**HK-T01（表との行単位の照合）はこの時点では落ちる**（②の完了後に照合する）
   - **②-1 拒否側の 1 本目（1 行）**: `block-chmod`（判定が単純で影響範囲が狭い）を fail-closed ラッパー付きで登録し、**T6**（`permissionDecision` + 終了 0 の deny が実際に効くか）を確かめる。効かなければ `exit 2` + stderr の縮退に切り替え、§1 の登録ラッパーごと作り直してから先へ進む
   - **②-2 残る拒否側（4 行）**: PreToolUse の workflow-entry（未宣言の拒否）/ workflow-state-guard / block-direct-git / workflow-guard。fail-closed ラッパー付き
   - 段ごとに新しいセッションで軽い操作（Read → Skill 宣言 → Edit → `commit.sh`）を通し、想定外の deny が出ないことを確かめる
3. **切り戻し（2 種類を区別する）**:
   - **判定の誤りで deny が出る場合**: `WORKFLOW_ENFORCE=0` または `WORKFLOW_<NAME>_ENFORCE=0` を設定した**新しいセッション**で再開する（環境変数はセッション開始時に読まれるため同一セッションでは解除できない — §4）
   - **フック本体が起動できない場合（WFx09 が出る）**: fail-closed ラッパーは環境変数を見ないので**環境変数では戻らない**。1 のバックアップからの復元（人間の操作）だけが経路
4. **登録した `settings.json` のコミット**: 登録は人間、コミットは AI が `commit.sh .claude/settings.json` で行う。`settings.json` は `common.confirm` に当たるため WF203 の確認が出る（人間が承認する）。ヘッドレスでは deny になるので、この操作は対話セッションで行う
5. **登録の照合**: ②-2 の完了後に HK-T01（§1 の表と `settings.json` の行単位の照合）と `run-tests.sh --ids` の全件を回し、結果を実装結果報告に記録する
6. **3/3 の未実装への依存**: `session-start` は `boundary.sh status --offline`（3/3）が無ければ何も出さずに終了 0、`workflow-entry` は `logs/` と作業領域を直接読むため 3/3 が無くても動く。この前提はフェーズ 4c の実測で確かめる

### 登録後に全体まとめが通らない経路（R3）

②（拒否側）を登録したままフェーズ 7 に入ると、`workflow-state-guard` が次を拒否する。どれも提供コマンド `finalize.sh`（3/3・未実装）が唯一の経路として設計されているためで、**想定どおりに動いた結果として詰む**。

| 操作 | 拒否 | 本来の経路 |
|---|---|---|
| `gh pr ready 12`（draft 解除） | WF304 | `finalize.sh release` |
| 全体まとめチケットを完了の置き場へ（`ticket.sh complete` は TK005 で拒否） | WF303 | `finalize.sh release` が完了を内包 |
| 片付け（`wip/` の削除）自体は `rm` なので `workflow-state-guard` の対象外（制御方式 2・3 は作成・編集・移動が対象）。ただし片付けは `finalize.sh release` が完了検査ごと内包する設計で、単独の手順が仕様に無い | — | `finalize.sh release` |

採る手（実装計画で確定し、フェーズ 7 の直前に人間と最終確認する）:

- **第 1 案（推奨）**: `WORKFLOW_STATE_GUARD_ENFORCE=0` を設定した**新しいセッション**でフェーズ 7 を実施する。`settings.json` を触らないので登録は 16 行のまま保たれ、HK-T01 と全件テストが通る状態でマージできる。他のフック（`workflow-guard` 等）の強制は残る
- **第 2 案**: 人間が拒否側 5 行を一時撤去する。ただし `settings.json` は git 追跡下なので、**撤去したままでは `push.sh` の項目 1（未コミットの変更が無い）で CP005 になり、コミットすれば 11/16 行の登録のままマージされて HK-T01 と全件テストが落ちる**。採るなら「フェーズ 7 の最終 push の前に 5 行を再登録し、HK-T01 と全件を回し直してからコミットする」を必須手順にする
- **第 3 案**: draft 解除・片付け・完了を人間が手で行う

## 判断が必要になりそうな点（調査の問い / 実装フェーズの検証項目）

読み取りで答えるもの（フェーズ 2）:

1. 11 本のフック仕様の判定順・識別子・終了方式・テスト ID の洗い出しと、仕様どうしの矛盾（`hooks/lib` の公開関数と各仕様の呼び出しの食い違いを含む）
2. 参考実装（`agent-workflow`）のフックが使う `exit 2` + stderr と、本仕様の `permissionDecision` + 終了 0 の差（T6 の予備知識）
3. 公式 hooks リファレンスによる入力・出力フィールドの確認（`SubagentStart` の実在と `model` / `agent_id`、`permissionDecision: "defer"`、`tool_response` のフィールド名）
4. `git 'commit'` のようにクォートで割った語のサブコマンド判定（`block-direct-git` は「特定できない」として扱う — D2）の仕様上の扱い
5. §12 の T5（PowerShell ツールの stdin 固有フィールド）が #6 で解決済みか（DDR・#6 の作業ログを読む）。済みなら §12 の T5 行の削除を書き戻しの対象に含める

実測が要るもの（フェーズ 4c。§12 の TBD と受け入れ条件 5）:

| # | 項目 | 確かめ方（登録済みの本物のフックの記録で） |
|---|---|---|
| ~~T1~~ | ~~`SubagentStop` の出力がメインエージェントに届くか~~ | **公式で解決済み・実測は不要**（`hooks.md:2346`「To inject context into the parent session after a subagent returns, use a `PostToolUse` hook on the `Agent` tool instead.」。現行の登録が公式の推奨形。共通仕様 §12 T1・DDR i0009-43） |
| T2 | サブエージェント内のツール呼び出しの `session_id` が親と同じか | `decisions.jsonl` の `session_id` を親子で比較 |
| T3 | `claude -p` を入力から判別できるか / `defer` の実在 | ヘッドレス実行時の入力（`permission_mode` 等）を `decisions.jsonl` に記録して比較 |
| T4 | `SubagentStart` イベントと `model` / `agent_id` の実在 | ①の登録後にサブエージェントを起動し、`logs/` に記録が残るかを見る |
| T9 | `systemMessage` が PreToolUse で**ユーザーに実際に表示されるか** | ②-2（7 行目 `subagent-start-check` の登録）の後、`executor` と違うモデルでサブエージェントを 1 つ起動し、警告がその場で表示されるかを見る。**登録表を 17 行に保つ唯一の支え**（共通仕様 §12 T9・DDR i0009-54） |
| — | `Agent` の `tool_response.status` が既定で `async_launched` になるか（サブエージェントが既定で background） | 同じ起動で `logs/` に落ちた `tool_response` を見る。`completed` なら `subagent-stop-check` の分岐は使われない（共通仕様 §2・DDR i0009-50） |
| — | **worktree に入ったとき、フックが worktree 側のチケットを見るか**（`${CLAUDE_PROJECT_DIR}` は本流に留まり `cwd` が追随する。共通仕様 §2・DDR i0009-55） | ②を登録した状態で `git worktree add` して Claude をそこへ移し、worktree 側の `wip/10_tickets/10_doing/` にチケットを置いて `workflow-guard` が判定するかを見る（本流を見ていれば「0 枚 → 許可」になり何も起きない） |
| T6 | PreToolUse の deny が `permissionDecision` + 終了 0 で効くか | 段階登録の ②-1（拒否側 1 本目 `block-chmod` の登録）で真っ先に確かめる。効かなければ `exit 2` + stderr へ切り替え、§1 の登録ラッパーも作り直す |
| T7 | `tool_response` の終了コードのフィールド名 | `post-push-*` が読む値を `logs/` に落として実物を見る。**公式で「終了コードのフィールドは存在しない」と分かっている（§12 T7）が、受け入れ条件 5 が「実物の確認に基づいて」を求めるため実測は省かない**（DDR i0009-43） |
| — | `agent_type` の実物（`subagent-stop-check` が読む値。受け入れ条件 5） | T4 と同じサブエージェント起動で `logs/` に残る値を見る |
| T8 | 案内側フックが `scope.sh` を `source` したとき `frontmatter.sh` が読めない場合の挙動（D2 の「案内側フックの `scope.sh` 読み込みポリシー」） | `frontmatter.sh` を一時的にリネーム（`mv`。宣言済みの `.claude/skills/20-common-step-shell-script/**` の内側）して案内側フックの挙動を見る。`chmod` は `block-chmod` が WF501 で拒否するうえ Windows では読み取り不可にできない |

## 保留した点

| 項目 | 決める時期 |
|---|---|
| `HOOK_DENY_ID` の既定（§6 台帳に無い `WF009` をどう扱うか） | AI アセット設計 |
| 「作業中チケット 2 枚以上」の扱い（G8）。WF207 の側で決め、`push.sh` / `run-tests.sh` / 完了検査の非対称を直すかは方針まで（提供コマンドの修正が要るなら 3/3 へ） | **決定済み**（DDR `i0009-18`・`i0009-40`）: 実体は直さず 1 枚前提を仕様に明記。`push.sh` の項目 2 だけ #10 へ申し送る |
| `investigation` 以外の実施タスクの `ops` 上限（D5）。`scope-limits.json` の実体を変えるかどうか | **決定済み**（DDR `i0009-19`）: 上限は広げない。`scope-limits.json` の実体は変えるならフェーズ 4 で実施（WF203 の確認 + HK-T02） |
| `shellcheck` の CI 実行（D6） | **決定済み**（DDR `i0009-19`）: CI に載せない。処理フロー 5 のローカル検査を続け、実施の有無の記録を省略できないものとする |
| フェーズ 7 を通すための手（上記の第 1〜3 案のどれを採るか。既定は第 1 案 = `WORKFLOW_STATE_GUARD_ENFORCE=0` の新セッション） | AI アセット実装計画で案を確定し、フェーズ 7 の直前に人間と最終確認 |
| 後続フェーズ（書き戻しの `ai-asset-design`）の要否 | フィードバック計画 |
| 実行者を既定のサブエージェントに戻す時期 | #10（3/3）の全体計画 |

## #10（3/3）への申し送り

**全体まとめ（`10-task-overall-summary`）の段取りに入れる**: 完了処理の issue コメント（承認⑥）で #10 に引き継ぐ内容として、次を本文案に含める。ここに書かれていない限り引き継がれないので、まとめの前にこの表を読み直す。

| # | 引き継ぐ内容 | 引き継ぎ先での扱い |
|---|---|---|
| 1 | **`boundary.sh` 依存で実施できないテスト観点 8 件**: `SE-T01` / `SE-T02` / `SE-T03` / `SE-T04` / `SE-T07` / `SE-T08` / `SE-T09` / `WE-T10`。加えて `SE-T05` / `SE-T06` の**前半**（後半はこの issue で実施済み） | `boundary.sh` の実装と同じ issue でテストを書く。仕様（`session-start.md` / `workflow-entry.md` のテスト観点表）は書き終わっており、実施だけが残る |
| 2 | **`push.sh` の項目 2 の 1 枚目依存**（`push.sh:92-100`）。作業中チケットが 2 枚以上のとき、1 枚目の `allow.ops` に `remote-write:push` があれば push を通す。影響がリモートに及ぶ唯一の非対称（DDR `i0009-18`・`i0009-40`） | 提供コマンドの実体を直す（枚数を見て 2 枚以上なら止める、または全枚の宣言を見る）。この issue では提供コマンドの実体を触らない |
| 3 | **`finalize.sh` 不在によるフェーズ 7 の詰み**（上記「②を登録したままフェーズ 7 に入ると」）と `boundary.sh` 不在によるレビュー依頼の直接投稿 | 3/3 で提供コマンドが揃えば解消する既知の逸脱 |
| 4 | **実行者を既定のサブエージェントに戻す時期**（※1） | #10 の全体計画で決める |
| 5 | 公式の仕様に無いイベント（`PostToolUseFailure` の常用・`PermissionRequest`）と空ディレクトリ 3 つの扱い | 3/3 または別 issue |

## 合意の記録

| 承認 | 内容 | 誰が | いつ |
|---|---|---|---|
| ① | 次に着手する issue として #9（実装 2/3）を選ぶ | ユーザー（AskUserQuestion） | 2026-09-02 |
| ② | issue 本文は追記なしで進む。ブランチ `feature-9-hook-bodies-settings`・MR タイトル `feat: 自己改善ワークフロー機構の実装 2/3: フック本体 11 本と settings.json 登録・TBD T1〜T4 の検証 (#9)` | ユーザー（AskUserQuestion） | 2026-09-02 |
| ③ | フェーズ列（テンプレートどおり）・実行者（全種類メインエージェント）・レビュー要否（基準どおり）・やってよいこと・`settings.json` の 2 段階登録（案内側 → 拒否側） | ユーザー（AskUserQuestion） | 2026-09-02 |
| ④（以降の切れ目） | 人間レビューの代わりに opus サブエージェントによる敵対的自己レビューで切れ目を通過し、全体まとめの draft 解除まで進める。マージは人間 | ユーザー（AskUserQuestion） | 2026-09-02 |
| ③の修正 2（チケット 0004） | 確認レビューの指摘 N1〜N11 を反映: フェーズ 7 の推奨を第 2 案（`WORKFLOW_STATE_GUARD_ENFORCE=0`）へ差し替え / 段階登録を ①・②-1・②-2 の 3 段に / `blocked-commands.txt` の新規作成を追加 / `agent_type` の実測を追加 / 書き戻しの置き場を制約の書き方に / `feedback-plan` の `issue-create` と `build-test` の削除 | AI（レビュー指摘の反映）。ユーザーへの報告で追認を求める | 2026-09-02 |
| ③の修正（チケット 0003） | 敵対的レビューの指摘 R1〜R8 を反映: 実測を調査フェーズから実装フェーズ 4d へ移す / T6・T8 を追加 / 段階登録を 16 行に割り当て直す / 切り戻しを 2 種類に分ける / 登録後の `settings.json` のコミット経路 / 全体まとめが通らない経路と 3 案 / 方針表の差分の書き方 | AI（レビュー指摘の反映）。ユーザーへの報告で追認を求める | 2026-09-02 |
