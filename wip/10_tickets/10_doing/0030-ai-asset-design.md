---
type: ticket
ticket_type: ai-asset-design
predecessors: ["0028", "0029"]
executor: main
human_review: {required: true, reason: "正史（要件・仕様）の変更。承認④により opus 自己レビューで代替（切れ目 1 回）"}
adversarial_review: {required: true, reason: "正史の変更で差分が 1 文書・50 行を超える（切れ目 1 回）"}
allow:
  write: [".claude/docs/**", "wip/**"]
  ops: ["read"]
started_at: "2026-09-01T17:01:20+09:00"
completed_at: ""
base_sha: "aa20fa8"
---

# 0030 AI アセット設計: requirement / issue / feature-mr / spec 仕様・ルール体系要件・要件 4 本の節順と横断整合（wip/20_plans/0026-ai-asset-design-plan.md の 0030）

## 目的

計画書 wip/20_plans/0026-ai-asset-design-plan.md「文書一覧と骨子」のうち、20-common-step-requirement（type: requirement、章名の統一）・-issue（追記の受け入れ条件）・-feature-mr（glab api + ファイル渡し + Draft: 接頭辞）・-spec（eval ID を SC-E）、計画タスク仕様のプレースホルダ表記 {{名前}} の統一（該当箇所を grep で一覧化して置換）、rules/ルール体系.md（frontmatter の category / paths / applies_when、本数、logger の glob）、要件 4 本（rules/design-docs・rules/ai-asset-design-docs・skills/10-task-overall-plan・自己改善ワークフロー機構）の受け入れ基準の節順と、自己改善ワークフロー機構.md のルールが禁じる「関連するドキュメント」節の削除、横断整合（自己改善ワークフロー機構.md・用語辞書・20-common-step-spec の節構成）の確認を行う

## DoD

- [x] 担当の要件定義書・仕様書が 20-common-step-requirement / -spec のテンプレートと固定節構成に沿って更新され、履歴（以前は〜）を書かず現在の正史だけになっている（requirement / issue / feature-mr / spec 仕様、計画タスク仕様の該当箇所、rules/ルール体系.md、要件 4 本）（根拠: requirement / issue / feature-mr / spec 仕様を pairs で更新（各 1〜3 か所、miss 0）、計画タスク仕様 6 本 + 実装 exec 仕様の該当行、rules/ルール体系.md 3 か所、要件 3 本の節順（design-docs / ai-asset-design-docs は例外フロー節の移動、自己改善ワークフロー機構.md は A〜J の小節化と関連ドキュメント節の削除）。履歴は書かず、変更は現在形の記述のみ）
- [x] 受け入れ条件 4（共通ステップ 9 本の SKILL.md と assets）が仕様のテスト観点に落ちている: SC-E01〜03 への改名、feature-mr の処理フロー 5 と FM-E の整合、issue の OUT ひな形と IS-E の整合（根拠: 20-common-step-spec の eval ID を SC-E01〜03 に改名（台帳 §6 と一致。SP-E の残存 0 件を grep で確認）。feature-mr 処理フロー 5 を SKILL.md と同じ glab api + ファイル渡し + Draft: 接頭辞にし FM-E01 の判定（ブランチ・開始コミット・draft 状態と本文）はそのまま成立。issue の OUT ひな形に追記テンプレートの「受け入れ条件（追加分）」を足し IS-E03（旧本文 + 追記）と整合）
- [x] プレースホルダ表記 <...> を使う箇所の一覧（ファイル・件数）が作業ログにあり、{{名前}} に統一されている（機械的な置換が危険な箇所は理由付きで残す）（根拠: 結果報告 0028「更新した文書 0030」に一覧を記載: grep -nE で 10-task-*.md を走査し、DoD の型の <アセット> <節> <ID> <対象> <コマンド> <行> <問い> <X> の 13 か所（ai-asset-implementation-plan 4 / design-feedback-plan 2 / implementation-plan 4 / investigation-plan 1 / ai-asset-design-plan 1 / design-plan 1）を {{名前}} に置換、実装 exec の完了前検査の形式を {{名前}} に。usage 表記（ticket.sh start <番号>・git diff --stat <基準点>・<連番>-<種類>.md・@<ファイル>・https://<ホスト>）は理由（シェルの慣習表記で検査対象と紛れる）付きで残した）
- [x] 要件 4 本の受け入れ基準の節が「メインフロー → 代替フロー → 例外フロー」の順・この文言になり、自己改善ワークフロー機構.md の「関連するドキュメント」節が削られ、内容は変わっていない（diff で確認）（根拠: design-docs / ai-asset-design-docs: 例外フロー節をメインフローの直後へ移動し、移動前後で行の多重集合が一致（diff of sorted lines が空）。自己改善ワークフロー機構.md: ### メインフロー を挿入し A〜J を #### に降格、関連するドキュメント節（7 行 + 区切り）を削除。見出しと削除した節以外の行の diff は 0。10-task-overall-plan.md: 既に メインフロー×3 → 代替 → 例外 → その他 の順で規定文言で始まるため変更なし（補足の後置は仕様が許容））
- [x] 横断文書（自己改善ワークフロー機構.md・rules/ルール体系.md・90_glossary）と用語が食い違っていない（変更なしならその確認を根拠に書く）（自己改善ワークフロー機構.md の変更要否、用語「承認単位」「自己強制」の追加要否を判断して記録）（根拠: 自己改善ワークフロー機構.md は関連ドキュメント節の削除と見出し構造の変更のみで受け入れ基準の内容は不変。90_glossary/ワークフロー用語.md に「承認単位」を追加（0028 で 4 文書が使う語。収録基準に当たる）。「自己強制」は DDR i0006-10 で使わず「保証」で書いたので追加不要と判断。rules/ルール体系.md の本数（8 + 7）と frontmatter キーは既存ルール 4 本の実態と一致）
- [x] ヘッドレス実行の帰結（止まる / 既定で進む）が変更ごとに仕様に書かれている（根拠: 結果報告「ヘッドレス実行で確認すること」に 0030 の 2 行（節順は直接の帰結なし / feature-mr の glab api は対話せず Draft: 接頭辞で draft を保証）を追記。仕様 feature-mr 処理フロー 5 に接頭辞の理由を書いた）
- [x] 他チケットの担当文書のうち参照先（台帳の番号・テスト ID・節名）を再読して文言が一致している（0028 の接頭辞 SC-E、0029 の節構成の判断）（根拠: 0028 の台帳 §6 の SC-E と 20-common-step-spec の SC-E01〜03 が一致。0029 の規約節の判断（Script 処理のサブ節）は 20-common-step-spec の固定節構成「Script 処理（テスト観点含む）」と矛盾しないことを再読して確認。0029 が足した CP008 は台帳 CP001–008 と commit-push 仕様の識別子表で一致）

## 作業内容

- 計画書の対応表（A1・A7・B1・B3・B5・G3・G4）とレポート 0013 の D-1・D-19〜D-21・D-28、レビュー F-16・F-23(a) の根拠を要件・仕様の文言に写す
- 20-common-step-requirement / -spec の手順で更新し、要件 4 本の節順は内容を変えずに並べ替える

## 作業ログ

### 現在地

- 済: 計画 0026 の 0030 行（A1・A7・B1・B3・B5・G3・G4）と D-1・D-19〜D-21・D-28、F-16・F-23 を読む → 要件 3 本の節順と機構要件の見出し・禁止節 → ルール体系 → 仕様 4 本 → プレースホルダ 13 か所 → 用語辞書 → 結果報告 0028 に 0030 の節を追記（md + HTML、check-html OK）→ このチケットの記入
- 完了: commit.sh → ticket.sh complete 0030 → push → 設計の切れ目（opus 敵対的レビュー → note）→ 0031

### うまくいったこと

- 節の移動は「行を並べ替えた後に sorted diff が空」で内容不変を機械的に示せた。機構要件は見出し以外の行の diff 0 で同じことを示した
- B5 は grep の一覧を先に作ったので、置換する 13 か所と残す usage 表記の線引きが明確になった

### うまくいかなかったこと

- 機構要件の見出し降格スクリプトで perl の置換回数の取り方を誤り（`() = s///g`）1 回やり直した。ファイルは無傷だったが、-i と die の組み合わせは事前に別ファイルで試すべきだった
- F-23(a) の「3 本が違反」を鵜呑みにせず読み直したら overall-plan は違反でなかった。レビュー指摘は件数まで検証してから作業に入る

### 仕様からの逸脱

- 人間レビュー: 承認④により opus 自己レビューで代替（この後の切れ目で 1 回）
- 実行者が main（全体計画の方針）

### 判断と根拠

- 節順は文書を直す（要件を緩めない）: ルールの機械検査の予告があり、移動は内容不変で済む
- 機構要件の A〜J は小節に降格: 10 見出しへの前置より読みやすい。仕様 requirement にこの許容（メインフローが長い要件書は #### の小節）を書いた
- ルール frontmatter のキー名は要件に書く: paths が既に要件にあり同じ「宣言の形」。markdown-docs ルール（未作成）を待つと収集・抽出の実装が読む形が決まらない
- プレースホルダは DoD の型だけ統一: {{名前}} はテンプレートのプレースホルダの形式で検査の対象。usage の <番号> を置換すると紛れる
- 用語辞書に「承認単位」: 4 文書で使う機構固有語。「自己強制」は追加しない
- ticket 要件に見出し重複の条件は足さない: 要件は外部的に「検査で拒否される」までで足り、条件は仕様の範囲

### 拒否・確認・迂回の記録

- なし

### 使った AI アセットと効き目

- 20-common-step-requirement 仕様（章順・節順の規定。自分で更新しつつ適用）・20-common-step-spec の固定節構成・ai-asset-design-docs ルール（要件書の形）
- 90_glossary/README.md のエントリ書式
- wip/tmp/apply-pairs.pl、wip/tmp/p30-apply.sh（節の移動と内容不変の確認）

### スコープ外で見つけたこと

- issue #6 の受け入れ条件 1「ルール 14 本」と要件の 15 本が食い違う → 全体まとめで issue に注記
- .claude/rules/ai-asset-design-docs.md（ルール本体）の「要件書の形」と要件の文言は一致（変更不要）

### AI アセットに反映すべき内容

- 20-common-step-requirement 仕様に書いた「メインフローが長い要件書は #### の小節を切ってよい」は requirements.template.md のガイドにも 1 行要る → 0031 の実装計画（テンプレートのコメント 1 行）か 3/3

### 備考

- スクリプト: wip/tmp/p30-apply.sh、pairs: wip/tmp/p30-pairs.txt、レポート追記: wip/tmp/rep-0030-{md,html}.txt。移動前の控え: wip/tmp/*.before
