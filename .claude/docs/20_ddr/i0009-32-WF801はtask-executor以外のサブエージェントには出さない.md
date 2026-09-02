---
type: ddr
title: i0009-32. WF801 は task-executor 以外のサブエージェントには出さない
description: subagent_type を読みながら判定に使っていなかったため、レビュアーや探索エージェントを別モデルで起動すると実行者の不一致が誤発報する問題を、種別で絞って解消した判断
tags: [ddr, hooks, subagent-start-check, WF801]
keywords: [subagent_type, task-executor, adversarial-reviewer, Explore, WF801, 誤警告, executor]
---

# i0009-32. WF801 は `task-executor` 以外のサブエージェントには出さない

## 背景

`subagent-start-check` の入出力は PreToolUse `Agent` のとき `tool_input.model` と **`tool_input.subagent_type`** の両方を読む（`hook_read_input` が `HOOK_MODEL` / `HOOK_SUBAGENT_TYPE` に入れる）と書かれている。しかし制御方式 4（不一致の判定）も 5（要点の注入）も **`subagent_type` を条件に使っていない**。

境界レビュー（付録 A の R21）の指摘: 敵対的レビュー（`adversarial-reviewer`）やコード探索（`Explore`）を明示的に別のモデルで起動すると、チケットの `executor` と一致しないので **WF801 が誤発報**する。禁止事項には「起動モデルが特定できないときの通知（**誤警告を出さない**）」とあり、誤警告を嫌う方針は既に書かれている。

現状は起動プロンプトが `model` を渡さない運用なので実害は出にくいが、この issue 自身が opus のレビュアーを明示的に起動しており、運用が変われば当たる。

## 決定

- 制御方式 4 の条件に **`tool_input.subagent_type` が `task-executor`（タスク実施者）であること**を加える。それ以外では不一致の判定を行わない
- 理由を「チケットの `executor` は**タスクの実施者**に対する指定であって、レビュアーや探索エージェントには当てはまらない」と明記する
- テスト `SA-T07` に負のケース（`adversarial-reviewer` / `Explore` では通知しない）を置き、同じテストの中に `task-executor` では出るという**正のコントロール**を添える
- **要点の注入（制御方式 5）は絞らない**。SubagentStart で全サブエージェントに注入する現行のままとする

## 理由

- **`executor` の意味に忠実**。`rules/work-defaults.md` の「既定の実行者」はタスクの種類ごとの実施者を定めるもので、レビュアーの起動モデルを縛る意図は無い（むしろ敵対的レビューは実施者と別のモデルで回す方が価値がある）
- **誤警告は通知の信用を落とす**。WF801 は「止めて起動し直す」という重い対処を促すので、当たらない場面で出ると無視されるようになる
- 注入（WF802）を絞らないのは、レビュアーにも「レビュー対象の範囲を知る材料」として有用だから（呼出条件に既にその旨がある）

## 却下した案

- **`executor` にレビュアーのモデルも書けるようにする**: チケットの frontmatter に項目が増え、`work-defaults.md` の表も列が増える。レビュアーのモデルは全体計画の方針で決まるもので、チケットごとに指定する必要が無い
- **`subagent_type` が `task-executor` 以外なら通知はしないが記録は残す**: 記録の価値が薄い（不一致でないものを不一致として記録することになる）。`decisions.jsonl` のノイズになる
- **現状のまま（運用で `model` を渡さないことに依存する）**: 依存が暗黙で、運用が変わったときに気づけない

## 影響

- `10_spec/hooks/12-SubagentStart/subagent-start-check.md` 制御方式 4・`SA-T07`（新規）
- `00_requirement/hooks/12-SubagentStart/subagent-start-check.md` メインフロー（**Shall not に「タスクの実施者でないときは通知しない」を追加**。仕様が要件より先に変わっていた状態を 0024 で解消）
- **実装フェーズへ**: `task-executor` という `subagent_type` の名前は `.claude/agents/` の実体と一致させる（実体の作成は 3/3）
