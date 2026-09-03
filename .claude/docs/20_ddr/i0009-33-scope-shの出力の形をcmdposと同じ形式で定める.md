---
type: ddr
title: i0009-33. scope.sh の出力の形を cmdpos.sh と同じ形式で定める
description: 3 本のフックが共有する scope.sh の関数名と出力変数が仕様のどこにも無く、判定結果と戻り値 0/1/2 が両立しなかったため、§7-9 と同じ「出力の形」を §8 に置いた判断
tags: [ddr, hooks, scope.sh, ライブラリ]
keywords: [scope.sh, 出力の形, SC_DECISION, SC_ID, SC_STAGE, SC_CLASS, scope_resolve, scope_classify, cmdpos.sh]
---

# i0009-33. `scope.sh` の出力の形を `cmdpos.sh` と同じ形式で定める

## 背景

`scope.sh` は `workflow-guard`（正）・`workflow-diff-check`・`subagent-stop-check`・`workflow-state-guard` が共有する。ところが仕様に書かれていたのは次の 2 つだけだった。

- §8「**`scope.sh` の関数の戻り値**: 0 = 判定できた / 1 = チケットの記載不正 / 2 = `frontmatter.sh` を読み込めていない」（`i0009-16`）
- §11 HK-T15「判定順 (1)〜(7) が §8 の順で適用され**段階番号が返る**」

境界レビュー（付録 A の R6）の指摘は 2 つ。

1. **両立しない**: 戻り値が 0/1/2 の 3 状態に予約されているなら、allow / ask WF202 / ask WF203 / deny WF201 という**判定結果**と**段階番号**をどこで返すのかが仕様に無い
2. **共有面が未定義**: 関数名は `20-common-step-shell-script` 仕様に出てくる `scope_classify` 1 つだけ。対照的に `cmdpos.sh` は §7-9「**出力の形**」で `CP_COUNT` / `CP_EXE[i]` / `CP_SUBCMD[i]` / `CP_PROVIDED[i]` / `cmdpos_args` まで完全に定義されている

「仕様書は実装・テストが推測なしに作れる粒度まで決める」という自分たちのルールを満たしていなかった。

## 決定

§8 に §7-9 と同じ形式の「**出力の形**」を表として置く。

| 関数 | 種類 | 出力変数 | 戻り値 |
|---|---|---|---|
| `scope_load <json> [type]` | 読み込み | `SC_COMMON_*` / `SC_TYPE_*` / `SC_BUILD_TEST[]` / `SC_ERROR` | 0 / 1 / 2 |
| `scope_load_ticket <ticket.md>` | 読み込み | `SC_TICKET_TYPE` / `SC_DECL_WRITE[]` / `SC_DECL_OPS[]` / `SC_ERROR` | 0 / 1 / 2 |
| `scope_load_approvals <json>` | 読み込み | `SC_APPROVED[]` / `SC_ERROR` | 0 / 1 / 2 |
| `scope_resolve <path>` | 判定 | `SC_DECISION` / `SC_ID` / `SC_STAGE` / `SC_ASK_SCOPE` | 常に 0 |
| `scope_classify <セグメント番号>` | 判定 | `SC_CLASS` / `SC_TARGETS[]` | 常に 0 |
| `scope_match <path> <pattern>` | 述語 | なし | 一致 0 / 不一致 1 |
| `scope_op_declared <class>` | 述語 | なし | 宣言あり 0 / なし 1 |

- **判定結果は戻り値ではなく `SC_DECISION` / `SC_ID` / `SC_STAGE` で返す**（判定関数の戻り値は常に 0）
- HK-T15・HK-T16 の期待値をこの形に合わせる

## 理由

- **`cmdpos.sh` で既にできている形をそのまま使える**。`§7-9` は「純 bash・fork なしで判定できる形」として bash の配列で結果を置く方式を確立しており、`scope.sh` も同じ制約（ホットパスで動く・fork を増やせない）の下にある。新しい方式を発明する理由が無い
- **戻り値の衝突が構造的に解ける**。bash の戻り値は 1 バイトの整数 1 つしか返せないので、「読めたか」と「判定結果」と「段階番号」の 3 つを同時には返せない。**読み込みの成否だけを戻り値に、残りを変数に**という分け方は、読み込みと判定を別の関数に分けたことの自然な帰結
- 3 本（実際は 4 本）のフックが共有する面なので、ここが未定義だと各フックの仕様が「`scope.sh` の判定順で」と書くしかなく、実装者は参考実装を読むことになる。**参考実装が正になってしまう**のは避けたい

## 却下した案

- **判定結果を戻り値で返し、読み込みの失敗を変数（`SC_ERROR`）で返す**: `set -e` の下では非 0 の戻り値が本体を落とすので、判定結果（deny = 非 0）を戻り値にすると呼び手が毎回 `|| rc=$?` で受けることになる。読み込みの失敗を戻り値にする方が、`set -e` の意味（失敗したら止まる）と合う
- **1 つの関数（`scope_check`）に統合してすべてを変数で返す**: 読み込みは 1 回、判定は対象ごとに複数回呼ぶので、呼び出しの回数が違う。統合すると毎回設定を読み直すことになる
- **JSON を 1 行で返して呼び手が `jq` で読む**: ホットパスの fork 上限（`i0009-22`・`i0009-46`）に反する

## 影響

- `10_spec/フック共通仕様.md` §8（出力の形の表を追加）・§11（HK-T15・HK-T16 の期待値）
- **実装フェーズへ**: 参考実装 `.claude/hooks/lib/scope.sh` は `SC_DECISION` / `SC_ID` / `SC_STAGE` / `SC_CLASS` / `SC_TARGETS` を既に使っているので、名前を揃えれば差分は小さい
- 関連: `i0009-34`（戻り値の規約の適用範囲）・`i0009-16`（3 状態の由来）
