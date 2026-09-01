---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0015", "0020"]
executor: main
human_review: {required: true, reason: "中核（提供コマンド・lib）を含む実装。切れ目で 1 回（承認④により opus 自己レビューで代替）"}
adversarial_review: {required: true, reason: "実装の切れ目。差分全体（0013〜0021）を対象に 1 回"}
allow:
  write: [".claude/rules/**", "wip/**"]
  ops: ["read", "build-test", "hook-test"]
started_at: "2026-09-01T14:28:07+09:00"
completed_at: "2026-09-01T14:49:07+09:00"
base_sha: "5b33582"
---

# 0021 AI アセット実装 S4-3・S5-1: ルール 3 本（logger / design-docs / ai-asset-design-docs）と参照更新・HTML 遡及

## 目的

成果物ルール 3 本を要件と章スキーマどおりに書き、参照更新一覧の再検索と既存計画書・レポートの HTML 遡及作成で本 issue の実装を閉じる。

## DoD

- [x] `.claude/rules/{logger,design-docs,ai-asset-design-docs}.md` が各要件の「ルールが定める内容」を満たし、7 章固定・該当なしは根拠 1 行・`paths` を frontmatter に持つ（根拠: 3 本とも `## ` 見出しが 適用範囲 / 構造・配置 / 書式・可読性 / セキュリティ / 堅牢性 / パフォーマンス / テスト・機械的検査 の順（grep で確認）。該当なしは design-docs・ai-asset-design-docs のセキュリティ / パフォーマンスで根拠 1 行付き。frontmatter に `paths`（logger: scripts と hooks の sh、design-docs: `docs/**`、ai-asset-design-docs: `.claude/docs/**`）。logger は要件の必須項目 4 つ（使い方 / レベル / 内部仕様の参照 / 禁止）を 構造・配置 / 書式・可読性 / 堅牢性 / セキュリティ に配置。design-docs / ai-asset-design-docs は要件の各節（配置・正史・書き分け・DDR・用語辞書・1:1:1・外部視点・要件書の形・例外）をすべて章に配置）
- [x] 参照更新一覧の検索語を再実行し、件数が計画書の記録から増えていない（根拠: `workflow-lib.sh` 1 / `work-boundary.sh` 26 / `merge-prep.sh` 26 / `10-work-` 31 / `20-task-gh-` 25 — 計画書の値と同数。旧ワークフロースキル 2 本の外では 0 件）
- [x] `wip/20_plans/*.md`・`wip/30_reports/*.md`（付録を除く）に同名の HTML があり、全件 `check-html.sh` で `OK:`。`wip/push-check-skip.md` を削除した（根拠: 計画 3 本（0002 / 0006 / 0011）・レポート 3 本（0003 / 0008 / 0013）の HTML を作り、6 本とも `OK: 検査 7 項目すべて通過`。0011 / 0003 は 0018 の試し埋めを正式配置。`wip/push-check-skip.md` は削除し、完了時の `push.sh` は項目 3 を含む 4 項目を実施）
- [x] `run-tests.sh --ids` が全通過し、ID 一覧が各仕様の「テスト観点」と一致する（根拠: `OK: 14 本 / 55 件`、FAIL なし、重複なし。CP 7 / LG 5 / SS 4 / FR 5 / TR 5 / TICKET 11 / RV 6 / HK 12（§11 の 14 件のうち HK-T01・T09 は 2/3）= 55。突合はレポート「テスト結果 0021（最終）」）
- [x] AI アセット実装結果レポート `wip/30_reports/0013-ai-asset-implementation.md`（+ HTML）に 0013〜0021 の節が揃い、exec 仕様 OUT ひな形の節（アセット一覧と仕様の節・テスト結果（機械 / eval 未実行）・検査結果・逸脱一覧・想定と異なった点・残課題）で集約されている（根拠: 「作成・更新したアセット」に 0013 / 0014 / 0016 / 0017 / 0018 / 0019 / 0020 / 0015 / 0021 の 9 節、「テスト結果」「検査結果」に各チケットの節、要約・逸脱 D-1〜D-28・想定と異なった点・残課題（0022 / 2/3 / 3/3 への送り分け）を記入。HTML は `report.template.html` から作り `check-html.sh` OK）
- [x] プレースホルダ（`{{ }}`・`TODO`・`TBD`。テンプレート `assets/*.template.*` は対象外）と frontmatter の検査が 0 件（根拠: ルール 3 本で 0 件、HTML 6 本は RV001 で 0 件。ルールの frontmatter は type / title / description / tags / keywords / category / paths）
- [x] 参照更新一覧の検索語で新規アセットに旧名が持ち込まれていない（0 件）（根拠: ルール 3 本と HTML 6 本に旧名 5 語なし。CR なし）
- [x] `git diff --stat <base_sha>` が許可範囲内（根拠: `git diff --name-only 5b33582` は `.claude/rules/**`（3 ファイル）と `wip/**`（HTML 6・レポート md・skip 記録の削除）のみ）

## 作業内容

- 順: ルール 3 本 → 再検索 → HTML 遡及 → skip 削除 → 全テスト → 結果レポート
- 結果レポートには 0013〜0021 の作業ログ「仕様からの逸脱」を集約し、0022 の入力にする

## 作業ログ

### 現在地

- 済: ルール 3 本 → 再検索 → HTML 遡及（6 本）→ skip 記録の削除 → 全テスト → 結果レポートの集約（要約・逸脱・残課題）と HTML
- 完了: `commit.sh` → `ticket.sh complete 0021` → 敵対的レビュー（opus）は切れ目の処理で実施

### うまくいったこと

- ルール 3 本は要件の節と 7 章の対応を先に決めてから書いたので、「該当なし」の判断（セキュリティ・パフォーマンス）に迷わなかった
- HTML は 0018 の試し埋め 2 本（0011 / 0003）がそのまま正式配置でき、残り 4 本もテンプレートの節に md の内容を当てはめるだけで `check-html.sh` が初回から通った
- 参照更新の再検索は計画書に検索コマンドと件数が残っていたので、同じコマンドで機械的に突合できた

### うまくいかなかったこと

- 0015 でレポートに差し込んだ節の見出しが前の行に連結されていた（`$(cat)` の末尾改行の欠落）。今回の集約で見つけて直した。差し込みのたびに見出し数を数える検査を入れた
- 実装結果レポートの HTML は節が多く（9 チケット分）、テンプレートの「実施した内容と結果」に 1 チケット 1 章で並べると長い。md の表をそのまま写すより、チケットごとの結論と根拠だけに絞った

### 仕様からの逸脱

- D-28: 成果物ルールの frontmatter に `category: artifact` と `paths` を置いた（キー名は `markdown-docs` ルール未作成のため未定義。D-1 と同じ判断）。詳細はレポート

### 判断と根拠

- logger ルールの `paths` は要件の「sh（スキルの scripts・フック）を書くとき」を glob（`.claude/skills/*/scripts/**/*.sh`、`.claude/hooks/**/*.sh`）で表した。テストの sh も含む（テストもログを書くことがあり、標準出力に混ぜない規約は同じ）
- design-docs と ai-asset-design-docs は「共通する規定は両方に書き、内容を食い違わせない」（要件）に従い、DDR・用語辞書・正史の規定を同じ文言で両方に置いた（片方から参照する形にしない。`ai-asset-design-docs` は 1 本で揃う要件）
- 0011 / 0003 の HTML は試し埋めの再利用。md がその後変わっていないこと（0011 は 0023 の修正後に試し埋め、0003 は 0007 以降変更なし）を確認した
- レポートの要約・残課題は 0013〜0021 の作業ログ「スコープ外で見つけたこと」「AI アセットに反映すべき内容」を送り先（0022 / 2/3 / 3/3 / 未確認 / 小さな改善）で分けて集約した
- 敵対的レビュー（このチケットの `adversarial_review: required: true`）は、切れ目の処理として `ticket.sh complete` の後に opus のサブエージェントで 0013〜0021 の差分全体を対象に行う（指摘は同種の追加チケットに落とす）

### 拒否・確認・迂回の記録

- なし

### 使った AI アセットと効き目

- `20-common-step-report-view`（`report.template.html` / `plan.template.html`、`check-html.sh`）: 6 本の HTML を同じ骨格で作れ、必須節の欠落とプレースホルダの残りを機械的に検出できた
- `20-common-step-shell-script`（`run-tests.sh --ids`）: 最終の全通過と ID の突合が 1 コマンド
- `20-common-step-ticket` / `20-common-step-commit-push`: 状態遷移とコミット・push（skip 記録なしで 4 項目）

### スコープ外で見つけたこと

- `ルール体系` 要件の成果物ルール一覧で logger の適用範囲は「sh を書くとき」と書かれ、他のルールのような glob ではない。`paths` の表現に揺れがある
- 実装結果レポートの節「作成・更新したアセット」は 0015 が 0020 の後ろに並んでいる（`next` の順で書いたため）。読み手には S 番号順の方が追いやすい

### AI アセットに反映すべき内容

- `markdown-docs` ルール（未作成）に成果物 / 行動ルールの frontmatter（`category` / `paths` / `applies_when`）を明記 → 0022（D-28）
- `20-common-step-report-view` の SKILL.md に「md を機械的に差し込んだ後は見出しの数を数える」を添えるか → 0022 で判断（規約というより作法）
- `ルール体系` 要件の logger の適用範囲を glob 表記に揃える → 0022

### 備考

- `wip/push-check-skip.md` を削除したので、以後の `push.sh` は項目 3（md / html の対）を実施する。新しい計画書・レポートを書いたら同じチケットで HTML も作る

### うまくいったこと

### うまくいかなかったこと

### 仕様からの逸脱

### 判断と根拠

### 拒否・確認・迂回の記録

### 使った AI アセットと効き目

### スコープ外で見つけたこと

### AI アセットに反映すべき内容

### 備考
