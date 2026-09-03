---
type: ddr
title: HTML の添付は人間がブラウザで行い AI は URL を記録する
description: GitHub の添付 API が .html を受け付けないことと、ブラウザ側の経路が API トークンで再現できないことを実測で確かめたうえで、全体まとめの HTML 添付を人間の作業とし、成果物の所在は MR 本文のリンク一覧で保証する決定
tags: [ddr, 添付, uploads, MR 本文, 全体まとめ]
keywords: [HTML 添付, uploads.github.com, content_type, user-attachments, CSRF, リンク一覧, pre_cleanup_sha, 統括]
---

# HTML の添付は人間がブラウザで行い AI は URL を記録する

## 背景

`10-task-overall-summary` 仕様の処理フロー 6 は、作業領域の HTML レポートを非公式エンドポイント `POST https://uploads.github.com/user-attachments/assets` へ `curl` でアップロードし、リンクを列挙した通常コメントを 1 件投稿する形になっていた。根拠は 2025-08 の GitHub changelog（添付として許可されるファイル種別の拡大）で、`.html` が通る前提だった。

issue #6（PR #7）の全体まとめを手作業で代替したときに、この手順がそのままでは実現できないことが分かった。issue #10 の追記（2026-09-02）に実測が記録されている。

## 実測（issue #10 追記 2）

同じトークン（scopes: `repo`, `workflow`, `gist`, `read:org`）・同じエンドポイントで、`content_type` だけを変えた:

| 送り方 | name / content_type | 結果 |
|---|---|---|
| multipart/form-data | — | 400 `Invalid name for request`（この API は multipart を受け付けない） |
| 生バイナリ + ヘッダ `Content-Type` | `.html` / `text/html` | 422 `content_type is not included in the list of allowed content types` |
| 同上 | `.md` / `text/markdown` | 422 同じ |
| 同上 | `.txt` / `text/plain` | 422 同じ |
| 同上 | `.zip` / `application/zip` | 422 同じ |
| 同上 | `.pdf` / `application/pdf` | 422 同じ |
| 同上 | `.png` / `image/png` | **201 Created** |

`image/png` が通るので、リクエストの組み立て自体は正しい。エラーの 2 行目（`.html != text/html`）は拡張子の不一致ではなく、`content_type` が許可リストに無いことに伴って出る文言である（`.md` / `text/markdown` のように正しい組でも同じ）。zip でまとめる回避策も同じ理由で塞がっている。

ブラウザからは本文に `.html` を添付でき、ダウンロードした内容が元ファイルと `cmp` で一致することも確認した。ただしブラウザは別経路（`POST /upload/policies/repository-files` でセッション Cookie + CSRF トークンを送り、S3 の署名を受け取って本体を送り、`PUT /upload/repository-files/<id>` で確定する 3 段階）を使う。この経路を API トークンで再現できるかも実測した: `GET github.com/settings/profile` は 302 → `/login`（web ルートは PAT を認証に使わない）、`POST /upload/policies/repository-files` は 422 + 汎用エラーページ（CSRF 不一致時の応答）、`PUT /upload/repository-files/<id>` は `GET` で 404。**1 段目が通らずアセット id が採番されないので、3 段目だけを叩いても意味がない**。

## 決定

- **GitHub への HTML 添付は AI が行わない**。`uploads.github.com` への `curl` も、web ルートの再現も、仕様から削除し禁止事項に移す
- 添付は**人間が MR 本文に対してブラウザで行う**。AI は返った URL（`user-attachments/files/<id>/<name>`）を本文に記録するだけにする
- **添付は任意**の位置づけに下げる。成果物の所在は**本文の `## 統括` 配下に置く成果物のリンク一覧の表**が保証する。リンクは片付け直前の SHA に固定した blob URL を使う
- リンクを列挙した**通常コメントの投稿は行わない**（issue #10 追記 1）。コメントは流れて見つけにくく、本文だけで辿れることを保証できない
- GitLab は `glab api "projects/:id/uploads"` が公式に使えるので、AI が添付して返された markdown リンクを本文に書いてよい（ホストによって扱いが違うことを仕様に明記する）

## 理由

- **実測で塞がっている**。API は種別で拒否し、web 経路は認証方式が違う。再試行やパラメータの調整で通る類の失敗ではない
- **リンク一覧があれば添付は要らない**。片付けは `wip/` を削除するが履歴からは消えないので、片付け直前の SHA に固定した blob URL で成果物は永続的に辿れる。添付は「ブラウザで開ける」利便だけの上乗せになる
- **代替フローが 1 本減る**。従来は「添付できない環境」を分岐として持っていたが、リンク一覧を必須にすれば分岐そのものが不要になる
- **AI に無理な操作をさせない**。通らないと分かっている API を手順に残すと、実行 → 失敗 → 縮退の判断という無駄な往復が毎回発生する

## 却下した案

- **PNG に変換して添付する**: `image/png` は通るので技術的には可能だが、HTML レポートは表とリンクを持つので画像化すると情報が落ちる。リンクが辿れなくなる
- **`.claude/docs/` に HTML を移して残す**: 片付けの対象から外れるが、正史に作業記録が混ざる。`.claude/docs/` は現在の正史だけを置く場所という原則に反する
- **GitHub Pages やリリースアセットに載せる**: リポジトリの設定変更を伴う。この機構は clone してそのまま使える形を保つ
- **添付を必須にして人間の手作業を手順に組み込む**: 全体まとめが人間の作業待ちで止まる。draft 解除の直前に人間の確認が入る以上、そこで任意に行えれば足りる

## 影響

- `10_spec/skills/10-task-overall-summary.md`: 処理フロー 6 を「成果物のリンク一覧と HTML 添付」に書き換え、`uploads.github.com` への `curl` の記述を削除。禁止事項に「リンクを列挙した通常コメントの投稿」と「AI による GitHub への添付」を追加。OUT ひな形の `attachment-comment.template.md` を `summary-section.template.md` に置き換え
- `00_requirement/skills/10-task-overall-summary.md`: 添付の受け入れ基準を「人間が行い AI は URL を記録」に、代替フロー「添付できない環境」を「添付が無くても補わない」に書き換え
- リンク一覧の書き込みは `finalize.sh release` の段階 4 が行う（`pre_cleanup_sha` が確定するのがそこであるため。段階の並びの正は `10_spec/skills/10-task-overall-summary.md` の Script 処理）
- テスト観点 FN-T06 が「リンク一覧が `pre_cleanup_sha` に固定され、片付けコミットの後も辿れる」を固定する
