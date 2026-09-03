---
type: report
title: 0013 AI アセット設計結果 — 案内側フック 5 本の判定の決定
description: subagent-start-check・subagent-stop-check・post-push-compact-prompt・post-push-usage-report・session-start について、WF801 の判定経路を PreToolUse Agent に移し、post-push の成功判定から終了コード読みを外し、session-start のテスト ID を SE-T に変えて boundary.sh 依存の観点を 3/3 に送った設計結果
tags: [report, ai-asset-design, issue-9]
keywords: [WF801, PreToolUse, Agent, model, tool_response, PostToolUse, SE-T, boundary.sh, 登録表 17 行, DDR]
---

# 0013 AI アセット設計結果 — 案内側フック 5 本の判定の決定

## サマリ

案内側フック 5 本について、0008 の設計計画が割り付けた**決定 5・6・7・8**を仕様に落とした。更新した文書は要件 1 本・仕様 5 本、新規の DDR は 4 件（`i0009-06`〜`09`）。横断文書は**更新不要**（0012 と同じ理由）。

最も影響が大きいのは **WF801 の判定経路**で、`SubagentStart` に `model` が来ない以上、比較の材料が取れるのは `Agent` ツールの `tool_input.model` だけ。**PreToolUse、matcher `Agent`** を本線にし、`subagent-start-check` を 2 か所（SubagentStart = 要点の注入、PreToolUse = 不一致の通知）に登録する。これで **フック共通仕様 §1 の登録表は 16 行 → 17 行**になり、HK-T01 と段階登録の割り当てが連動する（確定は 0014、組み直しは 0016）。

`post-push-*` の成功判定は「PostToolUse に届いた = 成功」に変え、`tool_response` の終了コード読み（4 候補）を削除した。`session-start` のテスト ID は `SS-H` → **`SE-T`** に変え、9 本のうち **7 本と 2 本の前半を 3/3 に送り**、この issue で実施するのは SE-T05 と SE-T06 の後半だけとした。

- ◎良 2 件 / △注意 2 件 / ✕問題 0 件

### ◆特に見てほしい（判断に困っている）

- **f1**: WF801 を PreToolUse `Agent` に移すと **§1 の登録表が 17 行になる**。0008 の計画は案 (c) を本線と見込んでいたのでそのとおりにしたが、代償（HK-T01・段階登録の割り当て・受け入れ条件 2 の連動）を払う価値があるかを見てほしい。代案 (a)（事後通知に一本化）なら 16 行のまま
- **f4**: `session-start` の 9 本のうち**この issue で実施するのは 2 本の半分だけ**になる。受け入れ条件 1 の解釈（依存先が未実装のテストは対象外）を 0012 から引き継いだが、9 本中 7.5 本が 3/3 送りという結果の重さを見てほしい

### ◇承認が欲しい（方針は決めた）

- **f2**: `post-push-*` の成功判定を「PostToolUse に届いた = 成功」に。`PostToolUseFailure` は登録しない（失敗時に出す案内が無いため）
- **f3**: テスト ID の接頭辞を `SE-T` に。`run-tests.sh` の正規表現は変えない

### ・細かいレビューは不要（ほぼ確実）

- **f5**: 横断文書と用語辞書は更新不要（0012 と同じ根拠）

## 確かめられなかったこと（この結果が言っていないこと）

- **PreToolUse の `additionalContext` が実機で AI に届くか**（公式は「String added to Claude's context alongside the tool result」と明記しているが、実測はフェーズ 4c）。届かない場合の縮退（事後通知に戻す）を仕様に書いた
- `SubagentStart` の実物に本当に `model` が無いか（実測はフェーズ 4c。設計判断は公式の記述で決めた）
- §1 の登録表を 17 行にしたときの段階登録の割り当て（**0016 の担当**）
- `assets/model-aliases.txt` の基準ディレクトリ（**0014 の担当**。暫定として書いた）
- `PostToolUseFailure` を将来使うかどうか（3/3 の検討事項）

## 実施条件（読んだ対象）

- 更新対象: `00_requirement/hooks/12-SubagentStart/subagent-start-check.md`、`10_spec/hooks/12-SubagentStart/subagent-start-check.md`・`13-SubagentStop/subagent-stop-check.md`・`22-PostToolUse/post-push-compact-prompt.md`・`post-push-usage-report.md`・`00-SessionStart/session-start.md`
- 入力: `wip/20_plans/0008-ai-asset-design-plan.md`、`wip/30_reports/0005〜0007-investigation.md`、`wip/30_reports/0012-ai-asset-design.md`（WE-T10 の判断）
- 公式の原文: 0007 が `curl` で落とした `hooks.md` の該当行（L743 / L1747 / L1930 / L1990 / L2066）
- 実行はしていない（テストは実装フェーズ）

## 実施した内容と結果

### f1. WF801 は PreToolUse `Agent` で起動前に判定する（§1 が 17 行になる）△注意

根拠: 公式 `hooks.md` L743（`model` は SessionStart のみ）・L1747（PreToolUse の `additionalContext`）、0007 f2

- `subagent-start-check` の呼出条件を 2 行にした: **SubagentStart**（要点の注入 WF802）と **PreToolUse、matcher `Agent`**（不一致の通知 WF801）。同じスクリプトを 2 か所に登録し、`hook_event_name` で処理を分ける（`workflow-entry` が 3 か所に登録されている前例と同じ形）
- 入出力を「SubagentStart では `agent_id`・`agent_type`（`model` は来ない）／PreToolUse `Agent` では `tool_input.model`・`tool_input.subagent_type`」に書き直した
- 制御方式 4 を「PreToolUse `Agent` のときだけ不一致を判定する」に変え、**起動は止めない**（`permissionDecision` を出さない）ことを明記した
- **どの経路でも共通の限界**を書いた: `Agent` の `model` は任意引数で、省略時はエージェント定義のモデルが使われる。省略された起動では `tool_input.model` が空になり比較そのものができない
- 縮退を 2 つに分けた: (1) PreToolUse で `additionalContext` が届かない版 → 事後通知（`subagent-stop-check`）だけにする（§1 は 16 行に戻る）、(2) SubagentStart が使えない版 → 要点の注入を起動プロンプトに委ね、不一致の検知は残る
- 要件に 2 つ足した（「サブエージェントが動き出す前に伝えなければならない」「起動時にモデルを明示しない場合は特定できない」）
- `subagent-stop-check` の概要に「WF801 の再掲は**事後の保険**であり本線ではない」と書いた
- 経緯: DDR `i0009-06`

結論: **§1 の登録表が 16 行 → 17 行**になる。0014 が §1・§2・§3・§6 台帳・§12 T4 を確定し、0016 が段階登録の割り当て（① 記録・案内側が 1 行増える）と HK-T01 の期待値を組み直す。

### f2. `post-push-*` の成功判定は「PostToolUse に届いた = 成功」◎良

根拠: 公式 `hooks.md` L1930（PostToolUse は成功時のみ発火）・L1990（`Bash` の `tool_response` は `stdout` / `stderr` / `interrupted` / `isImage`）・L2034-2068（`PostToolUseFailure`）、0007 f4

- `post-push-compact-prompt` の入出力から `tool_response`（終了コード・出力）を削り、制御方式 2 の「終了コードが 0（4 候補を順に読む）」を「**PostToolUse に届いた時点で成功とみなす**」に置き換えた。上流が解決できないときの縮退も同じ根拠に書き換えた
- PP-T08 の記述を合わせ、種別（機械テスト）を明記した
- `post-push-usage-report` は検知を `push-detect` 経由で共有するので、要件との対応に同じ方針を注記した
- **`PostToolUseFailure` は登録しない**（`post-push-*` は成功時の案内が仕事で、失敗時に出す案内が無い）
- 経緯: DDR `i0009-07`

結論: 共通仕様 §12 T7 を「終了コードのフィールドは存在しない」で閉じられる（0014 の担当）。§1 の行は増えない。

### f3. テスト ID の接頭辞を `SS-H` から `SE-T` に変える ◎良

根拠: `run-tests.sh:110` の `^(PASS|FAIL) ([A-Z]{2,6}-[TE][0-9]{2}[a-z]?)`、0005 f3

- `session-start` のテスト ID を `SE-T01`〜`SE-T09` に変え、テスト観点の表の前に理由（3 文字目以降が `T` か `E` に限られる・`SS-T` は既存テストが使用中）を書いた
- 「要件との対応」の 2 か所（`SS-H08` / `SS-H09`）も新しい ID に直した
- `run-tests.sh` 側の正規表現は変えない（`20-common-step-shell-script` の仕様。0015 が制約を明記する）
- 経緯: DDR `i0009-08`

結論: 受け入れ条件 2（`--ids` の全件）を満たせる形になった。`SE` は既存・新規のどの接頭辞とも衝突しない。

### f4. `boundary.sh` 依存の 7 本と 2 本の前半を 3/3 に送る △注意

根拠: 0005 f5、`session-start` 仕様 制御方式 3、0012 の DDR `i0009-04`

- テスト観点の表に「この issue で実施するか」の列を足し、行ごとに理由を書いた
- **3/3 へ送る**: SE-T01〜04・T07・T08・T09 と SE-T05 の前半・SE-T06 の前半
- **この issue で実施する**: SE-T05 の後半（`jq` 不在で無出力・終了 0）と SE-T06 の後半（サブエージェントの開始では無出力）の 2 つだけ
- SE-T09 は `boundary.sh` が無いと両方とも無出力になり**空同士の比較で無意味に通る**ため、通しても保証が無いとして送った
- 経緯: DDR `i0009-09`

結論: `session-start` は 9 本中 7.5 本が 3/3 送りになる。0012 の WE-T10 と合わせて、**この issue で通せないのは 8 本 + 2 本の前半**。受け入れ条件 1 の「テストが通る」は「この issue で実装するフックのテスト」と解釈する。

### f5. 横断文書と用語辞書は更新不要だった ◎良

根拠: `自己改善ワークフロー機構.md`・`rules/ルール体系.md`・`90_glossary/ワークフロー用語.md`

- 0012 と同じ結論。今回の決定もフック単位の判定とテストの話で、機構全体の方針（`web` の強制・`ops` 上限・CI）に触れない
- 用語辞書はワークフローの概念 20 語のみで、`WF801` や `PostToolUseFailure` のような実装の用語を収録していない
- 実測への依存: 無し

結論: 更新不要。0014 が §1・§2・§3・§6・§12 を触るときに、横断文書は 0014・0015 の担当と考えてよい。

## 検証の結果

| 検証 | 結果 |
|---|---|
| 更新した要件定義書 | 1 本（`subagent-start-check`） |
| 更新した仕様書 | 5 本（`subagent-start-check`・`subagent-stop-check`・`post-push-compact-prompt`・`post-push-usage-report`・`session-start`） |
| 新規の DDR | 4 件（`i0009-06`〜`i0009-09`。割り当て帯 06〜10 の範囲内。0012 の帯の未使用分 `i0009-05` は空けたまま） |
| 更新した横断文書 | 0 件（対象なし。f5） |
| 1:1:1 の維持 | 維持（アセット 5 : 要件 5 : 仕様 5。今回更新したのは要件 1 / 仕様 5） |
| 要件に内部構造が漏れていないか | 漏れなし（イベント名・`tool_input.model`・登録表の行数は仕様のみ。要件は「動き出す前に伝える」「モデルを特定できない場合は通知しない」で書いた） |
| テスト観点の機械 / eval の区別 | 追加・変更した観点（SA-T01/T02/T04・PP-T08・SE-T01〜09）はいずれも**機械テスト**。eval は追加していない |
| ヘッドレス実行の帰結 | 5 本とも記載（案内側は判定できなければ無出力・終了 0。WF801 は通知で起動を止めない） |
| §1 の登録表への影響 | **16 行 → 17 行**（PreToolUse `Agent` の 1 行が増える）。確定は 0014 |

## 受け入れ条件との対応

| # | 受け入れ条件（issue #9） | このチケットが満たす分 | テスト ID（種別） |
|---|---|---|---|
| 1 | フック本体 11 本が仕様どおり動きテストが通る | 5 本の判定順・識別子・テスト観点を確定した。`session-start` は 9 本中 7.5 本を 3/3 に送る | SA-T01〜06（機械）・SP-T01〜06（機械）・PP-T01〜08（機械）・UR-T01〜07（機械）・SE-T05 後半 / T06 後半（機械） |
| 5 | `tool_response` / `agent_type` / `web` の強制 / `defer` の扱いが実物の確認に基づいて仕様に書かれている | **`tool_response`**（終了コードのフィールドは無い → 読まない）と **`agent_type`**（SubagentStop の必須フィールド。`subagent-stop-check` が読む）を仕様に落とした。`web` と `defer` は 0014 | PP-T08（機械）・SP-T05（機械） |
| 6 | 決定の経緯が DDR に残っている | `i0009-06`〜`09` | — |

## 設計への反映（後続へ）

1. **0014 へ（最重要）**: §1 の登録表を **17 行**にする（`subagent-start-check` の PreToolUse `Agent` の行）。あわせて §2（`model` は SessionStart のみ）・§3（PreToolUse で `additionalContext` を返せる通知経路）・§6 台帳の WF801 の持ち主・§12 T4 を書き換える
2. **0014 へ**: §12 T7 を「`tool_response` に終了コードのフィールドは存在しない」で閉じる。§1 に `PostToolUseFailure` は足さない
3. **0014 へ**: `assets/model-aliases.txt` の基準ディレクトリを確定し、`subagent-start-check` 仕様のパスに反映する（今は暫定）
4. **0015 へ**: `run-tests.sh` の ID 抽出の制約（`[A-Z]{2,6}-[TE][0-9]{2}[a-z]?`）を `20-common-step-shell-script` 仕様に明記する
5. **0016 へ**: 段階登録の割り当てを組み直す（① 記録・案内側が 1 行増えて 12 行、②-1 が 1 行、②-2 が 4 行）。HK-T01 の期待値も 17 行に
6. **0016 へ**: `session-start` の実施本数は 9 本ではなく「2 本の半分」。テスト計画の本数の見積もりに反映する

## 想定と異なった点

| 計画時の見込み | 実際 | どう扱ったか |
|---|---|---|
| WF801 の案 (c) は「§3 に通知経路の行を足すだけ」で成立する | 公式で PreToolUse の `additionalContext` は確認できたが、**登録が 1 行増える**という代償が計画書の見込みより重かった（HK-T01・段階登録・受け入れ条件 2 が連動する） | f1 として採用しつつ、縮退（PreToolUse で届かない版は 16 行に戻る）を仕様に書いた。0016 への申し送りを明示した |
| `post-push-*` の変更は成功判定の 1 行だけ | 入出力の `tool_response`（終了コード・出力）の記述と、上流未解決時の縮退の根拠も同じフィールドに依存していた | f2 として 3 か所（入出力・制御方式 2・縮退）を直した |
| `session-start` は「7 本を 3/3 に送る」で済む | SE-T09（無意味に通る）と SE-T06 の前半も送る必要があり、**実施できるのは 2 本の半分だけ**になった | f4 として表に実施可否の列を足し、行ごとに理由を書いた |

## 残課題

- PreToolUse の `additionalContext` が実機で AI に届くか（フェーズ 4c で確かめる。届かなければ縮退して §1 は 16 行に戻る）
- `SubagentStart` の実物に `model` が無いことの確認（フェーズ 4c）
- `subagent-start-check` を 2 イベントに登録すると、SubagentStart と PreToolUse で「対象チケットを決める」処理が 2 回走る。重複した記録が `decisions.jsonl` に出ないかは実装時に確かめる
- `session-start` の 3/3 送りが 7.5 本に及ぶため、この issue の実装フェーズで `session-start` の振る舞いを機械的に確かめる手段がほとんど無い。実装の正しさは仕様のレビューと 4c の実測（登録後の実際の注入）に依存する
