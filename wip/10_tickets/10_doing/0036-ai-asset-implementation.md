---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0035"]
executor: main
human_review: {required: true, reason: "SKILL.md の指示文の変更（work-defaults の既定）。承認④により切れ目で opus 自己レビューに代替"}
adversarial_review: {required: true, reason: "切れ目で 1 回（実装 4 枚をまとめて）"}
allow:
  write: [".claude/skills/20-common-step-commit-push/SKILL.md", ".claude/skills/20-common-step-ticket/SKILL.md", ".claude/skills/20-common-step-report-view/SKILL.md", ".claude/skills/20-common-step-shell-script/SKILL.md", ".claude/skills/20-common-step-spec/SKILL.md", ".claude/skills/20-common-step-ai-asset-creator/SKILL.md", ".claude/skills/20-common-step-feature-mr/SKILL.md", ".claude/evals/**", "wip/**"]
  ops: ["read", "build-test", "hook-test"]
started_at: "2026-09-01T19:22:29+09:00"
completed_at: ""
base_sha: "8155f5b"
---

# 0036 AI アセット実装: SKILL.md 7 本のエラー表と eval ID の範囲・eval 2 本（SC-E / AC-E04）・参照更新と全件テスト（wip/20_plans/0031-ai-asset-implementation-plan.md の S4・S5）

## 目的

計画 wip/20_plans/0031-ai-asset-implementation-plan.md の S4 / S5: commit-push / ticket / report-view / shell-script の SKILL.md を仕様の識別子表・処理フロー・test-lib の関数一覧に合わせ（CP001 のディレクトリ、CP003 の 2 条件、CP004 は差分なしだけ、CP006 から環境の誤りを除く、CP007 / CP008 / TK008 / RV008 の行、手順 2 のファイル単位、スキップ記録は HEAD の版、complete の検査 3 条件、make_counting_path 等、テストの書き方（規約）への参照）、spec / ai-asset-creator / feature-mr の SKILL.md の eval ID の範囲（SP-E01〜03 → SC-E01〜03、AC-E01〜03 → 04）と push.sh の識別子（CP007 の追記）を直し、eval 定義の SP-E01〜03 を SC-E01〜03 に改名し AC-E04 を追加する。参照更新一覧の検索を再実行して 0 件を記録し、全件テストと実装結果レポートの完成（HTML）を行う

## DoD

- [x] SKILL.md 7 本が各仕様のエラー識別子表・処理フロー・OUT ひな形・eval ID の範囲のとおりになっていて、仕様の行 × SKILL.md の行の対応表が作業ログにある（受け入れ条件 4）（根拠: 7 本を p36-skills.pl で変更（commit-push 8 か所 / ticket 4 / report-view 3 / shell-script 3 / spec 1 / ai-asset-creator 1 / feature-mr 1）。仕様の行 × SKILL.md の行の対応表は下の「備考」。既存の表の形（エラー時の対処の 2 列表・手順の番号）に合わせ、構造は変えていない）
- [x] eval SC-E01〜03（改名。本文の参照を含む）と AC-E04（新）が定義されている（実行しない）。frontmatter は type: eval のまま（根拠: .claude/evals/20-common-step-spec.md: SP-E → SC-E 7 か所（表 3 行・行内参照 1・判定基準 3）。.claude/evals/20-common-step-ai-asset-creator.md: AC-E04 の行を AC-E01 の次（仕様の並び）に追加し、判定基準に AC-E04 と「4 シナリオのうち 3 つ以上」。両方 type: eval のまま、実行状況は未実行のまま。実行していない）
- [x] 参照更新の検索が計画の参照更新一覧の期待値どおり: SP-E 0 件（evals + spec/SKILL.md）、AC-E01〜03 0 件、SKILL.md の旧範囲表記（CP001〜006 / TK001〜007 / RV001〜007）と CP004 のコミット失敗の記述と feature-mr の CP005: CP006: が 0 件、HK-T11 は 21 件（DDR・用語辞書は対象外）（根拠: grep -rnE <語> .claude --include='*.md' --include='*.sh' --exclude-dir=docs: SP-E 0 / AC-E01〜03 0 / "RV:  0 / commit.sh の CP001 引数 4 語 0 / result_ng 004 "git commit が失敗 0 / result_ng 005 "引数 0 / result_ng 006 の 4 語 0 / ticket.sh result_ng 004 = 6（終了 2 の行 0）/ result_ng 001 "--title 0 / CP004:` 差分なし・コミット失敗 0 / CP001〜006 0 / TK001〜007 0 / RV001〜007 0 / push.sh` が `CP005:` `CP006:` | 0 / HK-T11 21 — すべて計画の期待どおり（結果報告「検査結果 0036」に表））
- [x] run-tests.sh --ids が全件 PASS（既存 14 本 / 55 件 + 追加分）で、結果（本数・ID 数）が作業ログにある（根拠: run-tests.sh --ids → OK: 14 本 / 59 件（機械テストの変更なし。前回 55 件 + CP-T08 + TICKET-T12 + RV-T07 + HK-T15）。FAIL / TIMEOUT なし。重複 ID の報告は CP-T08 のみ（0033 から）。出力 wip/tmp/p36-full.out）
- [x] プレースホルダ（{{名前}}・TODO・TBD。assets/*.template.* は対象外）と frontmatter の検査が 0 件で、結果がコマンドと件数で作業ログにある（根拠: grep -c '{{' 9 本: report-view/SKILL.md 2・shell-script/SKILL.md 1・ai-asset-creator/SKILL.md 1（いずれも二重波括弧の表記に言及する既存の指示文。git show HEAD と同数）、他 0。grep -cE 'TODO|TBD': spec/SKILL.md 3・ai-asset-creator/SKILL.md 2・evals/20-common-step-spec.md 1（「TBD の明示」の指示文。HEAD と同数）、他 0。frontmatter: eval 2 本は type: eval、SKILL.md は name / description のみ（report-view の description に RV001〜008 の 1 語））
- [x] 実装結果レポート wip/30_reports/0033-ai-asset-implementation.md（+ HTML、check-html.sh OK）が完成している: 全チケット（0033〜0036）の節、受け入れ条件 3〜7 との対応（テスト ID）、逸脱一覧、想定と異なった点、残課題（3/3 と 2/3 への申し送り、別 issue 候補）（根拠: wip/30_reports/0033-ai-asset-implementation.md + .html を完成: 0036 の節（アセット 9 本 × 仕様の節 / テスト結果 / 検査結果 = 参照更新の表）、「受け入れ条件との対応」（3〜7 × テスト ID・検査）、逸脱一覧 D2-1〜D2-4、想定と異なった点、残課題（3/3 へ 5 件・2/3 へ 1 件・別 issue 候補 2 件）。check-html.sh OK）

## 作業内容

- 計画の変更対象 A9・A10 と仕様の該当節を読み、20-common-step-ai-asset-creator の手順で変更する（既存の表の形に合わせる）
- S5: 計画の参照更新一覧の検索語 7 種を再実行し、件数を作業ログとレポートに残す

## 作業ログ

### 現在地

- 済: 計画の A9・A10・参照更新一覧と 6 仕様の該当節（識別子表・処理フロー・OUT ひな形・テストの書き方・eval 表）を読む → SKILL.md 7 本と eval 2 本を変更 → S5 の 11 検索語を再実行（期待どおり）→ プレースホルダ・frontmatter の検査 → 全件テスト → レポートに 0036 の節と受け入れ条件の対応を書いて完成 → このチケットの記入
- 完了: commit.sh で成果物をコミット → ticket.sh complete 0036 → push.sh → 実装 4 枚の切れ目（opus 自己レビュー・PR 本文・レビュー依頼コメント）→ 0037

### うまくいったこと

- 計画の参照更新一覧（検索語と期待値が「残るもの」で書いてあった）をそのまま再実行でき、11 語すべて一致した
- 0033〜0035 の申し送り（CP007 / CP008 / TK008 / RV008 の行、--filter の例、test-lib の関数一覧）をこのチケットで一度に反映できた

### うまくいかなかったこと

- なし（テストの変更が無いチケットなので、テスト先行の記録は無い）

### 仕様からの逸脱

- なし。計画 A9 に無い記述の追加は、--filter の glob の注意（0033 の申し送り）と ticket create の記号入りの値の注意（0034 の実装）で、どちらも仕様の記述（run-tests.sh の --filter・create 3 の YAML エスケープ）の範囲内
- 人間レビュー・敵対的レビューは実装 4 枚の切れ目で 1 回（承認④により opus 代替）。実行者 main

### 判断と根拠

- AC-E04 の行は AC-E01 の直後に置いた（仕様の表の並びに合わせる。eval は仕様の行と 1:1 が鍵で、番号順ではない）
- SKILL.md のエラー表は「状況 | 対処」の 2 列を保ち、終了コードは状況欄に括弧で添えた（表の形を変えない）
- shell-script SKILL.md の手順 4 は 1 段落のまま test-lib の関数を足した（雛形の構成を変えない。長さは仕様 OUT ひな形の一覧と同程度）
- feature-mr の CP007 は行を足さず既存の push.sh の行に追記した（feature-mr は commit-push の表に委ねる構造のため）

### 拒否・確認・迂回の記録

- なし

### 使った AI アセットと効き目

- 20-common-step-ai-asset-creator（既存の構成に合わせる・対応表・検査）、計画 0031 の参照更新一覧、各仕様のエラー識別子表

### スコープ外で見つけたこと

- 0033 で CP-T08 を test_commit.sh と test_push.sh の両方に付けたため run-tests.sh が「重複 ID」を報告する（不合格ではない）。1 つの ID を 2 ファイルに置く可否は 3/3 の設計で決める
- run-tests.sh の対象は .claude/hooks/tests/test_config_integrity.sh を含む 14 本（計画の「14 本」は lib 5 + hooks/tests 1 + skills 8）

### AI アセットに反映すべき内容

- 3/3 へ: (a) fm_get のエスケープ解除 / (b) check-html.sh の awk 前提 / (c) テスト ID の複数ファイル配置の可否 / (d) 計画スキルに「往復が要る修正は同じチケット」/ (e) run-tests.sh の本数の数え方 — 結果報告「残課題」に集約
- 2/3 へ: 片付けの提供コマンド（全体まとめの完了）— 0037 は手作業代替

### 備考

仕様の行 × SKILL.md の行の対応表（受け入れ条件 4）:

| 仕様（ファイル:行） | 内容 | SKILL.md（ファイル:行） |
|---|---|---|
| commit-push.md:99 CP001 | 対象未指定・一括・ディレクトリ・ステージ不可（終了 2） | commit-push/SKILL.md:27（手順 2）・:57（表） |
| commit-push.md:101 CP003 | 全対象が除外 / ステージ後の実パスに一致 | commit-push/SKILL.md:28 |
| commit-push.md:102 CP004 | 差分なし | commit-push/SKILL.md:28・:60 |
| commit-push.md:104 CP006 | リモート拒否（環境の誤りは含まない） | commit-push/SKILL.md:62 |
| commit-push.md:105 CP007 | 引数・環境の誤り（終了 2） | commit-push/SKILL.md:27・:38（push 手順 0）・:63 |
| commit-push.md:106 CP008 | git commit 自体の失敗 | commit-push/SKILL.md:28・:64 |
| commit-push.md:91 push.sh 2 | スキップ記録は HEAD にある版 | commit-push/SKILL.md:40 |
| commit-push.md:73 commit.sh 2 | 対象はファイル単位 | commit-push/SKILL.md:27 |
| 範囲 CP001〜008 | 識別子表の範囲 | commit-push/SKILL.md:16 |
| ticket.md:138 TK008 | 引数・環境の誤り（終了 2） | ticket/SKILL.md:23（作成）・:51（表） |
| ticket.md:106-112 complete 3 | 根拠欄なし・現在地の 3 条件・見出しの重複 | ticket/SKILL.md:25 |
| ticket.md create 3 | 値の YAML エスケープ | ticket/SKILL.md:23 |
| 範囲 TK001〜008 | 識別子表の範囲 | ticket/SKILL.md:16 |
| report-view.md:90 RV008 | 引数・ファイル不正（検査に入る前・終了 2） | report-view/SKILL.md:50 |
| 範囲 RV001〜008 | 識別子表の範囲 | report-view/SKILL.md:8・:16 |
| shell-script.md:66 test-lib.sh | 関数一覧（make_tmp_dir / make_restricted_path / make_counting_path / counted_calls / hook_payload --session / tl_jq） | shell-script/SKILL.md:25 |
| shell-script.md:149-158 テストの書き方（規約） | 6 項目 | shell-script/SKILL.md:25 |
| shell-script.md:119- run-tests.sh | --filter はルート相対パスの glob（TR001） | shell-script/SKILL.md:26 |
| shell-script.md:134-135 TR004 / TR005 | 終了 2 | shell-script/SKILL.md:47 |
| spec.md:81-83 SC-E01〜03 | eval ID の範囲 | spec/SKILL.md:17、evals/20-common-step-spec.md:21-23・:33-35 |
| ai-asset-creator.md:85 AC-E04 | eval ID の範囲と行 | ai-asset-creator/SKILL.md:17、evals/20-common-step-ai-asset-creator.md:22・:37 |
| commit-push.md:105 CP007（呼び手側） | push.sh の識別子 | feature-mr/SKILL.md:47 |

- スクリプト: wip/tmp/p36-skills.pl。全件テストの出力 wip/tmp/p36-full.out
