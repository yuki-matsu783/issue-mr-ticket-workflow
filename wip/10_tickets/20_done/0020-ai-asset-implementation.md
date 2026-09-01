---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0019"]
executor: main
human_review: {required: true, reason: "中核（提供コマンド・lib）を含む実装。切れ目で 1 回（承認④により opus 自己レビューで代替）"}
adversarial_review: {required: false, reason: "実装の切れ目で 1 回"}
allow:
  write: [".claude/skills/20-common-step-ai-asset-creator/**", ".claude/skills/20-common-step-feature-mr/**", ".claude/skills/20-common-step-issue/**", ".claude/skills/20-common-step-requirement/**", ".claude/skills/20-common-step-spec/**", ".claude/evals/**", "wip/**"]
  ops: ["read"]
started_at: "2026-09-01T13:36:42+09:00"
completed_at: "2026-09-01T13:52:45+09:00"
base_sha: "71956c3"
---

# 0020 AI アセット実装 S4-2: SKILL.md 5 本と assets 6 本・eval 定義 5 本

## 目的

スクリプトを持たない共通ステップスキル 5 本の SKILL.md・テンプレートと、その eval 定義を仕様どおりに作る。eval は定義まで。

## DoD

- [x] 5 本の SKILL.md が各仕様の処理フロー・参照ナレッジと 1:1 で、対応表が作業ログにある（根拠: 作業ログ「判断と根拠」の対応表。手順の番号が各仕様の処理フロー番号と一致（spec は 1〜6、requirement は 1〜7、issue は 1〜6、feature-mr は 1〜6、ai-asset-creator は 1〜7）。5 本とも `skill.template.md` の節構成（frontmatter name / description + Use when、目的の段落、手順、参照、エラー時の対処）で、セッションのスキル一覧に 5 本が現れた）
- [x] assets（`mr-body.template.md` / `issue.template.md` / `issue-addendum.template.md` / `requirements.template.md`。`skill.template.md` / `eval.template.md` は 0019 で作成済み）が各仕様 OUT ひな形のとおりで、テンプレートが完成形として正しい frontmatter を持つ（根拠: mr-body = 概要 / 変更点（空の見出し）/ 動作確認（「MR 上のレビュー完了」のみ）/ 関連 Issue `- Closes #N`。issue = 種別 / 概要 / 詳細 / 受け入れ条件 / スコープ外 / 優先度。issue-addendum = 区切り `---` / 日付 / 追記の経緯 / 追記内容。requirements = frontmatter 5 項目（`type: requirement`。既存 42 本と同じ表記 → 逸脱 D-20）+ 概要 → ユーザーストーリー → 受け入れ基準（メイン / 代替 / 例外 / 整合）→ 前提条件 → 制約条件 → 依存関係 → 非機能要件、各章に 1 行ガイドのコメント。issue 本文・MR 本文は frontmatter を持たない形式のため対象外）
- [x] `.claude/evals/20-common-step-{ai-asset-creator,feature-mr,issue,requirement,spec}.md` が `eval.template.md` から作られ、AC-E / FM-E / IS-E / RQ-E / SP-E の各 3 件を定義し、未実行を明記している（根拠: `wip/tmp/eval-fill.sh` が `cp eval.template.md` → perl でプレースホルダ 8 個を置換して生成（5 本とも残り 0）。各ファイルの評価シナリオ表は仕様「テスト観点（eval）」の 3 行と eval ID で 1:1、「実行状況」に **未実行**）
- [x] プレースホルダ（`{{ }}`・`TODO`・`TBD`。テンプレート `assets/*.template.*` は対象外）と frontmatter の検査が 0 件（根拠: 新規 14 ファイルのうちテンプレート 4 本を除く 10 本に `grep -nE '\{\{|TODO|TBD'` → 規約の説明文（`TBD は理由付きで明示` 等・`{{ }}` の表記説明）以外 0 件。frontmatter: SKILL.md 5 本の `name` がディレクトリ名と一致し description に `Use when` を含む。eval 5 本は `type: eval` + title / description / tags / keywords）
- [x] 参照更新一覧の検索語で新規アセットに旧名が持ち込まれていない（0 件）（根拠: 新規 14 ファイルに `workflow-lib.sh|work-boundary.sh|merge-prep.sh|10-work-|20-task-gh-` → 0 件。CR も 0 ファイル）
- [x] `git diff --stat <base_sha>` が許可範囲内（根拠: `git diff --name-only 71956c3` は 5 スキルディレクトリ・`.claude/evals/`・`wip/` の 14 + レポート・チケットのみ。範囲外 0 件）
- [x] 実装結果レポート `wip/30_reports/0013-ai-asset-implementation.md` に担当ステップの節（作成・更新したアセットと仕様の節・テスト結果・検査結果・逸脱）を追記した（根拠: 「### 0020 S4-2」を 作成・更新したアセット / テスト結果 / 検査結果 に追加、逸脱 D-20・D-21 を追加）

## 作業内容

- 順: ai-asset-creator の SKILL.md → 他 4 本の SKILL.md と assets → eval 定義 5 本（`eval.template.md` から）
- 参考実装の `evals/evals.json` の形は取り込まず、`eval.template.md` の md 形式に揃える

## 作業ログ

### 現在地

- 済: 着手（`ticket.sh start 0020`）
- 済: SKILL.md 5 本（ai-asset-creator / feature-mr / issue / requirement / spec）
- 済: assets 4 本（mr-body / issue / issue-addendum / requirements）
- 済: eval 定義 5 本（`wip/tmp/eval-fill.sh` で `eval.template.md` から生成）
- 済: 検査（プレースホルダ / 旧名 / CR / frontmatter / 許可範囲）すべて 0 件
- 済: 対応表（下記「判断と根拠」）、レポート追記、DoD 記入
- 完了: `commit.sh` → `ticket.sh complete 0020`

### うまくいったこと

- `skill.template.md`（0019）の節構成にそのまま乗せられた。0019 の 4 本と書き味（冒頭段落に禁止事項、手順は仕様の処理フロー番号と一致、エラー表は状況 → 対処）が揃った
- eval 定義はテンプレートのコピー + プレースホルダ置換（perl）で機械的に作れた。仕様のテスト観点表の 3 行をそのまま評価シナリオに写し、添付ファイル列だけを足す形で済んだ
- 5 本ともセッションのスキル一覧に現れ、description の 1 行目が一覧の要約として読める長さに収まった

### うまくいかなかったこと

- Bash ツールで複数ファイルを 1 回のヒアドキュメントの列で書こうとしたら 3 回とも `unexpected EOF while looking for matching quote` で落ちた（小さなヒアドキュメント単体は通る。大きさか文字列の組み合わせが原因と見られるが特定していない）。Write ツールで 1 ファイルずつ書いて回避した。生成物への影響なし

### 仕様からの逸脱

- D-20: `requirements.template.md` の frontmatter を `type: requirement` にした。仕様（requirement 処理フロー 2）は `type: requirements` と書くが、既存の要件書 42 本はすべて `type: requirement` で、テンプレート由来の新規文書が既存と揃わないほうが害が大きい。仕様側の表記の修正をフィードバック計画（0022）へ
- D-21: `issue-addendum.template.md` に「受け入れ条件（追加分）」の小節（不要なら削る旨のコメント付き）を追記内容の下に置いた。仕様 OUT ひな形の 4 項目（区切り・日付・追記の経緯・追記内容）に無いが、追記した依頼を DoD に落とす鍵になる項目のため。仕様への反映（OUT ひな形に「受け入れ条件（任意）」を足す）を 0022 へ

### 判断と根拠

対応表（SKILL.md の節 ⇔ 仕様の節）:

| SKILL.md | 冒頭段落 | 手順 | 参照 | エラー時の対処 |
|---|---|---|---|---|
| ai-asset-creator | 禁止事項 6 項目 | 処理フロー 1〜7（2 の置き場表を転記、3 に skill.template の使い方、5 に eval.template のコピー、7 に完了検査とコミット prefix） | 参照ナレッジ 5 項目 + OUT ひな形 2 本 + 呼び出し元 | 禁止事項・処理フロー 1・4 の停止条件 + TR006 / CPxxx の伝播 |
| feature-mr | 禁止事項 5 項目 | 処理フロー 1〜6（4 に commit.sh / push.sh の実コマンド、5 に gh / glab の MR 作成コマンド） | 参照ナレッジ 3 項目 + OUT ひな形 + 後続（MR 本文更新・draft 解除の担い先） | 要件の例外フロー 6 件（CLI / ホスト / 未コミット / 途中状態 / 同名 / 既存 MR / 失敗）+ CP の伝播 |
| issue | 禁止事項 5 項目 + 呼出条件の宣言前提 | 処理フロー 1〜6（2 に検索コマンド 4 本、4・5 に gh / glab の作成・追記コマンドと「GitLab の長文送信」の引用） | 参照ナレッジ 3 項目 + OUT ひな形 2 本 + 長文送信の利用元 | 停止条件 4 件 + 再取得不一致 + 範囲外操作 + フック拒否 + glab フラグ追加時の手順 |
| requirement | 禁止事項 6 項目 | 処理フロー 1〜7（2 に cp コマンドと章順、3 に EARS と節順、5 に DDR の命名と節） | 参照ナレッジ 3 項目 + OUT ひな形 + DDR の決定 + 呼び出し元 | 禁止事項 6 項目 + 処理フロー 6・7 の返し方 |
| spec | 禁止事項 6 項目 | 処理フロー 1〜6（3 に種別ごとの節構成の表とエラー識別子の規則を転記） | OUT ひな形（持たない理由）+ 参照ナレッジ 3 項目 + 手本 3 本 + 呼び出し元 | 禁止事項 6 項目 + 処理フロー 1・5 の検査 + 台帳への追加 |

- assets の置き場は各スキルの `assets/`（仕様 OUT ひな形のパスどおり）。`spec` はテンプレートを持たない（仕様 OUT ひな形の決定どおり。SKILL.md の参照に理由を書いた）
- テンプレートのプレースホルダは `{{大文字_名}}`（0017 の ticket.template・0019 の skill / eval.template と同じ表記）。ガイドは HTML コメントで、記入時に消す旨を requirement の手順 2・7 に書いた
- eval の「添付ファイル」列は、シナリオを再現するために要るフィクスチャ（テンプレート・既存文書・仕様書）を挙げ、無ければ「なし」
- 比較条件の without は「SKILL.md を読み込まず CLAUDE.md と要件・仕様だけ」に統一した（スキルの指示文の効果だけを測る。仕様書まで外すと「知らないからできない」と区別がつかない）

### 拒否・確認・迂回の記録

- なし（フック・提供コマンドの拒否なし。Bash のヒアドキュメント失敗は Write ツールで代替したが、ワークフロー上の迂回ではない）

### 使った AI アセットと効き目

- `20-common-step-ai-asset-creator/assets/skill.template.md`・`eval.template.md`: 5 + 5 本の骨格。節の抜けが起きない
- `20-common-step-ticket`（`ticket.sh start`）・`20-common-step-commit-push`（`commit.sh` / `push.sh`）: 状態遷移とコミット。手作業なし
- 0019 の SKILL.md 4 本: 書き味の手本（冒頭段落・手順の番号付け・エラー表の型）

### スコープ外で見つけたこと

- 仕様 `20-common-step-requirement` 処理フロー 2 の `type: requirements` は既存文書の `type: requirement` と食い違う（D-20）。同様に、要件書の章「他のスキル・機構との整合」は仕様では「その他の細かい記述（規約・整合）」と呼ばれており、見出しの規定文言が 2 通りある
- `00-workflow-issue-mr-driven/assets/issue-addendum.template.md`（旧ワークフロースキルの同名テンプレート）が残っている。3/3 のワークフロースキル置き換えで整理する対象
- `glab api projects/:id/merge_requests` の `title=Draft: ...` は GitLab の draft 規約（タイトル接頭辞）に依存する。仕様 feature-mr の処理フロー 5 は `glab mr create --draft` 相当の記述で切れており、API 経由での draft 指定方法は仕様に明記されていない（SKILL.md では接頭辞方式を書いた）

### AI アセットに反映すべき内容

- 仕様 `20-common-step-requirement`: `type: requirements` → `type: requirement`（D-20）。issue 仕様 OUT ひな形に addendum の「受け入れ条件（任意）」（D-21）。feature-mr 仕様 処理フロー 5 に GitLab API 経由の draft 指定（タイトル接頭辞 `Draft:`）を明記 → いずれも 0022 で棚卸し
- `skill.template.md` の `{{PURPOSE}}` は「冒頭段落 = 禁止事項の要約」として使われている（0019・0020 とも）。テンプレートのガイドにその旨を書くと揺れが減る → 0022

### 備考

- eval の生成スクリプト `wip/tmp/eval-fill.sh` は使い捨て（gitignore 対象）。再生成が要るときは同じ引数で再実行できる

### うまくいったこと

### うまくいかなかったこと

### 仕様からの逸脱

### 判断と根拠

### 拒否・確認・迂回の記録

### 使った AI アセットと効き目

### スコープ外で見つけたこと

### AI アセットに反映すべき内容

### 備考
