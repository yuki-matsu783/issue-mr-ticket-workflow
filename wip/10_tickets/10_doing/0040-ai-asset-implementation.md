---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0039"]
executor: main
human_review: {required: false, reason: "承認③により人間レビューは敵対的レビューで代替する"}
adversarial_review: {required: false, reason: "実装フェーズの敵対的レビューは上限 2 回に達している（その指摘への対応そのもの）"}
allow:
  write: [".claude/skills/10-task-feedback-plan/**", ".claude/skills/10-task-design-plan/**", ".claude/skills/10-task-design-exec/**", ".claude/skills/10-task-design-feedback-plan/**", ".claude/skills/10-task-design-feedback-exec/**", ".claude/skills/10-task-implementation-plan/**", ".claude/skills/10-task-implementation-exec/**", ".claude/skills/10-task-ai-asset-design-plan/**", ".claude/skills/10-task-ai-asset-design-exec/**", ".claude/skills/10-task-ai-asset-implementation-plan/**", ".claude/skills/10-task-ai-asset-implementation-exec/**", ".claude/skills/00-workflow-quick-request/**", ".claude/skills/20-common-step-issue/**", ".claude/agents/**", ".claude/rules/**", "logs/**", "wip/**"]
  ops: ["read", "build-test", "hook-test", "remote-read"]
started_at: "2026-09-04T14:21:59+09:00"
completed_at: ""
base_sha: "01382a5"
---

# 0040 S15 文書側の指摘 8 件（敵対的レビュー 2 回目）

## 目的

スキル・エージェント・ルール・レポートの文言と参照の食い違いを直し、正が 2 つに見える状態を消す

## DoD

- [x] 10-task-feedback-plan の類型の文言が機構の定義（00_requirement/自己改善ワークフロー機構.md）と 00-workflow-quick-request と同一になっている（根拠: 「(a) アセットが無かった / (b) あったが誤っていた / (c) あったが罠が書かれていなかった / (d) あったのに辿り着けなかった」に統一。機構の定義 131 行目と quick-request の 69 行目と同じ文字列）
- [x] 10 本のスキルの冒頭が共通手順の禁止事項を部分再掲せず、正への参照だけになっている（根拠: `grep -h '共通手順の禁止事項' .claude/skills/10-task-*/SKILL.md` の出力が 2 種類（`10-task-investigation-plan の冒頭が正` 5 本 / `10-task-investigation-exec の冒頭が正` 5 本）だけ）
- [x] 移設した issue-triage.md を指す参照が .claude/ 配下にある（20-common-step-issue の参照節）（根拠: `20-common-step-issue/SKILL.md` の参照節に「類似 / 関連 / 無関係の判定基準と検索コマンド集: `references/issue-triage.md`」を追加）
- [x] task-executor の手順に「文脈が足りなければ推測せず結果報告に書いて終える」が書かれている（eval TXE-E02 と整合）（根拠: 手順 2 の末尾に「これらのいずれかが起動プロンプトに無いときは、環境情報や推測で補わずに実施を始めない。何が足りないかを結果報告の『拒否・不整合』に書いて終える」を追加）
- [x] work-defaults の frontmatter（description・applies_when・keywords）が敵対的レビュアーのモデルの節を含んでいる（根拠: description に「敵対的レビュアーの既定モデルと実施回数の上限、実行者と一致したときの差し替え」、applies_when に「タスクの切れ目で敵対的レビュアーを起動しモデルを選ぶとき」、keywords に レビュアー / モデル差し替え / 実施回数の上限、tags に adversarial-review を追加）
- [x] 00-workflow-quick-request のヘッドレス節が仕様の手順番号に依存しない書き方になっている（根拠: 「手順 0-3・1-2・1-3・3-2・5-3 の確認を行わず」を「`AskUserQuestion` で待つ確認をすべて行わない（…4 つを列挙）」に書き換えた）
- [x] 実装結果レポートの対象チケットが実体（0024〜0032・0035〜0039）に直り、0034 の取り消しと 0037 への置き換えが 1 行書かれている（md と HTML の両方）（根拠: 冒頭の「チケット」を「0024〜0032・0035〜0040」に直し、0034 の取り消しの経緯（`--allow-write` の渡し方を誤り、WF208 で着手後の書き換えができなかった）をサマリに 1 段落で書いた。HTML も同じ内容を meta と lead に反映）
- [x] 実装結果レポートの HTML が md と同じ内容を言っている（e9 の解消済みの一文を含む）。check-html.sh が通る（根拠: e9 の解消済みの一文・e14・e15・検証の結果 4 行・設計への反映 3 行・残課題 R10〜R12 を HTML に反映。`OK: 検査 7 項目すべて通過（id 29 件 / リンク 22 件を確認。テンプレート: report）`）
- [x] （追加）S13〜S15 の後の全件テストが通っている（根拠: `run-tests.sh --ids --timeout 300` が `OK: 27 本 / 212 件`、FAIL ID 0 件、アサーション 2,335 件 / 失敗 0 件、重複 ID なし）

## 作業内容

- DoD の各項目を順に満たす

## 作業ログ

### 現在地

- 完了（文書 6 件・レポート 2 件を反映。全件テスト 27 本 / 212 件 / 2,335 アサーションが失敗 0）

### うまくいったこと

- 8 件のうち 6 件が「同じことを 2 か所に書いたら片方が古くなった」形だった（類型の文言・禁止事項の部分再掲・frontmatter と本文・仕様の手順番号への依存）。**参照に置き換える**という同じ直し方で揃った
- 部分再掲をやめたことで、共通手順の禁止事項を増やすときに 10 か所を同期する必要が消えた

### うまくいかなかったこと

- `issue-triage.md` は 0031 で「移設した」と書いたが、**参照を移していなかった**ので誰も辿り着けない状態だった。ファイルを置いた時点で移設が終わったと考えたのが誤り

### 仕様からの逸脱

- なし（文書の文言と参照の修正のみ。振る舞いは変えていない）

### 判断と根拠

- **類型は機構の定義に寄せた**: 3 か所（機構の要件・quick-request・feedback-plan）のうち 2 か所が同じで、feedback-plan だけが省略形だった。多数決ではなく「機構の要件が正」で決めた
- **禁止事項の括弧は列挙をやめて参照だけにした**: 部分集合を書くと、その本だけを読んだときに「共通の禁止事項はこれで全部」に見える。正が 10 通りに分裂するので、短く書く利点より害が大きい
- **ヘッドレス節は番号ではなく中身で書いた**: 仕様と SKILL で手順の粒度が違う（仕様の 1 と 2 が SKILL では 1 つ）ので、番号で参照する限りずれ続ける。「`AskUserQuestion` で待つ確認をすべて行わない」と書けば粒度が変わっても壊れない
- **e9 の △注意はそのまま残した**: 節はチケットの時点の状態を書くもので、後から良くなったことは「解消済み」の一文で示す。過去の節を書き換えると、なぜ 0036 が起きたか読めなくなる

### 拒否・確認・迂回の記録

- 無し

### 使った AI アセットと効き目

- 敵対的レビュアー（2 回目・文書担当）: 「参照が 1 つも無い」「frontmatter が古い」といった、書いた本人には見えにくい種類の指摘が出た。まとめの主張 12 件の抜き取り検証も付いていて、レポートの数値を独立に確かめられた

### スコープ外で見つけたこと

- 仕様側（`10_spec/skills/10-task-feedback-plan.md` 49 行目）にも省略形の類型が残っている。`.claude/docs/` はこのチケットの許可範囲外なので設計反映へ送る

### AI アセットに反映すべき内容

- 仕様の類型の文言を機構の定義に揃える（設計反映）
- 「移設」の完了条件に「参照も移す」を含める（ファイルを置いただけでは移設ではない）

### 備考
