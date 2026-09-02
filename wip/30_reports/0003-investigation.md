---
type: report
title: チケット Markdown の実形と壊れ方の調査結果
description: カードに出す 6 項目の取得元（ファイル名・状態ディレクトリ・frontmatter・H1）と、frontmatter が壊れたときの読み取り挙動を 9 パターンの実測で確定した
tags: [report, investigation]
---

# チケット Markdown の実形と壊れ方の調査結果

## 対象

- 対象 issue: #13 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/13
- PR: #14 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/pull/14
- チケット: 0003-investigation
- 担当した問い: Q1（実形）・Q2（壊れ方）

## サマリ

カードに出す 6 項目はすべて機械的に取得できる。番号とタイトルは H1 見出し、ticket_type / executor / 人間レビュー要否 / 敵対的レビュー要否は frontmatter、状態は置かれているディレクトリから取れる。frontmatter は YAML そのものではなく、書き手（ticket.sh）と読み手（frontmatter.sh）が合意した**サブセット**で、拡張はこのサブセットだけを解釈すれば足りる。

壊れ方は 9 パターンを実測した。参照実装 `frontmatter.sh` は壊れた入力に対して例外を投げず「値が取れない」で応答する設計になっており、拡張も同じ方針（落とさず欠落として扱う）を採れる。ただし**二重引用符の閉じ忘れは検出されずゴミの値が返る**点が例外で、拡張側で気づける必要がある。

- ◎良 3 件 / △注意 2 件 / ✕問題 0 件

### ◆特に見てほしい

- 拡張が frontmatter.sh と同じサブセットだけを解釈する方針でよいか。ブロック配列（`- "wip/**"`）を人が手で書いた場合、機構自身も読めないので拡張も読めなくてよい、という整理

### ◇承認が欲しい

- 「不備が分かる表示」の粒度。キー単位で「取得できなかった」を出す案（受け入れ条件 7 を満たす最小）

### ・細かいレビューは不要

- 状態がディレクトリで表されること、ファイル名が `<4 桁連番>-<ticket_type>.md` であること

## 確かめられなかったこと

- 実在するチケットは本ブランチで作った 6 枚だけで、`30_cancelled/` に置かれた実物は 1 枚も無い。取り消し済みチケットの frontmatter に何が入るかは `ticket.sh cancel` の実装からの推定であり、実物では確認していない
- 日本語以外・絵文字・非常に長いタイトルの表示崩れは、パーサではなく Webview の見た目の問題なので調べていない

## 実施条件

- リポジトリ `/home/user/issue-mr-ticket-workflow`、ブランチ `claude/vscode-ticket-visualization-ci8etr`
- 読んだ実装: `.claude/skills/20-common-step-ticket/scripts/ticket.sh`、`.claude/skills/20-common-step-shell-script/scripts/frontmatter.sh`、`.claude/skills/20-common-step-ticket/assets/ticket.template.md`、`.claude/hooks/config/task-types.tsv`
- 壊れ方の実測は `wip/tmp/fm-probe/` に使い捨ての 9 ファイルを作り、`frontmatter.sh` を source して `fm_get` で読ませた（書き込みは `wip/tmp/` のみ）

## 実施した内容と結果

### 1. 置き場・ファイル名・状態の表し方 ◎良

根拠: `ticket.sh` 22 行目、`ls -d wip/10_tickets/*/`

状態はディレクトリで表され、4 つある。

| ディレクトリ | 意味 |
|---|---|
| `wip/10_tickets/00_todo/` | 未着手 |
| `wip/10_tickets/10_doing/` | 作業中 |
| `wip/10_tickets/20_done/` | 完了 |
| `wip/10_tickets/30_cancelled/` | 取り消し |

ファイル名は `<4 桁ゼロ埋め連番>-<ticket_type>.md`。連番は取り消し済みを含む全チケットの最大 + 1 で、`ticket.sh` が採番する。4 ディレクトリはいずれも `.gitkeep` を持ち、チケットが 0 枚でもディレクトリ自体は存在する。

実在の 6 枚。

```
wip/10_tickets/00_todo/0004-investigation.md
wip/10_tickets/00_todo/0005-investigation.md
wip/10_tickets/00_todo/0006-design-plan.md
wip/10_tickets/10_doing/0003-investigation.md
wip/10_tickets/20_done/0001-overall-plan.md
wip/10_tickets/20_done/0002-investigation-plan.md
```

**結論**: 拡張はこの 4 ディレクトリを列とし、`[0-9][0-9][0-9][0-9]-*.md` に一致するファイルだけをカードにする。`.gitkeep` は自然に除外される。

### 2. frontmatter のキーと値の形 ◎良

根拠: `ticket.template.md`、`frontmatter.sh` のヘッダコメント 4 行目、実在チケットの実際の内容

frontmatter は YAML 全体ではなく次のサブセットに限られる。書き手（`ticket.sh`）がこの形しか出力せず、読み手（`frontmatter.sh`）もこの形しか解釈しない。

| 形 | 例 | 該当キー |
|---|---|---|
| フラットなスカラー | `ticket_type: investigation` | `type`, `ticket_type`, `executor` |
| クォート付きスカラー | `started_at: "2026-09-02T05:28:07+00:00"` | `started_at`, `completed_at`, `base_sha` |
| フロー配列 | `predecessors: ["0002"]` | `predecessors`, `allow.write`, `allow.ops` |
| インラインマップ | `human_review: {required: true, reason: "..."}` | `human_review`, `adversarial_review` |
| 入れ子マッピング（2 段） | `allow:` の下に `write:` / `ops:` | `allow` |

明示的に対象外なのはブロック配列（`- a`）と複数行スカラー。

実物。

```yaml
---
type: ticket
ticket_type: investigation
predecessors: ["0002"]
executor: main
human_review: {required: true, reason: "テストランナーの選択が実装フェーズ全体を左右する（基準どおり）"}
adversarial_review: {required: false, reason: "基準どおり"}
allow:
  write: ["wip/**"]
  ops: ["read", "build-test", "web"]
started_at: ""
completed_at: ""
base_sha: ""
---
```

`started_at` / `completed_at` / `base_sha` は作成時は空文字で、`ticket.sh` の `set_field` が `key: ""` 行を後から書き換える。つまり**空文字は「まだその段階に来ていない」を意味し、欠落とは違う**。

`ticket_type` の値域は `.claude/hooks/config/task-types.tsv` の 2 列目の 15 種。

**結論**: カードの 6 項目の取得元が確定した。

| カードの項目 | 取得元 |
|---|---|
| 番号 | ファイル名の先頭 4 桁（H1 とも一致） |
| タイトル | H1 見出しの番号より後ろ |
| ticket_type | frontmatter `ticket_type` |
| executor | frontmatter `executor` |
| 人間レビュー要否 | frontmatter `human_review.required` |
| 敵対的レビュー要否 | frontmatter `adversarial_review.required` |

### 3. 本文の見出し構造 ◎良

根拠: `ticket.template.md`、`ticket.sh` 26 行目の `LOG_HEADINGS`

frontmatter の直後は必ず `# <4 桁番号> <タイトル>` の H1。その下に `## 目的` / `## DoD` / `## 作業内容` / `## 作業ログ` が並び、`## 作業ログ` の下に 10 個の `###` 見出しが固定順で入る（現在地 / うまくいったこと / うまくいかなかったこと / 仕様からの逸脱 / 判断と根拠 / 拒否・確認・迂回の記録 / 使った AI アセットと効き目 / スコープ外で見つけたこと / AI アセットに反映すべき内容 / 備考）。

`## DoD` の中身は `- [ ]` / `- [x]` のチェックリストで、`ticket.sh complete` が未チェックの有無を検査している。

**結論**: タイトルは H1 から取る。ファイル名の番号と H1 の番号は `ticket.sh` が同じ値を書くので通常一致するが、手編集でずれうるのでファイル名を正とする。DoD のチェック数はカードに進捗として出せる材料になる（受け入れ条件には無いので設計で採否を決める）。

### 4. 壊れ方 9 パターンの実測 △注意

根拠: `wip/tmp/fm-probe/run.sh` の出力

`frontmatter.sh` を source して 9 パターンを読ませた結果。

| # | 壊れ方 | 読み取りの挙動 |
|---|---|---|
| 1 | 正常 | 全キー取得できる |
| 2 | frontmatter が無い | 全キー取得失敗。例外は出ない |
| 3 | 終端の `---` が欠落 | 全キー取得失敗。例外は出ない |
| 4 | 二重引用符の閉じ忘れ | **他のキーは正常に取得でき、該当キーだけゴミの値（`"閉じ忘れ`）が返る** |
| 5 | `allow.write` をブロック配列に手書き | `allow.*` だけ取得失敗、他のキーは取得できる |
| 6 | 空ファイル | 全キー取得失敗。例外は出ない |
| 7 | CRLF 改行 | 全キー正常に取得できる（`\r` を落としている） |
| 8 | `executor` キーの欠落 | そのキーだけ取得失敗、他は取得できる |
| 9 | 未知の `ticket_type` | 値としてそのまま返る。検証はしていない |

**結論**: 参照実装は「壊れた入力でも例外を投げず、取れないキーを取れないと返す」設計になっている。拡張も同じ方針を採れば受け入れ条件 7（落ちない）を満たせる。ただしパターン 4 と 9 は**取得失敗にならない**ため、値の妥当性検査を別に持つ必要がある。

### 5. 拡張が持つべきパーサの範囲 △注意

根拠: 上記 1〜4 の総合

`frontmatter.sh` は bash 実装なので拡張から再利用できない。拡張は同じサブセットを解釈する独自パーサを持つことになる。YAML ライブラリを入れる案もあるが、次の理由で**サブセット専用の自前パーサ**が妥当と考える。

- 読むキーは 8 個で、形は 5 種類に限られる。汎用 YAML の機能はどれも使われていない
- 汎用 YAML パーサはむしろパターン 4 で例外を投げる可能性があり、受け入れ条件 7 を満たすために例外の握り潰しが要る
- 依存を増やさない（Q3 の結果によっては依存を取得できない可能性がある）

**結論**: 設計では、frontmatter を 5 種類の形だけ解釈する小さなパーサとし、キー単位で「取れた / 取れなかった」を返す型にする。値の妥当性検査（`ticket_type` が 15 種のいずれか、`required` が真偽値）はパーサの外に置く。

## 想定と異なった点

| 計画時の見込み | 実際 | どう扱ったか |
|---|---|---|
| frontmatter は普通の YAML なので YAML パーサを入れれば済む | 書き手も読み手もサブセットしか扱わず、ブロック配列は機構自身が読めない | 汎用 YAML ではなくサブセット専用パーサを設計方針として提案（章 5） |
| 壊れた frontmatter は「読めない」に倒れる | 二重引用符の閉じ忘れだけは読めてしまい、ゴミの値が通る | 値の妥当性検査をパーサの外に置く方針にした（章 4・5） |
| `started_at` が空なのは異常 | 未着手のチケットでは空が正常 | 空文字と欠落を区別して扱う（章 2） |

## 設計への反映

1. 列は 4 状態のディレクトリで固定し、`[0-9]{4}-*.md` に一致するファイルだけを対象にする（章 1）
2. frontmatter パーサは 5 種類の形だけを解釈し、キー単位で取得可否を返す型にする（章 5）
3. 値の妥当性検査をパーサの外に置き、`ticket_type` が `task-types.tsv` の 15 種にあるか・`required` が真偽値かを検査する（章 4）
4. 番号はファイル名を正とし、H1 との不一致は不備として表示する（章 3）
5. 空文字（未着手の `started_at`）と欠落を区別する（章 2）
6. 「不備が分かる表示」は、取得できなかったキー名と不正な値をカードに列挙する形にする（章 4）
7. DoD のチェック進捗をカードに出すかを設計で決める。受け入れ条件には無い（章 3）

## 残課題

- `30_cancelled/` に置かれた実物のチケットが 1 枚も無く、取り消し済みの frontmatter を実測できていない。設計では他の状態と同じ形と仮定し、実装のテストで取り消し相当のファイルを作って確かめる
- `ticket_type` の 15 種を拡張が持つとして、`task-types.tsv` の変更に追従する仕組みを持つか（読み込むか、拡張に焼き込むか）は設計で決める
