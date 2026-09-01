---
type: report
title: 0015 付録 A — 設計ワーク（0012〜0015）のワーク境界レビュー 1 巡目の指摘
description: 承認④（人間レビューを opus の敵対的自己レビューで代替）に基づき、設計ワークの境界で 2 名のレビュアーが出した指摘 R1〜R26 / S1〜S12 の記録。確信度 0.5 以上のものを追加チケット 0019〜0022 に割り付けた
tags: [report, ai-asset-design, issue-9, review]
keywords: [敵対的レビュー, ワーク境界, 並列実行, additionalContext, push.sh, curl, WF204, scope.sh, DDR]
---

# 0015 付録 A — 設計ワーク（0012〜0015）のワーク境界レビュー 1 巡目の指摘

対象: チケット 0012・0013・0014・0015 の成果物（仕様・要件・DDR i0009-01〜19・結果報告）。
レビュアー: opus 2 名（担当 R = 仕様の内部整合と実装可能性 / 担当 S = 根拠の妥当性と受け入れ条件）。
確信度 0.5 未満の指摘は無かった（R21 と S12 が最小で 0.5・0.55）。

## メインエージェントによる検証

レビュアーの指摘を鵜呑みにせず、影響の大きい 4 件を原本・実体で確かめた。**4 件とも実在する問題**だった。

| # | 主張 | 検証 | 結果 |
|---|---|---|---|
| R1 | フックは並列実行される | `wip/tmp/hooks.md:414`「All matching hooks run in parallel. If you define the same handler in more than one settings file, it runs once.」 | **確認** |
| S1 | PreToolUse の `additionalContext` は「ツール結果の隣」に届く | `wip/tmp/hooks.md:988`「PreToolUse, PostToolUse, PostToolUseFailure, and PostToolBatch: **next to the tool result**」／`:972`「Claude reads the reminder on the next model request」 | **確認**（`Agent` ツールの結果 = サブエージェント完了後に届く） |
| S2 | `push.sh` が 1 枚目のチケットの宣言で push を承認する | `.claude/skills/20-common-step-commit-push/scripts/push.sh:98` `ticket="${doing[0]}"` → `:99` `fm_list "$ticket" allow.ops` → `:100` `grep -qx -- "remote-write:push"` | **確認** |
| S3 | `curl` は既定拒否（WF204）で「抜け道」ではない | `.claude/hooks/lib/scope.sh:29` `_SC_READ_ONLY_CMDS` に `curl` / `wget` **無し**。`workflow-guard.md:55`「上記のいずれにも該当しない → deny WF204（既定拒否）」で制御方式 6 に `web` の分岐が無い | **確認** |

あわせて `wip/tmp/hooks.md:3713`「Use absolute paths: specify full paths for scripts. In exec form, use `${CLAUDE_PROJECT_DIR}`…」（R10 の根拠）と、`:416`「Handlers run in the current directory with Claude Code's environment.（cwd が消えていたら起動ディレクトリ → プロジェクトルート → ホーム → temp の順にフォールバック）」も確認した。フォールバックがあるので R10 は「cwd がルート以外の**存在するディレクトリ**」のときだけ起きる。

## 指摘一覧（担当 R: 仕様の内部整合と実装可能性）

| # | 確信 | 重大 | 要旨 | 主な根拠 | 割り付け |
|---|---|---|---|---|---|
| R1 | 0.95 | 高 | フックは並列実行されるので §1:26 の「実行順」・§1:49 の「先に拒否したフックが理由を返す」「安価→高価」・HK-T01 の「順序」照合・各フック仕様の「〜の後、〜の前」が成立しない | `hooks.md:414` | 0019 |
| R2 | 0.85 | 高 | compact-prompt が `push-state.json[b].sha = head` を書く（`post-push-compact-prompt.md:60`）ため、同じ `push-detect` を共有する usage-report の検知条件（`sha != HEAD`）が偽になり発火しない／レースになる | 仕様 2 本 + HK-T13 | 0019 |
| R3 | 0.95 | 中 | §11 HK-T13 が `tool_response` の終了コードを 3 か所で要求。§12 T7・DDR i0009-07 と矛盾（0014 の掃き残し） | `フック共通仕様.md:256` vs `:273` | 0021 |
| R4 | 0.8 | 高 | `mcp__.*` が state-guard の matcher にしかなく、MCP 経由のリモート書き込みが WF101・WF206 を素通りする。要件 `workflow-guard.md:59` を満たさない | 登録表 3 行目 vs 2・6 行目 | 0020 |
| R5 | 0.7 | 高 | state-guard は MCP ツールに対し制御方式 2・3 のどちらにも当たらず 4（入力不正）に落ち、draft 解除以外の全 MCP 呼び出しが WF309 で拒否される（過剰拒否） | `workflow-state-guard.md:26,36-48` | 0020 |
| R6 | 0.85 | 高 | §8 に `scope.sh` の「出力の形」が無い。§8:204 の「戻り値 0/1/2」と HK-T15 の「段階番号が返る」が両立しない。3 フックが共有する面が未定義（§7-9 の `cmdpos.sh` は定義済みなので型として使える） | §8 vs §11 vs `lib/scope.sh:25,154` | 0021 |
| R7 | 0.75 | 中 | 戻り値 0/1/2 を全関数に課すと `scope_match`（`lib/scope.sh:138-143`）・`scope_op_declared`（`:195-201`）の真偽と衝突する | 参考実装 | 0021 |
| R8 | 0.75 | 中 | `set -euo pipefail` 下で `fm_*` の戻り値 1/2 を伝播させる呼び出し規約が無い。参考実装 `lib/scope.sh:101-104` は現に `\|\| true` で潰しており、`local v=$(…)` でも戻り値が消える | 参考実装 | 0021 |
| R9 | 0.8 | 中 | 読み込み行が 22 ファイルに逐語コピーされ `FM_AVAILABLE` は 0 件。0015 の申し送りは雛形の更新しか触れず、コピー間の一致を検査するテストも無い（`test_templates.sh:89` は雛形だけ） | `grep -rl __ss_load` | 0021 |
| R10 | 0.6 | 高 | 登録が `bash .claude/hooks/...` の相対パス。cwd がルート以外だと 127 で落ち、拒否側 5 本のラッパーが全操作を deny してロックアウトする | `hooks.md:3713`・§1:24,50 | 0019 |
| R11 | 0.85 | 中 | §2:67 の「`git rev-parse --show-toplevel` を基準にする」が、読み込み行の fork なし解決（`20-common-step-shell-script.md:107`「95 ms/回」）・ホットパス 1 秒・参考実装 `hook-common.sh:18` と矛盾 | 3 文書 | 0019 |
| R12 | 0.7 | 中 | 登録コマンドの雛形が `--accumulate` 引数と「実体のディレクトリ ≠ 登録イベント」（4 行該当）を表現できず、HK-T01 の行単位照合が書けない | §1:24 vs :38,42,45,46 | 0019 |
| R13 | 0.7 | 高 | `scope-limits.json` 破損時の state-guard の振る舞いが未定義。拒否側の原則どおり倒すと workflow-guard の WF210 の復旧経路が state-guard の deny で潰れる（設定 1 ファイルの破損が完全なロックアウト） | `workflow-guard.md:42` vs state-guard 制御方式 | 0020 |
| R14 | 0.75 | 中 | SubagentStop の蓄積が `transcript_path`（= メインの transcript）を読む記述。`agent_transcript_path` を使わないとメイン分が `subagents[]` に二重計上される | `hooks.md:2325`・`post-push-usage-report.md:31,39` | 0021 |
| R15 | 0.8 | 中 | §1:23 と §12 T8 が「`fm_*` が空を返すスタブ」のままで、0015 の「出力なし・戻り値 2・`FM_AVAILABLE=0`」が横断仕様（前提文書）に反映されていない | §1 vs §8 | 0021 |
| R16 | 0.85 | 低 | §1:20 が `scope.sh` の観点から HK-T16 を落とし、§1:18 が HK-T03・T04（フック横断の結合観点）を `hook-common.sh` の lib 単体観点に割り当てている | §1 vs §11 | 0022 |
| R17 | 0.8 | 低 | `BG-T09b` が `BG-T09`（無関係）の枝番に見え、表の並びが T08→T09b→T10→T09 と乱れている。正規表現には適合するので機械検出されない | `block-direct-git.md:82-85` | 0022 |
| R18 | 0.95 | 低 | `workflow-entry.md:29` に「`assets/entry-skills.txt` のパス…は 0014 で確定するまで暫定」が残存。同じ行の前半は確定形で自己矛盾 | 現 HEAD | 0022 |
| R19 | 0.8 | 低 | `workflow-guard.md:27` の「最後に実行」が、17 行化で 7 行目に入った `subagent-start-check` と食い違う | §1:37-38 | 0019 |
| R20 | 0.65 | 中 | WF801 の再掲に条件が無く（SP-T05 が無条件を固定）、通常経路で同じ不一致が 2 回通知される。「縮退のときだけ唯一の経路」という説明と食い違う | `subagent-stop-check.md:15,17,74` | 0020 |
| R21 | 0.5 | 低 | `subagent-start-check` が `subagent_type` を読みながら判定に使わず、`adversarial-reviewer` 等を別モデルで起動すると WF801 が誤発報し得る | `subagent-start-check.md:32,40,43` | 0020 |
| R22 | 0.6 | 中 | 並列実行下で `decisions.jsonl`・`approvals.json`・`usage/<branch>.json` に同時書き込みが起きるが、原子性・排他の規則が §5 に無い（usage は read-modify-write で集計が消える） | `hooks.md:414,2088`・§5 | 0019 |
| R23 | 0.55 | 中 | `rm wip/10_tickets/20_done/*.md` がどのフックにも塞がれない（state-guard は「宛先」判定で `rm` を持たず、切れ目では workflow-guard が働かない） | `workflow-state-guard.md:40,45`・§13 | 0020 |
| R24 | 0.9 | 低 | `session-start.md:85-86` にヘッダだけの空テーブルが残り、直後の段落が表の続きに見える | 現 HEAD | 0022 |
| R25 | 0.8 | 低 | §12 T1 は取得済みの原本（`hooks.md:2346` / `:2374`）が既に答えており、T7・T8 と同じ根拠で閉じられる | 原本 | 0022 |
| R26 | 0.6 | 低 | BG-T10 が `commit-tree`（拒否対象）と `stash`（明示的に対象外）を踏んでいない。HK-T05 に課した「語彙表の全要素踏破」と不揃い | `block-direct-git.md:40,84`・DDR i0004-07 | 0022 |

### R の観点で「問題なし」だったもの

- **WF 番号の整合**: §6 台帳の 12 帯と各フック仕様のエラー識別子表・回復手順・テスト観点を突き合わせて、欠番・重複・持ち主の食い違いは無し。`x09` を持つのが拒否側 5 本（WF109 / 209 / 309 / 409 / 509）だけという規則も守られている
- **登録表 17 行とフック仕様の呼出条件**: イベント・matcher の行単位では 17 行すべて一致（内訳・拒否側 5 行も一致）
- **テスト ID**: フック側 109 件・重複 0 件・正規表現への非適合 0 件（0015 f3 の主張と一致）。§11 の HK-T01〜T16 の並びに乱れなし
- **`subagent-start-check` の 2 イベント登録**: 「対象チケットを決める」処理は 2 回走るが、イベント名で分けているので判定の二重実行に害は無い（害は R20・R21 の側）

## 指摘一覧（担当 S: 根拠の妥当性と受け入れ条件）

| # | 確信 | 重大 | 要旨 | 主な根拠 | 割り付け |
|---|---|---|---|---|---|
| S1 | 0.7 | 高 | PreToolUse の `additionalContext` は「next to the tool result」に届くので、WF801 を PreToolUse `Agent` に移しても**起動前には伝わらない**。要件「動き出す前に伝える」は達成できず、17 行目の登録は代償に見合わない。`systemMessage`（`hooks.md:926`）や `ask` は却下案に挙がっていない | `hooks.md:988,972,1747`・要件 `subagent-start-check.md:44`・DDR i0009-06 | 0020 |
| S2 | 0.85 | 高 | `push.sh:92-100` が 1 枚目のチケットで push を承認する。i0009-18 の「リモート操作には及ばない」は偽で、G8 の閉じ方（#10 への申し送り不要）が成立しない | 実体 | 0022 |
| S3 | 0.75 | 中〜高 | `curl` は WF204 で既定拒否。i0009-12 の「抜け道が残る」も §8 の「`web` を宣言したときだけ通る」も要件 `:176` も事実と食い違う。しかも**記録が残る `curl` は塞がれ、記録が残らない `WebFetch` は素通り**という倒錯 | `lib/scope.sh:29`・`workflow-guard.md:55` | 0022 |
| S4 | 0.65 | 中 | 打ち切りの fail-open に対し `permissions.deny`（`hooks.md:1744`「still evaluated regardless of what the hook returns」）と事後ゲート（PostToolBatch、`hooks.md:867`）を検討せず「塞げない」を正史に断定。要件 `:174`（権限設定の併用を認める）と矛盾 | 原本・要件 | 0022 |
| S5 | 0.7 | 中 | 受け入れ条件 5 は「**実物の確認に基づいて**」を要求。`tool_response` は文書確認だけで §12 T7 を打ち消したため、4c で実物を見る動機が消え、全体計画 `overall-plan.md:146` と食い違う | issue #9・§12 | 0022 |
| S6 | 0.7 | 中 | `hooks.md:2374` が T1 の答え（親へ入れたいなら `Agent` の PostToolUse を使え）を明記しているのに実測待ちのまま。条件 3 の充足度が理由なく下がっている | 原本 | 0022 |
| S7 | 0.6 | 中 | §12 T6 の引用が `hooks.md:824-825`（`#### Other exit codes` 節）からの転用で、終了 0 の経路を支えていない。正しくは `:774`「reads JSON output fields from stdout on every exit code」・`:778` | 原本 | 0022 |
| S8 | 0.65 | 中 | 「自動実行の仕組みを外部のサービスに置かない」（要件 `:204`）はスコープ由来の一時的判断の恒久化で、DDR i0009-19 の「必要になったら別 issue で扱う」と矛盾 | 要件・DDR | 0022 |
| S9 | 0.85 | 低〜中 | 0014 が「偽」と名指しした可用性の行（要件 `:202`）を実際には直していない（例外フローに但し書きを足しただけ）。報告と成果物が食い違う | `git diff` | 0022 |
| S10 | 0.9 | 低〜中 | `workflow-entry.md:29` に旧パス `assets/entry-skills.txt` と「暫定」が残存（R18 と同一） | 現 HEAD | 0022 |
| S11 | 0.6 | 低 | メインフロー D の追記は主語が機構でなく検証手段が無い。自制統制の明記規約（要件 `:176`）にも従っていない | 要件 | 0022 |
| S12 | 0.55 | 低〜中 | 3/3 送り 8 件が issue #10 にも全体計画の保留表にも無く、0015 の「#10 への申し送りは無し」が無条件に書かれていて覆い隠す | `gh issue view 10`（comments: 0） | 0022 |

### S の観点で「問題なし」だったもの

- **公式引用の正確性**: 依頼で指定した 9 件の引用はすべて原本に実在し、行番号もほぼ一致（`model` は L743 / 打ち切りは L845 / 既定秒数は L428・L1302 / `defer` は L1783 / PostToolUse は L1930 / `Bash` の形は L1990 / `PostToolUseFailure` は L2065 / `additionalContext` は L1747 / deny は L1744）。**捏造は無い**。問題は文脈の取り扱い（S1・S7）だけ
- **受け入れ条件の充足**: 各報告は「このチケットが満たす分」という部分充足の書き方で、条件 1 の読み替えも f4 として明示レビュー依頼に上げている。0015 f3 の機械的確認はレビュアーが再現し、非適合 0 件を確認した（`SS-X01` と `ss-h01` は TR-T06 の負のコントロールとして意図的な文字列）
- **i0009-13（`defer` の不採用）**: 原文（`:1783`・`:1811`「only works when Claude makes a single tool call in the turn」・`:1809`「no timeout or retry limit」）に照らして妥当。却下理由に見落としなし
- **要件への内部構造の漏れ**: 今回足した 4 か所（`:92`・`:152`・`:176`・`:204`）にスクリプト名・判定順・スキーマ・秒数・matcher・`WebFetch` は含まれていない
- **3/3 送りの判断**: `boundary.sh` 依存 8 件を送る判断は健全。特に SE-T09 / WE-T10 の「本物が無ければ空同士の比較で無意味に通る」は、偽実装で条件を満たしたことにする誘惑を避けている
- **0012 f4 が挙げた現物**（`run-tests.sh:86`・`push.sh:95-98`・`ticket.sh:208`・`:334`）はすべて実体と一致

## 追加チケットへの割り付け

| チケット | 主題 | 指摘 |
|---|---|---|
| 0019 | 並列実行の前提と登録の書き方 | R1・R2・R10・R11・R12・R19・R22 |
| 0020 | 制御方式の穴（MCP・削除・設定破損・WF801 の到達） | R4・R5・R13・R20・R21・R23・**S1** |
| 0021 | ライブラリのインターフェースと呼び出し規約 | R3・R6・R7・R8・R9・R14・R15 |
| 0022 | 根拠の是正と掃き残し | S2〜S12・R16・R17・R18・R24・R25・R26 |

先行関係は 0019 → 0020 → 0021 → 0022 の直列にした（同じ文書の同じ節に複数チケットが触るため）。0016（実装計画）の先行に 4 枚を追加する。

## 最優先

1. **S1**（WF801 の到達タイミング）: 17 行目の登録を維持するか案 (a)（16 行）に戻すかの選択で、§1・HK-T01・段階登録・受け入れ条件 2 が連動する。**0016 の実装計画に入る前に決着させる**
2. **S2**（push の誤承認）: 実体 3 行の修正か DDR の書き換えで閉じる
3. **R1**（並列実行）: 順序を前提にした記述が 6 文書に及ぶ
