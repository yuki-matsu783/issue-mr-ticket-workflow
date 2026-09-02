---
type: report
title: "0038 AI アセット実装結果 — 0029 の敵対的レビュー指摘 6 件の反映"
description: 案内側フック 6 本に対する敵対的セルフレビューで確度 0.5 以上と判断した 6 件（承認単位にリポジトリ外のパスが入る／解決できない基準点を案内文に出す／作業中 2 枚のときの扱いの食い違い／since_sha が勝手に進む／一覧の上限の不整合／縮退判定の行数依存）を直した結果
tags: [report, ai-asset-implementation, issue-9, hooks, 敵対的レビュー]
keywords: [approvals.json, base_sha, since_sha, 縮退判定, WF601, WF801, WF813, プローブ, adv0029]
---

# 0038 AI アセット実装結果 — 0029 の敵対的レビュー指摘 6 件の反映

- 対象 issue: #9 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/9
- PR: #12 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/pull/12

## サマリ

0029（案内側フック 6 本）の敵対的セルフレビューで、**確度 0.5 以上の指摘 6 件**を直した。

レビューは読むだけで終わらせず、**仕様の穴を突く入力を 8 本流すプローブ**（`wip/tmp/adv0029.sh`）を書いて実際の出力を観察した。その結果、読みだけでは出なかった 2 件が実測で出た。

| # | 指摘 | 直し方 |
|---|---|---|
| 1 | `workflow-diff-check` が**リポジトリ外の絶対パスを承認単位として記録する**（実測で `C:/Users/.../Temp/outside` が入った） | ルート相対でないパスを承認単位の候補から外す |
| 2 | **解決できない基準点をそのまま案内文に出す**（実測で「基準点は PLACEHOLDER」「`git checkout PLACEHOLDER -- <path>`」が出た） | 差分の取得に失敗したのと同じ（制御方式 7）として黙って抜ける |
| 3 | 作業中チケットが 2 枚以上のときの扱いが `workflow-diff-check`（黙る）と `subagent-stop-check`（先頭 1 枚で範囲判定）で**食い違う** | `workflow-diff-check` 側に揃える。WF811 / WF812 は枚数に依らず出す |
| 4 | `post-push-usage-report` が初回 push で `since_sha` を HEAD へ進め、**集計値と集計期間の表示が食い違う** | 起点は書かない（進めるのは `boundary.sh` の責務） |
| 5 | 一覧の上限が WF601 は 30、WF812 / WF813 は 20 で**不整合** | 仕様に明記されている 20 に揃える |
| 6 | 縮退判定が `decisions.jsonl` の**末尾 400 行に依存**し、記録が育つと誤って縮退と判定する | セッション内の印を一次経路にし、全走査を二次経路として残す |

テストは 5 か所に追加（DC-T02 / DC-T03 / DC-T06 / SP-T04 / SP-T08 / SA-T08）。全件テストは 2 ロケールで **21 本 / 112 件・FAIL 0**。

## レビューしてほしい観点

**◆特に見てほしい（判断に困っている）**

- **r1（△注意）基準点が解決できないときに黙って抜けること**。「作業ツリーの差分だけで判定する」という中間の選択肢を捨てた。捨てた理由は復旧の道（`git checkout <base> -- <path>`）を示せず指示として成立しないから。**範囲外の差分を見逃す側に倒した**判断なので、拒否側（`workflow-guard`、0030）が同じ場面をどう扱うかと合わせて見てほしい
- **r2（△注意）作業中 2 枚以上で WF813 を出さないこと**。「1 枚目の許可範囲で判定して出す」より安全側に見えるが、**2 枚放置されている状況こそ範囲外の差分が残りやすい**とも言える。WF811 / WF812 は出し続けるので気づけるはず、という前提を置いている

**◇承認が欲しい（方針は決めた）**

- **r3**: 縮退判定の一次経路をセッション内の印（`logs/sessions/<id>/subagent-start-check.json`）にしたこと。`decisions.jsonl` の全走査は二次経路として残した
- **r4**: 一覧の上限を 20 に揃えたこと（仕様に明記されている側を正とする）
- **r5**: `since_sha` / `since_at` をフックが一切書かないようにしたこと（初回は「（記録なし）」と出る）

**・細かいレビューは不要（ほぼ確実）**

- リポジトリ外の絶対パス・`..` を含むパスを承認単位にしないこと
- プローブ `wip/tmp/adv0029.sh` は `wip/tmp/`（gitignore 対象）に置いたままで、コミットしていない

## 確かめられなかったこと（この結果が言っていないこと）

- **本番のフックとして動かしていない**。0029 と同じく `settings.json` に未登録（登録は 0031 の人間の操作）
- **プローブは 8 本しかない**。「仕様の穴を突く入力」の網羅ではなく、思いついた形を並べただけ
- **拒否側 4 本（0030）との整合を確かめていない**。とくに r1・r2 は拒否側が同じ場面をどう扱うかで評価が変わる
- **縮退判定の二次経路（`decisions.jsonl` の全走査）の実行時間を測っていない**。記録が数万行に育ったときの所要は未確認
- **`shellcheck` は 7 巡連続で未導入**

## 実施条件（読んだ対象）

| 対象 | 内容 |
|---|---|
| チケット | `wip/10_tickets/20_done/0038-ai-asset-implementation.md`（DoD 7 件） |
| 発端 | 0029 の敵対的セルフレビュー（結果報告 `0029-ai-asset-implementation.md` の r1〜r7 とプローブの実測） |
| 実体 | `workflow-diff-check.sh` / `post-push-usage-report.sh` / `subagent-start-check.sh` / `subagent-stop-check.sh` と各テスト |
| 環境 | Windows 10 Pro / Git Bash・`jq` あり・`shellcheck` **無し** |

## 実施した内容と結果

### 1. リポジトリ外のパスを承認単位にしない ✕問題

`hook_rel_path` はリポジトリの外のパスを**絶対パスのまま返す**。`workflow-diff-check` はその戻り値をそのまま承認単位にしていたので、リポジトリ外への Write が `approvals.json` に残っていた。

```
（直す前）Write /tmp/outside/evil.md
[approvals] [{"scope":"C:/Users/taniyama/AppData/Local/Temp/outside", ...}]
（直した後）
[approvals] なし
```

`scope_resolve` の判定はルート相対のパスにしか当たらないので、外のパスを覚えても許可には使われない。記録が汚れ、`SC_APPROVED` を読む他のフックのノイズになるだけだった。

### 2. 解決できない基準点をそのまま案内文に出していた ✕問題

`git rev-parse --verify` に失敗したとき、直す前は警告を出して**作業ツリーの差分だけで判定を続けて**いた。その結果 WF601 の本文が嘘になる。

```
（直す前）
WF601: … 基準点は PLACEHOLDER。
- docs/g1.md（未追跡 / WF201）
復旧: 追跡済みの変更は git checkout PLACEHOLDER -- <path>、…
（直した後）無出力・終了 0（実行ログに WARN 1 行）
```

仕様の制御方式 7「差分の取得に失敗 → 黙って抜ける」に寄せた。中間の選択肢（status だけで判定して出す）は、復旧の道を示せないので指示として成立しない。

### 3. 作業中 2 枚以上の扱いの食い違い △注意

`workflow-diff-check` は仕様どおり「2 枚以上は判定不能として黙って抜ける」。`subagent-stop-check` は**先頭 1 枚の許可範囲で他方の差分まで範囲外と呼んで**いた。同じ `scope.sh` を共有しているのに結論が食い違う。

`workflow-diff-check` 側に揃え、WF813（範囲外）は 1 枚のときだけ出す。WF811（残ったチケット）と WF812（未コミット）は枚数と無関係に事実なので出し続ける。

### 4. `since_sha` が勝手に進んでいた ✕問題

直す前は初回 push で `since_sha` を HEAD にしていた。集計値はリセットしていない（投稿が完了していないため）ので、**2 回目のレポートは「集計期間は push 1 の HEAD から」と表示しながら、数値には push 1 より前の分が入る**。

起点を書くのは `boundary.sh` の責務（仕様の既定 5）なので、フックは書かないようにした。初回は「（記録なし）」と出るが、これは「まだ 1 度も投稿していない」という事実そのもの。

### 5. 一覧の上限の不整合 △注意

WF601 は 30、WF812 / WF813 は 20 だった。仕様は `subagent-stop-check` 側にだけ「20 を超えれば先頭 20 件 + 件数」と明記している。明記されている側を正として 20 に揃えた。

### 6. 縮退判定が `decisions.jsonl` の末尾 400 行に依存していた ✕問題

`subagent-stop-check` は「`subagent-start-check` の記録が 1 件も無ければ縮退」と判定する。直す前は `tail -n 400` で見ていたので、**記録が育つと誤って縮退と判定し、WF801 を二重に出す**（`decisions.jsonl` はツール呼び出しのたびに増える）。

`subagent-start-check` が PreToolUse `Agent` の判定のたびに `logs/sessions/<id>/subagent-start-check.json` を置き、`subagent-stop-check` はまずその印を見る。印が無い古いセッション向けに `decisions.jsonl` の**全走査**（打ち切りなし）を二次経路として残した。

## 検証の結果

| 対象 | 件数 | 結果 |
|---|---|---|
| `test_workflow_diff_check.sh`（DC-T02 / T03 / T06 に追加） | 48 | FAIL 0 |
| `test_post_push_usage_report.sh`（UR-T04 に追加） | 38 | FAIL 0 |
| `test_subagent_start_check.sh`（SA-T08 に追加） | 58 | FAIL 0 |
| `test_subagent_stop_check.sh`（SP-T04 / SP-T08 に追加） | 57 | FAIL 0 |
| `test_post_push_compact_prompt.sh`（変更なし） | 37 | FAIL 0 |
| `test_session_start.sh`（変更なし） | 14 | FAIL 0 |
| プローブ `wip/tmp/adv0029.sh`（8 本） | — | 直す前の再現と直した後の解消を実測 |
| 全件テスト（既定ロケール / `LC_ALL=C.UTF-8`） | 21 本 / 112 件 | FAIL 0（両ロケール） |

## 設計への反映（後続へ）

0032（設計反映）へ送る:

1. `workflow-diff-check.md` に「基準点が解決できなければ黙って抜ける」を明記する
2. `workflow-diff-check.md` に WF601 のパス列挙の上限（20）を書く
3. `subagent-stop-check.md` に「作業中が 2 枚以上なら WF813 を出さない（WF811 / WF812 は出す）」を書く
4. `subagent-stop-check.md` の縮退判定を「セッション内の印を見る」に直す
5. `subagent-start-check.md` に「PreToolUse `Agent` の判定のたびにセッション内へ印を置く」を書く
6. `post-push-usage-report.md` に「`since_sha` / `since_at` はフックが書かない」を明記する

## 想定と異なった点

| 計画時の見込み | 実際 | どう扱ったか |
|---|---|---|
| レビューは読めば足りる | 読みだけでは 2 件（外部パスの記録・解決できない基準点）が出なかった。実際に入力を流して初めて見えた | プローブを書く形を次のチケットでも使う |
| 6 件とも設計の判断が要る | 4 件は「仕様のどこかに書いてある側へ寄せる」だけで済んだ | 判断の根拠を作業ログに残し、仕様側の追記を 0032 へ送った |
| `bash -n` が通れば置換は成功 | `if true; then` の骨が残っても構文は通る | 置換のあとに該当箇所を読み直す手順を足した |

## 残課題

- **0030（拒否側 4 本）**: `workflow-guard` / `workflow-state-guard` / `workflow-entry-guard` / `block-gh-ready`。r1・r2 は拒否側の扱いと合わせて再評価する
- **0031（人間の操作）**: 段階登録 ①② と T1〜T4 / T9 の実測
- **0032（設計反映）**: 上記 6 件 + 0029 からの累積
- **縮退判定の二次経路の実行時間が未測定**（`decisions.jsonl` が数万行に育ったとき）
- **WF601 の種別ラベルは削除も「変更」と出す**。区別する価値は 0032 で判断する
- **WF812 が移動元（消えた側）を出さない**。仕様どおりだが親切ではない
- `shellcheck` 未導入（7 巡連続）／`check-html.sh` が md と HTML の内容一致を検査しない（18 回連続）
