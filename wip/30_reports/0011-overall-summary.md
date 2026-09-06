---
type: report
title: 0011 全体まとめ結果 — hook機構（Claude Code Ticket Guard）設計文書の取り込み
description: issue #52 の統括。Confluence の設計文書全文を .claude/docs/00_requirement/hook機構.md へ生写しで取り込み、受け入れ条件 4 件を満たし、改善候補 20 件を 9 つの別 issue（#54〜#62）へ渡した記録。draft 解除は finalize.sh の不具合（#71）で未達。
tags: [report, overall-summary, issue-52]
keywords: [全体まとめ, hook機構, Ticket Guard, 生写し, 転記注記, 受け入れ条件, 別issue, draft解除, 敵対的レビュー, finalize.sh, FN001]
---

# 0011 全体まとめ結果 — hook機構（Claude Code Ticket Guard）設計文書の取り込み

- 対象 issue: [#52](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/52)
- MR: [#53](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/pull/53)（draft のまま。解除は未達）
- ブランチ: `claude/hook-mechanism-hx89wi`
- チケット: 0001〜0011
- 作成日: 2026-09-05

## サマリ

Confluence の設計文書「Claude Code Ticket Guard」の全文を `.claude/docs/00_requirement/hook機構.md` へ生写しで取り込んだ。文書は 680 行から 2383 行になり、章番号は §0 概要から §23 と付録 A〜D・補遺まで連続し、未解決の前方参照は 0 件になった。読み取れなかった箇所と原文の中の食い違いは転記注記 16 件で明示している。

受け入れ条件は 4 件すべて満たした（A4 は読み替えたうえで）。フェーズは 6 つ全部を通し、チケットは 11 枚を完了、取り消しは 0 枚。敵対的レビューを 1 回実施して 7 件の指摘を全件反映した。改善候補 20 件は 9 つの別 issue（#54〜#62）へ渡した。

ただし **draft は解除できていない**。`finalize.sh release` の段階 1（前提検査）が `--external` を渡しても MR 本文の取得を要求し、`gh` が無いこの環境では必ず失敗する。機構自身の不具合なので迂回せず、別 issue [#71](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/71) に渡した。#71 が直るまで issue #52 の draft は解除できない。

- ◎良 6 件（e1〜e6）/ △注意 1 件（e7）/ ✕問題 1 件（e8）（節は e1〜e8 の 8 件）

### ◆特に見てほしい（判断に困っている）

- **転記注記 16 件の扱い**。原文の中で食い違っている箇所（リスクスコア 40 の境界・§21 の丸数字の体系・§14.3 と付録 B.3 のキャッシュ可否）を、本文を直さず注記で示している。生写しを保つ判断だが、この文書を実装に落とすときはどちらを採るか決め直す必要がある。原本の作者に確認できるなら注記ではなく原本を直すのが本筋である

### ◇判断が欲しい（決めた方針の承認 / 決められない点の判断）

- **受け入れ条件 A4 の読み替え**。当初の A4 は「未提供の節（§13〜§23）と、それらへの参照が残ることの明記」を求めていた。取り込み範囲が全文に広がって未提供の節が無くなったため、「前方参照の全件確認で未解決 0 件」をもって答えている
- **既存部（§6〜§12.2）に手を入れなかった**。原文と突き合わせると §6 の見出し・§6.1 の Layer 0-A の行・§11.3 の判定結果の表が食い違う。取り込み範囲の外なので転記注記だけを付け、修正は別 issue #61 に渡した
- **改善候補の対応先**。ユーザーの指示（レビューなしで進める）により、スキルの既定の提案どおりに決めた。20 件のうち 17 件を別 issue、2 件を対応しない、1 件をこの MR で対応とした

### ・細かいレビューは不要（ほぼ確実）

- MR タイトルを実際の取り込み範囲（§0 概要〜補遺の全文）に合わせて直した
- 敵対的レビューの指摘 7 件は、原文の写真と突き合わせた結果いずれも転記誤りではなく、原文由来の欠落・食い違いだった

## 確かめられなかったこと

| 対象 | 確かめられなかった理由 | 引き取り先 |
|---|---|---|
| §20.1 の YAML の下端から先 | 原文の写真が画面下端で `".current-ticket.md": deny` の行までしか写っていない | 転記注記で明示。原本の追加提供があれば補える |
| §17.5 の承認台帳の JSONL の行末 | 原文でも横スクロールの途中で `"approved_` の後が切れている | 転記注記で明示 |
| §14.8 のコード例・§14.10 の JSON の 2 件目以降・付録 C.1 の JSON・付録 C.2 の YAML・付録 D.2 の `--explain` 出力 | いずれも原文の写真が途中で切れている | 転記注記で明示 |
| §11.3 の判定結果の表 | 原文の該当ページが提供されていない。既存部なので取り込み範囲の外でもある | 別 issue [#61](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/61) |
| squash merge の可否と既定 | `gh` が無く `gh repo view` が使えず、MCP 側にも該当ツールが無い | ユーザーに確認した（2026-09-05）。squash が既定で問題ないとの回答を得た |

## 実施した内容と結果

### e1. 受け入れ条件 4 件をすべて満たした（A4 は読み替えたうえで） ◎良

| # | 受け入れ条件 | 満たした内容 | 根拠 |
|---|---|---|---|
| A1 | `hook機構.md` が §0 概要表から始まり、§1〜§5 が §6 の前に入っている | §0 概要（表）から始まり、§1 サマリ・§2 解決する課題・§3 脅威モデル・§4 設計原則・§5 アーキテクチャが §6 の前に入った | チケット 0005。文書の 1 行目が `## 0. 概要`、§6 は 249 行目 |
| A2 | 提供された表・コードブロック・図が行の欠落なく Markdown として再現されている | 原文の表はヘッダと各行のセル数が一致し、コードフェンスは 118 個（偶数）で開閉が対になっている。罫線図と画面例は mermaid に変換せずコードフェンスで再現した | チケット 0005・0006・0008。敵対的レビューの「問題なしと確認された点」でも全表のセル数一致とフェンスの対を確認 |
| A3 | 章番号が連続し、重複や飛びが無い | `grep '^## '` の結果が §0 → §1 → … → §23 → 付録 A → 付録 B → 付録 C → 付録 D → 補遺。欠番・重複なし。§18・§19 の欠番はチケット 0008 で解消した | チケット 0006・0008 |
| A4 | 未提供の節と、本文からそれらへの参照が残ることが文書内に明記されている（読み替え済み） | 取り込み範囲が全文に広がって未提供の節が無くなったため、「本文の §N 参照 34 種を全件抜き出し、対応する見出しが実在することを確認。未解決 0 件」で答えた。原文が切れている箇所は転記注記 16 件で明示している | チケット 0008。読み替えの経緯はチケット 0006 の作業ログ「判断と根拠」 |

### e2. 6 フェーズを通し、チケット 11 枚を完了して取り消しは 0 枚 ◎良

| フェーズ | チケット | 結果 |
|---|---|---|
| 全体計画 | 0001 | issue #52 を起票、draft MR #53 とブランチを用意、フェーズ列と方針を合意 |
| 調査（計画 → 実施） | 0002・0003 | 既存文書が §6 から始まり §12.2 で終わること、前方参照 15 件の所在を確定 |
| AI アセット設計（計画 → 実施） | 0004・0005・0006・0008・0009 | 全文の取り込み。文書は 680 → 2383 行 |
| AI アセット実装・テスト（計画 → 実施） | 0007 | 対象なし。実装チケットは 0 枚 |
| フィードバック計画 | 0010 | 改善候補 20 件を洗い出し、9 つの別 issue 案に束ねた |
| 全体まとめ | 0011 | このレポート |

### e3. 各タスクの人間レビューの結果 ◎良

| タスク | チケット | 人間レビュー | 結果 |
|---|---|---|---|
| 全体計画 | 0001 | 要（実施） | 「レビューオッケー」。指摘 0 件 |
| 調査計画 | 0002 | 省略 | 全体計画の承認③で合意済み（読むだけの小さな調査） |
| 調査実施 | 0003 | 省略 | 同上 |
| AI アセット設計計画 | 0004 | 省略 | 計画書は設計結果と一緒に見れば足りる |
| AI アセット設計実施 | 0005・0006・0008・0009 | 要（実施） | 「レビューなしで draft 解消まで進めて」。指摘 0 件。レビュー依頼で挙げた 3 点は承認されたものとして扱った |
| AI アセット実装・テスト計画 | 0007 | 省略 | ユーザーの指示（2026-09-05）により、残りのフェーズはレビューを省略 |
| フィードバック計画 | 0010 | 省略 | 同上 |
| 全体まとめ | 0011 | 省略 | 同上 |

MR #53 のレビュースレッドとレビューはいずれも 0 件だった（GitHub MCP の `pull_request_read` で確認）。通常コメントは機構と AI が投稿した記録用のものだけである。

### e4. 敵対的レビューを 1 回実施し、指摘 7 件を全件反映した ◎良

モデルは `claude-fable-5-1`（`work-defaults.md` の既定どおり。実行者はメインエージェントなので差し替え不要）。対象は AI アセット設計の差分。実施回数はタスクごとの上限 1 回を消化した。

指摘 7 件はすべて `confidence >= 0.5` で全件採用し、追加チケット 0009 で反映した。原文の写真 6 枚と突き合わせた結果、**転記誤りは 0 件**で、6 件は原文由来の欠落・食い違いだった（残る 1 件はチケット 0008 で注記ごと削除して解消済み）。生写しを保つため本文は直さず転記注記で明示した。

| 指摘 | 原文と照合した結果 |
|---|---|
| §6.1 の題名欠落と §11.3 の判定結果の表の欠落 | 既存部の欠け。原文には題名も Layer 0-A の行もある |
| §17.4 直後の注記が §16.5 を誤って挙げている | チケット 0008 で注記ごと削除して解消 |
| §3.3 の T-2（→§11.3）と T-5（→§8.7）の参照先 | 原文どおり。実際の規定は §11.1 順 3 と §8.6 にある |
| §21 の検知層の丸数字が 2 体系を混用 | 原文どおり |
| §14.3 に `IMPL_TICKET_UNAPPROVED` が無い | 原文どおり。付録 B.3 との食い違いは原文由来 |
| リスクスコア 40 の境界（以上 / 超）の食い違い | 原文どおり。4 か所で表記が割れている |
| 付録 C.3 の箇条書きがフェンスの外 | 原文どおり。テンプレートではなく解説である |

### e5. フィードバック計画の対応 ◎良

改善候補 20 件の内訳は 別 issue 17 件 / 対応しない 2 件 / この MR 1 件。

| 対応先 | 件数 | 内容 |
|---|---|---|
| 別 issue | 17 件 | 9 つの issue（#54〜#62）に束ねて起票した |
| 対応しない | 2 件 | §8.7 の非対称な構成（生写しを保つ。#62 の型変換と一緒に判断する）/ squash merge の確認（ユーザーに確認済み） |
| この MR | 1 件 | MR タイトルと実範囲のずれ。タイトルを直した |

作業領域は片付けで消えるので、候補 20 件をそのまま転記する。

| # | 候補 | 出どころ | 観点 | 類型 | 対応先 |
|---|---|---|---|---|---|
| 1 | `ticket.sh create` の `--allow-ops` が `scope-limits.json` の正規名を検査せず、日本語ラベルを受け付ける | 0001 | 足りなかった | (c) あったが罠が書かれていなかった | [#55](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/55) |
| 2 | `ticket.sh create` の引数が長いと WF209 で拒否される。DoD をファイルから読ませる手段が無い | 0004 | 邪魔だった | (c) あったが罠が書かれていなかった | [#55](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/55) |
| 3 | 提供コマンドはリポジトリルートからの相対パスで呼ぶ必要がある（絶対パスは WF204） | 0003・0007 | 足りなかった | (c) あったが罠が書かれていなかった | [#54](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/54) |
| 4 | 長文の生成は Bash のヒアドキュメントではなく Write ツールを使う必要がある（WF209） | 0008 | 足りなかった | (c) あったが罠が書かれていなかった | [#54](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/54) |
| 5 | セッションのスクラッチパッドが作業ツリー外にあり WF209 で使えない。下書きの置き場がどこにも書かれていない | 0005 | 足りなかった | (c) あったが罠が書かれていなかった | [#54](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/54) |
| 6 | `gh` / `glab` が使えない環境で issue の追記コメントを読む手段が無い | 0001・0002 | 無かった | (a) アセットが無かった | [#56](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/56) |
| 7 | WF204 の拒否メッセージに判定の根拠が入っていない。同じ `curl` が 1 回目は通り 2 回目は拒否された | 0002 | 足りなかった | (c) あったが罠が書かれていなかった | [#57](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/57) |
| 8 | 外部資料の取り込みで「読めた範囲」と「推し量った範囲」を分けて確定する手順が無い | 0006・0009 | 無かった | (a) アセットが無かった | [#58](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/58) |
| 9 | 添付画像は転記の精度が要る用途では Read で開き直す必要がある。アップロード領域に残ることも書かれていない | 0005・0009 | 足りなかった | (c) あったが罠が書かれていなかった | [#54](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/54) |
| 10 | `.claude/docs/` に外部原本の生写しを置くときの扱いが `ai-asset-design-docs` ルールに無い | 0001・0008 | 無かった | (a) アセットが無かった | [#59](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/59) |
| 11 | `10-task-ai-asset-design-plan` に「取り込み型」の分岐が無く、1:1:1・テスト ID・DDR が空振りする | 0004 | 無かった | (a) アセットが無かった | [#58](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/58) |
| 12 | `10-task-ai-asset-implementation-plan` の「対象なし」の書き方がテンプレートに無い | 0007 | 足りなかった | (c) あったが罠が書かれていなかった | [#54](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/54) |
| 13 | `boundary.sh` の `last_task` が完了チケットの番号順で決まる。`logs/mr.json` が空だと `note` / `request --external` も通らない | 0010・全体計画 P5 | あったが誤っていた | (b) あったが誤っていた | [#60](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/60) |
| 14 | `hook機構.md` の既存部（§6〜§12.2）が原文と食い違う | 0005・0006・0009 | 問題なし | (b) あったが誤っていた | [#61](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/61) |
| 15 | 生写しの `hook機構.md` を要件定義書の型へ変換するか | 全体計画 P3・0004 | 問題なし | (b) あったが誤っていた | [#62](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/62) |
| 16 | 取り込んだ設計と既存 `.claude/hooks/` の実装との差分が未整理 | 全体計画 P4・0001 | 無かった | (a) アセットが無かった | [#62](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/62) |
| 17 | §8.7「⑥⑦⑧その他」の非対称な構成をどう扱うか | 0003 レポート R2 | 問題なし | (b) あったが誤っていた | 対応しない（#62 の型変換と一緒に判断する） |
| 18 | squash merge の可否と既定が未確認 | 全体計画 P1・0001 | 問題なし | (d) あったのに辿り着けなかった | 対応しない（ユーザーに確認済み。squash が既定） |
| 19 | 全体計画書の表題と MR タイトルが「§1〜§5」のままで実範囲とずれている | 0002・0004・0007 | 問題なし | (b) あったが誤っていた | この MR（タイトルを直した） |
| 20 | `hook機構.md` に frontmatter が無く、`.claude/docs/` の中から参照されていない | 0004・0005 | 問題なし | (b) あったが誤っていた | [#59](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/59) |

### e6. 別 issue 9 件を起票した ◎良

| issue | タイトル | 元の候補 |
|---|---|---|
| [#54](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/54) | 提供コマンドとツールの呼び出し作法を共通ステップに明記する | 3・4・5・9・12 |
| [#55](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/55) | ticket.sh create の入力検査と長い引数の回避 | 1・2 |
| [#56](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/56) | gh / glab が使えない環境での issue コメントの取得手順を用意する | 6 |
| [#57](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/57) | WF204 の拒否メッセージに判定の根拠を含める | 7 |
| [#58](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/58) | 外部資料の取り込み型のタスク手順を用意する | 8・11 |
| [#59](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/59) | .claude/docs/ に外部原本の生写しを置くときの規約を決める | 10・20 |
| [#60](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/60) | boundary.sh の last_task の導出と logs/mr.json が空のときの扱いを直す | 13 |
| [#61](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/61) | hook機構.md の既存部（§6〜§12.2）を原文と全件突き合わせて直す | 14 |
| [#62](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/62) | hook機構.md を要件定義書の型へ変換し、既存 .claude/hooks/ 実装との差分を整理する | 15・16・17 |

起票の可否はユーザーに 1 回で確認し「9 件すべて起票する」との回答を得た。この 9 件は改善候補 20 件の引き取り先であり、後述する [#71](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/71)（全体まとめ自身が止まった原因）はここには含まれない。

### e7. 全体計画書の表題が実範囲とずれたまま終わった △注意

全体計画書の表題は「§1〜§5 を取り込む」のままで、確定した範囲（§0 概要〜補遺の全文）とずれている。計画タスクは全体計画書を書き換えられない決まりがあり、全体まとめの片付けで作業領域ごと消えるため直しても残らない。MR タイトルは実範囲に合わせて直した。

### e8. finalize.sh release が段階 1 で止まり draft を解除できていない ✕問題

チケット 0011 の DoD 5「`finalize.sh release` が完了し draft が解除されている」は**未充足**である。

```
$ bash .claude/skills/10-task-overall-summary/scripts/finalize.sh release \
    --external --pr 53 --body-file wip/tmp/mr-body-linked.md
- MR 本文を取得できない（host=github mr=53。CLI が無い環境は --external を使う）
FN001: release の前提を満たしていない。未充足 1 件（上に列挙）
```

原因はスクリプトの側にある。段階 1 の前提検査が `fetch_body` を無条件に呼び、`fetch_body` は `command -v gh` が失敗すると 1 を返す（`finalize.sh` の 176〜182 行と 241〜245 行）。`--external` の分岐は段階 4（`put_body`）と段階 7（draft 解除）にしかなく、段階 1 には無い。スキル本文の「CLI が使えない環境」の節は段階 4 と段階 7 だけを代行対象として書いており、前提検査が CLI を要求することは書かれていない。実装と文書の契約がずれている。

`gh` を導入して突破する道も塞がっている。バイナリの取得先が作業ツリーの外になり WF209 で拒否される。迂回はしていない。

未達のまま残ったのは、完了検査の書き出し・成果物リンク一覧・作業領域の片付け・draft 解除の 4 つである。ユーザーの判断で、機構を直す別 issue [#71](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/71) に渡した（機構の変更なのでこの issue の範囲外）。

## 検証の結果

| 検証 | 結果 |
|---|---|
| 章番号の連続性 | `grep '^## '` の出力が §0 → §1 → … → §23 → 付録 A〜D → 補遺。欠番・重複なし |
| コードフェンスの対 | ファイル全体で 118 個（偶数）。開閉が対になっている |
| 前方参照の解決 | 本文の §N 参照 34 種を全件抜き出し、対応する見出しの実在を確認。未解決 0 件 |
| 転記注記の件数 | `grep -c '> 転記注記'` が 16 |
| 既存部の無改変（設計実施の各回） | `git diff --numstat` の削除がチケット 0005・0006 で 0 行、0008 で 4 行（差し替えた欠落注記のみ）、0009 で 0 行 |
| 完了チケットと取り消しチケット | 完了 11 枚（0001〜0011）・取り消し 0 枚 |
| MR のレビュー指摘 | GitHub MCP でレビュー 0 件・レビュースレッド 0 件を確認 |
| default との衝突 | `git rev-list --count HEAD..origin/main` が 0 |
| draft 解除 | **未達**。`finalize.sh release --external` が段階 1 の前提検査（FN001）で停止。別 issue [#71](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/71) |

## 設計への反映

| # | 反映すること | 引き取り先 |
|---|---|---|
| 1 | 取り込んだ設計と既存 `.claude/hooks/` 実装との差分整理 | 別 issue [#62](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/62) |
| 2 | 生写しの文書を要件定義書の型へ変換するか | 別 issue [#62](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/62) |
| 3 | `.claude/docs/` に外部原本を置くときの規約（型の適用対象外・転記注記の書式・frontmatter・索引） | 別 issue [#59](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/59) |

`.claude/docs/` に残すべき内容で未反映のものは無い。作業領域に残るのは計画書 4 件・レポート 2 件・チケット 11 枚で、いずれもこの issue の進行の記録である。改善候補は上の別 issue に渡した。

## 想定と異なった点

| 計画時の見込み | 実際 | どう扱ったか |
|---|---|---|
| 取り込む範囲は §1〜§5（issue 本文と全体計画書の表題） | 写真が 9 回に分けて追加提供され、§0 概要から補遺までの全文になった | issue #52 に範囲の追記コメントを重ね、設計計画（0004）で全文に確定した。全体計画書の表題は直せないまま残った（e7） |
| 未提供の §13〜§23 への参照が残る（受け入れ条件 A4） | 全文が揃って未提供の節が無くなり、未解決の前方参照が 0 件になった | A4 を「前方参照の全件確認で未解決 0 件」に読み替えて答えた |
| 実施タスクはサブエージェント（opus）が担当する | 原本の写真がセッションにしか無くサブエージェントから読めない | チケット 0005・0006・0008・0009 の `executor` をメインエージェントにした。`work-defaults.md` からの逸脱として MR に記録した |
| AI アセット実装・テストは「対象なし」で即完了する見込み | 見込みどおり。4 つの機械的な確認で反例が 1 つも出なかった | 実装チケットを 0 枚として計画を閉じた |
| `boundary.sh` の切れ目処理は `--external` で通る | `logs/mr.json` が空で「MR が無い」と拒否された | `--standalone`（`via: chat`）で記録し、コメントは GitHub MCP で MR へ投稿した。状態ファイルの `via` だけが実態と食い違う。別 issue [#60](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/60) |

## 残課題

| # | 残課題 | 引き取り先 |
|---|---|---|
| R1 | 原文の写真が切れている 7 か所（§14.8 のコード例・§14.10 の JSON・§17.5 の台帳 JSONL・§20.1 の YAML・付録 C.1 の JSON・付録 C.2 の YAML・付録 D.2 の出力例）。転記注記で明示済み | 原本の追加提供があれば補える。issue は立てていない |
| R2 | 既存部（§6〜§12.2）と原文の食い違い。§6 の見出し・§6.1 の Layer 0-A の行・§11.3 の判定結果の表 | 別 issue [#61](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/61) |
| R3 | 原文の中の食い違い 3 件（リスクスコア 40 の境界・§21 の丸数字の体系・§14.3 と付録 B.3 のキャッシュ可否）。転記注記で明示済み | 別 issue [#62](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/62) の型変換のときに原本の作者と決める |
| R4 | `hook機構.md` に frontmatter が無く、`.claude/docs/` の中から参照されていない | 別 issue [#59](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/59) |
| R5 | 機構の不具合 4 件（`ticket.sh create` の入力検査・`boundary.sh` の `last_task`・WF204 のメッセージ・`gh` 不在環境での issue コメント取得） | 別 issue [#55](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/55)・[#60](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/60)・[#57](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/57)・[#56](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/56) |
| R6 | 全体計画書の表題が実範囲とずれたまま片付けで消える | 対応しない（MR タイトルは直した。記録はこのレポートに残る） |
| R7 | `finalize.sh release` の前提検査が `--external` でも MR 本文の取得を要求するため draft を解除できず、完了検査の書き出し・成果物リンク一覧・作業領域の片付けも未実施のまま残る | 別 issue [#71](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/71)。直ってから issue #52 の draft を解除する |

## 運用上の注記

この環境に `gh` / `glab` が無く、MR と issue の読み書きはすべて GitHub MCP ツールで代行した。`boundary.sh` は MR を検出できず（`logs/mr.json` が空）、進行状態には単独実行モード（`via: chat`）が残っている。実際のレビュー依頼・判断の記録・敵対的レビューの指摘は PR #53 のコメントにあり、証跡そのものは MR に残っているが、**`gh` 自身が確認する強度より劣る**。`finalize.sh release` は段階 4 と段階 7 を `--external` で代行する想定だったが、段階 1 の前提検査を通れず一度も実行できていない（e8）。
