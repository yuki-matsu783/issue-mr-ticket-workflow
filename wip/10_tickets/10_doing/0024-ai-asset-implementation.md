---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0023"]
executor: main
human_review: {required: false, reason: "承認③により人間レビューは敵対的レビューで代替する"}
adversarial_review: {required: false, reason: "実装フェーズの敵対的レビュー 2 回は中核のステップ（0025〜0027）と総仕上げ（0032）に割り当てる"}
allow:
  write: [".claude/skills/**", "wip/**"]
  ops: ["read", "remote-read"]
started_at: "2026-09-04T04:13:32+09:00"
completed_at: ""
base_sha: "9ec55d0"
---

# 0024 S1 設定・定義: テンプレート実体 15 件

## 目的

仕様の OUT ひな形が名前とパスで指定しているテンプレート 13 件と、レポート・計画書の md 共通テンプレート 2 件を作る

## DoD

- [x] assets/ のテンプレート 13 件が 0003 の a2 の表のパスに作成され、各仕様の OUT ひな形の節と対応している（根拠: 一覧と仕様の節）（根拠: 13 件を作成。うち 9 番だけは a2 の `attachment-comment.template.md` ではなく現行仕様の `summary-section.template.md`（設計フェーズの残課題 R4 で置き換え済み）。各ファイルの節はレポート e1 の 3 つの表で仕様の OUT ひな形と対応づけた）
- [x] md の共通テンプレート 2 件（report.template.md / plan.template.md）が 20-common-step-report-view の assets/ に作成されている（残課題 R6）（根拠: `.claude/skills/20-common-step-report-view/assets/report.template.md` と `plan.template.md`。節構成は同ディレクトリの HTML ビューのテンプレートと 1 対 1）
- [x] 全 15 件にプレースホルダの説明があり、frontmatter を持つものは markdown-docs ルールの項目に従っている（根拠: 15 件すべての冒頭に HTML コメントで「何を埋めるか」「どの節が必須か」「書き終わりにコメントを消すこと」を書いた。frontmatter を持つのは 3 件（`report.template.md` / `plan.template.md` / `overall-plan.template.md`）で、`type` / `title` / `description` / `tags` / `keywords` を置いた。**`markdown-docs` ルールは存在しない**ので、既存文書の慣行に合わせた（レポートの残課題 R1）。`TODO` / `TBD` の残存は 0 件）
- [x] 実装結果レポート wip/30_reports/0024-ai-asset-implementation.md と同名 HTML があり、check-html.sh が通っている（最初の実装チケットの DoD）（根拠: `OK: 検査 7 項目すべて通過（id 15 件 / リンク 8 件を確認。テンプレート: report）`）
- [x] テンプレートを使う側の仕様（各タスクスキルの OUT ひな形）と名前・パスが 1 件も食い違っていない（検索の出力を根拠に貼る）（根拠: `10_spec/skills` と `10_spec/agents` から `assets/*.template.md` を抽出すると 20 種。各名前を `find .claude/skills -path "*/<名前>"` に通して MISSING 0 件）

## 作業内容

- テンプレート実体 15 件を作る
- 実装結果レポートを作る（以降のチケットはここに節を足す）

## 作業ログ

### 現在地

- 完了。テンプレート 15 件と実装結果レポート（md + HTML）を作った

### うまくいったこと

- **仕様から名前を機械的に抽出できた**。`10_spec/` の `assets/*.template.md` を grep すると 20 種で、`find` と突き合わせるだけで作り漏れが 0 件だと示せた。数え上げを目視でやっていない
- **共通の型を先に作った**ので、種類ごとの 8 件は「足す節」だけを書けばよく、1 件あたりが短くなった

### うまくいかなかったこと

- レポートの HTML に二重波括弧のプレースホルダを説明として書いたら `check-html.sh` の RV001 に当たる形になった。説明を「二重波括弧で名前を囲む形式」と言い換えて回避した。テンプレートの説明を書くレポートでは、プレースホルダの記法を literal で書けない

### 仕様からの逸脱

- なし。ただし 0003 の a2 の表の 9 番（`attachment-comment.template.md`）は現行仕様に無いので、`summary-section.template.md` として作った。仕様が正（設計フェーズの残課題 R4 の決着）

### 判断と根拠

- **種類ごとのテンプレート 8 件を「共通の型に足す節だけ」の形にした**。`20-common-step-report-view` 仕様「テンプレートの置き場」が「共通の型を丸ごと複製せず『共通の型に加えてこの節を持つ』形で書く」と定めている。15 本が同じ節構成を逐語で持つと、節を 1 つ足すのに 15 か所を直すことになる
- **`overall-plan.template.md` だけは完成形にした**。全体計画書は HTML ビューを作らず 1 画面程度という仕様なので、共通の型（計画書の 8 節）を使わない
- **`summary-section.template.md` の「成果物」の表は骨格だけ**にした。行を手で書くと、`finalize.sh release` の段階 4 が中身を置き換えるときに人手の行と衝突する。空の表を `linked` と誤判定しないための固定マーカーの規定とも噛み合う
- **frontmatter は既存文書の慣行に合わせた**。`markdown-docs` ルールが規約の正とされているが `.claude/rules/` に存在しない。存在しないルールに従ったと書けないので、根拠を「既存文書の慣行」と明記して残課題に上げた

### 拒否・確認・迂回の記録

- なし（このチケットの許可範囲 `.claude/skills/**` と `wip/**` の中で完結した）

### 使った AI アセットと効き目

- `20-common-step-report-view` 仕様「テンプレートの置き場」: 共通の型と種類ごとの型の切り分けが一意に決まった。この規定が無ければ 15 本の複製を作っていた
- `20-common-step-report-view/scripts/check-html.sh`: レポート HTML のプレースホルダ残存を検出した（説明として書いた二重波括弧を拾った）

### スコープ外で見つけたこと

- **`markdown-docs` ルールが存在しない**。`design-docs` と `ai-asset-design-docs` の 2 本が frontmatter の規約とアセット本体の書き方の正として参照しているが、`.claude/rules/` にも `00_requirement/rules/` にも無い。フィードバック計画（0033）へ

### AI アセットに反映すべき内容

- テンプレートを使う側の SKILL.md に「種類ごとのテンプレートは共通の型に足す節だけを持つ」ことを書く。1 枚コピーして完成と誤解する余地がある（S6 で反映する。レポートの「設計への反映」1 番）

### 備考

- テンプレートそのものにはプレースホルダが残っているのが正しい（プレースホルダ 0 件の検査は、テンプレートから作った成果物に対する検査）
