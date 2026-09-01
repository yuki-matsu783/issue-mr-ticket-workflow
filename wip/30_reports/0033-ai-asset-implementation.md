---
type: report
title: AI アセット実装 結果報告（2 回目、チケット 0033〜0036）
description: issue #6（実装 1/3）の 2 回目の AI アセット実装。設計 0028〜0032 が仕様に書いた実装 9 件（識別子 CP007 / CP008 / RV008 / TK008、ticket.sh の完了検査と YAML エスケープ、hook_payload --session、HK-T15、SC-E、テンプレート、SKILL.md）とテストの実施結果、逸脱、残課題
tags: [report, ai-asset-implementation, issue-6]
---

# AI アセット実装 結果報告（2 回目）

- 対象 issue: #6 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/6
- PR: #7 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/pull/7
- 対象チケット: 0033（テンプレート 2 本・commit.sh / push.sh・CP-T08）、0034（ticket.sh）、0035（check-html.sh・test-lib・HK-T15）、0036（SKILL.md 7 本・eval・参照更新）
- 計画: `wip/20_plans/0031-ai-asset-implementation-plan.md`（0038 で修正済み）
- 前回の実装結果: `wip/30_reports/0013-ai-asset-implementation.md`（0013〜0021・0025）

## 要約

設計 0028〜0032 が仕様に書き戻した内容のうち実装を伴う 9 件を、計画 0031 の固定順（テンプレート → 中核 → 中核のテスト → スキル・eval → 参照更新）で実装する。各チケットはテストを先に書いて失敗を確認してから実装し、`run-tests.sh --ids` の全件と参照更新の検索で確かめる。「自分が使っている提供コマンドを自分で変える」チケット（0033 commit.sh / push.sh、0034 ticket.sh、0035 check-html.sh / test-lib.sh）は、変更後の自分のコマンドで自分をコミット・完了させることを最初の実機確認にする。

このレポートは 0033 が作り、0034〜0036 が節を追記する。

## 確かめられなかったこと

- shellcheck は環境に無く、静的検査は `bash -n` のみ（前回と同じ）
- `push.sh` の CP007（`git` 不在・detached HEAD・`jq` 不在）はテストの一時リポジトリで確認した。実運用の push は完了コミット直後に行うため、作業中に CP005 の項目 2 で止まる経路は実機では踏んでいない

## 作成・更新したアセット（仕様の節との対応）

### 0033

| アセット | 変更 | 仕様の節 |
|---|---|---|
| `20-common-step-ai-asset-creator/assets/skill.template.md` | 見出し直下に冒頭段落のガイド（禁止事項の要約 3〜5 行、frontmatter は name / description の 2 項目）と プレースホルダ PROHIBITIONS、続けて `## 目的` | `ai-asset-creator` 仕様 OUT ひな形 |
| `20-common-step-requirement/assets/requirements.template.md` | 受け入れ基準のガイドに補足の後置と `####` 小節の許容を 1 文 | `requirement` 仕様 処理フロー 3 |
| `20-common-step-commit-push/scripts/commit.sh` | `-m` の値なし・`--amend` / `--no-verify`・不明オプション・ルートに移れない → CP007（4 か所）、`git commit` 自体の失敗 → CP008（2 か所。対処の案内を追記）。冒頭コメントに識別子と終了コードの対応 | 仕様 commit.sh 2・5、識別子表 CP007 / CP008 |
| `20-common-step-commit-push/scripts/push.sh` | 受け付けない引数・`git` 不在・ルートに移れない・detached HEAD・`jq` 不在 → CP007（5 か所）。CP005 は検査未充足、CP006 はリモート拒否だけに | 仕様 push.sh 0、識別子表 |
| `commit-push/scripts/tests/test_commit.sh` | CP-T08（`-m` 値なし・`--foo` → `CP007:` 終了 2 / `--amend` → CP007 / 対象未指定は `CP001:` のまま / pre-commit 失敗 → `CP008:` 終了 1・git の出力・コミット数不変 / logger 退避でも契約）。CP-T04 の `-m` 値なし・`--amend` を CP-T08 に移設 | CP-T08、CP-T04 |
| `commit-push/scripts/tests/test_push.sh` | CP-T08（`--force` → `CP007:` / `git` 不在 → CP007 / `jq` 不在（merge-state あり）→ CP007 / detached HEAD → CP007 / 正のコントロール: 環境が揃えば CP005） | CP-T08 |
| `ticket/scripts/tests/test_ticket.sh` | TICKET-T10 の期待値 `CP004:` → `CP008:`（3 assert） | TICKET-T10 |

### 0034

| アセット | 変更 | 仕様の節 |
|---|---|---|
| `20-common-step-ticket/scripts/ticket.sh` | `yaml_escape` を新設（`\` → `\\`、`"` → `\"`、改行 → 空白）し、`create` の理由 2 つと `json_list` の各要素（`--allow-write` / `--allow-ops` / `--predecessors`）に適用。`sed_escape` は `yaml_escape` + sed メタ文字の 2 段に組み替え（`set_field` / `cancel` の出力は不変） | 仕様 create 3 |
| 同 | TK004 を終了 2 で転用していた 15 か所と TK001 の誤用 1 か所（必須引数の欠落）を TK008 に。TK004 は `find_ticket` 失敗・状態違いの 6 か所（終了 1）だけ | 識別子表 TK004 / TK008、create 1 |
| 同 | `complete` 3 に固定見出しの重複検査（`^### 見出し$` が 2 行以上 → 「見出し「〜」が重複している（N 回）」） | 仕様 complete 3 |
| 同 | `create` / `start` / `complete` / `cancel` の `commit.sh` 拒否時に `git reset -q -- <パス>` で index も戻す | 仕様 Script 処理 冒頭（index にも残さない） |
| `ticket/scripts/tests/test_ticket.sh` | TICKET-T12（不明サブコマンド・種類不正・必須引数欠落・4 桁でない番号・不明引数 → `TK008:` 終了 2。`complete 9999` は `TK004:` 終了 1 の負のコントロール。拒否された `create` がファイルを残さない）、TICKET-T03（見出し重複 → 未充足 8 件）、TICKET-T05（記号入りの理由と glob の `create` → ファイルは YAML エスケープ済み・`fm_get` / `fm_list` が壊れずに読める・`executor` 不変）、TICKET-T10（拒否後に `git diff --cached` が空）。`frontmatter.sh` を読む読み込み行を追加 | TICKET-T03 / T05 / T10 / T12 |

## テスト結果

### 0033

- テスト先行: 新しいテストを旧スクリプト（`git checkout 176117d -- commit.sh push.sh`）に対して実行 → `test_commit.sh` FAIL 4（CP-T08）、`test_push.sh` FAIL 4（CP-T08）、`test_ticket.sh` FAIL 3（TICKET-T10）。実装後: 3 本とも全 PASS
- 全件: `bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --ids` → `OK: 14 本 / 56 件`（前回 55 件 + CP-T08。assert 数: test_commit 65、test_push 44、test_ticket 80）。重複 ID なし
- `bash -n` OK（commit.sh / push.sh）。shellcheck 不在

### 0034

- テスト先行: テストを先に足して実行 → `test_ticket.sh` FAIL 8（TICKET-T03 / T12）。実装後: 全 PASS（102 assert）
- 全件: `run-tests.sh --ids` → `OK: 14 本 / 57 件`（+ TICKET-T12）。重複 ID なし。`bash -n` OK
- 途中経過: `yaml_escape` の挿入が 1 回一致せず（perl の `q{}` でバックスラッシュが潰れた）、`create` が未定義関数を呼んで 68 assert が落ちた状態を経て、挿入し直して回復。作業ツリーの `ticket.sh` が壊れていた間は提供コマンドを使っていない

## 検査結果

### 0033

- プレースホルダ（二重波括弧形式 / TODO / TBD）: 変更したテンプレート以外の 4 ファイルで 0 件（テンプレート 2 本はプレースホルダを持つのが正）
- 参照更新（計画の参照更新一覧）: `result_ng 004 "git commit が失敗` 0 件 / `result_ng 005 "引数` 0 件 / `result_ng 006 "(git が無い|リポジトリルート|現在ブランチ|jq が無い)` 0 件 / `result_ng 001 "(-m に|存在しないオプション|不明なオプション|リポジトリルート)` 0 件。残るもの: CP006 2 件（リモート拒否）、CP001 5 件（対象の指定の誤り）— 計画の期待どおり
- ロックアウト対策の最初の操作: 0033 の成果物を変更後の `commit.sh` でコミットし、`ticket.sh complete 0033`（内部で `commit.sh`）を通す。push は完了コミット直後に `push.sh`

### 0034

- プレースホルダ: `test_ticket.sh` 1 件（既存の fixture）と `ticket.sh` 20 件は、テンプレートの置換対象の名前（`{{TITLE}}` 等）を文字列として持つもので、前回（0017）と同じく検査の除外。TODO / TBD 0 件
- 参照更新: `result_ng 004` は 6 件で終了 2 の行は 0 件（`grep -cE 'result_ng 004 "[^"]*" 2'`）、`result_ng 001` は 1 件（プレースホルダ残存のみ）、`result_ng 008` 16 件 — 計画の期待どおり
- ロックアウト対策の最初の操作: 0034 自身を変更後の `ticket.sh complete 0034` で完了させる（見出し重複検査・TK008 を含む新版）

## 仕様からの逸脱

| # | チケット | 逸脱 | 理由 | 送り先 |
|---|---|---|---|---|
| D2-1 | 0033 | `skill.template.md` の冒頭段落をプレースホルダ PROHIBITIONS として置いた（仕様は「冒頭段落は禁止事項の要約」とだけ書き、プレースホルダ名は定めない） | ひな形は二重波括弧の形式で埋める箇所を示す規約 | なし（名前は実装の裁量） |

## 想定と異なった点

- （0033）`run-tests.sh --filter` は「ファイル名」ではなくルート相対パスの glob で、`test_commit*` では 0 本（TR001）になる。`'*test_commit*'` で絞る。SKILL.md の例を確認する（0036 の対象外なら 3/3）
- （0034）`create` の値の往復（書いて読む）は `frontmatter.sh` のアンエスケープが無いと成立しない。計画は書き手（`ticket.sh`）だけを見ていた
- （0034）`start` は TK002（作業中あり）を TK004 より先に判定するので、作業中チケットがある状態では「対象不在」の負のコントロールに使えない

## 残課題

- （0033）SKILL.md（commit-push）のエラー表に CP007 / CP008 の行が無い状態が 0036 まで続く（計画どおり）
- （0034）0035 へ: `frontmatter.sh` の `__fm_unquote` で二重引用符内の `\"` → `"`、`\\` → `\` を解除し、TICKET-T05 の期待値を元の値に戻す（FR-T05 の追記と一緒に）
- （0034）3/3 へ: shell-script 仕様 `fm_get` の「クォートは外す」にエスケープ解除を含めることを明記
