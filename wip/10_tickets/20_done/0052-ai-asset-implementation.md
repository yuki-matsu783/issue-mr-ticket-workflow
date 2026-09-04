---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0051"]
executor: main
human_review: {required: false, reason: "承認③により人間レビューは敵対的レビューで代替する"}
adversarial_review: {required: false, reason: "中核を含まない文書の追随で、機械テストの対象ではない（eval の定義は既存のまま）"}
allow:
  write: [".claude/skills/00-workflow-issue-mr-driven/SKILL.md", ".claude/skills/10-task-investigation-plan/SKILL.md", ".claude/skills/10-task-investigation-exec/SKILL.md", ".claude/skills/10-task-ai-asset-design-exec/SKILL.md", ".claude/skills/10-task-ai-asset-implementation-plan/SKILL.md", ".claude/skills/10-task-overall-plan/SKILL.md", ".claude/skills/10-task-overall-summary/SKILL.md", ".claude/skills/10-task-feedback-plan/SKILL.md", "wip/**"]
  ops: ["read", "remote-read"]
started_at: "2026-09-04T17:28:38+09:00"
completed_at: "2026-09-04T17:39:08+09:00"
base_sha: "ec41fc1"
---

# 0052 ワークフロー・タスクスキル 8 本の SKILL.md を仕様に追随させる（S3）

## 目的

設計フェーズが仕様に足した手順・規約の要約を、対応する SKILL.md に写す

## DoD

- [x] 00-workflow-issue-mr-driven/SKILL.md に、敵対的レビュアーの起動にブランチ名を渡すこと・観点に必須節の実在を含めること・既定のモデルが使えないときの代替・BD006 の案内がある（根拠: 手順 2a の 2 に但し書き 4 つ（ブランチ名・必須節の実在・モデルの突き合わせ・既定のモデルが使えないとき）を並べた。エラー表に `BD006`（終了コード 2）の行と敵対的レビュアーが起動できないときの行を足し、冒頭の仕様の参照範囲を `BD001〜BD006` に直した）
- [x] 10-task-investigation-plan/SKILL.md に、DoD に書くコマンドの形を確かめることと保留の書き方 2 項目がある（根拠: 共通手順 4 に「DoD にコマンドを書くときは `--help` か仕様で形を確かめる」の但し書き。共通手順の後の箇条書きに「保留の書き方」（何が未決か / 現行の記述 / 誰がいつ決めるか）と「既に満たされていないかを先に確かめる」の 2 項目）
- [x] 10-task-investigation-exec/SKILL.md に、過去の節を書き換えないこと・表に載せきれない対象は表に行を足すこと・成果物の形を読み返すことがある（根拠: 共通手順 4（レポート）の但し書きに 3 項目を追加。仕様の共通 4 の但し書き 3 件と 1:1）
- [x] 10-task-ai-asset-design-exec/SKILL.md に、着手時に ai-asset-design-docs を読むこと・採番と観点の定義を同じチケットで済ませること・旧名のセルフレビューがある（根拠: 固有手順の先頭に `ai-asset-design-docs` を読む項目、書き終わりの検査の前後に採番と定義の項目・旧名のセルフレビューの項目）
- [x] 10-task-ai-asset-implementation-plan/SKILL.md に、削除対象を allow.write に含めること・run-tests.sh --filter のグロブの形・実測値は調査フェーズの値を使うこと・ロックアウト対策が変更箇所を踏むことがある（根拠: 固有手順に 4 項目を追加。あわせて OUT ひな形の「ロックアウト対策」の行に「その対策を守るテスト ID × 踏む判定」を足した）
- [x] 10-task-overall-plan/SKILL.md に前 issue の作業領域が default に残っている場合の扱いがあり、10-task-overall-summary/SKILL.md に進行状態の branch・--linked の前提・draft の 3 値・FN004 がある（根拠: overall-plan は手順 4 に但し書き 2 件（残骸の確認・承認と保留した点への記録）。overall-summary は再開の節に `branch` と draft の 3 値、CLI が使えない環境の段階 4 に `--linked` は `recorded` のときだけ、エラー表に `FN004`、冒頭の参照範囲を `FN001〜FN004` に）
- [x] 10-task-feedback-plan/SKILL.md の類型の文言が機構の定義と同一で、消し込み表の記載がある（根拠: 手順 3 の類型は `(a) アセットが無かった` から `(d) あったのに辿り着けなかった` まで既に定義と同一だったので変更なし。手順 2 に「抽出と集約を消し込み表で繋ぐ」の但し書き、OUT ひな形に「消し込み表」の行を追加）
- [x] 8 本それぞれについて、仕様書の該当節と 1:1 で対応することを根拠（仕様のファイルと節）付きで示している（根拠: レポートの e5 の表に、8 本 × 足した内容 × 仕様の該当箇所を 1 行ずつ書いた。右列がそのまま `.claude/docs/10_spec/skills/<同名>.md` の節を指す。追加は 18 項目）
- [x] プレースホルダ・frontmatter の検査が 0 件。実装結果レポートに S3 の節が追記されている（根拠: 8 本の二重波括弧は 3 本に計 3 か所あるが、すべて「DoD の型」のひな形として意図的に置かれている既存の記述で、このチケットで増やしていない。frontmatter は 8 本とも `---` で始まり `name` と `description` を持つ。レポートは e5 を追記し `OK: 検査 7 項目すべて通過（id 19 件 / リンク 12 件を確認。テンプレート: report）`）

## 作業内容

- 8 本の SKILL.md を順に直す

## 作業ログ

### 現在地

- 完了（SKILL.md 8 本の追随とレポートへの S3 の追記まで済み）

### うまくいったこと

- 8 本とも「仕様の該当節を開いて、そこから要約を写す」だけで足りた。SKILL.md 側で言い換えや新しい概念を作らなかったので、1:1 の対応表が後から機械的に書けた
- 足す位置が仕様の構造でほぼ決まっていた（処理フローの但し書きは対応する手順の直下、識別子はエラー表）。位置に迷った箇所は無い
- `10-task-feedback-plan` の類型の文言は既に定義と同一で、変更が要らないことを確かめるだけで済んだ

### うまくいかなかったこと

- 無し

### 仕様からの逸脱

- 無し

### 判断と根拠

- 仕様の但し書きをそのまま貼らず、SKILL.md の他の項目と同じ長さ（1〜3 文）に詰めた。SKILL.md は常に読まれる要約で、仕様書が正という関係を保つため
- `10-task-ai-asset-implementation-plan` は手順の 4 項目だけでなく OUT ひな形の「ロックアウト対策」の行も直した。ひな形の列が古いままだと、計画書を書く側が「テスト ID × 踏む判定」の列を作らないため
- `--filter` の項目は既存の「テスト ID の割付表は機械的に作る」の近くではなく、DoD の型のすぐ前に置いた。DoD にコマンドを書く場面で読まれる位置にしたかったため

### 拒否・確認・迂回の記録

- 無し（このチケットの許可範囲は 8 本の SKILL.md と `wip/` で、範囲外への書き込みは発生していない）

### 使った AI アセットと効き目

- 各スキルの仕様書（`.claude/docs/10_spec/skills/`）: 追随させる内容の出どころ。「要件との対応」の表があるおかげで、どの但し書きが SKILL.md に要るかを探しやすかった
- `20-common-step-report-view`: レポートへの節の積み上げ方（過去の節を書き換えず追記する）

### スコープ外で見つけたこと

- 無し

### AI アセットに反映すべき内容

- 無し（このチケット自体がアセットへの反映）

### 備考

- 追加は合計 24 項目（数え方: レポート e5 の表の「足した内容」欄をスラッシュで区切った数）。内訳は 00-workflow 4 / investigation-plan 3 / investigation-exec 3 / ai-asset-design-exec 3 / ai-asset-implementation-plan 4 / overall-plan 2 / overall-summary 4 / feedback-plan 1
