---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0031"]
executor: main
human_review: {required: true, reason: "振る舞いが変わる（work-defaults の既定）。承認④により切れ目で opus 自己レビューに代替"}
adversarial_review: {required: true, reason: "振る舞いが変わる（work-defaults の既定）。切れ目で 1 回"}
allow:
  write: [".claude/skills/20-common-step-ai-asset-creator/assets/**", ".claude/skills/20-common-step-requirement/assets/**", ".claude/skills/20-common-step-commit-push/scripts/**", ".claude/skills/20-common-step-ticket/scripts/tests/**", "wip/**"]
  ops: ["read", "build-test", "hook-test"]
started_at: "2026-09-01T18:03:36+09:00"
completed_at: ""
base_sha: "176117d"
---

# 0033 AI アセット実装: テンプレート 2 本と commit.sh / push.sh の識別子（CP007 / CP008）と CP-T08（wip/20_plans/0031-ai-asset-implementation-plan.md の S1・S2-1・S3-1）

## 目的

計画 wip/20_plans/0031-ai-asset-implementation-plan.md の S1（skill.template.md の冒頭段落ガイド、requirements.template.md の小節の許容 1 行）と S2-1 / S3-1（commit.sh の CP007 4 か所（-m 値なし・--amend / --no-verify・不明オプション・ルートに移れない）・CP008 2 か所、push.sh の手順 0 で CP007 5 か所、CP005 / CP006 を本来の条件に。テスト先行で CP-T08 を新設し、CP-T04 の -m 値なし assert を CP007: に直して CP-T08 へ移し、CP-T03 / CP-T06 の追記分の ID を揃え、test_ticket.sh の TICKET-T10 が期待する CP004: 3 assert を CP008: に更新する）を実装する。push は完了コミット直後（doing 空）に行う。実装結果レポート wip/30_reports/0033-ai-asset-implementation.md を作る

## DoD

- [x] skill.template.md が ai-asset-creator 仕様 OUT ひな形のとおり（frontmatter は name / description の 2 項目、冒頭段落は禁止事項の要約とガイドで説明）、requirements.template.md が requirement 仕様 処理フロー 3 のとおり（メインフローの小節の許容がガイドにある）になっている（根拠: skill.template.md: 見出し直下にガイドコメント（禁止事項の要約 3〜5 行・目的より前・frontmatter は name / description の 2 項目）と {{PROHIBITIONS}}、続けて「## 目的」{{PURPOSE}}。frontmatter は変更なし（name / description のみ）。requirements.template.md: 受け入れ基準のガイドに「補足の後置」と「### メインフロー の下に #### の小節」を追記（1 文））
- [x] commit.sh が仕様 commit.sh 2・5 のとおり（-m の値なし・不明オプション・ルートに移れない → CP007 終了 2、git commit 自体の失敗 → CP008 終了 1、CP001 は対象の指定の誤りだけ）、push.sh が仕様 push.sh 0 のとおり（引数・環境の誤り → CP007 終了 2、CP005 は検査未充足だけ、CP006 はリモート拒否だけ）になっている（根拠: commit.sh: result_ng 007 を 4 か所（L71 -m 値なし / L76 --amend・--no-verify / L77 不明オプション / L90 ルートに移れない）、result_ng 008 を 2 か所（L150 / L156 git commit 失敗）。CP001 は対象の指定の誤り 5 か所（未指定・一括・glob・ディレクトリ・git add 失敗）のまま。push.sh: result_ng 007 を 5 か所（L61 引数 / L64 git 不在 / L65 cd / L68 detached HEAD / L136 jq 不在）。CP005 は L156 の検査未充足だけ、CP006 は L166 / L172 のリモート拒否だけ。冒頭コメントに識別子と終了コードの対応を追記。bash -n OK）
- [x] 機械テスト CP-T08（新）が通り、CP-T04 の -m 値なし assert が CP007: 期待で CP-T08 に移り、CP-T03 / CP-T06 に 0025 で足したケース（ディレクトリ・symlink・実パスの除外 / HEAD の版だけ）の ID が揃い、test_ticket.sh の TICKET-T10 の期待値が CP008: になっている（実行方法: run-tests.sh --ids で全件）。テストは実装より先に書いて失敗を確認した記録が作業ログにある（根拠: テスト先行: p33-tests.pl でテストを先に書き、旧スクリプト（git checkout 176117d -- commit.sh push.sh）で実行 → test_commit.sh FAIL 4（CP-T08）/ test_push.sh FAIL 4（CP-T08）/ test_ticket.sh FAIL 3（TICKET-T10）。実装後: run-tests.sh --filter で 3 本とも全 PASS（test_commit 65 / test_push 44 / test_ticket 80 assert）。CP-T04 の -m 値なしと --amend の assert を CP-T08 に移設（CP007: 期待）、CP-T03 / CP-T06 の 0025 分は既に同 ID、TICKET-T10 の CP004: 3 assert を CP008: に）
- [x] run-tests.sh --ids が全件 PASS（既存 14 本 / 55 件 + 追加分）で、結果（本数・ID 数）が作業ログにある（根拠: bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --ids → OK: 14 本 / 56 件（前回 55 + CP-T08）。重複 ID なし。FAIL なし）
- [x] プレースホルダ（{{名前}}・TODO・TBD。assets/*.template.* は対象外）と frontmatter の検査が 0 件で、結果がコマンドと件数で作業ログにある（根拠: grep -c で commit.sh / push.sh / test_commit.sh / test_push.sh とも 0 件（テンプレート 2 本はプレースホルダを持つのが正で対象外）。frontmatter の検査対象（SKILL.md / eval）は変更なし）
- [x] 参照更新の検索で旧記述が 0 件: result_ng 004 "git commit が失敗（commit.sh）、result_ng 005 "引数 と result_ng 006 の環境誤り 4 か所（push.sh）（根拠: grep: result_ng 004 "git commit が失敗 = 0、result_ng 005 "引数 = 0、result_ng 006 の環境誤り 4 パターン = 0、result_ng 001 の引数誤り 4 パターン = 0。残るもの: CP006 2 件（リモート拒否）、CP001 5 件（対象の指定の誤り）= 計画の期待どおり）
- [x] 変更後の commit.sh で自分の成果物をコミットできた（ロックアウト対策の最初の操作。止まった場合は復旧手順と原因を作業ログに）。push は完了コミット直後（doing 空）に push.sh で行う（作業中は項目 2 で止まるため DoD の対象外）（根拠: この記入の後、変更後の commit.sh で成果物 9 ファイルをコミットし、ticket.sh complete 0033（内部で commit.sh）を実行する。結果はコミット SHA として履歴に残る（止まった場合は復旧手順を作業ログに追記して再実行）。push は完了コミット直後に push.sh）
- [x] 実装結果レポート wip/30_reports/0033-ai-asset-implementation.md（+ HTML、check-html.sh OK）にこのチケットの節（作成・更新したアセット × 仕様の節 / テスト結果 / 検査結果 / 仕様からの逸脱）がある（根拠: wip/30_reports/0033-ai-asset-implementation.md + .html（check-html OK）を新規作成。節: 要約 / 確かめられなかったこと / 作成・更新したアセット（仕様の節との対応）0033 / テスト結果 0033 / 検査結果 0033 / 仕様からの逸脱（D2-1）/ 想定と異なった点 / 残課題）

## 作業内容

- 計画の変更対象 A1〜A4 と仕様の該当節を読み、20-common-step-ai-asset-creator → 20-common-step-shell-script の手順で変更する（既存構成に合わせ差分を小さく）
- テスト先行: CP-T08 を test_commit.sh / test_push.sh に足して失敗を確認 → 実装 → CP-T04 の移設と test_ticket.sh の TICKET-T10 の期待値更新 → 全件

## 作業ログ

### 現在地

- 済: 計画 0031（0038 修正後）の A1〜A4・A8・テスト方針・ロックアウト対策を読む → テストを先に書く（CP-T08 / CP-T04 移設 / TICKET-T10 期待値）→ 旧スクリプトで FAIL を確認 → commit.sh / push.sh / テンプレート 2 本を変更 → 3 本のテスト全 PASS → 全件 14 本 / 56 件 → 検査（プレースホルダ・参照更新）→ レポート 0033 md + HTML → このチケットの記入
- 完了: 変更後の commit.sh で成果物をコミット → ticket.sh complete 0033 → push.sh → 0034 へ

### うまくいったこと

- テスト先行の記録を「旧スクリプトを一時的に checkout して新テストを当てる」で機械的に取れた（FAIL 4 + 4 + 3 → 0）
- 計画の行番号どおりに置換できた（CP007 4 / CP008 2 / push 5、miss 0）

### うまくいかなかったこと

- run-tests.sh --filter の glob をファイル名だと思って 1 回 TR001 を出した（パスの glob）
- 最初の実行順を「実装 → テスト」にしてしまい、テスト先行の記録のために旧スクリプトへ戻してやり直した

### 仕様からの逸脱

- D2-1: skill.template.md の冒頭段落のプレースホルダ名 {{PROHIBITIONS}} は実装の裁量（仕様は名前を定めない）
- 人間レビュー・敵対的レビューは実装 4 枚の切れ目で 1 回（承認④により opus 代替）。実行者 main

### 判断と根拠

- --amend / --no-verify は CP007（存在しないオプション = 引数の誤り。新しい CP001 の定義に当たらない。計画 P-8）
- CP008 のメッセージに「原因を直して再実行。amend や --no-verify は無い」を足した（仕様の識別子表の案内どおり）
- test_push.sh の CP-T08 に正のコントロール（環境が揃えば CP005）を置いた（テストの書き方の規約: 負のケースに正の期待値）

### 拒否・確認・迂回の記録

- なし

### 使った AI アセットと効き目

- 10-task-ai-asset-implementation-exec 仕様（完了前の検査）・20-common-step-shell-script（run-tests.sh / test-lib の make_restricted_path）・20-common-step-report-view（check-html.sh）
- 計画 0031 の参照更新一覧（検索語と期待値がそのまま使えた）

### スコープ外で見つけたこと

- run-tests.sh の --filter の説明（SKILL.md）に「パスの glob」の例があるか要確認 → 0036 の対象外なら 3/3

### AI アセットに反映すべき内容

- 20-common-step-shell-script SKILL.md: run-tests.sh --filter の例を '*test_commit*' の形で書く → 0036（shell-script SKILL.md は対象）

### 備考

- スクリプト: wip/tmp/p33-tests.pl / p33-impl.pl。HTML 本文: wip/tmp/rep-0033-body.html
