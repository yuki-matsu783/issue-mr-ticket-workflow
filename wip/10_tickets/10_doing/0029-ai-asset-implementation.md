---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0028"]
executor: main
human_review: {required: false, reason: "承認③により人間レビューは敵対的レビューで代替する"}
adversarial_review: {required: false, reason: "中核を含まず、実装フェーズの敵対的レビュー 2 回は中核（0025〜0027）と総仕上げ（0032）に割り当てる"}
allow:
  write: [".claude/skills/**", ".claude/agents/**", "wip/**"]
  ops: ["read", "remote-read"]
started_at: "2026-09-04T12:00:20+09:00"
completed_at: ""
base_sha: "1ad6389"
---

# 0029 S6 スキル・エージェント: タスクスキル 15 本 + エージェント 2 本

## 目的

各仕様の OUT ひな形・定義ひな形から SKILL.md 15 本とエージェント定義 2 本を作り、機構が type からスキルを引ける状態にする

## DoD

- [x] 10-task-* の SKILL.md 15 本が .claude/skills/<スキル名>/SKILL.md に作成され、対応する仕様書の処理フロー・OUT ひな形・参照ナレッジと 1:1 で対応している（根拠: 15 本を作成。各 SKILL.md の「目的」に対応する要件・仕様のパスを書き、「手順」は仕様の処理フロー（計画型は共通手順 1〜7 + 固有手順、実施型は共通手順 1〜6 + 固有手順、overall-plan は 1〜10、overall-summary は 1〜10 + release の 8 段階）、「OUT ひな形」は仕様の同名節、「参照」は参照ナレッジに対応させた）
- [x] エージェント定義 2 本（task-executor / adversarial-reviewer）が .claude/agents/ に作成され、仕様の定義ひな形（model・tools・プロンプト）のとおりになっている（根拠: `task-executor.md` は `tools: Read, Glob, Grep, Edit, Write, MultiEdit, Bash, Skill, WebFetch, WebSearch` / `model: inherit`、`adversarial-reviewer.md` は `tools: Read, Glob, Grep` / `model: claude-fable-5-1`。本文は仕様のひな形の括弧書きの並び（役割 / 禁止事項 / 手順 / 出力スキーマ）どおり）
- [x] 各 SKILL.md の frontmatter（name・description）が ai-asset-authoring ルールに従い、description が呼び出しの判断に足りる語を含んでいる（根拠: `grep -c "^name:\|^description:"` が 15 本すべて 2。`type` / `title` / `tags` / `keywords` の混入は grep で 0 件。description は「何をするか」+ `Use when ticket.sh next returns type "<type>"` の発火条件を含む）
- [x] 共通手順を持つスキルが手順を再掲せず、正（10-task-investigation-plan / 10-task-investigation-exec）を参照している（0003 の a9）（根拠: 計画型 5 本（design-plan・implementation-plan・design-feedback-plan・ai-asset-design-plan・ai-asset-implementation-plan）と実施型 5 本（design-exec・implementation-exec・design-feedback-exec・ai-asset-design-exec・ai-asset-implementation-exec）は「手順」の冒頭で正を指し、固有部分だけを書いている。共通手順の本文を持つのは investigation-plan と investigation-exec の 2 本だけ）
- [x] task-types.tsv のスキル名列 15 行すべてに対応するディレクトリが存在する（ls での突合の出力を根拠に貼る）（根拠: `task-types.tsv` の 5 列目 15 行と `.claude/skills/10-task-*/SKILL.md` の一覧を `diff` で突合し差分 0 行。「一致: 15 行すべてに SKILL.md あり」）
- [x] 分量が 1 枚に収まらないと判断して 2 枚に割った場合、計画書 0017 のステップ表を同じチケットの中で書き直している（記述順と実行順の一致）（根拠: 割っていない。1 枚で 15 本 + エージェント 2 本を作り切ったので書き直しは不要）

## 作業内容

- タスクスキル 15 本の SKILL.md を作る
- エージェント定義 2 本を作る

## 作業ログ

### 現在地

- 完了

### うまくいったこと

- 共通手順の正を 2 本（`10-task-investigation-plan` / `10-task-investigation-exec`）に集約したので、残り 10 本は固有手順だけになり 1 本あたり 60〜120 行に収まった。共通手順を 15 本に複製していたら、手順を 1 つ足すのに 15 か所を直すことになっていた
- `description` の発火条件を `Use when ticket.sh next returns type "<type>"` の形で揃えた。機構が type からスキルを引くので、日本語のタスク名ではなく type の文字列が入っているほうが確実に引ける
- 冒頭段落を「禁止事項の要約」にする雛形の指定は、計画型・実施型とも「共通手順の禁止事項に加えて」で始める形にできた。読み手は共通側を読みに行けばよいと分かる

### うまくいかなかったこと

- 実施型 6 本の「OUT ひな形」に `assets/<種類>.template.md` と書いたが、実施型は固有のテンプレートを持たず `20-common-step-report-view` のレポートテンプレートをそのまま使う（各仕様の OUT ひな形節がそう書いている）。存在しないファイルを指していたので 6 本とも書き直した。0024（S1）で作ったテンプレート 15 件の内訳（計画型 8 + 全体計画 1 + 統括節 1 + ワークフロー 4 + 共通の型 2）を先に確かめるべきだった

### 仕様からの逸脱

- なし

### 判断と根拠

- 15 本を 1 枚のチケットで作り切った。分割すると後半のチケットが前半の SKILL.md を前提に書くことになり、参照先の再読を DoD に足す必要が出る（`10-task-ai-asset-design-exec` 仕様の申し送り 0022 E5）。共通手順が 2 本に集約されている構造なら 1 枚で収まると判断した
- エージェント定義の `model` は仕様の指定どおりに分けた。`task-executor` は `inherit`（実行者がチケットごとに変わる）、`adversarial-reviewer` は `claude-fable-5-1` 固定（実行者と別のモデルであることが敵対的レビューの値）
- `tools` に `AskUserQuestion` と `Agent` を書かないことで、「ユーザーに質問しない」「サブエージェントを入れ子にしない」を機械的に担保した。定義本文の禁止事項は多重防御として残した

### 拒否・確認・迂回の記録

- `run-tests.sh` の実行が TR006 で止まった（このチケットの `allow.ops` は `read` / `remote-read` のみで `build-test` / `hook-test` が無い）。DoD にテスト実行は含まれないので、範囲を広げず `diff` と `grep` による突合で根拠を作った。迂回はしていない
- `for ... read` を含むコマンドが WF204 で止まった。`read` は分類に無いので、`for f in ...` と `diff` に書き換えて対処した

### 使った AI アセットと効き目

- `20-common-step-ai-asset-creator` の `assets/skill.template.md`: 冒頭段落を禁止事項の要約にする順序と、frontmatter を 2 項目に絞る規約が明示されていたので、15 本の形が最初から揃った
- 各タスクの仕様書の「処理フロー」「OUT ひな形」「参照ナレッジ」の節構成: SKILL.md の節にそのまま写せる形になっており、対応の確認が節単位でできた

### スコープ外で見つけたこと

- 実施型 6 本のスキルディレクトリには `assets/` が無い（レポートテンプレートを共有するため）。これは仕様どおりだが、`20-common-step-ai-asset-creator` の標準構成は `assets/` を必須のように読める。「共有する場合は持たない」を明記すると迷いが減る

### AI アセットに反映すべき内容

- 上記の `assets/` 任意の明記を設計反映フェーズで `20-common-step-ai-asset-creator` の仕様に入れる

### 備考

- allow.write は `.claude/skills/**` / `.claude/agents/**` / `wip/**`。この範囲だけを触った
