---
type: ddr
title: i0009-54. systemMessage の実測を TBD と 4c に登録し、17 行の支えを明示する
description: 登録表を 17 行に保つ唯一の根拠である systemMessage の到達が検証の予定表のどこにも無かったため T9 として登録し T4 の縮退条件を i0009-26 に合わせた判断
tags: [ddr, hooks, TBD, 検証]
keywords: [systemMessage, T4, T9, 17 行, フェーズ 4c, additionalContext, i0009-26, 縮退]
---

# i0009-54. `systemMessage` の実測を TBD と 4c に登録し、17 行の支えを明示する

## 背景

`i0009-26` は「WF801 を `systemMessage`（ユーザーへ即時）と `additionalContext`（AI へ）の 2 経路で出す」と決め、それによって §1 の登録表を **17 行のまま維持**した。7 行目（PreToolUse `Agent` の `subagent-start-check`）を残す根拠は、**`systemMessage` がサブエージェントの起動前に人間へ届く唯一の経路であること**である。

ワーク境界の 2 巡目レビューで 2 つの食い違いが見つかった。

1. **§12 T4 の記述が `i0009-26` より前のまま**だった。「残る検証は … **`PreToolUse` の `additionalContext` が実際に AI へ届くこと**」「`additionalContext` が届かなければ 7 行目の登録を外し … （登録表は 16 行に戻る）」と書かれており、7 行目の根拠が `additionalContext` だった頃の条件がそのまま残っていた。`subagent-start-check` 仕様の縮退（「`systemMessage` **も** `additionalContext` **も**届かない版」）とも食い違う
2. **`systemMessage` の実測がどこにも登録されていなかった**。0020 の結果報告は「0016 へ（最重要）: フェーズ 4c の実測項目に `systemMessage` が実際にユーザーへ表示されるかを足す」と申し送っていたが、共通仕様 §12 の TBD 表にも全体計画のフェーズ 4c の表にも `systemMessage` の行は無い（`grep -rn systemMessage wip/00_overall_plan/` → 0 件）。**17 行維持という結論の唯一の支えが、検証の予定表に載っていなかった**

## 決定

- **§12 に T9 を新設する**: 「`systemMessage` が PreToolUse でユーザーに実際に表示されるか」。現在の前提は「表示される」（公式は「Warning message shown to the user」と定め、PreToolUse の節に破棄の記述が無い）。**外れたときの縮退は「7 行目の登録を外し、実行者の不一致は `subagent-stop-check` の縮退判定だけに寄せる（登録表は 16 行に戻る）」**
- **全体計画のフェーズ 4c の表にも同じ行を置く**。あわせて「`tool_response.status` が既定で `async_launched` になるか」（`i0009-50`）も同じ起動で確かめる行として置く
- **§12 T4 の記述を `i0009-26` に合わせる**: 「残る検証は『実物の入力に `model` が無いこと』だけ。**7 行目を残す根拠は `systemMessage`（T9）に移った**ので、`additionalContext` の到達はこの行の判断材料ではない」。縮退も「実物に `model` が来るなら比較を SubagentStart 側へ戻してよい。7 行目を外すかどうかは T9 が決める」に直す

## 理由

- **結論を支える前提は、検証の予定表に載っていなければ検証されない**。17 行維持は登録の段取り（フェーズ 4b）にも影響する決定で、支えが外れたときの手戻りが大きい。実測のコストは「サブエージェントを 1 つ起動して警告が出るか見る」だけ
- **縮退の条件が 2 か所で違うと、実測の結果をどう解釈するか決まらない**。T4 が「`additionalContext` が届かなければ 16 行」、仕様が「両方届かなければ縮退」と書いていると、片方だけ届いたときの扱いが不定になる
- **T4 と T9 は別の問いである**。T4 は「SubagentStart の入力に何が来るか」、T9 は「PreToolUse の出力が誰に届くか」。1 行に混ぜると、片方が外れたときにもう片方まで巻き添えになる
- **同じ起動で 2 つ確かめられる**。`executor` と違うモデルでサブエージェントを 1 つ起動すれば、T9（警告が出るか）と `status`（`async_launched` か）の両方が見える

## 却下した案

- **`systemMessage` の実測を 0016（実装計画）の申し送りだけに残す**: 0020 が既にそうしていて、届かなかった。正史（§12）と全体計画の両方に置く
- **T4 に `systemMessage` の検証を足す**: 上記のとおり別の問い。T4 は SubagentStart の入力、T9 は PreToolUse の出力
- **`systemMessage` が届かない前提で最初から 16 行にする**: 公式の記述は明確（「Warning message shown to the user」・PreToolUse の節に破棄の記述なし）で、疑う根拠が無い。実測は確認であって、前提を変える理由ではない
- **人間への即時通知を諦め、`additionalContext` だけにする**: 要件が「サブエージェントが動き出す前に**ユーザーへ**伝える」を求めている（`i0009-26`）

## 影響

- `10_spec/フック共通仕様.md` §12（T9 を新設・T4 の残る検証と縮退を書き直し）
- `wip/00_overall_plan/overall-plan.md` フェーズ 4c の表（T9 と `status` の行）
- `20_ddr/i0009-26`（影響に §12 T9 を追加）
- **フェーズ 4c へ**: `executor` と違うモデルでサブエージェントを 1 つ起動し、警告の表示と `tool_response.status` を同時に見る
- 関連: `i0009-26`（2 経路と 17 行）・`i0009-50`（background 既定）
