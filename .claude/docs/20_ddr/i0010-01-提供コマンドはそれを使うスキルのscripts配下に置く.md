---
type: ddr
title: 提供コマンドはそれを使うスキルの scripts/ 配下に置く
description: boundary.sh と finalize.sh の置き場が仕様（各スキルの scripts/。フルパスは 4 行）と実装済みフックの案内（.claude/hooks/。7 行）で食い違っていたので、仕様側を正として全体の原則に格上げし、実装側の 7 行を追従させる決定
tags: [ddr, 提供コマンド, 置き場, boundary.sh, finalize.sh, フック]
keywords: [提供コマンド, 置き場, scripts, hooks, boundary.sh, finalize.sh, session-start, workflow-state-guard, scope.sh, 所有関係]
---

# 提供コマンドはそれを使うスキルの scripts/ 配下に置く

## 背景

issue #10 の調査（結果報告 0004 の b4）で、まだ実装されていない提供コマンド 2 本の置き場が 2 通りに書かれていることが分かった。

- **仕様の言い分**: `10_spec/skills/00-workflow-issue-mr-driven.md` は `.claude/skills/00-workflow-issue-mr-driven/scripts/boundary.sh`、`10_spec/skills/10-task-overall-summary.md` は `.claude/skills/10-task-overall-summary/scripts/finalize.sh`（IN / OUT サンプルにフルパスで 3 行 + 1 行の計 4 行。Script 処理は `scripts/<名前>.sh` の相対表記で置き場を含まない）
- **実装の言い分**: 先行の issue で実装済みのフックは `.claude/hooks/boundary.sh` と `.claude/hooks/finalize.sh` を前提にしている（7 行。`session-start.sh:64` のハードコード 1、`workflow-state-guard.sh:40, 43` の案内文 2、テストの入力 4）

どちらでも機構は動く。提供コマンドの識別（`フック共通仕様` §7 の項目 8）は `.claude/skills/*/scripts/*.sh` と `.claude/hooks/**/*.sh` の**両方**を受け付けるためである。ただし片方は必ず存在しないパスを案内することになり、そのまま実装フェーズに入ると「案内どおりに叩いたら無い」という形で AI と人間の両方が詰まる。申し送り 0028 は「実装と仕様が食い違う候補は計画の段階でどちらを正にするかまで決める」を求めており、AI アセット設計計画（チケット 0007）で決着させた。

## 決定

- **提供コマンドは、それを使うスキルの `scripts/` 配下に置く**。これを 2 本だけの措置ではなく、機構全体の原則とする
- したがって `boundary.sh` は `.claude/skills/00-workflow-issue-mr-driven/scripts/boundary.sh`、`finalize.sh` は `.claude/skills/10-task-overall-summary/scripts/finalize.sh` に置く（仕様の現行記述をそのまま正とする）
- `.claude/hooks/` はフック本体（イベント駆動で機構が呼ぶもの）と、その設定・ライブラリ・テストだけを置く場とする
- 実装済みフックの 7 行は実装フェーズで新しいパスへ追従させる。一覧は `10_spec/skills/00-workflow-issue-mr-driven.md`「現行アセットとの差分」に置く
- `scope.sh` の提供コマンド識別は両方の形を受け付けたままにする（狭めない）。実装フェーズの途中でどちらの形も現れうるため、識別を先に狭めると移行中に機構が止まる

## 理由

- **既存の 5 本と揃う**: 実装済みの提供コマンド（`ticket.sh` / `commit.sh` / `push.sh` / `check-html.sh` / `run-tests.sh`）はすべてスキルの `scripts/` にある。2 本だけを別の場所に置くと、置き場から種類を推測できなくなる
- **所有関係が置き場で分かる**: `boundary.sh` はワークフロースキルが、`finalize.sh` は全体まとめタスクが使う。スキルの下にあれば、スキルの手順を読む人がその場でスクリプトを見つけられる
- **フックと提供コマンドは呼ばれ方が違う**: フックはイベント（ツール実行前・セッション開始）で機構が呼び、提供コマンドは手順の中で AI が呼ぶ。同じディレクトリに混ぜると、`.claude/hooks/` の中身が「機構が呼ぶもの」で揃わなくなる
- **変更行数は仕様側のほうが少ない**: 実装側に寄せれば仕様 4 行（`00-workflow-issue-mr-driven` の IN / OUT サンプル 3 行と `10-task-overall-summary` の同 1 行）、仕様側に寄せれば実装 7 行。行数だけを見れば実装を正とするほうが安いが、この差では既存 5 本との一貫性を覆せないと判断した

## 却下した案

- **`.claude/hooks/` に寄せる（実装を正とする）**: 変更行数がわずかに少なく、`session-start.sh` のハードコード 1 行（中核）を触らずに済む。却下したのは、既存 5 本との不一致が恒久的に残るため。中核 1 行を触るリスクは、実装計画にロックアウト対策を付けることで引き受ける
- **`.claude/commands/` のような専用ディレクトリを新設する**: 提供コマンドが一覧できるようになるが、既存 5 本もすべて移すことになり、この issue の範囲を大きく超える。所有関係も失われる
- **両方に置く（実体とシンボリックリンク）**: Windows でのリンクの扱いが環境依存で、`フック共通仕様` §7 の項目 8 が「コマンド文字列上のルート相対表記」だけで識別する以上、2 つの正しい呼び方が生まれる。識別の一意性が崩れる
- **決めずに実装フェーズへ送る**: 実装計画が許可範囲を書く時点で置き場が決まっていないと、テスト 4 行を許可範囲に入れ忘れる（申し送り 0038 が指す事故そのもの）

## 影響

- `10_spec/skills/00-workflow-issue-mr-driven.md` の Script 処理に置き場を明記し、「現行アセットとの差分」の 7 行の表を追加する
- `10_spec/skills/10-task-overall-summary.md` の Script 処理に置き場を明記する
- `10_spec/hooks/00-SessionStart/session-start.md` の処理フロー 3 が参照するパスを明記する
- `00_requirement/自己改善ワークフロー機構.md` に置き場の原則を書く
- 実装フェーズでは、`session-start.sh:64` の 1 行を**中核の変更**として扱う。パスを取り違えると現在地の注入が丸ごと止まり、しかも不在時は無出力で終了 0 に倒れるため気づきにくい。変更前後で SE-T05 後半を通し、`hook_record skip` のログを確認する
- テスト 4 行（`test_workflow_entry.sh:143, 144` と `test_workflow_state_guard.sh:117, 118`）は期待値が置き場に依存するので、パスを変えるチケットと同じ許可範囲に入れる
