---
type: ddr
title: i0009-51. PostToolUse Agent は status で分岐し、async のときは作業後の検査をしない
description: background 起動では PostToolUse Agent が作業前に発火するため WF811〜813 を出さず WF814 で検査が届かないことだけを伝えると決めた判断
tags: [ddr, hooks, subagent-stop-check, PostToolUse]
keywords: [status, async_launched, completed, WF811, WF812, WF813, WF814, tool_response, i0009-50]
---

# i0009-51. PostToolUse `Agent` は `status` で分岐し、async のときは作業後の検査をしない

## 背景

`i0009-50` で「サブエージェントは既定で background で走り、PostToolUse `Agent` は起動直後に発火する」ことが確定した。`subagent-stop-check` は PostToolUse `Agent` で WF811（作業中のまま残ったチケット）/ WF812（未コミット差分）/ WF813（範囲外の差分）を伝える設計だが、起動直後に検査すると**作業前の作業領域**を見ることになる。

- 作業前なので、サブエージェントが起こした問題は 1 つも検知できない
- しかも「該当なし」を返すため、**問題が無かったと誤って伝わる**

`tool_response` には `status` があり、`"completed"`（foreground で走り終わった）と `"async_launched"`（background へ移った）を区別できる。

## 決定

`subagent-stop-check` の PostToolUse `Agent` の経路を `tool_response.status` で分岐する。

| `status` | 振る舞い |
|---|---|
| `completed` | 従来どおり。直近の記録（`tool_response.agentId` に対応するもの）を読み、無ければその場で検査して WF811〜813 を伝える |
| `async_launched` | **作業後の検査を行わない**（WF811〜813 を出さない）。代わりに **WF814** で「background 起動なので完了後の検査は届かない。`run_in_background: false` で起動し直すか、完了を確かめてから自分で作業領域を確認すること」を伝える |

WF801 の縮退判定（`i0009-52`）は**起動の事実**に関するものなので、`status` を問わず行う。

## 理由

- **「該当なし」を返さないことが要点**。検査できない状況で「問題なし」と伝えるのは、何も伝えないより悪い。WF814 は「検査していない」という事実を伝える
- **分岐の材料が入力に揃っている**。`status` は同じ `tool_response` にあり、追加の読み取りも fork も要らない
- **foreground の経路を残す価値がある**。`00-workflow-issue-mr-driven` がタスクの実施者を `run_in_background: false` で起動すれば `completed` になり、設計どおりの検査が働く。WF803（`i0009-50`）がそれを促す
- **SubagentStop 側の記録は残る**。background でも SubagentStop は発火して `logs/sessions/<session_id>/subagent-<agent_id>.json` に検査結果が残るので、後から人間や次のセッションが読める。届かないのは「その場でメインエージェントに」だけ

## 却下した案

- **`status` を見ずに常に検査する**: background では作業前を見て「該当なし」を返す。誤った安心を与える
- **`async_launched` のときは何も出さない**: 検査していないことが誰にも伝わらない。`subagent-stop-check` は案内側なので、伝えるコストは additionalContext 数行で足りる
- **`async_launched` のときに次のツール呼び出しまで検査を遅らせる**: フックは状態を持たないプロセスで、遅延の管理（いつ・どのイベントで実行するか）を新たに作ることになる。`Stop` に寄せる案も、サブエージェントがまだ走っている保証が無い
- **WF811〜813 の識別子を再利用して「検査していない」を表す**: 識別子は 1 つの意味に対応させる（§6 の台帳の原則）。新しい事実には新しい番号を割る

## 影響

- `10_spec/hooks/13-SubagentStop/subagent-stop-check.md` 呼出条件（`status` の分岐）・エラー識別子（WF814）・`SP-T07`
- `10_spec/フック共通仕様.md` §6（WF811–819 に 814 を追加）
- **実装フェーズへ**: `status` が想定外の値のときは `completed` 側に倒さない（検査しない側＝安全側）
- 関連: `i0009-50`（background 既定）・`i0009-52`（WF801 の縮退判定）
