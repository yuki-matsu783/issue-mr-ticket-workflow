---
type: ticket
ticket_type: ai-asset-design
predecessors: []
executor: main
human_review: {required: true, reason: "設計実施のレビュー指摘への対応（承認④により opus 自己レビューで代替。回数上限に達したため 0012 の切れ目では再実施しない）"}
adversarial_review: {required: false, reason: "上限 1 回を消化済み"}
allow:
  write: [".claude/docs/00_requirement/**", ".claude/docs/10_spec/**", ".claude/docs/20_ddr/**", "wip/**"]
  ops: ["read"]
started_at: "2026-09-01T03:09:35Z"
completed_at: "2026-09-01T03:14:52Z"
base_sha: "02a3f99"
---

# 0012 AI アセット設計実施（追加）— 敵対的自己レビュー F1〜F18 への対応

## 目的

設計実施（0008〜0010）の敵対的自己レビュー（PR #7 のコメント参照）の指摘 F1〜F18 に沿って仕様・要件・DDR を修正し、AI アセット設計結果レポートを作成して、実装計画（0011）が矛盾の無い仕様から書ける状態にする。

## DoD

- [x] F1・F5・F13: ticket 仕様の `commit.sh` 呼び出しが commit-push 仕様のインターフェース（`--` なし）と一致し、start / complete / cancel が「コミット成功後に移動（拒否時は移動しない）」、create が「コミット失敗時は作成したファイルを削除」になっている。DDR i0006-02 の影響欄も一致（根拠: `20-common-step-ticket.md` 冒頭・create 4・start 4・complete 4・cancel 3・TICKET-T10、DDR i0006-02 決定・影響）
- [x] F2: commit-push 仕様の push 前チェック項目 3 が `*-appendix-*.md` を対の対象外にしている（根拠: `20-common-step-commit-push.md` push 前チェック表 3 行目）
- [x] F3・F8・F11: shell-script 仕様の run-tests.sh に作業中チケットの `allow.ops` 検査（TR006・TR-T05）があり、§6 の TR 範囲と一致。§8 の `build-test` 定義に `tests/` `test/` 配下の `*.sh` の実行形が含まれ、`ops` 分類一覧に `web`（フックでは強制されない旨付き）がある（根拠: shell-script 仕様 run-tests.sh 手順 1・TR006・TR-T05、共通仕様 §6 `TR001–006`・§8 `build-test` / `web`）
- [x] F4: workflow-guard 仕様の制御方式 5・WG-T09・概要・回復手順に `adversarial_review` が含まれる（根拠: `workflow-guard.md` 44 行目・WF208 行・回復手順 WF208・WG-T09。概要行は識別子表の WF208 行を「レビュー要否（人間・敵対的）」に改めることで対応）
- [x] F6: investigation-plan 仕様の「要件との対応」に新 AC 2 件の行がある（根拠: `10-task-investigation-plan.md` 要件との対応 +2 行）
- [x] F7: AI アセット設計結果レポート `wip/30_reports/0008-ai-asset-design.md` があり、更新した文書の一覧（根拠の節）・受け入れ条件 × テスト ID（機械 / eval）の対応表・ヘッドレス挙動の一覧・想定と異なった点・残課題を含む（HTML は check-html.sh 完成後）（根拠: `wip/30_reports/0008-ai-asset-design.md`）
- [x] F9・F10・F17: フック共通仕様 §3（`trap ERR` ハンドラは deny 出力後 `exit 0`）・§1（ラッパーの `||` は起動失敗の縮退。共有ライブラリ 5 本 + 外部依存 `frontmatter.sh`）・HK-T09 が更新され、shell-script 仕様の読み込み行が `<lib>` と失敗ポリシー（nop / fatal / deny）を取る形で呼び手別に定義され、`LOGGER_ROOT` が明記されている（根拠: 共通仕様 §1 lib 一覧末尾・ラッパー文・§3 拒否側の段落・HK-T09、shell-script 仕様「読み込み行」導入文と 4 の表）
- [x] F14: logger 要件「使い方」が外部的な記述（1 行で読み込む・自作しない・失敗しても本体を止めない・解決順は仕様が正）に縮まり、却下理由が DDR i0006-06 にある（根拠: `rules/logger.md` 使い方、`20_ddr/i0006-06-*.md`）
- [x] F15・F16・F18: §2 入力に PowerShell ツールの `tool_input` の確定事実があり、§12 の T5 が stdin 固有フィールドの問いに絞られ T3 から日付が消えている。§7-8 の提供コマンド識別がコマンド文字列上の `.claude/` 始まりのルート相対表記に限定され HK-T12 に絶対パスの例がある。§6 の規則が「登録義務はエラー識別子」に緩められている（根拠: 共通仕様 §2 共通フィールド文・§12 T3/T5・§7-8・HK-T12・§6 導入文と末尾）
- [x] 各文書の「要件との対応」表・用語の整合が崩れておらず、プレースホルダ 0 件、履歴的表現なし（根拠: `apply-pairs.pl` の全適用 ok=34 miss=0、`grep '（根拠: ）'` 0 件、§12 T3 の日付削除）

## 作業内容

- レビュー結果（PR #7 の note コメント）を読み、指摘ごとに仕様・要件・DDR を修正する
- 0008〜0010 の DoD 根拠と作業ログから設計結果レポートを構成する
- 完了（手作業代替）

## 作業ログ

### 現在地

- 済: F1〜F18 の反映（8 文書 34 箇所 + DDR i0006-06 新規）、設計結果レポート、完了

### うまくいったこと

- 指摘ごとに OLD/NEW の対を先に全部書いてから一括適用したので、1 回で全件当たり、途中状態のコミットが要らなかった

### うまくいかなかったこと

- `workflow-guard.md` の置き場を `12-PreToolUse` と思い込み 1 回空振りした（実際は `20-PreToolUse`）

### 仕様からの逸脱

- 無し

### 判断と根拠

- F1「コミット成功後に移動」は、`commit.sh` がパスをステージしてコミットする都合上「移してから旧・新パスを渡し、拒否されたら戻す」と表現した（結果として同じ不変条件: 拒否時に移動が残らない）
- F11 の `web` は分類一覧に入れるが強制はしない（`WebFetch` / `WebSearch` が matcher 外）。強制の要否は 2/3 に送る
- F18 は台帳の登録義務をエラー識別子に限定し、テスト/eval ID の所有を各仕様に置いた（重複は `run-tests.sh --ids` が拾う）

### 拒否・確認・迂回の記録

- 無し

### 使った AI アセットと効き目

- `wip/tmp/apply-pairs.pl`（手作業代替。完全一致の置換で誤爆なし）

### スコープ外で見つけたこと

- 共通仕様 §12 に残る TBD 3 件（サブエージェント通知の届き方・`agent_id` からの親解決・`-p` の判別）は 2/3 の実装時確認事項のまま

### AI アセットに反映すべき内容

- 設計チケットを 3 分割すると文書間の突合が閉じないので、実装計画では各チケットの DoD に「参照先の再読」を含める（レポート「想定と異なった点」）

### 備考

- 敵対的レビューは上限 1 回を消化済みのため、この切れ目では再実施しない（note のみ）
