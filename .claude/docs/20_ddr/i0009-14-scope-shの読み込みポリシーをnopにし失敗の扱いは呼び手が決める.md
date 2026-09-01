---
type: ddr
title: i0009-14. scope.sh の読み込みポリシーを nop にし失敗の扱いは呼び手のフックが決める
description: 案内側フックが scope.sh を source すると deny ポリシーのせいで案内側の原則と矛盾する問題に対し、ライブラリ側を nop にして失敗の扱いを呼び手に委ねると決めた判断
tags: [ddr, hooks, scope.sh, frontmatter.sh, ライブラリ]
keywords: [scope.sh, frontmatter.sh, 読み込み行, nop, deny, 案内側, 拒否側, WF209, WF211, T8]
---

# i0009-14. `scope.sh` の読み込みポリシーを `nop` にし失敗の扱いは呼び手のフックが決める

## 背景

`scope.sh`（§8 の許可範囲判定）は、チケットの frontmatter を読むために `frontmatter.sh`（`.claude/skills/20-common-step-shell-script/scripts/`）を `source` する。この**読み込み行**には `20-common-step-shell-script` 仕様が定めるポリシーがあり、現行の共通仕様では `deny`（読めなければ deny JSON を出して終了 0）としていた。

`scope.sh` を共有するフックは 4 本ある。

| フック | 側 | `frontmatter.sh` が読めないときの原則 |
|---|---|---|
| `workflow-guard` | 拒否側 | 拒否側に倒す（deny） |
| `workflow-state-guard` | 拒否側 | 拒否側に倒す（deny） |
| `workflow-diff-check` | 案内側 | **何も出さずに通す** |
| `subagent-stop-check` | 案内側 | **何も出さずに通す** |

ライブラリ側が `deny` を出すと、案内側の 2 本は §3 の原則（案内側は依存が壊れたら何も出さずに通す）に反する。共通仕様 §12 T8 はこれを「実機で害があれば `nop` にする」として実測待ちの TBD にしていた。

さらに `PostToolUse` では `permissionDecision` 自体が無視されるため、案内側が deny JSON を出しても操作は止まらず、**ログと理由だけが残る**（誤解を招く記録が増える）。

## 決定

- **`scope.sh` の読み込みポリシーを `nop` に変える**。`frontmatter.sh` が読めなければ `fm_*` が空を返すスタブになり、`scope.sh` 自身は何も出力しない
- **失敗の扱いは呼び手のフックが決める**
  - 拒否側（`workflow-guard` / `workflow-state-guard`）: 自分で deny に倒す（`WF209` / `WF309`）
  - 案内側（`workflow-diff-check` / `subagent-stop-check`）: 何も出さずに通す
- **`frontmatter.sh` 不在（機構の破損 → `WF209`）とチケットの記載不正（→ `WF211`）を戻り値で区別する方法**は `20-common-step-shell-script` 仕様が定める（チケット 0015 の担当）
- §12 T8 を実測を待たずに閉じる

## 理由

- 実測を待つ必要が無い。「案内側が deny を出す」ことが原則と矛盾するのは仕様を読めば分かることで、実機で確かめても「矛盾していた」以上の情報が得られない
- **失敗ポリシーは呼び手の性格で決まる**。同じライブラリを拒否側と案内側の両方が使う以上、ライブラリ側が一律のポリシーを持つ設計そのものが誤り。`nop` は「判断しない」なので、どちらの呼び手にも矛盾しない
- 拒否側が自分で deny に倒すのは負担ではない。`scope.sh` の関数が空を返したことは呼び手側で検知でき、そのとき `WFx09` を出すのは各フックの制御方式に既に書かれている
- `WF209`（機構の破損）と `WF211`（チケットの記載不正）は回復の案内が違う（前者は `.claude/` の状態確認、後者はチケットの修正）。空の `fm_*` だけでは区別できないので、戻り値で区別する必要がある。ただしそれは `frontmatter.sh` を持つスキルの仕様に属するため、0015 に送る

## 却下した案

- **`deny` のまま残し、案内側は `scope.sh` を使わない**: `workflow-diff-check` の「範囲外の差分」判定（WF601）は許可範囲の照合そのものなので、`scope.sh` を使わない選択は判定を二重に書くことになる
- **呼び手がポリシーを引数で渡す（`scope_load --policy deny`）**: 読み込み行はライブラリの先頭で走るので、呼び手が引数を渡す前に評価が終わる。`source` 前に環境変数で渡す形は可能だが、設定し忘れの既定が結局どちらかに倒れるので `nop` を既定にするのと変わらない
- **実測まで TBD に残す**: 実測で分かるのは「案内側が deny を出す」という既知の事実だけ。TBD を持ち越すと実装フェーズで判断が要る

## 影響

- `10_spec/フック共通仕様.md` §1（`frontmatter.sh` の依存の行）・§12 T8（閉じる）
- `10_spec/skills/20-common-step-shell-script.md`「読み込み行」（`scope.sh` のポリシーを `nop` にし、戻り値で `WF209` / `WF211` を区別する方法を定める。**0015 の担当**）
- `10_spec/hooks/20-PreToolUse/workflow-guard.md` / `workflow-state-guard.md`（呼び手側で deny に倒すことの確認）
- `10_spec/hooks/22-PostToolUse/workflow-diff-check.md` / `13-SubagentStop/subagent-stop-check.md`（何も出さずに通すことの確認）
