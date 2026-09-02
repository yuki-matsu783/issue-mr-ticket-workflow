---
type: report
title: 調査結果 — 置き場依存箇所と issue #20 の 5 論点の現状
description: apl/ 配下への置き場変更で書き換えが要る箇所の一覧（行番号つき）と、issue #20 が挙げる 5 論点（アプリ向け節構成・置き場の一般化・識別子台帳・受け入れ条件の対応表・機械的検査）の現状の結論
tags: [report, investigation, apl, design-docs]
keywords: [調査結果, 置き場, apl, scope-limits, design-docs, 要件定義書, 仕様書, TB識別子, 機械的検査]
---

# 調査結果 — 置き場依存箇所と issue #20 の 5 論点の現状

## 対象

- issue: #20 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/20
- PR: #25 https://github.com/yuki-matsu783/issue-mr-ticket-workflow/pull/25
- チケット: 0003-investigation、0005-investigation（敵対的レビュー指摘の反映）
- 計画: `wip/20_plans/0002-investigation-plan.md`

## 結論の要約

1. **置き場を `apl/vscode-ticket-board/` に変えると、`src/vscode-ticket-board/` の中身をそのまま持ち上げる形になり、拡張のビルド設定は 1 文字も変えずに済む**（Q8）。`apl/<アプリ名>/` がアプリのルートで、その下に既存の `src/` `test/` `package.json` が入り、設計文書が `docs/` として加わる
2. 拡張のチケット走査はワークスペースフォルダ基準で、拡張自身の位置に依存しない（Q9）。移動しても壊れない
3. 置き場に依存する記述は **7 分類・のべ 45 ファイル**。うち**本文・設定の書き換えが要るのは 28 ファイル**で、残る 17 はアプリのソースの単純な移動（Q1）
4. 機械が読む値は `scope-limits.json` の 12 行、そのテストの 10 行、`design-docs` ルールの `paths` 1 行の 3 か所。`paths` を読むフックは現時点で未実装（`.claude/hooks/` のイベントディレクトリはすべて空）
5. 機械的検査は **issue #24 に寄せるのが妥当**。ただし #24 は「仕様書（`10_spec/`）の形の検査」を明示的にスコープ外にしており、#20 の詳細 §5 が挙げる動機（仕様書の自己矛盾）はそこに落ちる。申し送りが要る（Q6）
6. 要件定義書に「issue の受け入れ条件との対応」を章として足すと、`ai-asset-design-docs` の章順の規定（7 章固定）と衝突する（Q5）

## Q1: 置き場に依存している記述

### 仕分けの基準

`src/**` `docs/**` `` `docs/` `` `` `src/` `` `src/vscode-ticket-board` `docs/00_requirement` などパス区切りを含む形で全リポジトリを検索し、次の基準で分けた。

| 判定 | 基準 | 例 |
|------|------|-----|
| **書き換えが要る** | このリポジトリの実在の置き場を指しており、置き場が変わると指し先が壊れるか、記述が事実と食い違う | `scope-limits.json` の `"allow": ["docs/**"]`、`design-docs` ルールの `paths` |
| **据え置き** | 架空のプロジェクトを想定したサンプル値、またはグロブ照合そのものを試すテストの入力で、実在の置き場を指していない | `test_scope.sh:65` の `match 'src/**' 'src/a/b/c.ts'`、`evals.json` の `src/login.ts` |
| **移動だけ** | ファイル自身が移動対象で、本文に置き場の記述を持たない | 拡張のテストコード、`docs/00_requirement/vscode-ticket-board.md` |

### 書き換えが要る箇所（行番号つき）

| # | ファイル | 行 | 現在の記述（要点） |
|---|---------|----|--------------------|
| A1 | `.claude/hooks/config/scope-limits.json` | 11〜16, 18〜23（12 行） | 各 type の `allow` / `deny` に `"src/**"` `"docs/**"`。`design` と `design-feedback` の `allow` が `["docs/**"]`、`implementation` の `allow` が `["src/**", "tests/**"]` |
| A2 | `.claude/hooks/lib/tests/test_scope.sh` | 29〜31, 95, 96, 103, 125, 126, 128, 129（10 行） | A1 のフィクスチャ JSON と、`design` が `src/a.ts` を拒否・`implementation` が `docs/a.md` を拒否・`implementation` が `src/a/b.ts` を許可するアサーション、上限外宣言のチケット |
| B1 | `.claude/rules/design-docs.md` | 3, 4, 8, 11, 13, 17, 22（7 行） | frontmatter の `title` / `description` / `paths: ["docs/**"]`、H1、冒頭説明、適用範囲、構造・配置の 4 ディレクトリ |
| B2 | `.claude/rules/ai-asset-design-docs.md` | 4（1 行） | `description` の「`docs/` には効かない（`design-docs` が持つ）」 |
| C1 | `.claude/skills/20-common-step-requirement/SKILL.md` | 4, 24, 42（一般化が要る 3 行） | `description` の「`.claude/docs/00_requirement/` 配下」、処理フロー 2 の `cp` 先、処理フロー 10 の DDR の置き場。18・19・51 行は自身の設計文書への参照で据え置き |
| C2 | `.claude/skills/20-common-step-spec/SKILL.md` | 5, 21, 25〜29（一般化が要る 2 行 + 種別表 5 行） | `description` の「`.claude/docs/10_spec/` 配下」、処理フロー 1 の要件の存在確認と置き場、種別表（スキル / エージェント / フックの 3 行） |
| D1〜D9 | `.claude/docs/00_requirement/` の要件書 9 本 | `skills/10-task-design-plan.md`:65,72 / `skills/00-workflow-issue-mr-driven.md`:144,160 / `skills/10-task-overall-plan.md`:56 / `skills/10-task-design-exec.md`:13,59 / `skills/10-task-implementation-exec.md`:58 / `rules/design-docs.md`:13,37,46,83 / `rules/ルール体系.md`:88,102 / `rules/ai-asset-design-docs.md`:13,19,86,100 / `自己改善ワークフロー機構.md`:120 | 設計タスクの対象を「`docs/` 配下」と書いている箇所、ルールの適用範囲の表 |
| D10〜D13 | `.claude/docs/10_spec/` の仕様書 4 本 | `skills/10-task-design-plan.md`:17,30,43,57 / `skills/00-workflow-issue-mr-driven.md`:89 / `skills/10-task-design-exec.md`:31,42 / `フック共通仕様.md`:170,186〜193 | 同上と、許可範囲の表（`scope-limits.json` の写し） |
| E1 | `.claude/evals/design-docs.md` | 13, 27（2 行） | 「`paths`（`docs/**`）の一致で読み込まれている」 |
| F1 | `docs/10_spec/vscode-ticket-board.md` | 28, 426 | 28 行が配置図の `src/vscode-ticket-board/`、426 行が識別子の台帳の記述。72 行は `tsconfig.json` の引用で据え置き |
| F2 | `docs/20_ddr/i0013-01-成果物の置き場をsrc配下にする.md` | frontmatter のみ | **本文は変更しない**（下記） |
| G1 | `src/vscode-ticket-board/README.md` | 5, 6, 30 | 要件・仕様へのリンクと「このディレクトリ（`src/vscode-ticket-board/`）で実行する」 |
| G2〜G6 | `src/vscode-ticket-board/src/core/{scan,board,render,ticket,frontmatter}.ts` | 各ファイル 3〜5 行目（計 6 行） | ヘッダコメントの `仕様: docs/10_spec/vscode-ticket-board.md`。`frontmatter.ts` は加えて `設計の経緯: docs/20_ddr/i0013-03-…md` |

### マージ済み DDR の扱い

`design-docs` ルール（`:44`）は「マージ済みの DDR は本文を変更しない。後続の決定で無効になったときは frontmatter の状態（置き換え済み / 廃止）と置き換え先だけを更新する」と定める。issue #20 の追記受け入れ条件も `i0013-01` について「置き換え済みとして frontmatter だけ更新される」と書いている。

したがって `docs/20_ddr/i0013-01`（本文 8 か所に `src/` の記述）と `i0013-02`（4 か所）は、**移動はするが本文は直さない**。その時点の決定として正しいまま残す。置き場の変更はフェーズ 2 で起こす新しい DDR が担う。

### 集計

| 分類 | ファイル数 | うち本文・設定の書き換えが要る |
|------|-----------|------------------------------|
| A. 機械が読む設定 | 2 | 2 |
| B. ルール本体 | 2 | 2 |
| C. スキル本体 | 2 | 2 |
| D. AI アセット設計文書（`.claude/docs/`） | 13（要件 9 / 仕様 4） | 13 |
| E. eval 定義 | 1 | 1 |
| F. アプリの設計文書（`docs/`） | 7 | 2（うち 1 は frontmatter のみ） |
| G. アプリのソース（`src/vscode-ticket-board/`） | 18 | 6 |
| **計** | **45** | **28** |

ルートの `.gitignore` と `.gitattributes` には `src/` `docs/` を前提にした行が無い。`.claude/settings.json` `README.md` `CLAUDE.md` にも無い。`.claude/agents/` は空。拡張のビルド成果物の除外は入れ子の `src/vscode-ticket-board/.gitignore` が担っており、これも一緒に移動する。

### 据え置き（実在の置き場を指さないサンプル値）

書き換えないが、次に読む人が同じ仕分けを再現できるよう列挙する。

| ファイル | 行 | 理由 |
|---------|----|------|
| `.claude/hooks/lib/tests/test_scope.sh` | 64〜67, 91, 134〜136（9 行） | グロブ照合そのものを試す入力と、承認スコープの例 |
| `.claude/skills/20-common-step-shell-script/scripts/tests/test_frontmatter.sh` | 25, 65 | `src/auth/**` — 架空プロジェクトのチケットの `allow.write` |
| `.claude/skills/00-workflow-quick-request/evals/evals.json` | 34, 38 | `src/login.ts` — 評価シナリオの架空のファイル |
| `.claude/hooks/lib/tests/test_hook_common.sh` | 153, 157, 164, 166, 168, 174, 235, 237 | `src/x.ts` / `src/a.ts` — 照合の入力 |
| `.claude/skills/20-common-step-commit-push/scripts/tests/test_commit.sh` | 68, 73, 81, 83, 85 | 一時リポジトリ内に作る `src/` |
| `.claude/docs/10_spec/agents/task-executor.md` | 49 | 許可範囲の説明の例示 |
| `.claude/docs/10_spec/agents/adversarial-reviewer.md` | 43, 55 | 同上 |
| `.claude/docs/10_spec/skills/20-common-step-commit-push.md` | 46, 50 | コミット対象の例示 |
| `.claude/docs/10_spec/hooks/20-PreToolUse/workflow-guard.md` | 102 | 判定例 |
| `src/vscode-ticket-board/test/fixtures/0011-implementation.md` | 20 | 実物のチケットの写し（下記） |

`test/fixtures/0011-implementation.md` の `allow.write: ["src/**", "wip/**"]` は据え置きでよい。唯一の利用者 `test/ticket.test.ts:167-179`（TB-T06）が `issues` / `number` / `title` / `ticketType` / `executor` / `humanReview` / `adversarialReview` しかアサートしておらず、`allow` を参照していない。フィクスチャ自身が「ticket.sh が実際に書き出すチケットの写し」と書いているとおり、当時のチケットの実物として残すのが正。

## Q2: `20-common-step-requirement` の置き場の決め打ち

置き場を書いているのは 6 行で、いずれも `.claude/docs/` を literal で持つ。

| 行 | 記述 | 一般化 |
|----|------|--------|
| 4（description） | 「要件定義書（.claude/docs/00_requirement/ 配下、対象と同名 1:1）」 | 要る |
| 18・19 | 自身の要件・仕様への参照 | 不要（自身の設計文書の場所） |
| 24（処理フロー 2） | `cp …/requirements.template.md .claude/docs/00_requirement/<種別>/<対象名>.md` | 要る |
| 42（処理フロー 10） | DDR の置き場 `.claude/docs/20_ddr/` | 要る |
| 51（参照） | DDR の手本の置き場 | 不要 |

仕様書側（`.claude/docs/10_spec/skills/20-common-step-requirement.md`）は IN / OUT 表（38 行目）と IN / OUT サンプル（42・43 行目）が同じく `.claude/docs/` 固定。

**一般化の単位**: 置き場を決めているのは「ルート」だけで、その下の `00_requirement/<種別ディレクトリ>/<対象名>.md` という形は AI アセットとアプリで共通に使える。`<設計文書ルート>` を 1 つの変数として導入し、AI アセットなら `.claude/docs/`、アプリなら `apl/<アプリ名>/docs/` と決まる形にすれば足りる。種別ディレクトリはアプリでは使わない（1 アプリ 1 対象なので `docs/00_requirement/<アプリ名>.md`）点だけが差分。

## Q3: `20-common-step-spec` の種別表とアプリ向け節構成

種別表は SKILL.md の 25〜29 行目にあり、スキル / エージェント / フックの 3 行。正は仕様書 `.claude/docs/10_spec/skills/20-common-step-spec.md`。

DDR `i0013-02`（`:21`）が定めた実際の 10 節は次のとおりで、`docs/10_spec/vscode-ticket-board.md` の見出し（13 / 25 / 86 / 128 / 147 / 282 / 346 / 424 / 440 / 466 行）と完全に一致する。

```
概要・禁止事項 / 配置 / 起動と入口 / モジュール構成 / データの形 / 処理フロー /
HTML の構造と CSP / 不備の識別子とメッセージ / テスト観点 / 要件との対応
```

**issue #20 の本文は 7 番目を「画面（HTML）の構造」と書いているが、DDR と実際の仕様書は「HTML の構造と CSP」**。issue の記述は後から書かれた要約で、正は DDR。

**そのまま採用できるか**: 7 番目は VS Code の Webview に固有で、CLI アプリやサーバに一般化できない。「HTML の構造と CSP」を一般名（例: 「画面・出力の構造」）に置き換えるか、任意節にするかの判断が要る。他の 9 節はアプリ種別に依らず使える。

## Q4: アプリのエラー識別子の台帳

| | 機構（AI アセット） | アプリ（チケットボード拡張） |
|---|---|---|
| 台帳 | `.claude/docs/10_spec/フック共通仕様.md` §6（112・136・138 行目） | `docs/10_spec/vscode-ticket-board.md`（426 行目）が兼ねる |
| 採番の単位 | 接頭辞 + 3 桁。接頭辞をこの表に追加してから使う | `TB` + 3 桁。`TB001`〜`TB007` |
| 衝突の防止 | 台帳が全アセットの接頭辞を集約する | 仕様書 1 本の中だけ。他のアプリと接頭辞が衝突しうる |

**「アプリは台帳の対象外」は台帳側に明記されていない。** `フック共通仕様.md:138` は「新しいエラー識別子の接頭辞・範囲はこの表に追加してから使う」としか書いておらず、AI アセット限定とは書いていない。アプリを対象外とする根拠は `docs/20_ddr/i0013-02:32`（識別子の接頭辞についての理由）と `docs/10_spec/vscode-ticket-board.md:426` の側にある。

方針としては次の 2 案があり、設計で決める。どちらを採っても、台帳側（`フック共通仕様.md` §6）に「アプリの接頭辞は対象外」を追記するかどうかの判断が付いてくる。

- 案 1: 仕様書が兼ねる形を明文化し、接頭辞の衝突は「アプリごとに 2 文字を選び、`apl/` 配下の既存仕様書を grep して確かめる」運用にする
- 案 2: `apl/` 直下にアプリ横断の台帳を 1 本置く（アプリが増えたときだけ効く。今は空に近い）

## Q5: 要件定義書テンプレートと「issue の受け入れ条件との対応」

テンプレート `.claude/skills/20-common-step-requirement/assets/requirements.template.md` の章見出しは 11 / 25 / 37 / 107 / 115 / 125 / 133 行目の 7 章。

```
概要 / ユーザーストーリー / 受け入れ基準 / 前提条件 / 制約条件 / 依存関係 / 非機能要件
```

`ai-asset-design-docs.md:33`（「要件書の形」）が「章順は 概要 → ユーザーストーリー → 受け入れ基準 → 前提条件 → 制約条件 → 依存関係 → 非機能要件」と**この 7 章を固定**し、`:43` が禁止節（関連するドキュメント / レビュー記録 / 変更履歴）を挙げている。`design-docs` 側には要件書の形の規定が無い（Q7）。

したがって「issue の受け入れ条件との対応」を 8 章目として足すと、章順の規定と衝突する。選べる形は 3 つ。

| 案 | 置き場 | 規定の変更 | 既存文書への影響 |
|----|--------|-----------|----------------|
| 案 A | 8 章目として追加 | `ai-asset-design-docs` の章順を**更新**し、`design-docs` に同じ規定を**新設**する | 既存 46 件（`.claude/docs/00_requirement/` 45 + `docs/00_requirement/` 1）が章不足になる |
| 案 B | 「概要」章の中の小節 | 不要 | 既存 46 件は小節を持たないまま残る（案 A と同じ） |
| 案 C | 要件書に置かず設計計画書に置く | 不要 | 正史に残らず、マージ後に追えない。issue #20 の条件 4 を満たさない |

**案 A と案 B の差は「規定の変更要否」であって「既存文書への影響」ではない。** どちらでも既存 46 件は新しい記載を持たない状態で残り、その扱い（新規・更新時のみ適用するか、一括で直すか）は別途決める（issue #8 と重なる）。表は定型（箇条書き・表・EARS・図）側なので、自由記述 600 字の制限には抵触しない。

セルフレビューは仕様書（`.claude/docs/10_spec/skills/20-common-step-requirement.md:138-159`）の 13 項目として定義され、SKILL.md 処理フロー 12（`:44`）が全件確認する形。ここに「対応表の行数が issue の受け入れ条件の数と一致する」を 14 項目目として足せる。

## Q6: 機械的検査の要否

issue #24（設計文書検査の実装）の受け入れ条件は 6 件。

- 検査の対象と項目を定めた仕様書がある（どのルールの規定をどの項目が担うかの対応が付いている）
- 検査を実行する手段があり、未充足を全件列挙して終了コードで区別できる
- 既存の要件定義書 45 件に対して実行でき、違反の一覧が出せる
- 検査のテストがある（正常系・違反ごとの異常系・負のコントロール）
- `ai-asset-design-docs` と `design-docs` の「テスト・機械的検査」の節が、将来形ではなく実在の手段を指している
- `20-common-step-requirement` のセルフレビュー項目のうち、機械化できたものが検査に委譲されている

**#24 は #20 の条件 5 を完全には含まない。** 2 つのずれがある。

1. #24 の**スコープ外**に「仕様書（`10_spec/`）の形の検査」が明記されている。一方 #20 の詳細 §5 が挙げる動機は「仕様書の自己矛盾（ある関数を宣言しつつ『提供しない』と書いていた）」で、まさに #24 のスコープ外
2. #24 の「既存の要件定義書 45 件」は `.claude/docs/00_requirement/` の実測件数と一致する。アプリ側（`docs/` / `apl/`）は #24 の視野に入っていない

**推奨: 今回は検査を実装せず、issue #24 に寄せる。** ただし申し送りを 2 件付ける。

| 申し送り | 内容 |
|---------|------|
| 対象ルート | 検査の対象ルートが `.claude/docs/` と `apl/<アプリ名>/docs/` の 2 つになる。#24 の設計は最初から両方を見る形にする |
| 仕様書の形の検査 | #24 のスコープ外。#20 の詳細 §5 の動機（仕様書の自己矛盾）はどこで担うかを別途決める（#24 のスコープを広げるか、別 issue を起こすか） |

寄せる理由は、#24 が検査の仕様・実行手段・テスト・既存 45 件への適用までを 1 セットで要求しており、#20 の中で部分的に作ると #24 が作り直すことになるため。#20 の条件 5 は「要否が判断され、入れる場合は検査項目が定義されている」なので、判断と根拠を DDR に残せば満たせる。

## Q7: 2 つのルールの重複と食い違い

章立ては両者とも 適用範囲 / 構造・配置 / 書式・可読性 / セキュリティ / 堅牢性 / パフォーマンス / テスト・機械的検査 の 7 章で同一（`design-docs.md`:15/20/28/38/42/49/53、`ai-asset-design-docs.md`:15/20/29/45/49/56/60）。行数は 56 行と 64 行。

| 規定 | design-docs | ai-asset-design-docs | apl/ 化で起きること |
|------|------------|---------------------|-------------------|
| 適用範囲 | `docs/**`（`:8`） | `.claude/docs/**`（`:8`） | `design-docs` を `apl/**` に変える。`ai-asset-design-docs:4` の相互参照も直す |
| 4 ディレクトリ構成 | `:22` | `:22` | 変わらない（アプリ側のルートが深くなるだけ） |
| DDR の命名・不変性 | `:24`, `:44` | `:26`, `:52` | 変わらない |
| 用語辞書 | `:26`, `:31`〜`:34` | `:28`, `:41`〜`:42` | 変わらない |
| 機械的検査 | `:55`（将来形） | `:62`（将来形） | Q6 のとおり #24 に寄せる |

**`design-docs` に無く `ai-asset-design-docs` にだけある規定は 4 件。** issue #20 の条件 6・8 が求める「相互に矛盾しない」の対象はこの 4 件。

| # | 規定 | ai-asset-design-docs | 内容 |
|---|------|---------------------|------|
| 1 | 要件書の形 | `:33`〜`:40` | 章順（7 章固定）・EARS の節順・フロー節の判定順・メインフローの mermaid とノード数 15・識別子の対応・規約節の命名と 3 節以内・自由記述 600 字・禁止節 |
| 2 | 仕様書は要件書より先に変えない | `:53` | 「要件側の誤り・不足を仕様側の辻褄合わせで吸収しない」 |
| 3 | 「要件との対応」表の全件カバー | `:63` | 「行数が一致する」。実装漏れ（実現箇所の無い要件）と過剰仕様（要件の無い節）を書き終わりに確かめる |
| 4 | 横断文書の置き場と、正の指し先 | `:24`, `:27` | 横断文書は `00_requirement/` / `10_spec/` の直下。節構成の正は `10_spec/skills/20-common-step-spec.md`、テンプレートは `assets/requirements.template.md` |

アプリの要件書（`docs/00_requirement/vscode-ticket-board.md`）と仕様書は実際には 1・3 と同じ形で書かれており、規定が後追いになっている。両ルールは「共通する規定は両方に書き、内容を食い違わせない」方針なので、4 件とも `design-docs` に書く。

## Q8: 拡張のビルド・テスト設定

| ファイル | 置き場を含む記述 | 移動の影響 |
|---------|----------------|-----------|
| `package.json` | `"main": "./out/src/extension.js"`、`"compile": "tsc -p ."`、`"test": "tsc -p . && node --test out/test/*.test.js"` | すべて拡張ルート相対。**影響なし** |
| `tsconfig.json` | `"outDir": "out"`、`"rootDir": "."`、`"include": ["src/**/*.ts", "test/**/*.ts"]` | 同上。**影響なし** |
| `.gitignore`（入れ子） | `node_modules/` `out/` | 同上。**影響なし** |
| `test/ticket.test.ts` | `path.join(__dirname, "..", "..", "test", "fixtures", …)` | 拡張ルート相対。**影響なし** |
| `README.md` | 5・6 行が要件・仕様へのリンク、30 行が「このディレクトリ（`src/vscode-ticket-board/`）で実行する」 | 文言の更新が要る |
| `src/core/{scan,board,render,ticket,frontmatter}.ts` | ヘッダコメントの `仕様: docs/10_spec/vscode-ticket-board.md`（計 6 行） | リポジトリルート相対からアプリルート相対に意味が変わる。更新が要る |

`src/vscode-ticket-board/` の中身をそのまま `apl/vscode-ticket-board/` へ持ち上げれば、`package.json` と `tsconfig.json` は無変更で通る。更新が要るのは README とソースのヘッダコメントの計 6 ファイル。

## Q9: 拡張のチケット走査のパス解決

- `src/core/scan.ts:16` — `export const TICKETS_DIR = path.join("wip", "10_tickets")`
- `src/core/scan.ts:37` — `path.join(workspaceRoot, TICKETS_DIR)`
- `src/board-panel.ts:41` — `vscode.workspace.workspaceFolders?.[0]`

ワークスペースフォルダ（VS Code で開いたフォルダ）を基点にしており、拡張ファイル自身の位置を参照していない。**移動しても壊れない。**

## フェーズ 2 に送る判断材料

| # | 決めること | 選択肢 | 調査からの推奨 |
|---|-----------|--------|--------------|
| 1 | アプリのディレクトリの形 | `apl/<アプリ名>/` をアプリのルートとし、既存の `src/` `test/` `package.json` をそのまま置き、`docs/` を足す | 推奨。ビルド設定を変えずに済む |
| 2 | `scope-limits.json` の新しい形 | `design` / `design-feedback` の `allow` を `apl/*/docs/**`、`implementation` の `allow` を `apl/*/src/**` `apl/*/test/**` などに割る。`implementation.allow` を `apl/**` にすると実装チケットがアプリ設計文書を書けてしまう | `apl/*/docs/**` と `apl/*/src/**` に分ける。照合器は対応できる（下記） |
| 3 | アプリ向け仕様書の 7 番目の節 | 「HTML の構造と CSP」のまま / 一般名に置き換え / 任意節 | 一般名 + 任意節。他アプリ種別に効かせるため |
| 4 | エラー識別子の台帳 | 仕様書が兼ねる（案 1）/ `apl/` 直下に横断台帳（案 2） | 案 1。あわせて `フック共通仕様.md` §6 に「アプリの接頭辞は対象外」を書くか決める |
| 5 | 「issue の受け入れ条件との対応」の置き場 | 8 章目（案 A）/ 概要の小節（案 B）/ 計画書（案 C） | 案 B。ルールの章順規定を変えずに済む。既存 46 件の扱いは別途 |
| 6 | 機械的検査 | 今回入れる / issue #24 に寄せる | 寄せる。申し送り 2 件（対象ルートが 2 つ・仕様書の形の検査は #24 のスコープ外）を付ける |
| 7 | `design-docs` に足す規定 | Q7 の 4 件 | 4 件とも足す。両ルールの「共通規定は両方に書く」方針に従う |
| 8 | `90_glossary/` を最初から置くか | 置く / 必要になってから | 必要になってから。空ディレクトリは git が追跡しない |

### 照合器の確認

`.claude/hooks/lib/scope.sh` の `scope_match` に新しい形のパターンを食わせて確かめた。

| パターン | パス | 結果 |
|---------|------|------|
| `apl/*/docs/**` | `apl/vscode-ticket-board/docs/10_spec/x.md` | yes |
| `apl/*/docs/**` | `apl/vscode-ticket-board/src/core/scan.ts` | no |

照合器側の変更は要らない。

## 調査で決められなかったこと

| 項目 | 理由 | 決める場所 |
|------|------|-----------|
| 既存 46 件の要件書が案 B の小節を持たない状態をどう扱うか | issue #8 のスコープと重なる | フェーズ 2。設計で「新規・更新時のみ適用」と決められる |
| `フック共通仕様.md` §6 に「アプリの接頭辞は対象外」を書くか | 台帳の適用範囲は機構側の設計判断で、調査では決められない | フェーズ 2 |
| #24 のスコープ外（仕様書の形の検査）をどこで担うか | #24 のスコープを広げるか別 issue かは人間の判断 | フェーズ 5（フィードバック計画） |

## うまくいったこと

- `grep -P` の否定先読みで `.claude/docs/` と裸の `docs/` を分離でき、対象を 13 ファイルまで絞り込めた
- 拡張のビルド設定が拡張ルート相対だったため、移動の影響が 6 ファイルに収まることが分かった
- `scope_match` に新しいパターンを実際に食わせ、照合器側の変更が不要であることを確かめた

## うまくいかなかったこと

- 初版は「6 分類・のべ 30 ファイル」と書いたが、表の内訳（7 分類・45 ファイル）と一致していなかった。敵対的レビューで検出された
- 初版は Q1 に行番号と現在の記述を入れておらず、調査計画「成果物の形」の要求と、チケット 0003 の DoD 1 を満たしていなかった
- 初版は拡張ソース 5 ファイルのヘッダコメントを見落とし、「置き場の記述を持つのは README とフィクスチャの 2 件」と書いていた。`docs/10_spec` を検索語に含めていなかったため
- 初版は「#24 が #20 の条件 5 を完全に含む」と書いたが、#24 のスコープ外を読んでいなかった
- 初版は F 行でマージ済み DDR に「本文の追随」を割り当てており、`design-docs` ルールと issue の受け入れ条件の両方に反していた
- issue #20 の本文が DDR `i0013-02` の節名を「画面（HTML）の構造」と誤って要約していた。issue を正としていたら節名を取り違えていた

## 残課題

- なし（フェーズ 2 に送る判断材料 8 件と、決められなかったこと 3 件はいずれも後続フェーズで決まる）
