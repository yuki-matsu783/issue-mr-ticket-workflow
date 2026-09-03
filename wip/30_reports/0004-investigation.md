---
type: report
title: 0004 調査結果 — boundary.sh / finalize.sh の仕様の洗い出しと実装済みフックとの食い違い
description: 提供コマンド 2 本（boundary.sh 5 サブコマンド・finalize.sh release 5 段階）の判定順・入出力・logs のスキーマを仕様から書き出し、置き場のハードコード・段階順の内部矛盾・注入整形の未実装・全体まとめの完了検査の出力先という 4 件の食い違いを列挙した調査結果
tags: [report, investigation, issue-10]
keywords: [boundary.sh, finalize.sh, 判定順, サブコマンド, logs, review-state, merge-state, mr.json, 置き場, session-start, 段階順, pre_cleanup_sha, BD001, FN001]
---

# 0004 調査結果 — boundary.sh / finalize.sh の仕様の洗い出しと実装済みフックとの食い違い

## サマリ

提供コマンド 2 本の仕様は**そのまま実装に落とせる粒度**にある。`boundary.sh` は 5 サブコマンド（`status` / `note` / `request` / `skip` / `complete`）で、前提検査・エラー識別子 BD001〜005・テスト ID BD-T01〜13 まで書かれている。`finalize.sh` は `release` 1 本で、5 段階（前提検査 → 完了検査 → 片付け → push → 最終ゲートと draft 解除）と冪等の規則、FN001〜003・FN-T01〜05 が揃っている。`logs/` の 4 ファイルは**書く側（仕様）と読む側（実装済みフック）でキー名が一致**しており、そのまま結線できる。

食い違いは **4 件**。うち 2 件は設計で先に決めないと実装できない。最も重いのは `finalize.sh release` の段階順が **issue #10 の追記 3 の要求と仕様内で矛盾している**こと（本文のリンク一覧を書く時点で `pre_cleanup_sha` が未確定）。次に、置き場が仕様（`skills/*/scripts/`）と実装（`session-start.sh` のハードコード `.claude/hooks/boundary.sh`）で割れている。

- ◎良 4 件 / △注意 4 件 / ✕問題 2 件

### ◆特に見てほしい（判断に困っている）

- **b6**: `finalize.sh release` の段階順が矛盾。仕様の処理フローは 5（MR 本文の最終化）→ 6（HTML 添付）→ 7（push）→ 9（release で片付け）だが、`pre_cleanup_sha` は release の段階 3 で初めて確定する。**本文にリンク一覧を書く時点で片付け前 SHA が無い**。issue 追記 3 が求める「片付け直前の SHA 確定 → 本文のリンク一覧更新 → 片付け」を成立させるには、release に本文更新の段階を足すか、手順 5 を release の直前に移すかを設計で決める必要がある
- **b4**: 置き場の食い違い。仕様は `.claude/skills/00-workflow-issue-mr-driven/scripts/boundary.sh` と `.claude/skills/10-task-overall-summary/scripts/finalize.sh`、実装済みの `session-start.sh` は `$HOOK_WORKTREE/.claude/hooks/boundary.sh` をハードコードしている。**どちらに寄せるかで直す対象が変わる**（仕様 4 行 vs 実装 1 行 + 案内文 2 行）

### ◇承認が欲しい（方針は決めた）

- **b5**: `session-start` の注入整形（制御方式 4〜11）が 2/3 で保留され、コードに `3/3 で実装する` と書かれたまま残っている。`boundary.sh` の出力形式が決まる 3/3 が実装の場なので、**この issue の実装フェーズに含める**のが妥当。ただし issue #10 の受け入れ条件には明示が無いため、スコープに入れる合意が要る
- **b8**: 全体まとめチケットの完了検査（`ticket.sh complete` が TK005 で拒否するための代替）は release の段階 2 に書かれているが、**検査結果の出力先が仕様に無い**。issue 追記の受け入れ条件 B4 が求める「DoD × 根拠を統括レポートに写す」を段階 2 の出力として書き足す

### ・細かいレビューは不要（ほぼ確実）

- **b1**〜**b3**: サブコマンドの判定順・入出力、release の 5 段階、`logs/` 4 ファイルのスキーマ一致（いずれも仕様と実装の転記）
- **b9**: `gh` CLI 不在時のフォールバック（`--external` / `--standalone`）は 2 本とも仕様に揃っている

## 確かめられなかったこと（この結果が言っていないこと）

- 実装が仕様どおり動くか（読み取りのみ。実測は計画書の V1〜V5）
- `boundary.sh status` がこのリポジトリの実際の作業領域から正しい現在地を返すか（V1）
- `finalize.sh release` の前提検査がこの issue の途中の状態で正しく拒否するか（V4）
- 食い違いを「仕様を直す」「実装を直す」のどちらで解消するか（**0007 の担当**。ここは列挙と材料まで）
- 旧名の残存箇所（0005 の担当）と申し送りの反映先（0006 の担当）
- `logs/review-history.jsonl` の 1 行のスキーマ（仕様は「直前の内容を 1 行追記」とだけ書き、読む側の実装が無いため確かめようがない）

## 実施条件（読んだ対象）

| 対象 | 読んだ節 |
|---|---|
| `10_spec/skills/00-workflow-issue-mr-driven.md` | Script 処理（進行状態と記録 / 切れ目の判定 / `--final` / 各サブコマンド / エラー識別子 / テスト観点） |
| `10_spec/skills/10-task-overall-summary.md` | 処理フロー 1〜10 / Script 処理 / release / エラー識別子 / テスト観点 |
| `10_spec/hooks/00-SessionStart/session-start.md`、`10_spec/hooks/10-UserPromptSubmit/workflow-entry.md` | `boundary.sh` への依存の記述 |
| `.claude/hooks/00-SessionStart/session-start.sh` | 62〜86 行（制御方式 3 と保留） |
| `.claude/hooks/20-PreToolUse/workflow-state-guard.sh` | 40〜56 行（案内文と状態ファイルの一覧） |
| `.claude/hooks/10-UserPromptSubmit/workflow-entry.sh` | 155〜205 行（継続条件） |
| `.claude/hooks/lib/hook-common.sh`、`.claude/hooks/lib/cmdpos.sh`、`.claude/hooks/lib/scope.sh` | 状態ファイルの読み取り / 提供コマンドの判定 / 分類 |
| `.claude/skills/20-common-step-ticket/scripts/ticket.sh` | 254 行（TK005） |

読み取りのみ。テスト・ビルドは実行していない。

## 実施した内容と結果

### b1. `boundary.sh` は 5 サブコマンド。前提検査と判定順が全件書かれている ◎良

| サブコマンド | 主な前提（未充足は BD001） | 出力 | 状態の変化 |
|---|---|---|---|
| `status [--offline]` | なし（矛盾検出時のみ BD005） | JSON（`mr` / `current` / `next` / `at_boundary` / `last_task` / `review` / `position`） | `logs/mr.json` を書くことがある |
| `note --body-file [--usage-report]` | 本文が空でない / MR がある | コメント URL | `review-history.jsonl` に追記（`state` は変えない） |
| `request --body-file [--external --comment-url] [--standalone] [--usage-report]` | 切れ目である / 未コミット無し / push 済み / MR がある / 二重依頼でない / 本文が空でない | コメント URL・対象・差分範囲 | `state: requested`、`base_sha` / `head_sha` / URL / 時刻 / `via` |
| `skip --reason` | 切れ目である / レビュー要でない / 理由が空でない | `OK:` | `state: skipped` |
| `complete [--accept-unresolved] [--external --report-file] [--standalone] [--final]` | `state` が `requested`（違えば BD002）/ リモート取得成功（失敗は BD004）/ 未解決・変更要求が無い（あれば BD003） | `findings` の JSON と件数 | `state: completed`、`findings`、履歴追記 |

`--final`（全体まとめ）は前提の読み替えが明示されている: 「`at_boundary` である」→「`10_doing/` が `overall-summary` 1 枚である」、レビュー要否は `last_task.review_required` ではなく作業中チケットの `human_review.required`。

**切れ目の判定（正）**も仕様側にある: `at_boundary` = `10_doing/` が空 かつ（`next` が null または `next.type` ≠ `20_done/` 最大連番の type）。`position` は上から順に `requested` → `in_task` → `before_request` → `completed` → `merge_prep` → `none`。

### b2. `finalize.sh` は `release` 1 本。5 段階と冪等の規則が書かれている ◎良

| 段階 | 内容 | 記録 |
|---|---|---|
| 1 前提検査（初回のみ） | 全体まとめチケットが作業中 / 他にチケットが無い / 統括レポートの md + HTML がある / MR 本文に `## 統括` がある / HEAD が push 済み / レビューが `completed`（不要なら `skipped`） | 未充足は FN001 で全件列挙 |
| 2 完了検査（初回のみ） | 全体まとめチケットの DoD・作業ログ・根拠欄。`ticket.sh` の完了検査を source して二重実装しない | 未充足は FN002 |
| 3 片付け | `pre_cleanup_sha` を記録し、`wip/` 配下の全成果物を削除して 1 コミット（`.gitkeep` は残す） | `state: cleaned` |
| 4 push | `push.sh` を内部実行 | `state: pushed` |
| 5 最終ゲートと draft 解除 | `git fetch` して遅れ・衝突が無いことを検査し、`gh pr ready` / `glab mr update --ready` | `state: ready`。検査で止まれば FN003 |

`logs/merge-state.json` が壊れた場合の**実態からの再導出**も規定済み（`wip/` に成果物 → 未実施 / `wip/` 空で未 push → `cleaned` / push 済みで draft → `pushed` / draft でない → `ready`）。`pre_cleanup_sha` を失った場合は片付けコミットの親から再構成する。

### b3. `logs/` の 4 ファイルは書く側と読む側でキーが一致している ◎良

| ファイル | 書く側（仕様） | 読む側（実装済み） | 一致 |
|---|---|---|---|
| `logs/mr.json` | `{"host", "issue", "mr", "url"}` を `boundary.sh status` が書く | `post-push-compact-prompt.sh:90` が `.mr // .number // .iid` を読む。`post-push-usage-report.sh:245` も参照 | 一致（`number` / `iid` は別実装からの受け皿とコメントに明記） |
| `logs/review-state.json` | `{"mr", "boundary": {...}, "state", "via", "base_sha", "head_sha", ...}` | `workflow-entry.sh` が `state` だけを読み `requested` で継続を許す。`hook-common.sh:412` が読み込みを担う | 一致 |
| `logs/review-history.jsonl` | 直前の内容を 1 行追記 | 読む実装は無い（`workflow-state-guard` の保護対象にだけ入る） | 読む側なし |
| `logs/merge-state.json` | `{"issue", "mr", "state", "pre_cleanup_sha", ...}` | `workflow-entry.sh` が `state` を読み、`started`/`cleaned`/`pushed` のとき提供コマンドの再実行だけを通す。`hook-common.sh:413` | 一致 |

4 ファイルとも `workflow-state-guard.sh:56` の `__SG_STATE_FILES` に列挙されており、直接編集は拒否される。**`boundary.sh` / `finalize.sh` だけが書ける**という設計は実装済みの側で担保されている。

### b4. 提供コマンドの置き場が仕様と実装で割れている ✕問題

| 出どころ | 指しているパス |
|---|---|
| `10_spec/skills/00-workflow-issue-mr-driven.md`（IN / OUT サンプル 3 行、Script 処理） | `.claude/skills/00-workflow-issue-mr-driven/scripts/boundary.sh` |
| `10_spec/skills/10-task-overall-summary.md`（サンプル 1 行、Script 処理） | `.claude/skills/10-task-overall-summary/scripts/finalize.sh` |
| `.claude/hooks/00-SessionStart/session-start.sh:64`（実装。ハードコード） | `$HOOK_WORKTREE/.claude/hooks/boundary.sh` |
| `.claude/hooks/20-PreToolUse/workflow-state-guard.sh:40, 43`（案内文） | `.claude/hooks/boundary.sh` / `.claude/hooks/finalize.sh` |

**分類の側は両方に対応済み**なので、どちらに置いても機構は壊れない: `cmdpos.sh:317` が提供コマンドと認めるのは `.claude/skills/<名前>/scripts/<名前>.sh` **または** `.claude/hooks/(<ディレクトリ>/)*<名前>.sh` の両方。`workflow-entry.sh:192` の継続判定も `*/finalize.sh|*/boundary.sh` のパターンで、パスに依存しない。

| 案 | 直す対象 | 既存パターンとの整合 |
|---|---|---|
| (a) `skills/*/scripts/` に置く（仕様どおり） | `session-start.sh` 1 行 + 案内文 2 行 | 既存の提供コマンド（`ticket.sh` / `commit.sh` / `push.sh` / `check-html.sh` / `run-tests.sh`）はすべて `skills/*/scripts/`。`.claude/hooks/` は settings.json が起動するフック本体だけ |
| (b) `.claude/hooks/` に置く | 仕様 4 行 | `.claude/hooks/` に非フックのスクリプトが混ざる |

**(a) が既存パターンと整合する**。ただし副作用として、テストの置き場が `skills/*/scripts/tests/` になり、`scope.sh:377` の分類では `hook-test` に当たる（`build-test` ではない）。実装チケットの `allow.ops` に `hook-test` が要る。**決定は 0007**。

### b5. `session-start` の注入整形が未実装のまま残っている △注意

`.claude/hooks/00-SessionStart/session-start.sh` の 62〜86 行は、`boundary.sh status --offline` を呼ぶところまでで終わっており、次の状態にある。

- 64 行: `boundary.sh` が無ければ `hook_record skip`（`boundary.sh 不在（3/3 で実装）`）で終了
- 83〜86 行: `制御方式 4〜11（注入テキストの組み立て）は boundary.sh の出力の形が確定してから書く` とコメントし、出力があっても `注入の整形は 3/3 で実装` として何も出さない

仕様（`10_spec/hooks/00-SessionStart/session-start.md`）は 6 行の注入形式と `position` ごとの文言、WF702 / WF703 まで定めており、テスト SE-T08・SE-T09 も「3/3 へ」と明記されている。**`boundary.sh` を作るこの issue が実装の場**である。

ただし issue #10 の受け入れ条件は「`finalize.sh` / `boundary.sh` が仕様どおり動き、FN-T01〜05 と boundary のテスト ID が通る」までで、`session-start` の注入整形には触れていない。**スコープに入れるかの合意が要る**（入れないなら別 issue）。

### b6. `finalize.sh release` の段階順が issue 追記 3 の要求と矛盾する ✕問題

現行仕様の順序:

```
処理フロー 4  統括レポート（md + HTML）
処理フロー 5  MR 本文の最終化（## 統括 に要約を書き写す）
処理フロー 6  HTML 添付 → リンク一覧を ## 統括 に追記
処理フロー 7  push
処理フロー 8  レビュー（--final）
処理フロー 9  finalize.sh release
                段階 3 で pre_cleanup_sha を記録 → 片付け
```

issue #10 の追記 3 は「リンク一覧を本文に書くなら、**片付け前の SHA が確定してから本文を更新する**順序が要る」と指摘する。現行順序では手順 6 の時点で `pre_cleanup_sha` が存在しない（release の段階 3 で初めて決まる）ため、**本文に書けるのは添付 URL だけで、コミット固定の作業領域リンクは書けない**。

一方で release の段階 6（出力）は「`pre_cleanup_sha` から組み立てた作業領域リンク」を出力すると書いており、処理フロー 10（報告）も同じものを報告する。つまり**リンクは AI の報告には出るが MR 本文には残らない**。片付け後に本文へ書き足す手順は仕様に無い。

| 案 | 内容 | 影響 |
|---|---|---|
| (a) release に段階を足す | 段階 3 の直前に「HEAD の SHA を確定 → 本文のリンク一覧を書き換え」を入れる | release が MR 本文を書くようになる（`remote-write:mr-edit` が release の権限に加わる） |
| (b) 手順 5〜6 を release の直前に移す | 本文最終化を手順 8 の後に置き、`git rev-parse HEAD` で SHA を取る | release は現状のまま。ただし「push 済み」の前提検査との順序が入り組む |
| (c) 片付け後に本文へ追記する手順を足す | release の後に手順 11 を置く | draft 解除後に本文を触ることになり、完了の定義がぼやける |

**決定は 0007**。受け入れ条件 B3 が「手順 5〜9 の順序が成立していること」を求めているので、この issue で必ず解消する。

### b7. 手順 6 の HTML 添付は実測で成立しない（issue 追記 2 の既知の指摘） △注意

現行仕様は GitHub について非公式エンドポイント `POST https://uploads.github.com/user-attachments/assets` への `curl` を前提にし、「`.html` は添付として許可されたファイル種別」と書いている。issue #10 の追記 2 は、同じトークン・同じ経路で `image/png` は 201 になるのに `text/html` / `text/markdown` / `text/plain` / `application/zip` / `application/pdf` はすべて 422 になる実測を載せ、**ブラウザの経路（`/upload/policies/repository-files` → S3 → `PUT /upload/repository-files/<id>`）は PAT で再現できない**ことまで確かめている。

受け入れ条件 B2 は「HTML の添付は人間がブラウザで本文に行い、AI は返った URL を記録する」に改めることと、実測の根拠を DDR に残すことを求める。**現仕様の `curl` の記述は丸ごと差し替えになる**。あわせて手順 6 の投稿先も「通常コメント 1 件」から「本文の `## 統括` 配下の表」へ（受け入れ条件 B1）。

### b8. 全体まとめチケットの完了検査の出力先が仕様に無い △注意

`ticket.sh:254` は `overall-summary` の `complete` を **TK005 で必ず拒否する**（「全体まとめは complete しない。片付けの提供コマンド（`finalize.sh release`）が完了を内包する」）。release の段階 2 は「全体まとめチケットの完了検査（DoD・作業ログ・根拠欄）を行い、未充足は FN002 で拒否する」と書くが、**検査した結果をどこに残すかの記述が無い**。片付け（段階 3）でチケットごと削除されるため、記録を残さないと DoD の充足の証跡が消える。

受け入れ条件 B4 は「DoD × 根拠を統括レポートに写す」手順を仕様に書くことを求める。**段階 2 の出力先として書き足すのが素直**（統括レポートは段階 3 の片付けで消えるが、直前の push で履歴に載っており `pre_cleanup_sha` から辿れる）。

### b9. `gh` CLI 不在時のフォールバックは 2 本とも仕様に揃っている ◎良

- `boundary.sh`: `request --external --comment-url <url>`（投稿は呼び出し元が代行）、`complete --external --report-file <json>`（同じスキーマの JSON を読む）、`--standalone`（MR が無い単独実行）。`via` に `cli` / `external` / `chat` を記録する
- `finalize.sh`: 仕様の Script 処理には `--external` の記述が無い。`00-workflow-issue-mr-driven` 仕様のエラーハンドリング表が `merge-prep.sh`（旧名）について `--external` を書いていたが、新仕様の `finalize.sh` には対応する記述が見当たらない

後者は**欠落の可能性**があるが、`gh` 不在時の draft 解除をどう扱うかは受け入れ条件に無いため、残課題に置く。

### b10. 「1 タスク 1 レポート」の規定と実際の運用が食い違っている △注意

`10-task-investigation-exec` 仕様の共通手順 4 は「**最初のチケット**で `wip/30_reports/<最初のチケット連番>-<種類>.md` を作り、**以降のチケットは同じレポートに節を追記**する」と定める。しかし #9（PR #12）の実績は 1 チケット 1 レポート（`0005` / `0006` / `0007` がそれぞれ md + HTML を持つ）で、この issue の調査計画 0002 も同じ形で 4 枚のチケットに別々のレポートを割り当てている。

どちらが良いかは決めない。**レポートが大きくなりすぎる（1 タスクで 4 観点・数百行）** ことと、**レビューの単位が 1 レポートになる** ことのトレードオフ。この報告は食い違いの存在を挙げるところまでで、扱いは 0007 とフィードバック計画へ。

## 検証の結果

読み取りのみ。根拠に使った主なコマンド:

```
grep -rn "logs/mr.json\|logs/review-state\|logs/review-history\|logs/merge-state" .claude/hooks/ --include=*.sh
grep -rn "boundary.sh\|finalize.sh" .claude/hooks/ --include=*.sh
grep -rn "hooks/boundary\|hooks/finalize\|skills/00-workflow-issue-mr-driven/scripts\|skills/10-task-overall-summary/scripts" .claude/docs/
sed -n '368,415p' .claude/hooks/lib/scope.sh          # scope_classify（提供コマンド・hook-test の判定）
sed -n '310,320p' .claude/hooks/lib/cmdpos.sh          # 提供コマンドと認める 2 つのパス形
sed -n '155,205p' .claude/hooks/10-UserPromptSubmit/workflow-entry.sh
grep -n "TK005\|overall-summary" .claude/skills/20-common-step-ticket/scripts/ticket.sh
```

## 設計への反映

| # | 設計で決めること | 効く受け入れ条件・保留 |
|---|---|---|
| 1 | `finalize.sh release` の段階順（b6 の案 a / b / c）。本文のリンク一覧をいつ書くか | B3 |
| 2 | 提供コマンド 2 本の置き場（b4 の案 a / b）。決めた側に合わせて仕様 4 行か実装 3 行を直す | A2、保留 P1 |
| 3 | 手順 6 の書き換え（投稿先を本文の表に、添付は人間の操作に、`curl` の記述を削除）と DDR への実測の記録 | B1・B2 |
| 4 | release 段階 2 の出力先（DoD × 根拠を統括レポートに写す） | B4 |
| 5 | `session-start` の注入整形（制御方式 4〜11）をこの issue に含めるか | 受け入れ条件に無い。スコープの合意 |
| 6 | `finalize.sh` に `--external`（`gh` 不在時）が要るか | 残課題 R2 |
| 7 | 「1 タスク 1 レポート」の規定を実運用に合わせるか、運用を規定に合わせるか | 残課題 R3、フィードバック計画 |

## 想定と異なった点

| 計画時の見込み | 実際 | どう扱ったか |
|---|---|---|
| 置き場の食い違いは機構を壊す | `cmdpos.sh` が両方のパス形を提供コマンドと認めるため、分類は壊れない。実害はハードコード 1 行と案内文 2 行だけ | 「✕問題」に留めつつ、影響範囲を正確に書いた |
| `logs/` のスキーマに不整合があるはず | 4 ファイルとも書く側と読む側でキーが一致していた | 「◎良」として、そのまま結線できることを記録した |
| 食い違いは置き場だけ | 段階順の内部矛盾（b6）という、より重いものが出た | 設計への反映の 1 番目に置いた |

## 残課題

| # | 残課題 | 引き取り先 |
|---|---|---|
| R1 | `logs/review-history.jsonl` の 1 行のスキーマが仕様に無い（「直前の内容を追記」とだけ）。振り返りの材料として使うなら形が要る | 設計（0007） |
| R2 | `finalize.sh` に `gh` 不在時のフォールバック（`--external`）が要るか。仕様に記述が無い | 設計（0007） |
| R3 | 「1 タスク 1 レポート」の規定と 1 チケット 1 レポートの運用の食い違い（b10） | 設計またはフィードバック計画 |
| R4 | `session-start` の注入整形をこの issue に含めるかの合意（b5） | 設計計画 0007 でユーザーに確認 |
