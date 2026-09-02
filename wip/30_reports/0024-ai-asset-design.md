---
type: report
title: 0024 AI アセット設計結果 — サブエージェントは既定で background という前提の反映
description: 公式が subagents run in the background by default と定め PostToolUse Agent が起動直後に発火することを踏まえ WF801 と WF811〜813 の到達を設計し直した結果
tags: [report, ai-asset-design, issue-9, review-fix]
keywords: [background, async_launched, run_in_background, WF803, WF814, agentId, camelCase, skip, 縮退, systemMessage, T9]
---

# 0024 AI アセット設計結果 — サブエージェントは既定で background という前提の反映

## サマリ

境界レビュー 2 巡目の **B1・B15・B2・B3・B4・B5** を反映した。中心は **公式が「subagents run in the background by default」と定めており、PostToolUse `Agent` が「走り終わった後」ではなく「起動した直後」に発火する**という前提の食い違いで、`.claude/docs/` に background への言及は 1 件も無かった。更新は要件 1 本・仕様 3 本・DDR 3 本の訂正、新規の DDR は 5 件（`i0009-50`〜`54`）。

確定したのは 5 つ。

1. **サブエージェントは既定で background** という前提を §2 に据えた（`i0009-50`）。この違いは **WF801 には有利**（起動直後に届く）・**WF811〜813 には致命的**（作業前を見る）と、用途によって逆に効く
2. **PostToolUse `Agent` は `tool_response.status` で分岐**し、`async_launched` では作業後の検査をせず **WF814**（検査が届かない）だけを伝える（`i0009-51`）
3. **通知しない場合も `skip` を記録**し、`subagent-stop-check` は縮退時に**自分で判定する**（`i0009-52`）。「記録が無いときに再掲する」は論理的に成立しなかった
4. **`tool_response` のフィールドは camelCase**（`agentId` / `status`）。イベント入力側の `agent_id` と別物（`i0009-53`）
5. **`systemMessage` の実測を §12 T9 と 4c の表に登録**した（`i0009-54`）。17 行維持の唯一の支えが、検証の予定表のどこにも無かった

## レビューしてほしい観点

**◆特に見てほしい（判断に困っている）**

- **f1（✕問題）background 既定という前提が、案内側フックの設計全体に効く**。今回は `subagent-stop-check` の検査（WF811〜813）が「起動直後に作業前の作業領域を見る」ことになる、という 1 点を直したが、**「サブエージェントが終わったことをメインエージェントが知る経路」が機構に無い**という構造は残る。SubagentStop の出力は親に届かず（§12 T1）、PostToolUse は起動時に返る。foreground を促す（WF803）以外の手が無いのが正しいか
- **f2（△注意）`run_in_background` の判定を「明示的に `false` でなければ background」としたこと**。公式の `tool_input` の表に `run_in_background` は載っていない（載っているのは `prompt` / `description` / `subagent_type` / `model`）。省略時が background なので**この向きの判定は安全側**だが、公式が表に載せていないフィールドを読む形になる

**◇承認が欲しい（方針は決めた）**

- **f3**: 通知しなかった場合も `skip` を記録し、記録が 1 件も無いときだけを縮退とすること
- **f4**: `systemMessage` の実測を §12 T9 として立て、外れたら 16 行に戻すこと
- **f5**: WF803（background 起動の警告）を新設し、起動は止めないこと

**・細かいレビューは不要（ほぼ確実）**

- **f6**: `agentId` の camelCase、§6 台帳の訂正、要件への `subagent_type` の反映、`SA-T07` の並べ直し

## 確かめられなかったこと（この結果が言っていないこと）

- **`tool_input.run_in_background` が実際にフック入力に来るか**を確かめていない（公式の `tool_input` の表に無い）。来なければ「省略 = background」として扱うので WF803 は常に出る（安全側だが、うるさい可能性がある）
- **`status` が想定外の値のとき**の扱いを「検査しない側に倒す」と決めたが、実物にどんな値があるかは見ていない
- **WF803 を出しても AI が foreground で起動し直すか**は、案内側フックなので保証できない
- `systemMessage` が実際に表示されるか（T9。フェーズ 4c）
- **background のサブエージェントが SubagentStop で残す記録を、誰がいつ読むか**の経路を決めていない（記録は残るが、その場では届かない）

## 実施条件（読んだ対象）

- 公式原本: `wip/tmp/hooks.md` の `:1680-1697`（`Agent` の `tool_input`）・`:1699`（foreground に限定した記述）・`:1701`（`status` と background 既定）・`:1702`（`agentId`）・`:1711`（background は即座に返る）・`:2325`（`agent_id` / `agent_transcript_path`）・`:2346`（SubagentStop の出力は親に届かない）
- 更新対象: 要件 `00_requirement/hooks/12-SubagentStart/subagent-start-check.md`、仕様 `10_spec/フック共通仕様.md`（§1・§2・§6・§12）・`hooks/12-SubagentStart/subagent-start-check.md`・`hooks/13-SubagentStop/subagent-stop-check.md`、全体計画のフェーズ 4c
- 訂正した DDR: `i0009-26`・`i0009-31`・`i0009-32`
- 入力: `wip/30_reports/0022-ai-asset-design-appendix-A.md`（B1・B15・B2・B3・B4・B5）

## 実施した内容と結果

### 1. サブエージェントは既定で background（B1） ✕問題

公式の `Agent` の `tool_response` の表に次がある。

```
hooks.md:1699  When a foreground Agent call completes, your PostToolUse hook receives
               the subagent's final text and run telemetry in tool_response
hooks.md:1701  status | "completed" for foreground subagents, "async_launched" for
               background subagents. As of v2.1.198, subagents run in the background
               by default, so an omitted run_in_background also produces "async_launched"
hooks.md:1711  For background subagents, the tool returns when the task moves to the
               background … a background launch returns immediately
```

つまり**既定では PostToolUse `Agent` は起動した直後に発火する**。`.claude/docs/` に background への言及は 1 件も無かった。この違いは 2 つの用途で逆に効く。

| 用途 | 起動直後に発火することの意味 |
|---|---|
| **WF801**（実行者の不一致） | **有利**。`i0009-26` が「AI へは遅くとも結果と同時に」とした想定より早く届く |
| **WF811〜813**（作業後の検査） | **成立しない**。作業前の作業領域を見て「該当なし」を返し、**問題が無かったと誤って伝わる** |

**決定**: 前提を §2 に据え、`tool_input.run_in_background` が明示的に `false` でなければ background として扱う（判定は PreToolUse `Agent` で可能）。タスクの実施者を background で起動しようとしたら **WF803** で通知する（起動は止めない）。要件のメインフローにも「完了を待たない形で起動されるとき、その旨と検査が届かないことを伝える」を足した。DDR `i0009-50`。

**結論**: 前提の食い違いを塞いだ。ただし「サブエージェントが終わったことをメインエージェントが知る経路」が機構に無い構造は残る。

### 2. `status` で分岐し、async では検査しない（B1） ◎良

**決定**: `subagent-stop-check` の PostToolUse `Agent` を `tool_response.status` で分岐する。

| `status` | 振る舞い |
|---|---|
| `completed` | 従来どおり。記録を読む／その場で検査して WF811〜813 |
| `async_launched` | **検査しない**。代わりに **WF814**「background 起動なので完了後の検査は届かない。`run_in_background: false` で起動し直すか、完了を確かめてから自分で確認すること」 |

WF801 の縮退判定は**起動の事実**に関するものなので `status` を問わず行う。想定外の `status` は**検査しない側**（安全側）に倒す。DDR `i0009-51`。テスト `SP-T07`。

**結論**: 「検査できない状況で『問題なし』と伝える」を避けた。SubagentStop 側の記録は background でも残るので、後から読むことはできる。

### 3. 「記録が無いときに再掲する」は成立しない（B2） ◎良

`i0009-31` は「`decisions.jsonl` に WF801 の `notify` 記録が**無い**ときだけ再掲する」と書いていたが、**記録が無ければ再掲する元が無い**。さらに「記録が無い」は 2 つの状態を区別できない — (a) PreToolUse が使えず**判定していない**（縮退）、(b) PreToolUse が判定したが**通知不要と決めた**（一致していた等）。(b) で通知すると、不一致でないものを通知する。

**決定**: `subagent-start-check` は**通知しなかった場合も `skip`（理由 5 通り: 一致 / 対象チケット無し / `executor` の記載無し / `model` が特定できない / `subagent_type` が対象外）を記録する**。記録が **1 件も無い**ときだけが縮退。縮退時、`subagent-stop-check` は**再掲ではなく自分で判定する**（`tool_input.subagent_type` / チケットの `executor` / `tool_input.model` を `model-aliases.txt` で正規化して比較）。制御方式にこの手順を置き、入出力に `tool_input`・`decisions.jsonl`・`model-aliases.txt` を加えた。DDR `i0009-52`。テスト `SA-T08`・`SP-T08`。

**結論**: 縮退が機械的に判定できるようになった。`skip` の記録は「なぜ通知されなかったか」の振り返りにも効く。

### 4. `tool_response` は camelCase（B15） ◎良

`subagent-stop-check` は `tool_response` の `agent_id` で記録を引くと書いていたが、公式では **`agentId`**（`hooks.md:1702`）。イベントの共通入力側は snake_case（`agent_id` / `agent_transcript_path`。`:2325`）で、**同じものを指す名前が経路によって違う**。

`i0009-52` で縮退判定が `agentId` による記録の引き当てに依存するようになったので、取り違えると **`jq` が `null` を返して常に「縮退」と判定し、WF801 を重複して出す**。エラーにならないので、テストを書かない限り気づけない。

**決定**: §2 に命名の違いを書き、PostToolUse 経路の記述を `tool_response.agentId` に直した（SubagentStop 経路の `agent_id` はそのまま）。`SP-T08` に「`agent_id` では引けない」を明記。DDR `i0009-53`。

### 5. `systemMessage` の実測を登録し、T4 を `i0009-26` に合わせた（B4） ◎良

**17 行維持の唯一の支え**は「`systemMessage` がサブエージェントの起動前に人間へ届くこと」なのに、その実測が **§12 の TBD にも全体計画のフェーズ 4c の表にも無かった**（`grep -rn systemMessage wip/00_overall_plan/` → 0 件）。0020 は「0016 へ（最重要）」と申し送っていたが届いていなかった。あわせて §12 T4 が `i0009-26` より前の記述（「`additionalContext` が届かなければ 16 行に戻す」）のままで、`subagent-start-check` 仕様の縮退（「両方届かない版」）と食い違っていた。

**決定**: **§12 に T9 を新設**（`systemMessage` が PreToolUse でユーザーに表示されるか。外れたら 7 行目を外して **16 行に戻す**）。全体計画のフェーズ 4c にも同じ行と、`status` が `async_launched` になるかの行を置いた。T4 は「残る検証は『実物の入力に `model` が無いこと』だけ。7 行目を残す根拠は `systemMessage`（T9）に移った」に書き直した。DDR `i0009-54`。

**結論**: 結論を支える前提が検証の予定表に載った。T4 と T9 は別の問い（前者は SubagentStart の入力、後者は PreToolUse の出力）として分けた。

### 6. 掃き残し（B3・B5 と表の並び） ◎良

- **B3**: §6 の採番台帳の WF801–809 の行が「`subagent-stop-check` が WF801 を再掲するのは**事後の保険**」のままだった → 「縮退時だけで、そのときは再掲ではなく自分で判定する」に直し、WF803 / WF814 も台帳に載せた。`i0009-31` の影響に §6 を追記
- **B5**: `i0009-32`（WF801 を `task-executor` に絞る）が仕様だけに入り要件に無かった（「仕様書は対応する要件書より先に変えない」に反する）→ 要件の Shall not に「タスクの実施者でないときは通知しない」を追加し、`i0009-32` の影響に要件書を追記。仕様の「要件との対応」表にも行を足した
- **表の並び**: `SA-T07` が `SA-T02` の直後に挿入されていた（B14 と同型）→ 末尾へ移し、`SA-T08` / `SA-T09` を続けて `T01`〜`T09` の通番にした

## 検証の結果

| 検証 | 結果 |
|---|---|
| 更新した要件定義書 | 1 本（`subagent-start-check` のメインフロー 2 行） |
| 更新した仕様書 | 3 本（`フック共通仕様`（§1・§2・§6・§12）・`subagent-start-check`・`subagent-stop-check`）+ 全体計画のフェーズ 4c |
| 訂正した DDR | 3 件（`i0009-26`・`i0009-31`・`i0009-32`）。いずれも未マージ |
| 新規の DDR | 5 件（`i0009-50`〜`54`。**割り当て帯 50〜54 に完全一致**） |
| 新設した識別子 | 2 件（**WF803** background 起動の警告 / **WF814** 検査が届かない） |
| 追加したテスト観点 | 4 件（`SA-T08` `skip` の記録 / `SA-T09` WF803 / `SP-T07` `status` の分岐 / `SP-T08` 縮退時の自己判定と `agentId`）。`SA-T07` を並べ直し |
| 新設した TBD | 1 件（**T9** `systemMessage` の到達。外れたら 16 行） |
| 対応した指摘 | 6 件（B1・B2・B3・B4・B5・B15）。すべて反映済み |
| 登録表の行数 | **17 行のまま**（WF803 は 7 行目の同じ登録から出る） |
| ヘッドレス実行の帰結 | 変更なし（案内側のフックで ask を使わない） |

### 受け入れ条件との対応

| # | 受け入れ条件（issue #9） | このチケットが満たす分 | テスト ID（種別） |
|---|---|---|---|
| 1 | フック本体 11 本が仕様どおり動きテストが通る | `subagent-start-check` / `subagent-stop-check` の 2 本が、公式の実際の発火タイミングに合った形になった | SA-T08・SA-T09・SP-T07・SP-T08（すべて機械） |
| 3 | 公式リファレンスとの整合が取れている | background 既定（`:1701`・`:1711`）・`agentId`（`:1702`）・`tool_input` の表（`:1680-1697`）を仕様に反映した | — |
| 5 | `agent_type` の扱いが実物の確認に基づいて仕様に書かれている | `agent_type` の実測（4c）に加え、`tool_response.status` の実測を 4c に登録した | — |
| 6 | 決定の経緯が DDR に残っている | `i0009-50`〜`54`（5 件）+ 既存 3 件の訂正 | — |

## 設計への反映（後続へ）

1. **0016 へ（最重要）**: フェーズ 4c の実測に **T9（`systemMessage` の表示）** と **`tool_response.status`** を含める。同じサブエージェント起動 1 回で両方見える
2. **0016 へ**: `00-workflow-issue-mr-driven` がタスクの実施者を起動するとき **`run_in_background: false`** を付ける手順にする（そうしないと `completed` にならず検査が働かない）
3. **実装フェーズへ**: `tool_response` は公式の名前（camelCase）をそのまま使う。`agentId` を `agent_id` と書くと静かに失敗する
4. **実装フェーズへ**: `status` が想定外の値なら**検査しない側**に倒す
5. **0025・0026 へ**: `subagent-stop-check` の制御方式が 1 つ増えて番号が繰り下がった（旧 2〜5 → 3〜6）。「要件との対応」表の番号を 0026 の B9 と同じ要領で確かめる

## 想定と異なった点

| 計画時の見込み | 実際 | どう扱ったか |
|---|---|---|
| B1 は「PostToolUse の発火タイミングを直す」1 点 | **WF801 には有利・WF811〜813 には致命的**と、同じ事実が用途によって逆に効いた | `i0009-50` で両方を表にして書き分けた |
| B2 は再掲の条件を書き直すだけ | 「記録が無い」が (a) 判定していない と (b) 通知不要と判定した の 2 状態を区別できない、という別の欠陥が隠れていた | `skip` の記録を課して区別できるようにした（`i0009-52`） |
| B15 は名前の 1 文字違い | `i0009-52` で縮退判定が `agentId` に依存するようになったため、**取り違えると常に縮退と判定して重複通知する**という結果に直結していた | `SP-T08` に「`agent_id` では引けない」を明記 |
| B4 は §12 T4 の書き換え | 実測が **§12 にも 4c の表にも無い**ことが本体で、0020 の申し送りが届いていなかった | T9 を新設し、正史と全体計画の両方に置いた |

## 残課題

- **サブエージェントの完了をメインエージェントが知る経路が機構に無い**（f1）。SubagentStop は親に届かず、PostToolUse は起動時に返る。foreground を促す以外の手が無いかは決めていない
- **`tool_input.run_in_background` が実際に来るか**（公式の表に無い）。来なければ WF803 が常に出る
- **background の SubagentStop が残す記録を誰がいつ読むか**の経路が無い
- `status` の想定外の値（実物を見ていない）
- `systemMessage` が実際に表示されるか（T9。フェーズ 4c）
- `subagent-stop-check` の制御方式の番号が繰り下がったので、他の参照箇所に取り残しが無いか（0026 で確かめる）
