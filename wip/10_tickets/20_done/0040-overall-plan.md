---
type: ticket
ticket_type: overall-plan
predecessors: []
executor: main
human_review: {required: true, reason: "フェーズ列・実行者・やってよいことの合意は人間が行う（work-defaults 基準どおり）"}
adversarial_review: {required: false, reason: "work-defaults 基準どおり"}
allow:
  write: ["wip/00_overall_plan/**", "wip/10_tickets/**", "wip/tmp/**"]
  ops: ["read", "remote-read", "remote-write:issue-append", "remote-write:mr-create", "remote-write:push"]
started_at: "2026-09-03T05:53:18+00:00"
completed_at: "2026-09-03T07:08:48+00:00"
base_sha: "8f9368e"
---

# 0040 issue #15 全体計画 — フックのコマンド検査を shlex で行うかを判断し反映する

## 目的

issue #15 の 2026-09-03 追記分（cmdpos.sh を shlex に寄せるかの判断と反映）について、フェーズ列・各フェーズの実行者・レビュー要否・やってよいことを人間と合意し、最初の計画チケットを起こす

## DoD

- [x] 全体計画書 wip/00_overall_plan/overall-plan.md がある（対象・種別・フェーズ列・受け入れ条件との対応・方針・保留した点・合意の記録の 7 節）（根拠: コミット e544d07。7 節すべてを含む）
- [x] フェーズ列・実行者・レビュー要否について承認③を得ている（根拠: 2026-09-03 に「この内容で合意」。全体計画書「合意の記録」③ 行）
- [x] 最初の計画チケット（investigation-plan）が 00_todo にある（根拠: wip/10_tickets/00_todo/0041-investigation-plan.md、コミット 90c6bbc）

## 作業内容

- DoD の各項目を順に満たす

## 作業ログ

### 現在地

- 完了

### うまくいったこと

- 既存 issue の検索で #15「シェルスクリプト群の uv + Python 移行の検討」が見つかり、その受け入れ条件「フック層（`cmdpos.sh` / `scope.sh` / `hook-common.sh`）を移行するか据え置くかの判断が記録されている」がそのまま今回の依頼に対応していた。新規 issue を立てずに済んだ
- 依頼の「shlex で検査する」を鵜呑みにせず、DDR i0009-22（ホットパスは jq 以外の外部プロセスを起こさない）との衝突を承認①の前に示せた。置き場を先に決めず調査してから判断する形で合意できた

### うまくいかなかったこと

- `git rm -r wip/10_tickets/20_done` がフック WF303 に拒否された。#9 のチケット 39 枚が main に残ったままで、AI からは片付けられない。`merge-prep.sh reset-wip` が唯一の経路だが未実装
- ヒアドキュメントで全体計画書を書こうとして WF209（コマンドが 4096 文字超で実行位置を判定できない）に拒否された。Write ツールに切り替えて解決

### 仕様からの逸脱

- 全体計画書のひな形 `assets/overall-plan.template.md`（`10_spec/skills/10-task-overall-plan.md`「OUT ひな形」が指す）が未作成のため、仕様の節構成の表から手で組んだ。7 節（対象・種別・フェーズ列・受け入れ条件との対応・方針・保留した点・合意の記録）は満たしている
- マージ方式の確認（仕様 手順 3 の `gh repo view --json squashMergeAllowed,...`）を行えなかった。`gh` がこの実行環境に無いため。#9 の全体計画の記載を引き継いで squash 前提とした

### 判断と根拠

- **新規 issue ではなく #15 への追記**: ユーザーの選択。#15 本文が「着手時は改めて `00-workflow-issue-mr-driven` で開始する」と自ら指示している
- **`Closes #15` ではなく `Refs #15`**: #15 は提供コマンド層の移行など本 PR のスコープ外の受け入れ条件を多く含む。マージで閉じると未了の条件が失われる
- **実行者を全種類メインエージェントに倒す**: `10-task-*` スキル 15 本と敵対的レビューエージェントが未作成で、サブエージェントに渡す手順書が無い。`work-defaults.md` の「プロジェクトの一時的な事情で全種類を一律に変える場合も、差分として明示する」に沿って計画書に差分として書いた
- **フェーズを省かない**: 調査の結論が「採用しない」でも設計・実装フェーズは残し、計画チケットの「対象なし」で即完了する。フェーズ列のテンプレートどおり

### 拒否・確認・迂回の記録

| 識別子 | 何をしたとき | どうしたか |
|---|---|---|
| WF303 | `git rm -r wip/10_tickets/20_done` | 迂回せず、削除対象から外した。人間の手が要ることを計画書の「保留した点」に記録 |
| WF209 | ヒアドキュメントで全体計画書を作成 | Write ツールに切り替えた |

### 使った AI アセットと効き目

- `00-workflow-issue-mr-driven`: 承認ポイントの位置（①②③）と手順の順序がそのまま使えた。ただし委譲先の `10-work-*` / `10-task-*` スキルと `work-boundary.sh` / `merge-prep.sh` が実在しないため、手順 5 以降は代行が要る
- `20-common-step-ticket` の `ticket.sh`: `create` / `start` が仕様どおり動いた。`overall-plan` をコミットしない扱いも期待どおり
- `20-common-step-commit-push` の `commit.sh` / `push.sh`: 空コミットと 65 ファイルの削除コミットが通った

### スコープ外で見つけたこと

- `merge-prep.sh reset-wip` が無いまま PR #12 がマージされ、`wip/` の 2.6 MB（チケット 39 枚・計画書と結果レポート 65 ファイル）が main に入っていた。同じことは #10 が完了するまで毎 PR で起きる
- `.claude/hooks/config/scope-limits.json` の `commands.build-test` が npm の 6 コマンドしか列挙しておらず、Python やシェルの計測コマンドを `build-test` として実行できない。issue #30（計画タスクが commands.build-test を列挙できない）と同根
- `00-workflow-issue-mr-driven` の SKILL.md が `retrospective` という type を使っているが、`task-types.tsv` にその行は無く `feedback-plan` / `overall-summary` が正。issue #34 の「仕様が先に進んだ」件と同種の drift

### AI アセットに反映すべき内容

- `10-task-overall-plan` の `assets/overall-plan.template.md` が未作成。仕様が指すひな形が無いので毎回手で組むことになる
- `gh` が使えない実行環境向けの手順が `20-common-step-issue` に無い。issue の追記を MCP で行うと本文が HTML エスケープされて返るため、書き戻す前にエスケープを戻す必要がある。この注意が仕様に無い
- WF303 が `wip/10_tickets/20_done` への削除をすべて拒むため、`merge-prep.sh` が無い間は AI が作業領域を片付けられない。`merge-prep.sh` の実装（#10）までの暫定手段が要る

### 備考

- 本チケットは `overall-plan` のためコミットされない。`push.sh` の項目 2（作業中チケットが無い）を通すには完了が先
