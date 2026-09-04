---
type: ticket
ticket_type: ai-asset-design
predecessors: ["0041"]
executor: main
human_review: {required: false, reason: "承認③により人間レビューは敵対的レビューで代替する"}
adversarial_review: {required: false, reason: "設計フェーズの敵対的レビューは 0046 で 4 枚分をまとめて 1 回行う"}
allow:
  write: [".claude/docs/**", "wip/**"]
  ops: ["read", "remote-read"]
started_at: "2026-09-04T15:25:20+09:00"
completed_at: "2026-09-04T15:43:10+09:00"
base_sha: "e75feea"
---

# 0043 フックと提供コマンドの仕様に書き戻す

## 目的

0036・0038・0039 で実装した振る舞いと、boundary.sh / finalize.sh の逸脱を仕様に写す（候補 1〜7・18〜20・44）

## DoD

- [x] workflow-guard 仕様の制御方式 6 に、削除だけの段の判定（置き場 or 宣言の一致・ディレクトリ・展開前の文字列・進行状態のファイル）が 1 節にまとまり、テスト表に WG-T18 がある（候補 1）（根拠: `10_spec/hooks/20-PreToolUse/workflow-guard.md` 制御方式 6「削除の判定」1〜7、テスト表 WG-T18、要件との対応「削除だけのコマンドは宣言した範囲でのみ許可」）
- [x] フック共通仕様 §6 に「eval ID の登録は接頭辞の予約で、表は各仕様書が持つ」がある（候補 44）（根拠: `10_spec/フック共通仕様.md`「この表への登録は接頭辞の予約であって、eval の定義ではない」の段落）
- [x] 過渡期の記述（現行アセットとの差分の表・session-start の「実装フェーズで直す」）が正史から落ちている（候補 6）（根拠: `00-workflow-issue-mr-driven` 仕様の「現行アセットとの差分」節を削除、`session-start` 仕様の過渡期の記述と「この issue で実施するか」列を削除、`10-task-overall-summary` 仕様と `00-workflow-quick-request` 仕様に残っていた同種の記述も削除。`grep -rn '実装フェーズで直す|現行アセットとの差分' .claude/docs` の残りは DDR 2 件のみ（DDR は本文を変更しない））
- [x] 10-task-overall-summary 仕様に merge-state.json の branch・--linked の前提（state=recorded）・is_draft の 3 値化・未知の state の再導出・時刻を読めない指摘を落とさないことが書かれている（候補 2〜4）（根拠: `10_spec/skills/10-task-overall-summary.md` Script 処理（`branch` の項目と書き手が 1 つであること）・再導出の段落（未知の値を終了 2 にしない・draft の 3 値・拒否側に倒す原則）・「CLI が使えない環境での release」（`--linked` は `state=recorded` のときだけ）。時刻を読めない指摘は `boundary.sh` の振る舞いなので `10_spec/skills/00-workflow-issue-mr-driven.md` の `complete` 3 に書いた）
- [x] 00-workflow-issue-mr-driven 仕様に before_request の「完了したチケットが 1 件以上ある」・敵対的レビューの起動にブランチ名を渡すこと・観点に「必須節の実在」・レビュアーのモデルが使えないときの代替がある（候補 5・18〜20）（根拠: `10_spec/skills/00-workflow-issue-mr-driven.md` の `position` の判定（`before_request` の条件）、手順 2a の 2 の但し書き 3 本、要件との対応「整合 6」「整合 7」）
- [x] 提供コマンドの識別子表に引数・環境の誤りの番号（BD006 / FN004）があり、要件を先に直してから仕様の対応表を書いている（候補 7）（根拠: 要件に先に `00-workflow-issue-mr-driven` の例外 [E7] と `10-task-overall-summary` の例外フロー 3 行を足し、その後に仕様の識別子表 BD006 / FN004 と要件との対応「例外 [E7]」「例外 7〜9」を書いた。対応表の行数は要件の項目数と一致（44 / 44、41 / 41））
- [x] このチケットで旧名を増やしていない（0005 の c5 の検索が 0 行）。アセット本体に触っていない（根拠: `grep -rn '10-work-|20-task-|work-boundary|merge-prep' .claude/docs .claude/skills .claude/agents .claude/rules CLAUDE.md --exclude-dir=20_ddr` が 0 行。`git status --porcelain` の変更は `.claude/docs/` 配下 9 ファイルのみ）

## 作業内容

- DoD の各項目を順に満たす

## 作業ログ

### 現在地

- 完了（DoD 7 件すべて根拠付きで充足）

### うまくいったこと

- 「要件を先に直してから仕様の対応表を書く」順序を守れた。要件の項目数と仕様の対応表の行数を数えて突き合わせる検算（44 / 44、41 / 41）が、書き漏らしと過剰仕様の両方を機械的に拾った
- 実装済みのスクリプトを読んでから仕様を書いたので、仕様と実装の食い違いが残っていない（`is_draft` の 3 値、`merge_state()` のブランチ照合、`--linked` の前提、`ep` の 0 扱いをそれぞれ該当行で確認した）

### うまくいかなかったこと

- 仕様のテスト観点の表が実装より遅れていた。`FN-T10`〜`FN-T17` と `BD-T14`〜`BD-T18` はテストファイルに実在するのに仕様の表に無く、対応表からそれらを参照するために先に表へ足す必要があった

### 仕様からの逸脱

- DoD の 4 行目は「10-task-overall-summary 仕様に…時刻を読めない指摘を落とさないこと」と書かれていたが、その振る舞いは `boundary.sh complete` のもので、`finalize.sh` には無い。置き場を `00-workflow-issue-mr-driven` 仕様（`complete` 3 の但し書き）に変え、要件も同じスキルの例外 [E6] に足した。文書の 1:1 対応を優先した

### 判断と根拠

- BD006 / FN004 を末尾に足し、既存の番号を振り直さなかった（DDR `i0010-07`。振り直しはテストの期待値・実装・レポートの記述に連動して波及する）
- 例外 [E6]・[E7] は要件の mermaid 図に離脱先ノードを足して識別子を図と一致させた（`ai-asset-design-docs` の「図と節の識別子の一致」）
- 「判定できないときは『済んでいない』側に倒す」を `10-task-overall-summary` 仕様に 1 つの原則として書き、`draft` の 3 値・`--linked` の前提・未知の `state` の再導出をその適用例として並べた（3 つを別々の注意書きにすると、次に似た分岐が出たときに参照できない）

### 拒否・確認・迂回の記録

- `perl -i -pe` による置換が **WF204**（どの分類にも当たらない）で拒否された。迂回せず Edit ツールで同じ修正を行った

### 使った AI アセットと効き目

- `.claude/rules/ai-asset-design-docs.md`: 「要件との対応表は受け入れ基準を全件カバーする（行数が一致する）」が検算の手順として直接効いた
- `wip/20_plans/0041-ai-asset-design-plan.md`: 候補と文書の対応表があったので、どの候補をどのファイルに書くかを迷わず決められた

### スコープ外で見つけたこと

- 仕様のテスト観点の表と実際のテストファイルの ID がずれても誰も気づかない（今回は `FN-T10`〜`17`・`BD-T14`〜`18` の 13 件が欠けていた）。候補 22「設計文書検査の機械化」に「仕様のテスト ID 表とテストファイルの ID の突き合わせ」を含められる

### AI アセットに反映すべき内容

- 上記の突き合わせ検査は別 issue 候補 22 の範囲。このチケットでは足さない

### 備考

- 変更したのは `.claude/docs/` 配下の 9 ファイルのみ。アセット本体（スキル・フック・スクリプト）には触っていない
